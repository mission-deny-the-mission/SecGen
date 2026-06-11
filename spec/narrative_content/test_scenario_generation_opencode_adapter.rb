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
      assert_equal '/workspace', policy['container_write_root']
      assert_equal 'docker', policy['isolation_mode']
      assert_equal 2, policy['retry_limit']
      assert_equal [['test', '-f', '/workspace/opencode.policy.json'], ['test', '-f', '/workspace/intent.normalized.json']], policy['approved_validation_commands']
    end
  end

  def test_plan_command_uses_opencode_plan_agent_in_host_mode
    Dir.mktmpdir('secgen_opencode') do |dir|
      adapter = ScenarioGeneration::OpenCodeAdapter.new(intent: valid_intent, staging_dir: dir, config: { 'isolation_mode' => 'host' })
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

  def test_generate_command_uses_opencode_build_agent_in_host_mode
    Dir.mktmpdir('secgen_opencode') do |dir|
      adapter = ScenarioGeneration::OpenCodeAdapter.new(intent: valid_intent, staging_dir: dir, config: { 'isolation_mode' => 'host' })
      command = adapter.generate_command

      assert_includes command, '--agent'
      assert_includes command, 'build'
      assert_includes command.last, 'Write only inside this staging directory'
    end
  end

  def test_repair_command_embeds_validation_report_in_host_mode
    Dir.mktmpdir('secgen_opencode') do |dir|
      adapter = ScenarioGeneration::OpenCodeAdapter.new(intent: valid_intent, staging_dir: dir, config: { 'isolation_mode' => 'host' })
      command = adapter.repair_command('failures' => [{ 'code' => 'missing_metadata' }])

      assert_includes command, '--agent'
      assert_includes command, 'build'
      assert_includes command.last, 'missing_metadata'
      assert_includes command.last, 'Modify only files inside this staging directory'
    end
  end

  def test_default_plan_command_runs_opencode_inside_docker
    Dir.mktmpdir('secgen_opencode') do |dir|
      adapter = ScenarioGeneration::OpenCodeAdapter.new(intent: valid_intent, staging_dir: dir)
      command = adapter.plan_command

      assert_equal 'docker', command[0]
      assert_includes command, 'run'
      assert_includes command, '--rm'
      assert_includes command, '--network'
      assert_includes command, 'none'
      assert_includes command, '--cap-drop'
      assert_includes command, 'ALL'
      assert_includes command, '--security-opt'
      assert_includes command, 'no-new-privileges'
      assert_includes command, '--mount'
      assert_includes command, "type=bind,source=#{File.expand_path(dir)},target=/workspace"
      assert_includes command, 'opencode:latest'
      assert_includes command, '--dir'
      assert_includes command, '/workspace'
      assert_includes command, '--agent'
      assert_includes command, 'plan'
    end
  end

  def test_validation_commands_are_docker_isolated
    adapter = ScenarioGeneration::OpenCodeAdapter.new(intent: valid_intent, staging_dir: '/tmp/staged')
    commands = adapter.validation_commands

    assert_equal 2, commands.length
    commands.each do |command|
      assert_equal 'docker', command[0]
      assert_includes command, 'opencode:latest'
      assert_includes command, '/workspace'
    end
    assert_includes commands[0], 'test'
    assert_includes commands[0], '/workspace/opencode.policy.json'
  end

  def test_optional_vm_validation_command
    adapter = ScenarioGeneration::OpenCodeAdapter.new(
      intent: valid_intent,
      staging_dir: '/tmp/staged',
      config: { 'vm_validation_command' => ['bundle', 'exec', 'ruby', 'validate_vm.rb'] }
    )

    assert_equal ['bundle', 'exec', 'ruby', 'validate_vm.rb'], adapter.vm_validation_command
  end

  def test_unknown_validation_profile_is_rejected
    assert_raises(ScenarioGeneration::HarnessError) do
      ScenarioGeneration::OpenCodeAdapter.new(
        intent: valid_intent,
        staging_dir: '/tmp/staged',
        config: { 'validation_profile' => 'unknown' }
      )
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
    assert_equal 'docker', report['isolation_mode']
    assert_equal 'opencode:latest', report['container_image']
    assert_equal 'plan', report['plan_agent']
    assert_equal 'build', report['build_agent']
  end

  def test_harness_factory_selects_opencode
    adapter = ScenarioGeneration::HarnessAdapter.for(intent: valid_intent, staging_dir: '/tmp/staged')

    assert_instance_of ScenarioGeneration::OpenCodeAdapter, adapter
  end

  def test_harness_factory_rejects_unknown_harness
    intent = valid_intent
    intent.normalized['harness']['name'] = 'unknown'

    error = assert_raises(ScenarioGeneration::HarnessError) do
      ScenarioGeneration::HarnessAdapter.for(intent: intent, staging_dir: '/tmp/staged')
    end

    assert_includes error.message, 'Unsupported harness'
  end

  def test_phase_command_routes_supported_phases
    adapter = ScenarioGeneration::OpenCodeAdapter.new(intent: valid_intent, staging_dir: '/tmp/staged', config: { 'isolation_mode' => 'host' })

    assert_includes adapter.phase_command(:plan), 'plan'
    assert_includes adapter.phase_command(:generate), 'build'
    assert_equal 2, adapter.phase_command(:validate).length
    assert_includes adapter.phase_command(:repair, validation_report: { 'failures' => [] }).last, 'validation report'
    assert_equal 'opencode', adapter.phase_command(:report)['harness']
  end

  def test_phase_command_rejects_unknown_phase
    adapter = ScenarioGeneration::OpenCodeAdapter.new(intent: valid_intent, staging_dir: '/tmp/staged')

    assert_raises(ScenarioGeneration::HarnessError) { adapter.phase_command(:deploy) }
  end

  def test_retry_stopping_uses_retry_limit
    adapter = ScenarioGeneration::OpenCodeAdapter.new(intent: valid_intent, staging_dir: '/tmp/staged')

    refute adapter.retries_exhausted?(1)
    assert adapter.retries_exhausted?(2)
  end

  def test_staged_path_validation_rejects_out_of_scope_paths
    Dir.mktmpdir('secgen_opencode') do |dir|
      adapter = ScenarioGeneration::OpenCodeAdapter.new(intent: valid_intent, staging_dir: dir)

      assert adapter.staged_path_allowed?(File.join(dir, 'scenario.xml'))
      assert adapter.staged_path_allowed?('relative/path.xml')
      refute adapter.staged_path_allowed?('/etc/passwd')
      assert adapter.validate_staged_paths!([File.join(dir, 'scenario.xml'), 'relative/path.xml'])
      assert_raises(ScenarioGeneration::HarnessError) { adapter.validate_staged_paths!(['/etc/passwd']) }
    end
  end

  def test_validation_command_approval
    adapter = ScenarioGeneration::OpenCodeAdapter.new(intent: valid_intent, staging_dir: '/tmp/staged')

    assert adapter.approved_validation_command?(['test', '-f', '/workspace/opencode.policy.json'])
    refute adapter.approved_validation_command?(['rm', '-rf', '/workspace'])
    assert adapter.validate_validation_command!(['test', '-f', '/workspace/intent.normalized.json'])
    assert_raises(ScenarioGeneration::HarnessError) { adapter.validate_validation_command!(['rm', '-rf', '/workspace']) }
  end
end
