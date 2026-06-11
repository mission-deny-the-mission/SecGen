require 'digest'
require 'json'
require 'time'
require 'fileutils'

module ScenarioGeneration
  class ManifestError < StandardError; end

  # Builds, writes, loads, and compares the generation manifest: original +
  # normalized intent, seed, selected templates, module names, generated paths,
  # tool version, timestamp, harness/provider/model metadata, retry metadata,
  # per-file content hashes, harness trace, and separately-tracked review/
  # promotion status. Supports drift detection by recomputing hashes.
  #
  # output_hashes covers ONLY the deterministically generated artifacts (module
  # files, scenario, doc) so a regeneration into a fresh staging dir produces
  # identical hashes. generated_at is the only non-deterministic field and is
  # excluded from hash comparison.
  class Manifest
    TOOL_VERSION = '0.1.0'.freeze

    def self.build(intent:, selection:, modules:, scenario:, adapter:, validation_report:, staging_dir:, harness_trace: {}, now: Time.now)
      paths = output_paths(modules, scenario)
      data = {
        'tool_version' => TOOL_VERSION,
        'generated_at' => now.utc.iso8601,
        'intent' => { 'original' => intent.to_h, 'normalized' => intent.normalized },
        'seed' => intent.normalized['seed'],
        'identifiers' => intent.identifiers,
        'templates' => selection,
        'modules' => Array(modules).map { |mod| { 'module_name' => mod['module_name'], 'module_path' => mod['module_path'] } },
        'generated_paths' => paths,
        'output_hashes' => compute_hashes(staging_dir, paths),
        'harness' => harness_metadata(adapter, intent),
        'retry' => {
          'limit' => adapter.respond_to?(:retry_limit) ? adapter.retry_limit : nil,
          'attempts' => Array(harness_trace['repair_attempts']).length
        },
        'harness_trace' => harness_trace,
        'validation' => validation_report.respond_to?(:to_h) ? validation_report.to_h : validation_report,
        'status' => { 'review' => 'generated', 'promotion' => 'staged' }
      }
      new(data)
    end

    def self.load(path)
      raise ManifestError, "Manifest not found: #{path}" unless File.exist?(path)

      new(JSON.parse(File.read(path)))
    rescue JSON::ParserError => e
      raise ManifestError, "Failed to parse manifest #{path}: #{e.message}"
    end

    def self.output_paths(modules, scenario)
      paths = []
      Array(modules).each do |mod|
        Array(mod['generated_files']).each { |relpath| paths << File.join(mod['module_path'], relpath) }
      end
      paths << scenario['scenario_relpath']
      paths << scenario['doc_relpath']
      paths.compact.uniq.sort
    end

    def self.compute_hashes(staging_dir, paths)
      paths.each_with_object({}) do |relpath, result|
        abs = File.join(staging_dir, relpath)
        result[relpath] = File.exist?(abs) ? Digest::SHA256.hexdigest(File.read(abs)) : nil
      end
    end

    def self.harness_metadata(adapter, intent)
      report = adapter.respond_to?(:report) ? adapter.report : {}
      {
        'harness' => report['harness'],
        'model' => report['model'],
        'isolation_mode' => report['isolation_mode'],
        'container_image' => report['container_image'],
        'retry_limit' => report['retry_limit'],
        'provider' => (intent.respond_to?(:llm_options) ? intent.llm_options['provider'] : nil)
      }
    end

    def initialize(data)
      raise ManifestError, 'Manifest data must be a Hash' unless data.is_a?(Hash)

      @data = stringify(data)
    end

    def [](key)
      @data[key.to_s]
    end

    def to_h
      stringify(@data)
    end

    def output_hashes
      @data['output_hashes'] || {}
    end

    def write(path)
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, JSON.pretty_generate(to_h))
      path
    end

    # Recompute hashes under staging_dir and (optionally) compare inputs.
    def detect_drift(staging_dir:, intent: nil, templates: nil)
      files = []
      output_hashes.each do |relpath, expected|
        abs = File.join(staging_dir, relpath)
        unless File.exist?(abs)
          files << { 'path' => relpath, 'reason' => 'missing', 'expected' => expected, 'actual' => nil }
          next
        end

        actual = Digest::SHA256.hexdigest(File.read(abs))
        files << { 'path' => relpath, 'reason' => 'content_changed', 'expected' => expected, 'actual' => actual } if actual != expected
      end

      inputs = { 'tool_version_changed' => TOOL_VERSION != self['tool_version'] }
      inputs['intent_changed'] = (intent.normalized != self['intent']['normalized']) if intent
      inputs['templates_changed'] = (templates != self['templates']) unless templates.nil?

      { 'drifted' => !files.empty? || inputs.values.any? { |value| value == true }, 'files' => files, 'inputs' => inputs }
    end

    # Returns a NEW manifest with only the review/promotion status changed; all
    # original inputs are deep-duplicated and preserved.
    def with_review_status(review:, promotion:)
      data = stringify(@data)
      data['status'] = { 'review' => review, 'promotion' => promotion }
      self.class.new(data)
    end

    private

    def stringify(value)
      case value
      when Hash
        value.each_with_object({}) { |(key, val), result| result[key.to_s] = stringify(val) }
      when Array
        value.map { |entry| stringify(entry) }
      else
        value
      end
    end
  end
end
