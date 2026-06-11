require_relative 'spec_helper'
require 'tmpdir'
require 'json'
require 'yaml'
require 'scenario_generation'

class TestScenarioGenerationTemplateCatalog < Minitest::Test
  INITIAL_WEB_VULNERABILITY_CLASSES = %w[
    broken_access_control
    command_injection
    path_traversal
    sql_injection
    xss
  ].freeze

  def valid_metadata(overrides = {})
    {
      'id' => 'sql-injection-web-form',
      'name' => 'SQL Injection Web Form',
      'version' => '1.0.0',
      'approved' => true,
      'description' => 'Generates a vulnerable PHP form backed by a SQL table.',
      'vulnerability_class' => 'sql_injection',
      'supported_platforms' => %w[linux debian web],
      'difficulties' => %w[easy medium],
      'module' => {
        'module_type' => 'vulnerability',
        'module_path' => 'modules/vulnerabilities/generated/sql_injection_web_form',
        'puppet_entry' => 'sql_injection_web_form.pp',
        'metadata_path' => 'secgen_metadata.xml'
      },
      'parameters' => [
        { 'name' => 'table_name', 'type' => 'datastore', 'target' => 'generator_input' }
      ],
      'required_files' => ['secgen_metadata.xml', 'sql_injection_web_form.pp'],
      'flags' => [{ 'name' => 'record_flag', 'target' => 'strings_to_leak' }],
      'tests' => {
        'exploit_expectation' => 'A crafted query exposes the flag.',
        'validation_hooks' => [{ 'name' => 'metadata exists', 'command' => %w[test -f secgen_metadata.xml] }]
      }
    }.merge(overrides)
  end

  def test_loads_initial_web_catalog
    catalog = ScenarioGeneration::TemplateCatalog.load

    assert_equal 5, catalog.templates.length
    assert_empty catalog.load_errors
    assert catalog.templates.all?(&:approved?)
    assert_equal INITIAL_WEB_VULNERABILITY_CLASSES, catalog.vulnerability_classes
  end

  def test_unparseable_or_unapproved_template_is_skipped_not_fatal
    Dir.mktmpdir('catalog') do |dir|
      File.write(File.join(dir, 'good.yml'), valid_metadata.to_yaml)
      File.write(File.join(dir, 'unapproved.yml'), valid_metadata('approved' => false, 'id' => 'unapproved').to_yaml)
      File.write(File.join(dir, 'broken.yml'), "id: broken\n  : not valid yaml : :\n")

      catalog = ScenarioGeneration::TemplateCatalog.load(dir)

      assert_equal 1, catalog.templates.length
      assert_equal 2, catalog.load_errors.length
      messages = catalog.load_errors.map { |e| e['message'] }.join("\n")
      assert_includes messages, 'approved must be true'
      assert_includes messages, 'Failed to parse'
    end
  end

  def test_compatible_filters_by_class_platform_difficulty
    catalog = ScenarioGeneration::TemplateCatalog.load

    matches = catalog.compatible(vulnerability_class: 'sql_injection', platform: 'web', difficulty: 'easy')
    refute_empty matches
    assert matches.all? { |t| t['vulnerability_class'] == 'sql_injection' }

    # Alias + spacing normalization on the requested class still matches.
    assert_equal matches.length,
                 catalog.compatible(vulnerability_class: 'SQL Injection', platform: 'web', difficulty: 'easy').length

    # Unsupported difficulty yields no matches.
    assert_empty catalog.compatible(vulnerability_class: 'sql_injection', platform: 'web', difficulty: 'advanced')
    # Unsupported platform yields no matches.
    assert_empty catalog.compatible(vulnerability_class: 'sql_injection', platform: 'windows', difficulty: 'easy')
  end

  def test_missing_catalog_root_raises
    error = assert_raises(ScenarioGeneration::CatalogError) do
      ScenarioGeneration::TemplateCatalog.load('/no/such/catalog/root')
    end
    assert_includes error.message, 'not found'
  end
end
