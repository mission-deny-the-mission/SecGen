require_relative 'spec_helper'
require 'tmpdir'
require 'json'
require 'scenario_generation'

class TestScenarioGenerationTemplateMetadata < Minitest::Test
  def valid_metadata
    {
      'id' => 'SQL Injection Web Form',
      'name' => 'SQL Injection Web Form',
      'version' => '1.0.0',
      'approved' => true,
      'description' => 'Generates a vulnerable PHP form backed by a SQL table.',
      'vulnerability_class' => 'SQL injection',
      'supported_platforms' => ['linux', 'debian'],
      'difficulties' => ['easy', 'medium'],
      'module' => {
        'module_type' => 'vulnerability',
        'module_path' => 'modules/vulnerabilities/generated/sql_injection_web_form',
        'puppet_entry' => 'sql_injection_web_form.pp',
        'metadata_path' => 'secgen_metadata.xml',
        'requires' => ['.*apache.*compatible.*', '.*mysql.*compatible.*']
      },
      'parameters' => [
        {
          'name' => 'table_headings',
          'type' => 'datastore',
          'target' => 'generator_input',
          'required' => true
        },
        {
          'name' => 'difficulty',
          'type' => 'enum',
          'target' => 'template_variable',
          'values' => ['easy', 'medium']
        }
      ],
      'required_files' => [
        'templates/index.php.erb',
        'manifests/install.pp',
        'secgen_metadata.xml'
      ],
      'flags' => [
        {
          'name' => 'customer_admin_flag',
          'target' => 'strings_to_leak'
        }
      ],
      'tests' => {
        'exploit_expectation' => 'Submitting a crafted review query can reveal the configured flag.',
        'validation_hooks' => [
          {
            'name' => 'metadata exists',
            'command' => ['test', '-f', 'secgen_metadata.xml']
          }
        ]
      }
    }
  end

  def test_valid_metadata_is_accepted_and_normalized
    metadata = ScenarioGeneration::TemplateMetadata.new(valid_metadata)

    assert metadata.approved?
    assert_equal 'sql-injection-web-form', metadata['id']
    assert_equal 'sql_injection', metadata['vulnerability_class']
    assert_equal ['linux', 'debian'], metadata['supported_platforms']
    assert_equal ['easy', 'medium'], metadata['difficulties']
    assert_equal ['table_headings', 'difficulty'], metadata.parameter_names
  end

  def test_unapproved_template_is_rejected
    error = assert_raises(ScenarioGeneration::TemplateMetadataError) do
      ScenarioGeneration::TemplateMetadata.new(valid_metadata.merge('approved' => false))
    end

    assert_includes error.message, 'approved must be true'
  end

  def test_missing_required_descriptors_are_reported
    data = valid_metadata
    data.delete('required_files')
    data['module'].delete('puppet_entry')
    data['tests'].delete('exploit_expectation')

    error = assert_raises(ScenarioGeneration::TemplateMetadataError) do
      ScenarioGeneration::TemplateMetadata.new(data)
    end

    assert_includes error.message, 'template missing required_files'
  end

  def test_missing_nested_fields_are_reported_after_top_level_is_complete
    data = valid_metadata
    data['module'].delete('puppet_entry')
    data['tests'].delete('exploit_expectation')

    error = assert_raises(ScenarioGeneration::TemplateMetadataError) do
      ScenarioGeneration::TemplateMetadata.new(data)
    end

    assert_includes error.message, 'module missing puppet_entry'
    assert_includes error.message, 'tests missing exploit_expectation'
  end

  def test_unsupported_vulnerability_class_is_rejected
    error = assert_raises(ScenarioGeneration::TemplateMetadataError) do
      ScenarioGeneration::TemplateMetadata.new(valid_metadata.merge('vulnerability_class' => 'time travel'))
    end

    assert_includes error.message, 'Unsupported vulnerability_class'
  end

  def test_parameter_descriptors_require_name_type_and_target
    data = valid_metadata
    data['parameters'] = [{ 'name' => 'difficulty' }]

    error = assert_raises(ScenarioGeneration::TemplateMetadataError) do
      ScenarioGeneration::TemplateMetadata.new(data)
    end

    assert_includes error.message, 'parameters[0] missing type'
    assert_includes error.message, 'parameters[0] missing target'
  end

  def test_loads_json_metadata_file
    Dir.mktmpdir('template_metadata') do |dir|
      path = File.join(dir, 'template.json')
      File.write(path, JSON.pretty_generate(valid_metadata))

      metadata = ScenarioGeneration::TemplateMetadata.load(path)

      assert_equal 'sql_injection', metadata['vulnerability_class']
    end
  end

  def test_loads_yaml_metadata_file
    Dir.mktmpdir('template_metadata') do |dir|
      path = File.join(dir, 'template.yml')
      File.write(path, valid_metadata.to_yaml)

      metadata = ScenarioGeneration::TemplateMetadata.load(path)

      assert_equal 'sql-injection-web-form', metadata['id']
    end
  end
end
