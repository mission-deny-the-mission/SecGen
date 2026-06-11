require_relative 'spec_helper'
require 'tmpdir'
require 'json'
require 'yaml'
require 'scenario_generation'

class TestScenarioGenerationTemplateSelector < Minitest::Test
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

  def template_metadata(id:, vulnerability_class: 'sql_injection')
    {
      'id' => id,
      'name' => id,
      'version' => '1.0.0',
      'approved' => true,
      'description' => 'desc',
      'vulnerability_class' => vulnerability_class,
      'supported_platforms' => %w[linux debian web],
      'difficulties' => %w[easy medium],
      'module' => {
        'module_type' => 'vulnerability',
        'module_path' => "modules/vulnerabilities/generated/#{id.tr('-', '_')}",
        'puppet_entry' => "#{id.tr('-', '_')}.pp",
        'metadata_path' => 'secgen_metadata.xml'
      },
      'parameters' => [{ 'name' => 'p', 'type' => 'string', 'target' => 'template_variable' }],
      'required_files' => ['secgen_metadata.xml'],
      'flags' => [{ 'name' => 'flag', 'target' => 'strings_to_leak' }],
      'tests' => {
        'exploit_expectation' => 'exploit',
        'validation_hooks' => [{ 'name' => 'h', 'command' => %w[test -f secgen_metadata.xml] }]
      }
    }
  end

  def catalog_with(*ids)
    Dir.mktmpdir('selector-catalog') do |dir|
      ids.each { |id| File.write(File.join(dir, "#{id}.yml"), template_metadata(id: id).to_yaml) }
      yield ScenarioGeneration::TemplateCatalog.load(dir)
    end
  end

  def test_selects_one_template_per_requested_class
    catalog = ScenarioGeneration::TemplateCatalog.load
    intent = valid_intent('vulnerability_classes' => ['SQL injection', 'XSS'])

    selection = ScenarioGeneration::TemplateSelector.new(intent: intent, catalog: catalog).select

    assert_equal 2, selection.length
    assert_equal %w[sql_injection xss], selection.map { |s| s['vulnerability_class'] }
    assert selection.all? { |s| s['template'].is_a?(ScenarioGeneration::TemplateMetadata) }
    assert selection.all? { |s| !s['template_id'].to_s.empty? }
  end

  def test_selection_is_deterministic_for_seed
    catalog_with('sql-a', 'sql-b') do |catalog|
      intent = valid_intent('seed' => 99)
      first = ScenarioGeneration::TemplateSelector.new(intent: intent, catalog: catalog).select
      second = ScenarioGeneration::TemplateSelector.new(intent: intent, catalog: catalog).select

      assert_equal 1, first.length
      assert_equal first.first['template_id'], second.first['template_id']
    end
  end

  def test_selection_summary_omits_template_object
    catalog = ScenarioGeneration::TemplateCatalog.load
    summary = ScenarioGeneration::TemplateSelector.new(intent: valid_intent, catalog: catalog).selection_summary

    assert_equal [{ 'vulnerability_class' => 'sql_injection', 'template_id' => 'sql-injection-web-form', 'template_version' => '1.0.0' }], summary
  end

  def test_fails_fast_when_no_compatible_template
    catalog = ScenarioGeneration::TemplateCatalog.load
    # insecure_file_upload is a valid Intent class but has no template in the catalog.
    intent = valid_intent('vulnerability_classes' => ['insecure file upload'])

    error = assert_raises(ScenarioGeneration::TemplateSelectionError) do
      ScenarioGeneration::TemplateSelector.new(intent: intent, catalog: catalog).select
    end
    assert_includes error.message, 'insecure_file_upload'
    assert_includes error.message, 'No approved template supports'
  end

  def test_rejects_when_platform_unsupported
    catalog = ScenarioGeneration::TemplateCatalog.load
    intent = valid_intent('target_platform' => 'windows')

    error = assert_raises(ScenarioGeneration::TemplateSelectionError) do
      ScenarioGeneration::TemplateSelector.new(intent: intent, catalog: catalog).select
    end
    assert_includes error.message, 'platform=windows'
  end
end
