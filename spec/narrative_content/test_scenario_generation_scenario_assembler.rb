require_relative 'spec_helper'
require 'tmpdir'
require 'json'
require 'nokogiri'
require 'scenario_generation'

class TestScenarioGenerationScenarioAssembler < Minitest::Test
  SCENARIO_XSD = File.expand_path('../../lib/schemas/scenario_schema.xsd', __dir__)
  SCENARIO_NS = 'http://www.github/cliffe/SecGen/scenario'.freeze

  def valid_intent(overrides = {})
    data = {
      'name' => 'Vulnerable Web App Lab',
      'scenario_type' => 'lab',
      'target_platform' => 'web',
      'difficulty' => 'medium',
      'vulnerability_classes' => ['sql_injection'],
      'learning_outcomes' => ['Understand SQL injection', 'Practice safe queries'],
      'cybok' => [{ 'ka' => 'WAM', 'topic' => 'Web & Mobile Security', 'keywords' => ['sql injection'] }],
      'flags' => ['exfiltrate the customer flag'],
      'evidence' => ['database dump'],
      'seed' => 4242
    }.merge(overrides)
    ScenarioGeneration::Intent.new(data)
  end

  def generated_modules(dir, intent)
    catalog = ScenarioGeneration::TemplateCatalog.load
    intent.normalized['vulnerability_classes'].map do |vc|
      template = catalog.compatible(
        vulnerability_class: vc,
        platform: intent.normalized['target_platform'],
        difficulty: intent.normalized['difficulty']
      ).first
      ScenarioGeneration::ModuleGenerator.new(intent: intent, template: template, staging_dir: dir).generate
    end
  end

  def assemble(dir, intent: valid_intent)
    modules = generated_modules(dir, intent)
    ScenarioGeneration::ScenarioAssembler.new(intent: intent, modules: modules, staging_dir: dir).assemble
  end

  def xpath(xml, expr)
    Nokogiri::XML(xml).xpath(expr, 's' => SCENARIO_NS)
  end

  def test_assembles_xsd_valid_scenario
    Dir.mktmpdir('assembler') do |dir|
      artifact = assemble(dir)
      schema = Nokogiri::XML::Schema(File.read(SCENARIO_XSD))
      errors = schema.validate(Nokogiri::XML(artifact['xml']))
      assert_empty errors, "XSD errors: #{errors.map(&:message).join('; ')}"
      assert File.exist?(artifact['staged_scenario_path'])
    end
  end

  def test_scenario_references_generated_module
    Dir.mktmpdir('assembler') do |dir|
      intent = valid_intent
      artifact = assemble(dir, intent: intent)

      system_name = xpath(artifact['xml'], '//s:system/s:system_name').first.text
      assert_equal intent.identifiers['system_name'], system_name

      module_paths = xpath(artifact['xml'], '//s:vulnerability').map { |n| n['module_path'] }
      assert_includes module_paths, ".*/#{intent.identifiers['module_name']}"
    end
  end

  def test_metadata_maps_type_and_difficulty_and_includes_cybok
    Dir.mktmpdir('assembler') do |dir|
      xml = assemble(dir).to_h['xml']
      assert_equal 'lab-sheet', xpath(xml, '//s:scenario/s:type').first.text
      assert_equal 'intermediate', xpath(xml, '//s:scenario/s:difficulty').first.text
      cybok = xpath(xml, '//s:scenario/s:CyBOK').first
      assert_equal 'WAM', cybok['KA']
      refute_empty cybok.xpath('s:keyword', 's' => SCENARIO_NS)
    end
  end

  def test_flag_datastore_wiring_matches_module_flag_value
    Dir.mktmpdir('assembler') do |dir|
      intent = valid_intent
      modules = generated_modules(dir, intent)
      artifact = ScenarioGeneration::ScenarioAssembler.new(intent: intent, modules: modules, staging_dir: dir).assemble
      xml = artifact['xml']

      flag = modules.first['flags'].first
      ds_name = "#{modules.first['module_name']}_#{flag['name']}".downcase

      precompute = xpath(xml, '//s:input[@into_datastore]').find { |n| n['into_datastore'] == ds_name }
      refute_nil precompute, "expected datastore #{ds_name}"
      assert_equal flag['value'], precompute.xpath('s:value', 's' => SCENARIO_NS).first.text

      consumed = xpath(xml, '//s:vulnerability/s:input[@into="strings_to_leak"]/s:datastore').map(&:text)
      assert_includes consumed, ds_name
    end
  end

  def test_optional_attacker_system_only_for_attack_ctf
    Dir.mktmpdir('lab') do |dir|
      artifact = assemble(dir, intent: valid_intent('scenario_type' => 'lab'))
      assert_equal 1, xpath(artifact['xml'], '//s:system').length
    end

    Dir.mktmpdir('attack') do |dir|
      artifact = assemble(dir, intent: valid_intent('scenario_type' => 'attack_ctf'))
      systems = xpath(artifact['xml'], '//s:system')
      assert_equal 2, systems.length
      bases = xpath(artifact['xml'], '//s:base').map { |b| b['distro'] }.compact
      assert_includes bases, 'Kali'
    end
  end

  def test_doc_stub_written_and_summarizes
    Dir.mktmpdir('assembler') do |dir|
      artifact = assemble(dir)
      doc = File.read(artifact['doc_stub_path'])
      assert_includes doc, '# Vulnerable Web App Lab'
      assert_includes doc, 'not yet reviewed'
      assert_includes doc, 'sql_injection'
      assert_includes doc, 'Understand SQL injection'
    end
  end

  def test_xml_is_deterministic_across_staging_dirs
    Dir.mktmpdir('a') do |a|
      Dir.mktmpdir('b') do |b|
        assert_equal assemble(a)['xml'], assemble(b)['xml']
      end
    end
  end
end
