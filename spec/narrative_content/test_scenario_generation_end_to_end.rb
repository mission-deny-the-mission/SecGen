require_relative 'spec_helper'
require 'tmpdir'
require 'json'
require 'nokogiri'
require 'scenario_generation'

# End-to-end verification (section 9) driving the section 8 example intent
# through the full deterministic generation pipeline. No real docker/OpenCode
# process is executed: the pipeline records harness phases as command arrays and
# the repair loop uses an injectable command_runner.
class TestScenarioGenerationEndToEnd < Minitest::Test
  EXAMPLE_INTENT = File.expand_path(
    '../../openspec/changes/insecure-software-scenario-generation/docs/examples/example-intent.yml', __dir__
  )
  SCENARIO_XSD = File.expand_path('../../lib/schemas/scenario_schema.xsd', __dir__)
  VULN_XSD = File.expand_path('../../lib/schemas/vulnerability_metadata_schema.xsd', __dir__)

  def example_intent
    ScenarioGeneration::Intent.load(EXAMPLE_INTENT)
  end

  # A host-isolation adapter so nothing depends on docker.
  def host_adapter(intent, dir)
    ScenarioGeneration::OpenCodeAdapter.new(intent: intent, staging_dir: dir, config: { 'isolation_mode' => 'host' })
  end

  def pipeline(intent, dir, command_runner: nil)
    ScenarioGeneration::GenerationPipeline.new(
      intent: intent, staging_dir: dir, adapter: host_adapter(intent, dir), command_runner: command_runner
    )
  end

  def test_example_intent_loads_and_selects_sql_template
    intent = example_intent
    assert_equal 'sql_injection', intent.normalized['vulnerability_classes'].first
    catalog = ScenarioGeneration::TemplateCatalog.load
    selection = ScenarioGeneration::TemplateSelector.new(intent: intent, catalog: catalog).select
    assert_equal 'sql-injection-web-form', selection.first['template_id']
  end

  def test_generates_staged_scenario_from_example_intent
    Dir.mktmpdir('e2e') do |dir|
      result = pipeline(example_intent, dir).run

      scenario = result['scenario']
      mod = result['modules'].first
      assert File.exist?(scenario['staged_scenario_path']), 'scenario.xml missing'
      assert Dir.exist?(mod['staged_module_dir']), 'module dir missing'
      assert File.exist?(scenario['doc_stub_path']), 'doc stub missing'
      assert File.exist?(File.join(dir, 'manifest.json')), 'manifest.json missing'
    end
  end

  def test_staged_scenario_validates_and_produces_manifest
    Dir.mktmpdir('e2e') do |dir|
      result = pipeline(example_intent, dir).run

      assert result['promotion_ready'], "validation failures: #{result['validation'].failed.inspect}"
      manifest = result['manifest']
      refute_empty manifest.output_hashes

      # Independently re-validate the staged XML against the real schemas.
      scenario_schema = Nokogiri::XML::Schema(File.read(SCENARIO_XSD))
      assert_empty scenario_schema.validate(Nokogiri::XML(File.read(result['scenario']['staged_scenario_path'])))
      vuln_schema = Nokogiri::XML::Schema(File.read(VULN_XSD))
      meta = File.join(dir, result['modules'].first['metadata_path'])
      assert_empty vuln_schema.validate(Nokogiri::XML(File.read(meta)))
    end
  end

  def test_regeneration_matches_manifest_hashes
    Dir.mktmpdir('run-a') do |a|
      Dir.mktmpdir('run-b') do |b|
        intent = example_intent
        result = pipeline(intent, a).run
        regen = pipeline(intent, a).regenerate(into: b, manifest: result['manifest'])
        assert regen['matches'], "hash mismatch:\n#{regen['output_hashes'].to_a - result['manifest'].output_hashes.to_a}"
      end
    end
  end

  def test_repair_loop_fixes_failing_artifact
    Dir.mktmpdir('repair') do |dir|
      result = pipeline(example_intent, dir).run
      mod = result['modules'].first
      scenario = result['scenario']

      stub = File.join(mod['staged_module_dir'], 'secgen_test', "#{mod['module_name']}.rb")
      File.delete(stub)
      validator = ScenarioGeneration::Validator.new(scenario: scenario, modules: result['modules'], staging_dir: dir)
      runner = ->(_command) { File.write(stub, "# repaired stub\n") }

      outcome = ScenarioGeneration::RepairLoop.new(
        adapter: host_adapter(example_intent, dir), validator: validator, command_runner: runner
      ).run

      assert_equal 'passed', outcome['status']
      assert outcome['promoted']
      assert File.exist?(stub)
    end
  end

  def test_retry_exhaustion_reports_without_promotion
    Dir.mktmpdir('repair') do |dir|
      result = pipeline(example_intent, dir).run
      mod = result['modules'].first
      stub = File.join(mod['staged_module_dir'], 'secgen_test', "#{mod['module_name']}.rb")
      File.delete(stub) # never repaired

      validator = ScenarioGeneration::Validator.new(scenario: result['scenario'], modules: result['modules'], staging_dir: dir)
      adapter = ScenarioGeneration::OpenCodeAdapter.new(intent: example_intent, staging_dir: dir, config: { 'isolation_mode' => 'host', 'retry_limit' => 2 })

      outcome = ScenarioGeneration::RepairLoop.new(adapter: adapter, validator: validator).run

      assert_equal 'retry_exhausted', outcome['status']
      assert_equal 2, outcome['repair_commands'].length
      refute outcome['promoted']
    end
  end
end
