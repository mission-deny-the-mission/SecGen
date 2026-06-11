require_relative 'spec_helper'
require 'tmpdir'
require 'json'
require 'fileutils'
require 'nokogiri'
require 'scenario_generation'

# Regression tests for defects found by the adversarial review of the
# scenario-generation code (sections 3.3-9).
class TestScenarioGenerationReviewFixes < Minitest::Test
  SCENARIO_NS = 'http://www.github/cliffe/SecGen/scenario'.freeze
  VULN_XSD = File.expand_path('../../lib/schemas/vulnerability_metadata_schema.xsd', __dir__)
  SCENARIO_XSD = File.expand_path('../../lib/schemas/scenario_schema.xsd', __dir__)

  def intent(overrides = {})
    ScenarioGeneration::Intent.new({
      'name' => 'Review Lab', 'scenario_type' => 'lab', 'target_platform' => 'web', 'difficulty' => 'easy',
      'vulnerability_classes' => ['sql_injection'], 'learning_outcomes' => ['x'],
      'cybok' => [{ 'ka' => 'WAM', 'topic' => 'Web', 'keywords' => ['k'] }],
      'flags' => ['f'], 'evidence' => ['e'], 'seed' => 4242
    }.merge(overrides))
  end

  def stage(dir, it = intent)
    catalog = ScenarioGeneration::TemplateCatalog.load
    modules = it.normalized['vulnerability_classes'].map do |vc|
      template = catalog.compatible(vulnerability_class: vc, platform: it.normalized['target_platform'], difficulty: it.normalized['difficulty']).first
      ScenarioGeneration::ModuleGenerator.new(intent: it, template: template, staging_dir: dir).generate
    end
    scenario = ScenarioGeneration::ScenarioAssembler.new(intent: it, modules: modules, staging_dir: dir).assemble
    [scenario, modules]
  end

  # --- HIGH: duplicate vulnerability-class aliases -------------------------

  def test_intent_dedupes_aliased_vulnerability_classes
    it = intent('vulnerability_classes' => ['SQL injection', 'sqli', 'sql_injection'])
    assert_equal ['sql_injection'], it.normalized['vulnerability_classes']
  end

  def test_pipeline_produces_one_module_for_aliased_duplicates
    Dir.mktmpdir('dedupe') do |dir|
      it = intent('vulnerability_classes' => ['SQL injection', 'sqli'])
      adapter = ScenarioGeneration::OpenCodeAdapter.new(intent: it, staging_dir: dir, config: { 'isolation_mode' => 'host' })
      result = ScenarioGeneration::GenerationPipeline.new(intent: it, staging_dir: dir, adapter: adapter).run

      assert_equal 1, result['modules'].length
      assert result['promotion_ready']
      generated = Dir.glob(File.join(dir, 'modules/vulnerabilities/generated/*'))
      assert_equal 1, generated.length
    end
  end

  # --- HIGH: validator catches colliding modules / datastores --------------

  def test_validator_flags_duplicate_module_path
    Dir.mktmpdir('dup') do |dir|
      scenario, modules = stage(dir)
      report = ScenarioGeneration::Validator.new(scenario: scenario, modules: modules + modules, staging_dir: dir).validate
      assert_includes report.failed.map { |f| f['code'] }, 'duplicate_module_path'
      refute report.promotion_ready?
    end
  end

  # --- MEDIUM: XSD-invalid (but well-formed) artifacts ---------------------

  def test_xsd_invalid_scenario_blocks_promotion
    Dir.mktmpdir('xsd') do |dir|
      scenario, modules = stage(dir)
      xml = File.read(scenario['staged_scenario_path']).sub('</scenario>', "<bogus_undeclared_element/></scenario>")
      File.write(scenario['staged_scenario_path'], xml)
      report = ScenarioGeneration::Validator.new(scenario: scenario, modules: modules, staging_dir: dir).validate
      assert_includes report.failed.map { |f| f['code'] }, 'invalid_scenario_xml'
      assert report.failed.find { |f| f['code'] == 'invalid_scenario_xml' }['hint']
    end
  end

  def test_xsd_invalid_module_metadata_blocks_promotion
    Dir.mktmpdir('xsd') do |dir|
      scenario, modules = stage(dir)
      meta = File.join(dir, modules.first['metadata_path'])
      File.write(meta, File.read(meta).sub('<privilege>user_rwx</privilege>', '<privilege>super_admin</privilege>'))
      report = ScenarioGeneration::Validator.new(scenario: scenario, modules: modules, staging_dir: dir).validate
      assert_includes report.failed.map { |f| f['code'] }, 'invalid_module_metadata'
    end
  end

  def test_default_input_without_read_fact_reported
    Dir.mktmpdir('orphan') do |dir|
      scenario, modules = stage(dir)
      meta = File.join(dir, modules.first['metadata_path'])
      injected = File.read(meta).sub('  <conflict>', "  <default_input into=\"orphan_fact\">\n    <value>x</value>\n  </default_input>\n  <conflict>")
      File.write(meta, injected)
      report = ScenarioGeneration::Validator.new(scenario: scenario, modules: modules, staging_dir: dir).validate
      assert_includes report.failed.map { |f| f['code'] }, 'default_input_without_read_fact'
    end
  end

  # --- MEDIUM: XML-illegal control chars stripped --------------------------

  def test_metadata_strips_xml_illegal_control_chars
    Dir.mktmpdir('ctrl') do |dir|
      it = intent('name' => "Bad\u0000\u0007 Name\u0001")
      catalog = ScenarioGeneration::TemplateCatalog.load
      template = catalog.compatible(vulnerability_class: 'sql_injection', platform: 'web', difficulty: 'easy').first
      artifact = ScenarioGeneration::ModuleGenerator.new(intent: it, template: template, staging_dir: dir).generate

      xml = File.read(File.join(artifact['staged_module_dir'], 'secgen_metadata.xml'))
      refute_match(/[\u0000\u0007\u0001]/, xml)
      schema = Nokogiri::XML::Schema(File.read(VULN_XSD))
      assert_empty schema.validate(Nokogiri::XML(xml)), 'control chars stripped -> XSD-valid'
    end
  end

  # --- MEDIUM: manifest drift on changed inputs / missing intent section ---

  def build_manifest(dir, it = intent)
    catalog = ScenarioGeneration::TemplateCatalog.load
    selector = ScenarioGeneration::TemplateSelector.new(intent: it, catalog: catalog)
    modules = selector.select.map { |e| ScenarioGeneration::ModuleGenerator.new(intent: it, template: e['template'], staging_dir: dir).generate }
    scenario = ScenarioGeneration::ScenarioAssembler.new(intent: it, modules: modules, staging_dir: dir).assemble
    adapter = ScenarioGeneration::OpenCodeAdapter.new(intent: it, staging_dir: dir, config: { 'isolation_mode' => 'host' })
    report = ScenarioGeneration::Validator.new(scenario: scenario, modules: modules, staging_dir: dir).validate
    ScenarioGeneration::Manifest.build(intent: it, selection: selector.selection_summary, modules: modules,
                                       scenario: scenario, adapter: adapter, validation_report: report,
                                       staging_dir: dir, now: Time.utc(2026, 1, 1))
  end

  def test_detect_drift_flags_changed_intent
    Dir.mktmpdir('drift') do |dir|
      manifest = build_manifest(dir)
      drift = manifest.detect_drift(staging_dir: dir, intent: intent('difficulty' => 'medium'))
      assert drift['inputs']['intent_changed']
      assert drift['drifted']
    end
  end

  def test_detect_drift_flags_changed_templates
    Dir.mktmpdir('drift') do |dir|
      manifest = build_manifest(dir)
      drift = manifest.detect_drift(staging_dir: dir, templates: [{ 'template_id' => 'something-else' }])
      assert drift['inputs']['templates_changed']
      assert drift['drifted']
    end
  end

  def test_detect_drift_without_intent_section_does_not_crash
    Dir.mktmpdir('drift') do |dir|
      manifest = ScenarioGeneration::Manifest.new('output_hashes' => {}, 'tool_version' => '0.1.0')
      drift = manifest.detect_drift(staging_dir: dir, intent: intent)
      assert drift['inputs']['intent_changed'] # stored nil != current normalized
      assert drift['drifted'] # an input change is drift
    end
  end

  # --- LOW: selection determinism is seed-driven, not constant -------------

  def test_template_selection_varies_with_seed
    Dir.mktmpdir('sel') do |root|
      %w[sql-a sql-b].each do |id|
        File.write(File.join(root, "#{id}.yml"), {
          'id' => id, 'name' => id, 'version' => '1.0.0', 'approved' => true, 'vulnerability_class' => 'sql_injection',
          'supported_platforms' => %w[web], 'difficulties' => %w[easy],
          'module' => { 'module_type' => 'vulnerability', 'module_path' => "modules/vulnerabilities/generated/#{id.tr('-', '_')}", 'puppet_entry' => "#{id.tr('-', '_')}.pp", 'metadata_path' => 'secgen_metadata.xml' },
          'parameters' => [{ 'name' => 'p', 'type' => 'string', 'target' => 'template_variable' }],
          'required_files' => ['secgen_metadata.xml'], 'flags' => [{ 'name' => 'flag', 'target' => 'strings_to_leak' }],
          'tests' => { 'exploit_expectation' => 'x', 'validation_hooks' => [{ 'name' => 'h', 'command' => %w[test -f secgen_metadata.xml] }] }
        }.to_yaml)
      end
      catalog = ScenarioGeneration::TemplateCatalog.load(root)
      picks = (1..40).map do |seed|
        ScenarioGeneration::TemplateSelector.new(intent: intent('seed' => seed), catalog: catalog).select.first['template_id']
      end
      assert picks.uniq.length > 1, 'selection should depend on the seed, not be constant'
    end
  end
end
