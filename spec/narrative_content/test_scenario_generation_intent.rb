require_relative 'spec_helper'
require 'tmpdir'
require 'scenario_generation'

class TestScenarioGenerationIntent < Minitest::Test
  def valid_intent
    {
      'name' => 'Customer Portal Break-In',
      'scenario_type' => 'attack-ctf',
      'target_platform' => 'linux',
      'difficulty' => 'medium',
      'vulnerability_classes' => ['SQL injection', 'XSS'],
      'learning_outcomes' => [
        'Identify unsafe query construction',
        'Exploit reflected input handling safely in a lab'
      ],
      'cybok' => {
        'ka' => 'WAM',
        'topic' => 'Server-Side Vulnerabilities and Mitigations',
        'keywords' => ['SQL-INJECTION', 'CROSS-SITE SCRIPTING (XSS)']
      },
      'flags' => ['customer_admin_flag'],
      'evidence' => ['customer feedback records'],
      'seed' => 1234,
      'narrative_generation' => {
        'provider' => 'openai',
        'model' => 'gpt-4o-mini'
      }
    }
  end

  def test_valid_intent_is_accepted_and_normalized
    intent = ScenarioGeneration::Intent.new(valid_intent)

    assert_equal 'attack_ctf', intent.normalized['scenario_type']
    assert_equal 'linux', intent.normalized['target_platform']
    assert_equal 'medium', intent.normalized['difficulty']
    assert_equal ['sql_injection', 'xss'], intent.normalized['vulnerability_classes']
    assert_equal 1234, intent.normalized['seed']
    assert_equal 'customer-portal-break-in', intent.identifiers['scenario_slug']
    assert_equal 'customer_portal_break_in_target', intent.identifiers['system_name']
    assert_equal 'customer_portal_break_in', intent.identifiers['module_name']
    assert_equal 'openai', intent.llm_options['provider']
  end

  def test_alias_fields_are_accepted
    data = valid_intent
    data['title'] = data.delete('name')
    data['type'] = data.delete('scenario_type')
    data['platform'] = data.delete('target_platform')
    data['vulnerabilities'] = data.delete('vulnerability_classes')
    data['learning_objectives'] = data.delete('learning_outcomes')

    intent = ScenarioGeneration::Intent.new(data)

    assert_equal 'Customer Portal Break-In', intent['name']
    assert_equal ['sql_injection', 'xss'], intent.normalized['vulnerability_classes']
  end

  def test_missing_required_fields_are_reported
    error = assert_raises(ScenarioGeneration::IntentError) do
      ScenarioGeneration::Intent.new('name' => 'Incomplete')
    end

    assert_includes error.message, 'Missing required field: scenario_type'
    assert_includes error.message, 'Missing required field: vulnerability_classes'
    assert_includes error.message, 'Missing required field: seed'
  end

  def test_unsupported_values_are_reported
    data = valid_intent.merge(
      'difficulty' => 'impossible',
      'vulnerability_classes' => ['unsafe teleportation'],
      'narrative_generation' => { 'provider' => 'unknown_api' }
    )

    error = assert_raises(ScenarioGeneration::IntentError) do
      ScenarioGeneration::Intent.new(data)
    end

    assert_includes error.message, 'Unsupported difficulty'
    assert_includes error.message, 'Unsupported vulnerability class'
    assert_includes error.message, 'Unsupported narrative_generation provider'
  end

  def test_seed_must_be_integer
    data = valid_intent.merge('seed' => 'not-a-number')

    error = assert_raises(ScenarioGeneration::IntentError) do
      ScenarioGeneration::Intent.new(data)
    end

    assert_includes error.message, 'seed must be an integer'
  end

  def test_loads_json_intent_file
    Dir.mktmpdir('scenario_intent') do |dir|
      path = File.join(dir, 'intent.json')
      File.write(path, JSON.pretty_generate(valid_intent))

      intent = ScenarioGeneration::Intent.load(path)

      assert_equal 'customer-portal-break-in', intent.identifiers['scenario_slug']
    end
  end

  def test_loads_yaml_intent_file
    Dir.mktmpdir('scenario_intent') do |dir|
      path = File.join(dir, 'intent.yml')
      File.write(path, valid_intent.to_yaml)

      intent = ScenarioGeneration::Intent.load(path)

      assert_equal ['sql_injection', 'xss'], intent.normalized['vulnerability_classes']
    end
  end
end

