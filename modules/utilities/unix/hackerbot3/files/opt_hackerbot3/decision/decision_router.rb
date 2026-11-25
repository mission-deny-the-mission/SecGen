require 'net/http'
require 'json'
require 'uri'
require 'thread'
require 'time'
require_relative '../print.rb'

# DecisionRouter: answers a student's catch-all message with a canned lab-help response,
# or tells the caller to fall through to the LLM.
#
# Where it plugs in: ONLY the catch-all fallback in BotManager#create_bot, after every
# deterministic handler (hello/help/next/goto/answer/ready/...). It never sees quiz answers,
# flags, attack prompts or anything that marks a student, and the pairs file must not contain
# them either.
#
# How it decides (the System One "decision model" pipeline):
#   1. Candidates = the canned questions for this bot's lab (pairs file, filtered by lab).
#   2. Optional shortlist: an OpenAI-compatible embedding server ranks the candidates and only
#      the top `shortlist_k` go to the decision model (cuts prefill time on big labs).
#   3. One `choice` question to a decision model (Clef-Flash etc.) at POST /v1/systemone over
#      the candidates plus an explicit `escalate` option (always last).
#   4. Gate on the TOP option's own probability: serve the canned answer only if the top option
#      is not `escalate` and p >= threshold; otherwise escalate to the LLM.
#   5. Optional answer-fit check (fit_check): ask the decision model once more whether the chosen
#      canned ANSWER answers what the student actually asked. Catches topic-level matches
#      ("what are the arguments for chattr" -> "what is chattr"). Below fit_threshold -> escalate.
#      Costs one small extra call (~50-70 ms) on canned answers only.
#
# Strategies:
#   full       every candidate goes to the decision model (no embedder needed)
#   shortlist  embedder top-K only
#   twopass    embedder top-K first; if that says escalate or p < threshold, ask again with the
#              full list (same answers as `full`, usually faster). Needs an embedder; without
#              one it behaves as `full`.
#
# Any error (network, timeout, bad JSON) means ESCALATE: the router must never make the bot worse
# than the plain LLM fallback. After `breaker_failures` consecutive failures it stops calling the
# servers for `breaker_cooldown` seconds.
class DecisionRouter
  ESCALATE = 'escalate'.freeze
  EMBED_INSTRUCT = "Given a student's message to a security-lab chatbot, retrieve the canned question that asks the same thing".freeze
  DEFAULT_INSTRUCTIONS = "Which canned question is the student asking? Pick the option whose question asks the same " \
                         "thing as the student's message. If no option asks the same thing, pick 'escalate'.".freeze
  DEFAULT_ESCALATE_DESC = "None of the above: a question not covered by any other option, small talk, " \
                          "or anything the other options do not answer".freeze
  STRATEGIES = %w[full shortlist twopass].freeze
  MAX_MESSAGE_CHARS = 500
  FIT_INSTRUCTIONS = 'Does candidate_answer directly answer what the student asked in user_message?'.freeze
  # Pair tiers the answer-fit check skips. challenge_adjacent answers are deliberate refusals or redirects
  # ("can you give me the flag?" -> "no, but..."): they never "answer what was asked", so the check would
  # always send them to the LLM, which is the opposite of why they were written.
  FIT_SKIP_TIERS = %w[challenge_adjacent].freeze
  FIT_CRITERIA = { 'answers' => 'Yes: it answers the specific question asked',
                   'off' => 'No: it is only on a related topic, or misses what was specifically asked' }.freeze

  Result = Struct.new(:action, :pair_id, :answer, :tier, :probability, :strategy, :second_pass,
                      :latency_ms, :reason, :top_other, :fit, keyword_init: true) do
    def canned?
      action == :canned
    end
  end

  attr_reader :lab, :threshold, :strategy, :timeout, :fit_check, :fit_threshold

  # @param opts [Hash]
  #   :pairs_file, :lab (required)           pairs JSON and the lab id whose pairs are candidates
  #   :url (required)                        decision model base URL (serves /v1/systemone)
  #   :model                                 model name sent in the request (vLLM wants one; llama.cpp ignores it)
  #   :threshold (0.5)                       top-option probability needed to serve a canned answer
  #   :strategy ('twopass')                  full | shortlist | twopass
  #   :embed_url, :embed_model               embedding server (/v1/embeddings); enables shortlist/twopass
  #   :shortlist_k (8)
  #   :timeout (4.0)                         seconds per HTTP call (raise it for big classes: under a burst
  #                                          requests queue at the decision model; see decision/README.md)
  #   :fit_check (false)                     answer-fit check on canned matches (step 5)
  #   :fit_threshold (0.25)                  p('answers') needed to keep the canned answer
  #   :api_key                               optional bearer token for url/embed_url (e.g. a LiteLLM key
  #                                          when the servers are reached through LiteLLM pass-through routes)
  #   :breaker_failures (5), :breaker_cooldown (30)
  #   :log_path                              optional JSONL decision log (stores student messages: off by default)
  #   :http_post                             injectable lambda(url, body, timeout) -> parsed JSON (tests)
  def initialize(opts)
    @lab = opts.fetch(:lab).to_s
    @url = opts.fetch(:url).to_s.chomp('/')
    @model = opts[:model]
    @threshold = (opts[:threshold] || 0.5).to_f
    @embed_url = opts[:embed_url] && !opts[:embed_url].to_s.empty? ? opts[:embed_url].to_s.chomp('/') : nil
    @embed_model = opts[:embed_model]
    @shortlist_k = (opts[:shortlist_k] || 8).to_i
    @timeout = (opts[:timeout] || 4.0).to_f
    @breaker_failures = (opts[:breaker_failures] || 5).to_i
    @breaker_cooldown = (opts[:breaker_cooldown] || 30).to_f
    @log_path = opts[:log_path]
    @api_key = opts[:api_key].to_s.empty? ? nil : opts[:api_key].to_s
    @fit_check = %w[1 true yes on].include?(opts[:fit_check].to_s.strip.downcase)
    @fit_threshold = (opts[:fit_threshold] || 0.25).to_f
    @http_post = opts[:http_post] || method(:default_http_post)

    strategy = (opts[:strategy] || 'twopass').to_s
    raise ArgumentError, "unknown decision strategy '#{strategy}'" unless STRATEGIES.include?(strategy)
    # shortlist/twopass without an embedder degrade to full rather than failing at message time
    @strategy = (@embed_url.nil? && strategy != 'full') ? 'full' : strategy

    load_pairs(opts.fetch(:pairs_file))
    @mutex = Mutex.new
    @pair_vectors = nil
    @failures = 0
    @open_until = 0.0
  end

  def pair_count
    @pairs.length
  end

  def pair_ids
    @pairs.keys
  end

  # Decide what to do with one student message. Never raises.
  def route(message)
    t0 = monotonic
    text = message.to_s.strip[0, MAX_MESSAGE_CHARS]
    return finish(escalate_result('empty message', t0), text) if text.empty?
    if monotonic < @open_until
      return finish(escalate_result('circuit open', t0), text)
    end

    begin
      result = decide(text, t0)
      @mutex.synchronize { @failures = 0 }
    rescue StandardError => e
      note_failure
      Print.err "DecisionRouter (#{@lab}): #{e.class}: #{e.message}; escalating to the LLM"
      result = escalate_result("error: #{e.class}", t0)
    end
    finish(result, text)
  end

  private

  def decide(text, t0)
    ids = @pairs.keys
    second_pass = false
    probs = nil

    case @strategy
    when 'full'
      probs = ask(text, ids)
    when 'shortlist'
      probs = ask(text, shortlist(text))
    when 'twopass'
      probs = ask(text, shortlist(text))
      if escalating?(probs)
        probs = ask(text, ids)
        second_pass = true
      end
    end

    top_id, top_p = probs.max_by { |_, p| p }
    other_id, = probs.reject { |k, _| k == ESCALATE }.max_by { |_, p| p }
    latency = ((monotonic - t0) * 1000).round
    if top_id.nil? || top_id == ESCALATE || top_p < @threshold || !@pairs.key?(top_id)
      return Result.new(action: :escalate, pair_id: nil, probability: top_p, strategy: @strategy,
                        second_pass: second_pass, latency_ms: latency, top_other: other_id,
                        reason: top_id == ESCALATE ? 'model chose escalate' : 'below threshold')
    end
    pair = @pairs[top_id]
    fit = nil
    if @fit_check && !FIT_SKIP_TIERS.include?(pair['tier'])
      fit = answer_fit(text, pair['a'])
      latency = ((monotonic - t0) * 1000).round
      if fit < @fit_threshold
        return Result.new(action: :escalate, pair_id: nil, probability: top_p, strategy: @strategy,
                          second_pass: second_pass, latency_ms: latency, top_other: top_id, fit: fit,
                          reason: 'answer does not fit')
      end
    end
    Result.new(action: :canned, pair_id: top_id, answer: pair['a'], tier: pair['tier'], probability: top_p,
               strategy: @strategy, second_pass: second_pass, latency_ms: latency, fit: fit, reason: 'matched')
  end

  # Probability that `answer` directly answers `text` (step 5). Errors propagate (-> escalate).
  def answer_fit(text, answer)
    body = {
      'state' => { 'user_message' => text, 'candidate_answer' => answer.to_s },
      'questions' => { 'fit' => { 'type' => 'choice', 'instructions' => FIT_INSTRUCTIONS, 'criteria' => FIT_CRITERIA } }
    }
    body['model'] = @model if @model && !@model.to_s.empty?
    a = @http_post.call("#{@url}/v1/systemone", body, @timeout).dig('answers', 'fit') or
      raise 'decision model returned no fit answer'
    probs = a['probabilities'] || {}
    return probs['answers'].to_f unless probs.empty?
    a['choice'] == 'answers' ? 1.0 : 0.0
  end

  def escalating?(probs)
    top_id, top_p = probs.max_by { |_, p| p }
    top_id.nil? || top_id == ESCALATE || top_p < @threshold
  end

  def escalate_result(reason, t0)
    Result.new(action: :escalate, strategy: @strategy, second_pass: false,
               latency_ms: ((monotonic - t0) * 1000).round, reason: reason)
  end

  # ---- pairs -------------------------------------------------------------------------------

  def load_pairs(path)
    data = JSON.parse(File.read(path))
    @instructions = data['instructions'] || DEFAULT_INSTRUCTIONS
    @escalate_desc = data['escalate_desc'] || DEFAULT_ESCALATE_DESC
    @pairs = {}
    (data['pairs'] || []).each do |p|
      next unless Array(p['labs']).include?(@lab)
      raise ArgumentError, "pair id '#{ESCALATE}' is reserved" if p['id'] == ESCALATE
      @pairs[p['id']] = p
    end
    raise ArgumentError, "no pairs for lab '#{@lab}' in #{path}" if @pairs.empty?
  end

  # ---- decision model ----------------------------------------------------------------------

  # Returns {option_id => probability}, escalate included.
  def ask(text, ids)
    criteria = {}
    ids.each { |id| criteria[id] = @pairs[id]['q'] }
    criteria[ESCALATE] = @escalate_desc # escalate stays last, as in the measured configuration
    body = {
      'state' => { 'user_message' => text },
      'questions' => { 'best_match' => { 'type' => 'choice', 'instructions' => @instructions, 'criteria' => criteria } }
    }
    body['model'] = @model if @model && !@model.to_s.empty?
    answer = @http_post.call("#{@url}/v1/systemone", body, @timeout).dig('answers', 'best_match') or
      raise 'decision model returned no best_match answer'
    probs = (answer['probabilities'] || {}).transform_values(&:to_f)
    probs = { answer['choice'] => 1.0 } if probs.empty? && answer['choice']
    raise 'decision model returned no probabilities' if probs.empty?
    probs
  end

  # ---- embedder shortlist ------------------------------------------------------------------

  def shortlist(text)
    return @pairs.keys if @embed_url.nil?
    vecs = pair_vectors
    q = embed(["Instruct: #{EMBED_INSTRUCT}\nQuery:#{text}"]).first
    scored = vecs.map { |id, v| [id, dot(q, v)] }
    scored.sort_by { |_, s| -s }.first(@shortlist_k).map(&:first)
  rescue StandardError => e
    # a broken embedder costs speed, not correctness: ask the model with the whole list
    Print.err "DecisionRouter (#{@lab}): embedder failed (#{e.class}: #{e.message}); using the full list"
    @pairs.keys
  end

  def pair_vectors
    @mutex.synchronize do
      @pair_vectors ||= begin
        ids = @pairs.keys
        vs = embed(ids.map { |id| @pairs[id]['q'] }) # documents get no instruction prefix
        ids.zip(vs).to_h
      end
    end
  end

  def embed(inputs)
    body = { 'input' => inputs }
    body['model'] = @embed_model if @embed_model && !@embed_model.to_s.empty?
    data = @http_post.call("#{@embed_url}/v1/embeddings", body, @timeout)['data'] or raise 'embedder returned no data'
    data.sort_by { |d| d['index'] }.map { |d| unit(d['embedding']) }
  end

  def unit(v)
    n = Math.sqrt(v.sum { |x| x * x })
    n = 1.0 if n.zero?
    v.map { |x| x / n }
  end

  def dot(a, b)
    s = 0.0
    a.each_index { |i| s += a[i] * b[i] }
    s
  end

  # ---- plumbing ----------------------------------------------------------------------------

  def default_http_post(url, body, timeout)
    uri = URI(url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == 'https'
    http.open_timeout = timeout
    http.read_timeout = timeout
    http.proxy_from_env = false # lab servers are local; the build env sets proxies (see Hackerbot 2 proxy fix)
    req = Net::HTTP::Post.new(uri.request_uri, 'Content-Type' => 'application/json')
    req['Authorization'] = "Bearer #{@api_key}" if @api_key
    req.body = JSON.generate(body)
    res = http.request(req)
    raise "HTTP #{res.code} from #{uri.host}:#{uri.port}#{uri.path}" unless res.code.start_with?('2')
    JSON.parse(res.body)
  end

  def note_failure
    @mutex.synchronize do
      @failures += 1
      if @failures >= @breaker_failures
        @open_until = monotonic + @breaker_cooldown
        @failures = 0
        Print.err "DecisionRouter (#{@lab}): #{@breaker_failures} failures in a row; skipping the decision model for #{@breaker_cooldown.round}s"
      end
    end
  end

  def monotonic
    Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end

  def finish(result, text)
    log(result, text)
    result
  end

  def log(result, text)
    return unless @log_path
    line = { 't' => Time.now.utc.iso8601, 'lab' => @lab, 'message' => text, 'action' => result.action,
             'pair' => result.pair_id, 'p' => result.probability && result.probability.round(4),
             'other' => result.top_other, 'strategy' => result.strategy, 'second_pass' => result.second_pass,
             'fit' => result.fit && result.fit.round(4), 'ms' => result.latency_ms, 'reason' => result.reason }
    @mutex.synchronize { File.open(@log_path, 'a') { |f| f.puts(JSON.generate(line)) } }
  rescue StandardError => e
    Print.err "DecisionRouter: could not write decision log: #{e.message}"
  end
end
