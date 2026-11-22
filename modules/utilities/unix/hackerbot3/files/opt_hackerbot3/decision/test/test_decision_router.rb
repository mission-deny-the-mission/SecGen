require 'minitest/autorun'
require 'json'
require_relative '../../print'
require_relative '../decision_router'

# Fake servers: no network, no models. Deterministic stand-ins for /v1/systemone and /v1/embeddings.
class TestDecisionRouter < Minitest::Test
  PAIRS = File.expand_path('../pairs/labhelp_pairs.json', __dir__)
  LAB = 'hb2_siem'.freeze

  def router(probs_for: nil, calls: [], fit_p: 0.9, **opts)
    post = lambda do |url, body, _t|
      calls << [url, body]
      if url.end_with?('/v1/systemone') && body['questions'].key?('fit')
        p = fit_p.respond_to?(:call) ? fit_p.call(body) : fit_p
        raise Net::ReadTimeout if p == :timeout
        { 'answers' => { 'fit' => { 'probabilities' => { 'answers' => p, 'off' => 1.0 - p } } } }
      elsif url.end_with?('/v1/systemone')
        crit = body['questions']['best_match']['criteria']
        probs = probs_for ? probs_for.call(crit) : { 'escalate' => 1.0 }
        { 'answers' => { 'best_match' => { 'probabilities' => probs } } }
      else # embeddings: one-hot on the first word's length, enough to be deterministic
        { 'data' => body['input'].each_with_index.map { |t, i| { 'index' => i, 'embedding' => [1.0, t.length.to_f % 7, i.to_f % 3] } } }
      end
    end
    DecisionRouter.new({ pairs_file: PAIRS, lab: LAB, url: 'http://dm', http_post: post, strategy: 'full' }.merge(opts))
  end

  def first_id
    router.pair_ids.first
  end

  def test_serves_canned_answer_above_threshold
    id = first_id
    r = router(probs_for: ->(c) { c.keys.to_h { |k| [k, k == id ? 0.9 : 0.1 / (c.size - 1)] } })
    res = r.route('what is a siem')
    assert res.canned?
    assert_equal id, res.pair_id
    refute_empty res.answer
  end

  def canned_first
    id = first_id
    ->(c) { c.keys.to_h { |k| [k, k == id ? 0.9 : 0.1 / (c.size - 1)] } }
  end

  def fit_calls(calls)
    calls.count { |u, b| u.end_with?('systemone') && b['questions'].key?('fit') }
  end

  def test_fit_check_off_by_default_makes_no_extra_call
    calls = []
    r = router(calls: calls, probs_for: canned_first, fit_p: 0.0)
    refute r.fit_check
    assert r.route('what is a siem').canned?
    assert_equal 0, fit_calls(calls)
  end

  def test_fit_check_keeps_answer_that_fits
    calls = []
    r = router(calls: calls, probs_for: canned_first, fit_p: 0.8, fit_check: 'true')
    res = r.route('what is a siem')
    assert res.canned?
    assert_in_delta 0.8, res.fit
    assert_equal 1, fit_calls(calls)
    _, body = calls.find { |u, b| u.end_with?('systemone') && b['questions'].key?('fit') }
    assert_equal 'what is a siem', body['state']['user_message']
    assert_equal res.answer, body['state']['candidate_answer']
  end

  def test_fit_check_escalates_answer_that_does_not_fit
    r = router(probs_for: canned_first, fit_p: 0.1, fit_check: true)
    res = r.route('what are the arguments for chattr')
    refute res.canned?
    assert_equal 'answer does not fit', res.reason
    assert_equal first_id, res.top_other
    assert_nil res.answer
  end

  def test_fit_threshold_is_configurable
    assert router(probs_for: canned_first, fit_p: 0.3, fit_check: '1').route('x y').canned?           # 0.3 >= 0.25 default
    refute router(probs_for: canned_first, fit_p: 0.3, fit_check: '1', fit_threshold: '0.5').route('x y').canned?
  end

  def test_fit_check_error_escalates_and_counts_towards_breaker
    r = router(probs_for: canned_first, fit_p: :timeout, fit_check: true, breaker_failures: 2)
    res = r.route('what is a siem')
    refute res.canned?
    assert res.reason.start_with?('error')
  end

  def test_fit_check_not_called_when_router_already_escalates
    calls = []
    r = router(calls: calls, fit_check: true) # default probs: escalate
    refute r.route('tell me a joke').canned?
    assert_equal 0, fit_calls(calls)
  end

  def test_timeout_option_reaches_http_calls
    seen = []
    post = lambda do |_u, _b, t|
      seen << t
      { 'answers' => { 'best_match' => { 'probabilities' => { 'escalate' => 1.0 } } } }
    end
    DecisionRouter.new(pairs_file: PAIRS, lab: LAB, url: 'http://dm', http_post: post, strategy: 'full', timeout: '10').route('hi there')
    assert_equal [10.0], seen.uniq
  end

  def test_escalates_when_model_says_escalate
    r = router(probs_for: ->(c) { c.keys.to_h { |k| [k, k == 'escalate' ? 0.95 : 0.05 / (c.size - 1)] } })
    res = r.route('tell me a joke')
    refute res.canned?
    assert_equal 'model chose escalate', res.reason
  end

  def test_escalates_below_threshold
    id = first_id
    r = router(probs_for: ->(c) { c.keys.to_h { |k| [k, k == id ? 0.45 : 0.55 / (c.size - 1)] } })
    assert_equal 'below threshold', r.route('hmm').reason
    r2 = router(threshold: 0.4, probs_for: ->(c) { c.keys.to_h { |k| [k, k == id ? 0.45 : 0.55 / (c.size - 1)] } })
    assert r2.route('hmm').canned?
  end

  def test_escalate_is_last_option_and_only_lab_pairs_are_offered
    calls = []
    router(calls: calls).route('anything')
    crit = calls.last[1]['questions']['best_match']['criteria']
    assert_equal 'escalate', crit.keys.last
    assert crit.keys[0..-2].all? { |k| k.start_with?('siem_') || k.start_with?('shared_') }, crit.keys.inspect
    refute crit.keys.any? { |k| k.start_with?('ip_') }
    assert_equal({ 'user_message' => 'anything' }, calls.last[1]['state'])
  end

  def test_network_error_escalates_never_raises
    post = ->(*) { raise Errno::ECONNREFUSED, 'nope' }
    r = DecisionRouter.new(pairs_file: PAIRS, lab: LAB, url: 'http://dm', http_post: post, strategy: 'full')
    res = r.route('what is a siem')
    refute res.canned?
    assert_match(/error/, res.reason)
  end

  def test_circuit_breaker_stops_calling_after_repeated_failures
    n = 0
    post = ->(*) { n += 1; raise 'down' }
    r = DecisionRouter.new(pairs_file: PAIRS, lab: LAB, url: 'http://dm', http_post: post, strategy: 'full',
                           breaker_failures: 3, breaker_cooldown: 60)
    6.times { r.route('x') }
    assert_equal 3, n
    assert_equal 'circuit open', r.route('x').reason
  end

  def test_empty_and_overlong_messages
    calls = []
    r = router(calls: calls)
    refute r.route('   ').canned?
    assert_empty calls
    r.route('a' * 5000)
    assert_equal DecisionRouter::MAX_MESSAGE_CHARS, calls.last[1]['state']['user_message'].length
  end

  def test_unknown_option_from_model_escalates
    r = router(probs_for: ->(_c) { { 'made_up_pair' => 0.99, 'escalate' => 0.01 } })
    refute r.route('x').canned?
  end

  def test_twopass_asks_again_with_full_list_on_escalate
    calls = []
    id = first_id
    seq = 0
    probs = lambda do |c|
      seq += 1
      if seq == 1 then c.keys.to_h { |k| [k, k == 'escalate' ? 0.9 : 0.1 / (c.size - 1)] }
      else c.keys.to_h { |k| [k, k == id ? 0.8 : 0.2 / (c.size - 1)] }
      end
    end
    r = router(calls: calls, probs_for: probs, strategy: 'twopass', embed_url: 'http://emb', shortlist_k: 5)
    res = r.route('what is a siem')
    assert res.canned?
    assert res.second_pass
    sizes = calls.select { |u, _| u.end_with?('systemone') }.map { |_, b| b['questions']['best_match']['criteria'].size }
    assert_equal 6, sizes.first          # 5 + escalate
    assert_equal r.pair_count + 1, sizes.last
  end

  def test_shortlist_without_embedder_degrades_to_full
    assert_equal 'full', router(strategy: 'shortlist').strategy
  end

  def test_unknown_lab_and_strategy_rejected
    assert_raises(ArgumentError) { DecisionRouter.new(pairs_file: PAIRS, lab: 'nope', url: 'http://dm') }
    assert_raises(ArgumentError) { router(strategy: 'wat') }
  end

  def test_pairs_contain_no_flag_like_text
    JSON.parse(File.read(PAIRS))['pairs'].each do |p|
      # 'flag{somethingrandom}' is the lab sheet's own format placeholder, not a flag
      refute_match(/password:|flag\{(?!somethingrandom\})/i, p['a'], p['id'])
    end
  end
end
