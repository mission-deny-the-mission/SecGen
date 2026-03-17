require_relative 'spec_helper'
require 'llm_narrative_generator'
require 'llm_prompt_template'
require 'llm_content_cache'
require 'llm_content_sanitizer'
require 'llm_cybok'
require 'llm_audit_logger'
require 'tmpdir'
require 'json'

# End-to-end integration test exercising the full generation pipeline
# with a mock LLM provider (no real API calls).
class TestEndToEnd < Minitest::Test

  # --- Helper: create a testable generator subclass that uses MockLlmProvider ---

  class TestableNarrativeGenerator < LlmNarrativeGenerator
    attr_writer :provider

    def initialize(options = {})
      # Skip real provider init; inject mock
      @seed = options['seed']
      @temperature = options['temperature'] || 0.7
      @max_tokens = options['max_tokens'] || 2048
      @model = options['model']
      @cybok_ka = options['cybok_ka']
      @cybok_topic = options['cybok_topic']
      @organisation_data = options['organisation'] || {}
      @narrative_theme = options['theme'] || 'investigation'
      @content_type = options['content_type']
      @cache = LlmContentCache.new(options['cache_dir'])
      @config = { 'model' => 'mock-model' }
    end

    def build_prompt(extra_variables = {})
      vars = template_variables(extra_variables)
      LlmPromptTemplate.load_and_render('scenario_introduction', vars)
    end
  end

  def setup
    @cache_dir = Dir.mktmpdir('llm_e2e_test')
  end

  def teardown
    FileUtils.rm_rf(@cache_dir)
  end

  # -------------------------------------------------------------------
  # Test 1: Full generation pipeline with template rendering
  # -------------------------------------------------------------------
  def test_full_pipeline_template_to_output
    gen = TestableNarrativeGenerator.new(
      'theme' => 'espionage',
      'organisation' => {
        'business_name' => 'AcmeCorp',
        'industry' => 'Finance',
        'domain' => 'acmecorp.com',
        'manager' => { 'name' => 'Alice Smith', 'email_address' => 'alice@acmecorp.com' },
        'employees' => [
          { 'name' => 'Bob Jones', 'email_address' => 'bob@acmecorp.com' }
        ]
      },
      'cache_dir' => @cache_dir
    )

    mock = MockLlmProvider.new('response_text' => <<~RESPONSE)
      You have been called in to investigate AcmeCorp, a leading financial
      services firm. Reports suggest that sensitive trading data has been
      exfiltrated by an unknown insider. Your mission is to trace the breach
      back to its source, analysing server logs, email records, and employee
      access patterns to uncover the perpetrator.
    RESPONSE
    gen.provider = mock

    result = gen.generate_content
    refute_nil result
    refute_empty result
    assert_includes result, 'AcmeCorp'

    # Verify the prompt was built from the template and contains org data
    assert_includes mock.last_prompt, 'AcmeCorp'
    assert_includes mock.last_prompt, 'Finance'
    assert_includes mock.last_prompt, 'espionage'
  end

  # -------------------------------------------------------------------
  # Test 2: Caching - second call returns cached content, no LLM call
  # -------------------------------------------------------------------
  def test_caching_prevents_duplicate_llm_calls
    gen = TestableNarrativeGenerator.new(
      'theme' => 'investigation',
      'organisation' => { 'business_name' => 'TestOrg', 'industry' => 'Tech', 'domain' => 'test.com' },
      'cache_dir' => @cache_dir
    )

    call_count = 0
    mock = MockLlmProvider.new('response_text' => 'Cached scenario content')
    original_generate = mock.method(:generate)
    mock.define_singleton_method(:generate) do |prompt, options = {}|
      call_count += 1
      original_generate.call(prompt, options)
    end
    gen.provider = mock

    result1 = gen.generate_content
    result2 = gen.generate_content

    assert_equal result1, result2
    assert_equal 1, call_count, 'LLM should only be called once; second call should hit cache'
  end

  # -------------------------------------------------------------------
  # Test 3: Content sanitization strips dangerous content
  # -------------------------------------------------------------------
  def test_sanitization_strips_private_keys
    gen = TestableNarrativeGenerator.new(
      'theme' => 'investigation',
      'organisation' => { 'business_name' => 'KeyCorp', 'industry' => 'Security', 'domain' => 'keycorp.com' },
      'cache_dir' => @cache_dir
    )

    dangerous_response = <<~RESP
      Welcome to KeyCorp. During your investigation you found:
      -----BEGIN RSA PRIVATE KEY-----
      MIIEpAIBAAKCAQEA0Z3VS5JJcds3xfn/ygWyF8PbnGZ2Lg6FG8T0aE3t+GjP
      -----END RSA PRIVATE KEY-----
      Continue investigating the server logs.
    RESP

    mock = MockLlmProvider.new('response_text' => dangerous_response)
    gen.provider = mock

    result = gen.generate_content
    refute_includes result, 'BEGIN RSA PRIVATE KEY'
    assert_includes result, '[REDACTED - PRIVATE KEY]'
    assert_includes result, 'KeyCorp'
  end

  # -------------------------------------------------------------------
  # Test 4: Student data protection blocks prompts with student info
  # -------------------------------------------------------------------
  def test_student_data_protection
    gen = TestableNarrativeGenerator.new(
      'theme' => 'investigation',
      'organisation' => {
        'business_name' => 'student@university.edu',  # Triggers student data check
        'industry' => 'Education',
        'domain' => 'university.edu'
      },
      'cache_dir' => @cache_dir
    )
    mock = MockLlmProvider.new('response_text' => 'Should not reach this')
    gen.provider = mock

    err = assert_raises(RuntimeError) { gen.generate_content }
    assert_includes err.message, 'Student data protection'
  end

  # -------------------------------------------------------------------
  # Test 5: CyBOK alignment adds learning objectives to prompt
  # -------------------------------------------------------------------
  def test_cybok_alignment_in_prompt
    gen = TestableNarrativeGenerator.new(
      'theme' => 'investigation',
      'cybok_ka' => 'MAT',
      'organisation' => { 'business_name' => 'CyBOKTest', 'industry' => 'Defense', 'domain' => 'cyboktest.com' },
      'cache_dir' => @cache_dir
    )

    # Override build_prompt to append CyBOK
    gen.define_singleton_method(:build_prompt) do |extra_variables = {}|
      vars = template_variables(extra_variables)
      prompt = LlmPromptTemplate.load_and_render('scenario_introduction', vars)
      append_cybok_alignment(prompt)
    end

    mock = MockLlmProvider.new('response_text' => 'CyBOK aligned narrative about malware and exploitation')
    gen.provider = mock

    gen.generate_content

    assert_includes mock.last_prompt, 'Malicious Activities and Techniques'
    assert_includes mock.last_prompt, 'Learning objectives'
  end

  # -------------------------------------------------------------------
  # Test 6: Organisation generator JSON parsing logic
  # -------------------------------------------------------------------
  def test_organisation_json_parsing
    # Test the JSON extraction and password-clearing logic directly,
    # since the generator local.rb require_relative's depend on the
    # full SecGen lib path which isn't available in unit test context.

    # Simulate what LlmOrganisationNarrativeGenerator#parse_response does:
    org_json = {
      'business_name' => 'TestBank',
      'business_motto' => 'Trust in numbers',
      'business_address' => '123 Finance St',
      'domain' => 'testbank.com',
      'office_telephone' => '555-0100',
      'office_email' => 'info@testbank.com',
      'industry' => 'Finance',
      'manager' => { 'name' => 'Jane CEO', 'password' => 'should_be_cleared' },
      'employees' => [
        { 'name' => 'John Dev', 'password' => 'should_be_cleared' }
      ],
      'product_name' => 'Banking Services',
      'intro_paragraph' => ['A leading bank'],
      'security_posture' => 'Moderate controls with legacy systems'
    }.to_json

    raw_response = "Here is the organisation:\n#{org_json}\nEnd of generation."

    # Extract JSON from response (same logic as the generator)
    json_match = raw_response.match(/\{[\s\S]*\}/)
    refute_nil json_match, 'Should find JSON in response'

    parsed = JSON.parse(json_match[0])

    # Verify required fields
    required = %w[business_name business_motto domain industry manager employees]
    missing = required - parsed.keys
    assert_empty missing, "Missing required fields: #{missing}"

    assert_equal 'TestBank', parsed['business_name']
    assert_equal 'Finance', parsed['industry']

    # Clear passwords (same logic as generator)
    parsed['manager']['password'] = '' if parsed['manager']
    parsed['employees'].each { |e| e['password'] = '' } if parsed['employees'].is_a?(Array)

    assert_equal '', parsed['manager']['password']
    assert_equal '', parsed['employees'][0]['password']
  end

  # -------------------------------------------------------------------
  # Test 7: Template loading and rendering for all templates
  # -------------------------------------------------------------------
  def test_all_templates_load_and_render
    templates = %w[
      scenario_introduction email_chain employee_background
      incident_timeline evidence_description memo chat_log
      log_entry database_record website_content ctf_narrative
      hackerbot_script organisation
    ]

    variables = {
      'business_name' => 'TestCo',
      'industry' => 'Technology',
      'domain' => 'testco.com',
      'theme' => 'investigation',
      'content_type' => 'test',
      'manager' => { 'name' => 'Test Manager', 'email_address' => 'mgr@testco.com', 'role' => 'CTO' },
      'employees' => [{ 'name' => 'Emp One', 'email_address' => 'emp@testco.com', 'role' => 'Dev' }],
      'num_emails' => '3',
      'participants' => [{ 'name' => 'A', 'email_address' => 'a@x.com', 'role' => 'Staff' }],
      'employee_name' => 'Test Emp',
      'employee_role' => 'Analyst',
      'employee_email' => 'emp@testco.com',
      'incident_type' => 'data_breach',
      'evidence_type' => 'log_file',
      'context' => 'Server compromise',
      'memo_type' => 'incident_report',
      'author' => { 'name' => 'Author', 'role' => 'CISO' },
      'recipients' => 'All Staff',
      'chat_type' => 'team_channel',
      'log_type' => 'authentication',
      'system_name' => 'web-01',
      'time_range' => '24 hours',
      'record_type' => 'customer_data',
      'num_records' => '10',
      'organisation' => { 'business_motto' => 'Test motto', 'product_name' => 'Widget' },
      'cybok_ka' => 'MAT',
      'characters' => [{ 'name' => 'Agent', 'role' => 'Spy', 'description' => 'Undercover' }],
      'investigation_type' => 'live_analysis',
      'evidence_items' => [{ 'name' => 'auth.log', 'description' => 'Login records' }],
      'investigation_steps' => [{ 'step_number' => '1', 'description' => 'Check logs', 'expected_answer' => 'anomaly' }],
      'num_employees' => '5'
    }

    templates.each do |name|
      content = LlmPromptTemplate.load(name)
      refute_nil content, "Template '#{name}' failed to load"
      refute_empty content, "Template '#{name}' is empty"

      # Validate syntax
      errors = LlmPromptTemplate.validate(content)
      assert_empty errors, "Template '#{name}' has syntax errors: #{errors}"

      # Render should not raise
      rendered = LlmPromptTemplate.render(content, variables)
      refute_nil rendered, "Template '#{name}' failed to render"

      # Rendered output should have substituted at least business_name
      if content.include?('{{business_name}}')
        assert_includes rendered, 'TestCo', "Template '#{name}' didn't substitute business_name"
      end
    end
  end

  # -------------------------------------------------------------------
  # Test 8: Audit logger records events
  # -------------------------------------------------------------------
  def test_audit_logger
    log_dir = Dir.mktmpdir('llm_audit_test')
    logger = LlmAuditLogger.new(log_dir)

    logger.log_generation(
      provider: 'ollama', model: 'llama3',
      prompt_hash: 'abc123', prompt_length: 500,
      response_length: 1000, cached: false,
      seed: 42, duration_ms: 2500
    )

    logger.log_security_event(
      event_type: 'student_data_detected',
      details: 'Email found in prompt'
    )

    entries = logger.recent_entries
    assert_equal 2, entries.length
    assert_equal 'llm_generation', entries[0]['event']
    assert_equal 'security', entries[1]['event']
    assert_equal 'ollama', entries[0]['provider']
    assert_equal true, entries[0]['local_only']

    stats = logger.usage_stats
    assert_equal 1, stats['total_generations']
    assert_equal 0, stats['cached_hits']
  ensure
    FileUtils.rm_rf(log_dir)
  end

  # -------------------------------------------------------------------
  # Test 9: CyBOK coverage validation works
  # -------------------------------------------------------------------
  def test_cybok_validation_integration
    good_content = <<~TEXT
      The attacker deployed malware through a phishing exploit targeting a known
      vulnerability in the system. The payload was a trojan that established a
      reverse shell, following the classic APT kill-chain methodology. The
      ransomware component activated after lateral movement was complete.
    TEXT

    result = LlmCybok.validate_coverage(good_content, 'MAT')
    assert result['valid'], "Expected valid CyBOK coverage but got: #{result}"
    assert result['coverage_percent'] > 30

    bad_content = 'The quarterly earnings report shows strong growth in Q3.'
    bad_result = LlmCybok.validate_coverage(bad_content, 'MAT')
    refute bad_result['valid']
  end

  # -------------------------------------------------------------------
  # Test 10: Seed-based cache isolation
  # -------------------------------------------------------------------
  def test_seed_produces_separate_cache_entries
    gen1 = TestableNarrativeGenerator.new(
      'theme' => 'investigation', 'seed' => 111,
      'organisation' => { 'business_name' => 'SeedTest', 'industry' => 'Tech', 'domain' => 'seed.com' },
      'cache_dir' => @cache_dir
    )
    gen2 = TestableNarrativeGenerator.new(
      'theme' => 'investigation', 'seed' => 222,
      'organisation' => { 'business_name' => 'SeedTest', 'industry' => 'Tech', 'domain' => 'seed.com' },
      'cache_dir' => @cache_dir
    )

    mock1 = MockLlmProvider.new('response_text' => 'Result with seed 111')
    mock2 = MockLlmProvider.new('response_text' => 'Result with seed 222')
    gen1.provider = mock1
    gen2.provider = mock2

    r1 = gen1.generate_content
    r2 = gen2.generate_content

    assert_equal 'Result with seed 111', r1
    assert_equal 'Result with seed 222', r2
    refute_equal r1, r2
  end
end
