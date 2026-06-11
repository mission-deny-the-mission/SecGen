require_relative 'spec_helper'
require 'tmpdir'
require 'json'
require 'scenario_generation'

class TestScenarioGenerationRepairLoop < Minitest::Test
  # Returns successive ValidationReports, repeating the last once exhausted.
  class StubValidator
    def initialize(reports)
      @reports = reports
      @index = 0
    end

    def validate
      report = @reports[@index] || @reports.last
      @index += 1
      report
    end
  end

  def passing_report
    ScenarioGeneration::ValidationReport.new
  end

  def failing_report(code = 'missing_required_file')
    ScenarioGeneration::ValidationReport.new.add_failure(code: code, message: "needs #{code}")
  end

  def adapter(staging_dir, retry_limit: 3)
    intent = ScenarioGeneration::Intent.new(
      'name' => 'Repair Lab', 'scenario_type' => 'lab', 'target_platform' => 'web', 'difficulty' => 'easy',
      'vulnerability_classes' => ['sql_injection'], 'learning_outcomes' => ['x'],
      'cybok' => [{ 'ka' => 'WAM', 'topic' => 'Web', 'keywords' => ['k'] }],
      'flags' => ['f'], 'evidence' => ['e'], 'seed' => 1
    )
    ScenarioGeneration::OpenCodeAdapter.new(
      intent: intent, staging_dir: staging_dir, config: { 'isolation_mode' => 'host', 'retry_limit' => retry_limit }
    )
  end

  def test_passes_without_repair_when_valid
    Dir.mktmpdir('repair') do |dir|
      validator = StubValidator.new([passing_report])
      runner = ->(_cmd) { raise 'command_runner must not run when already valid' }
      result = ScenarioGeneration::RepairLoop.new(adapter: adapter(dir), validator: validator, command_runner: runner).run

      assert_equal 'passed', result['status']
      assert_equal 0, result['attempts']
      assert_empty result['repair_commands']
      assert result['promoted']
    end
  end

  def test_repairs_then_passes
    Dir.mktmpdir('repair') do |dir|
      validator = StubValidator.new([failing_report('missing_required_file'), passing_report])
      ran = []
      runner = ->(cmd) { ran << cmd; { 'status' => 'ok' } }
      result = ScenarioGeneration::RepairLoop.new(adapter: adapter(dir), validator: validator, command_runner: runner).run

      assert_equal 'passed', result['status']
      assert_equal 1, result['attempts']
      assert_equal 1, ran.length
      assert_includes result['repair_commands'].last.last, 'missing_required_file'
      assert result['promoted']
    end
  end

  def test_retry_exhaustion_reports_without_promoting
    Dir.mktmpdir('repair') do |dir|
      validator = StubValidator.new([failing_report]) # always fails (last is repeated)
      result = ScenarioGeneration::RepairLoop.new(adapter: adapter(dir, retry_limit: 2), validator: validator).run

      assert_equal 'retry_exhausted', result['status']
      assert_equal 2, result['repair_commands'].length
      refute result['promoted']
    end
  end
end
