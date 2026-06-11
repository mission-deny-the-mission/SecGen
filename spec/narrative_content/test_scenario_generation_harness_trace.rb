require_relative 'spec_helper'
require 'tmpdir'
require 'scenario_generation'

class TestScenarioGenerationHarnessTrace < Minitest::Test
  def intent
    ScenarioGeneration::Intent.new(
      'name' => 'Trace Lab', 'scenario_type' => 'lab', 'target_platform' => 'web', 'difficulty' => 'easy',
      'vulnerability_classes' => ['sql_injection'], 'learning_outcomes' => ['x'],
      'cybok' => [{ 'ka' => 'WAM', 'topic' => 'Web', 'keywords' => ['k'] }],
      'flags' => ['f'], 'evidence' => ['e'], 'seed' => 1
    )
  end

  def test_trace_records_phases_and_prompt_hashes
    Dir.mktmpdir('trace') do |dir|
      adapter = ScenarioGeneration::OpenCodeAdapter.new(
        intent: intent, staging_dir: dir, config: { 'isolation_mode' => 'host', 'model' => 'gpt-4o' }
      )
      trace = ScenarioGeneration::HarnessTrace.new(adapter: adapter)
      trace.record_phase(phase: 'plan', command: adapter.plan_command, status: 'ok')
      trace.record_phase(phase: 'generate', command: adapter.generate_command, status: 'ok')
      trace.record_validation(attempt: 0, report: ScenarioGeneration::ValidationReport.new.add_failure(code: 'x', message: 'y'))
      trace.record_repair(attempt: 0, report: ScenarioGeneration::ValidationReport.new.add_failure(code: 'x', message: 'y'))

      final = trace.finalize(status: 'passed')

      assert_equal 'opencode', final['harness']
      assert_equal 'gpt-4o', final['model']
      assert_equal 'host', final['isolation_mode']
      assert_equal 2, final['phases'].length
      assert final['prompt_hashes'].key?('plan')
      assert final['prompt_hashes'].key?('generate')
      assert_match(/\A[0-9a-f]{64}\z/, final['prompt_hashes']['plan'])
      assert_equal 1, final['validation_attempts'].length
      assert_equal ['x'], final['validation_attempts'].first['failures']
      assert_equal 1, final['repair_attempts'].length
      assert_equal 'passed', final['final_status']
    end
  end
end
