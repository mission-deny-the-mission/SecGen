require 'minitest/autorun'
require 'json'
require_relative '../../print'
require_relative '../decision_router'

# Fake servers: no network, no models. Deterministic stand-ins for /v1/systemone and /v1/embeddings.
class TestDecisionRouter < Minitest::Test
  PAIRS = File.expand_path('../pairs/labhelp_pairs.json', __dir__)
  LAB = 'hb2_siem'.freeze

  def router(probs_for: nil, calls: [], **opts)
    post = lambda do |url, body, _t|
      calls << [url, body]
      if url.end_with?('/v1/systemone')
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
