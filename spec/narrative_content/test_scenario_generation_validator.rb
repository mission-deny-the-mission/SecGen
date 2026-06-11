require_relative 'spec_helper'
require 'tmpdir'
require 'json'
require 'fileutils'
require 'scenario_generation'

class TestScenarioGenerationValidator < Minitest::Test
  def valid_intent
    ScenarioGeneration::Intent.new(
      'name' => 'Vulnerable Web App Lab',
      'scenario_type' => 'lab',
      'target_platform' => 'web',
      'difficulty' => 'easy',
      'vulnerability_classes' => ['sql_injection'],
      'learning_outcomes' => ['Understand SQL injection'],
      'cybok' => [{ 'ka' => 'WAM', 'topic' => 'Web & Mobile Security', 'keywords' => ['sql injection'] }],
      'flags' => ['exfiltrate the customer flag'],
      'evidence' => ['database dump'],
      'seed' => 4242
    )
  end

  # Generates real module + scenario artifacts into `dir`; returns [scenario, modules].
  def stage(dir, intent: valid_intent)
    catalog = ScenarioGeneration::TemplateCatalog.load
    modules = intent.normalized['vulnerability_classes'].map do |vc|
      template = catalog.compatible(vulnerability_class: vc, platform: intent.normalized['target_platform'], difficulty: intent.normalized['difficulty']).first
      ScenarioGeneration::ModuleGenerator.new(intent: intent, template: template, staging_dir: dir).generate
    end
    scenario = ScenarioGeneration::ScenarioAssembler.new(intent: intent, modules: modules, staging_dir: dir).assemble
    [scenario, modules]
  end

  def validate(dir, scenario, modules)
    ScenarioGeneration::Validator.new(scenario: scenario, modules: modules, staging_dir: dir).validate
  end

  def codes(report)
    report.failed.map { |failure| failure['code'] }
  end

  def test_valid_artifacts_pass_and_are_promotion_ready
    Dir.mktmpdir('val') do |dir|
      scenario, modules = stage(dir)
      report = validate(dir, scenario, modules)
      assert report.promotion_ready?, "unexpected failures: #{report.failed.inspect}"
      assert_empty report.failed
      refute_empty report.passed
    end
  end

  def test_malformed_scenario_xml_blocks_promotion
    Dir.mktmpdir('val') do |dir|
      scenario, modules = stage(dir)
      File.write(scenario['staged_scenario_path'], '<scenario><not well formed')
      report = validate(dir, scenario, modules)
      refute report.promotion_ready?
      assert_includes codes(report), 'malformed_xml'
    end
  end

  def test_missing_module_metadata_reported
    Dir.mktmpdir('val') do |dir|
      scenario, modules = stage(dir)
      FileUtils.rm_f(File.join(dir, modules.first['metadata_path']))
      report = validate(dir, scenario, modules)
      refute report.promotion_ready?
      assert_includes codes(report), 'missing_required_file'
      assert report.failed.any? { |f| f['path'].to_s.end_with?('secgen_metadata.xml') }
    end
  end

  def test_unresolved_reference_reported
    Dir.mktmpdir('val') do |dir|
      scenario, modules = stage(dir)
      # Validate the scenario against an empty module set -> its selector resolves to nothing.
      report = ScenarioGeneration::Validator.new(scenario: scenario, modules: [], staging_dir: dir).validate
      assert_includes codes(report), 'unresolved_module_reference'
    end
  end

  def test_missing_test_stub_blocks_promotion
    Dir.mktmpdir('val') do |dir|
      scenario, modules = stage(dir)
      FileUtils.rm_f(File.join(modules.first['staged_module_dir'], 'secgen_test', "#{modules.first['module_name']}.rb"))
      report = validate(dir, scenario, modules)
      refute report.promotion_ready?
      assert_includes codes(report), 'missing_test_stub'
    end
  end

  def test_convention_violation_reported
    Dir.mktmpdir('val') do |dir|
      scenario, modules = stage(dir)
      init = File.join(modules.first['staged_module_dir'], 'manifests', 'init.pp')
      File.write(init, "class wrong_name {\n}\n")
      report = validate(dir, scenario, modules)
      refute report.promotion_ready?
      assert_includes codes(report), 'convention_violation'
    end
  end

  def test_repair_context_is_machine_readable
    Dir.mktmpdir('val') do |dir|
      scenario, modules = stage(dir)
      FileUtils.rm_f(File.join(dir, modules.first['metadata_path']))
      report = validate(dir, scenario, modules)
      context = report.repair_context
      assert context['failures'].is_a?(Array)
      first = context['failures'].first
      %w[code message path hint].each { |key| assert first.key?(key), "missing key #{key}" }
      assert_kind_of String, context['summary']
    end
  end
end
