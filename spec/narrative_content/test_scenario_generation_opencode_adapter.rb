require_relative 'spec_helper'
require 'tmpdir'
require 'json'
require 'scenario_generation'

class TestScenarioGenerationOpenCodeAdapter < Minitest::Test
  def valid_intent
    ScenarioGeneration::Intent.new(
      'name' => 'Customer Portal Break-In',
      'scenario_type' => 'attack-ctf',
      'target_platform' => 'linux',
      'difficulty' => 'medium',
      'vulnerability_classes' => ['SQL injection'],
      'learning_outcomes' => ['Identify unsafe query construction'],
      'cybok' => {
        'ka' => 'WAM',
        'topic' => 'Server-Side Vulnerabilities and Mitigations'
      },
      'flags' => ['customer_admin_flag'],
      'evidence' => ['customer feedback records'],
      'seed' => 1234,
      'harness' => {
        'name' => 'opencode',
        'model' => 'openai/gpt-4o-mini',
        'retry_limit' => 2
      }
    )
  end

  def test_prepare_workspace_writes_intent_and_policy
    Dir.mktmpdir('secgen_opencode') do |dir|
      adapter = ScenarioGeneration::OpenCodeAdapter.new(intent: valid_intent, staging_dir: dir)

      assert adapter.prepare_workspace

      intent_path = File.join(dir, 'intent.normalized.json')
      policy_path = File.join(dir, 'opencode.policy.json')
      assert File.exist?(intent_path)
      assert File.exist?(policy_path)

      intent_data = JSON.parse(File.read(intent_path))
      policy = JSON.parse(File.read(policy_path))
      assert_equal 'customer-portal-break-in', intent_data['identifiers']['scenario_slug']
      assert_equal dir, policy['allowed_write_root']
      assert_equal 2, policy['retry_limit']
    end
  end

  def test_plan_command_uses_opencode_plan_agent
    Dir.mktmpdir('secgen_opencode') do |dir|
      adapter = ScenarioGeneration::OpenCodeAdapter.new(intent: valid_intent, staging_dir: dir)
      command = adapter.plan_command

      assert_equal 'opencode', command[0]
      assert_includes command, 'run'
      assert_includes command, '--dir'
      assert_includes command, dir
      assert_includes command, '--agent'
      assert_includes command, 'plan'
      assert_includes command, '--format'
      assert_includes command, 'json'
      assert_includes command, '--model'
      assert_includes command, 'openai/gpt-4o-mini'
      assert_includes command.last, 'Do not edit files'
    end
  end

  def test_generate_command_uses_opencode_build_agent
    Dir.mktmpdir('secgen_opencode') do |dir|
      adapter = ScenarioGeneration::OpenCodeAdapter.new(intent: valid_intent, staging_dir: dir)
      command = adapter.generate_command

      assert_includes command, '--agent'
      assert_includes command, 'build'
      assert_includes command.last, 'Write only inside this staging directory'
    end
  end

  def test_repair_command_embeds_validation_report
    Dir.mktmpdir('secgen_opencode') do |dir|
      adapter = ScenarioGeneration::OpenCodeAdapter.new(intent: valid_intent, staging_dir: dir)
      command = adapter.repair_command('failures' => [{ 'code' => 'missing_metadata' }])

      assert_includes command, '--agent'
      assert_includes command, 'build'
      assert_includes command.last, 'missing_metadata'
      assert_includes command.last, 'Modify only files inside this staging directory'
    end
  end

  def test_export_command_can_sanitize_session
    adapter = ScenarioGeneration::OpenCodeAdapter.new(intent: valid_intent, staging_dir: '/tmp/staged')

    assert_equal ['opencode', 'export', 'ses_test', '--sanitize'], adapter.export_command('ses_test')
    assert_equal ['opencode', 'export', 'ses_test'], adapter.export_command('ses_test', sanitize: false)
  end

  def test_report_contains_harness_metadata
    adapter = ScenarioGeneration::OpenCodeAdapter.new(intent: valid_intent, staging_dir: '/tmp/staged')
    report = adapter.report

    assert_equal 'opencode', report['harness']
    assert_equal 'openai/gpt-4o-mini', report['model']
    assert_equal 2, report['retry_limit']
    assert_equal 'plan', report['plan_agent']
    assert_equal 'build', report['build_agent']
  end
end
