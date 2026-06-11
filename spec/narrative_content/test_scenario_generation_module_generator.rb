require_relative 'spec_helper'
require 'tmpdir'
require 'json'
require 'nokogiri'
require 'scenario_generation'

class TestScenarioGenerationModuleGenerator < Minitest::Test
  VULN_METADATA_XSD = File.expand_path('../../lib/schemas/vulnerability_metadata_schema.xsd', __dir__)

  def valid_intent(overrides = {})
    data = {
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
    }.merge(overrides)
    ScenarioGeneration::Intent.new(data)
  end

  def sql_template
    catalog = ScenarioGeneration::TemplateCatalog.load
    catalog.compatible(vulnerability_class: 'sql_injection', platform: 'web', difficulty: 'easy').first
  end

  def generate(dir, intent: valid_intent, adapter: nil, seed: nil)
    ScenarioGeneration::ModuleGenerator.new(
      intent: intent, template: sql_template, staging_dir: dir, adapter: adapter, seed: seed
    ).generate
  end

  def test_generates_secgen_module_layout
    Dir.mktmpdir('modgen') do |dir|
      artifact = generate(dir)
      mod_dir = artifact['staged_module_dir']
      name = artifact['module_name']

      assert Dir.exist?(mod_dir)
      assert_equal "require #{name}\n", File.read(File.join(mod_dir, "#{name}.pp"))
      assert_includes File.read(File.join(mod_dir, 'manifests/init.pp')), "class #{name} {"
      assert_includes File.read(File.join(mod_dir, 'manifests/install.pp')), "class #{name}::install"
      assert_includes File.read(File.join(mod_dir, 'manifests/configure.pp')), "class #{name}::configure"
      assert File.exist?(File.join(mod_dir, 'secgen_metadata.xml'))
      assert File.exist?(File.join(mod_dir, 'templates/index.php.erb'))
      assert File.exist?(File.join(mod_dir, "secgen_test/#{name}.rb"))
    end
  end

  def test_module_path_comes_from_intent_identifiers
    Dir.mktmpdir('modgen') do |dir|
      intent = valid_intent
      artifact = generate(dir, intent: intent)

      assert_equal intent.identifiers['module_name'], artifact['module_name']
      assert_equal intent.identifiers['module_path'], artifact['module_path']
      assert_includes artifact['module_path'], 'modules/vulnerabilities/generated/'
      assert_equal ".*/#{intent.identifiers['module_name']}", artifact['selection_regex']
    end
  end

  def test_metadata_is_xsd_valid_and_read_facts_cover_default_inputs
    Dir.mktmpdir('modgen') do |dir|
      artifact = generate(dir)
      xml = File.read(File.join(artifact['staged_module_dir'], 'secgen_metadata.xml'))

      schema = Nokogiri::XML::Schema(File.read(VULN_METADATA_XSD))
      doc = Nokogiri::XML(xml)
      errors = schema.validate(doc)
      assert_empty errors, "XSD errors: #{errors.map(&:message).join('; ')}"

      ns = { 'v' => ModuleGeneratorNS }
      read_facts = doc.xpath('//v:read_fact', ns).map(&:text)
      default_into = doc.xpath('//v:default_input', ns).map { |n| n['into'] }
      assert (default_into - read_facts).empty?, "default_input without read_fact: #{(default_into - read_facts).inspect}"
    end
  end

  def test_parameter_rendering_is_deterministic_for_seed
    Dir.mktmpdir('a') do |dir_a|
      Dir.mktmpdir('b') do |dir_b|
        a = generate(dir_a, seed: 7)
        b = generate(dir_b, seed: 7)
        assert_equal a['rendered_parameters'], b['rendered_parameters']
        assert_equal a['flags'], b['flags']

        c = generate(Dir.mktmpdir('c'), seed: 8)
        refute_equal a['flags'].first['value'], c['flags'].first['value']
      end
    end
  end

  def test_flag_value_is_seed_derived_flag_format
    Dir.mktmpdir('modgen') do |dir|
      artifact = generate(dir, seed: 99)
      assert_match(/\AFLAG\{[0-9a-f]{16}\}\z/, artifact['flags'].first['value'])
    end
  end

  def test_test_stub_describes_exploit_and_flag
    Dir.mktmpdir('modgen') do |dir|
      artifact = generate(dir)
      stub = File.read(File.join(artifact['staged_module_dir'], "secgen_test/#{artifact['module_name']}.rb"))
      assert_includes stub, 'Exploit expectation:'
      assert_includes stub, 'Expected flag'
    end
  end

  def test_writes_only_inside_staging
    Dir.mktmpdir('modgen') do |dir|
      intent = valid_intent
      adapter = ScenarioGeneration::OpenCodeAdapter.new(intent: intent, staging_dir: dir, config: { 'isolation_mode' => 'host' })
      generator = ScenarioGeneration::ModuleGenerator.new(intent: intent, template: sql_template, staging_dir: dir, adapter: adapter)

      error = assert_raises(ScenarioGeneration::ModuleGenerationError) do
        generator.send(:write_staged, '../../../../../../../../tmp/escape.pp', 'pwned')
      end
      assert_includes error.message, 'staging'
    end
  end

  # Namespace constant used in XPath above.
  ModuleGeneratorNS = 'http://www.github/cliffe/SecGen/vulnerability'.freeze
end
