require_relative 'spec_helper'
require 'tmpdir'
require 'json'
require 'fileutils'
require 'time'
require 'scenario_generation'

class TestScenarioGenerationManifest < Minitest::Test
  FIXED_NOW = Time.utc(2026, 1, 1, 0, 0, 0)

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

  # Runs the deterministic mini-pipeline into `dir` and returns a built Manifest.
  def build_manifest(dir, intent: valid_intent, now: FIXED_NOW)
    catalog = ScenarioGeneration::TemplateCatalog.load
    selector = ScenarioGeneration::TemplateSelector.new(intent: intent, catalog: catalog)
    selection = selector.selection_summary
    modules = selector.select.map do |entry|
      ScenarioGeneration::ModuleGenerator.new(intent: intent, template: entry['template'], staging_dir: dir).generate
    end
    scenario = ScenarioGeneration::ScenarioAssembler.new(intent: intent, modules: modules, staging_dir: dir).assemble
    adapter = ScenarioGeneration::OpenCodeAdapter.new(intent: intent, staging_dir: dir, config: { 'isolation_mode' => 'host', 'model' => 'gpt-4o' })
    report = ScenarioGeneration::Validator.new(scenario: scenario, modules: modules, staging_dir: dir).validate
    ScenarioGeneration::Manifest.build(
      intent: intent, selection: selection, modules: modules, scenario: scenario,
      adapter: adapter, validation_report: report, staging_dir: dir, now: now
    )
  end

  def test_manifest_records_required_fields
    Dir.mktmpdir('manifest') do |dir|
      manifest = build_manifest(dir)
      %w[tool_version generated_at intent seed identifiers templates modules
         generated_paths output_hashes harness retry harness_trace validation status].each do |key|
        refute_nil manifest[key], "missing #{key}"
      end
      assert_equal '0.1.0', manifest['tool_version']
      assert_equal 4242, manifest['seed']
      assert_equal 'opencode', manifest['harness']['harness']
      assert_equal 'gpt-4o', manifest['harness']['model']
      refute_empty manifest.output_hashes
    end
  end

  def test_review_status_tracked_separately
    Dir.mktmpdir('manifest') do |dir|
      manifest = build_manifest(dir)
      updated = manifest.with_review_status(review: 'reviewed', promotion: 'promoted')

      assert_equal({ 'review' => 'reviewed', 'promotion' => 'promoted' }, updated['status'])
      # original inputs untouched
      assert_equal manifest['intent'], updated['intent']
      assert_equal manifest['output_hashes'], updated['output_hashes']
      # original manifest not mutated
      assert_equal({ 'review' => 'generated', 'promotion' => 'staged' }, manifest['status'])
    end
  end

  def test_output_hashes_are_content_only_and_stable
    Dir.mktmpdir('a') do |a|
      Dir.mktmpdir('b') do |b|
        assert_equal build_manifest(a).output_hashes, build_manifest(b).output_hashes
      end
    end
  end

  def test_detect_drift_flags_changed_file
    Dir.mktmpdir('manifest') do |dir|
      manifest = build_manifest(dir)
      changed = manifest.output_hashes.keys.find { |k| k.end_with?('secgen_metadata.xml') }
      File.write(File.join(dir, changed), "<vulnerability/>\n")

      drift = manifest.detect_drift(staging_dir: dir)
      assert drift['drifted']
      flagged = drift['files'].find { |f| f['path'] == changed }
      assert_equal 'content_changed', flagged['reason']
    end
  end

  def test_detect_drift_flags_missing_file
    Dir.mktmpdir('manifest') do |dir|
      manifest = build_manifest(dir)
      gone = manifest.output_hashes.keys.first
      FileUtils.rm_f(File.join(dir, gone))

      drift = manifest.detect_drift(staging_dir: dir)
      assert drift['drifted']
      assert_equal 'missing', drift['files'].find { |f| f['path'] == gone }['reason']
    end
  end

  def test_no_drift_when_unchanged
    Dir.mktmpdir('manifest') do |dir|
      manifest = build_manifest(dir)
      drift = manifest.detect_drift(staging_dir: dir, intent: valid_intent, templates: manifest['templates'])
      refute drift['drifted'], drift.inspect
    end
  end

  def test_load_roundtrip_modulo_generated_at
    Dir.mktmpdir('manifest') do |dir|
      manifest = build_manifest(dir)
      path = manifest.write(File.join(dir, 'manifest.json'))
      loaded = ScenarioGeneration::Manifest.load(path)
      assert_equal manifest.to_h, loaded.to_h
    end
  end
end
