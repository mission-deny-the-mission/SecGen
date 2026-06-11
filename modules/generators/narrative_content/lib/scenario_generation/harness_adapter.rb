module ScenarioGeneration
  class HarnessError < StandardError; end

  class HarnessAdapter
    PHASES = %i[
      prepare
      plan
      generate
      validate
      repair
      report
    ].freeze

    attr_reader :intent, :staging_dir, :config

    def self.for(intent:, staging_dir:, config: {})
      harness_config = intent.respond_to?(:harness_options) ? intent.harness_options : {}
      merged = stringify_static_keys(harness_config).merge(stringify_static_keys(config || {}))
      harness_name = (merged['name'] || merged['harness'] || 'opencode').to_s

      case harness_name
      when 'opencode'
        ScenarioGeneration::OpenCodeAdapter.new(intent: intent, staging_dir: staging_dir, config: merged)
      else
        raise HarnessError, "Unsupported harness: #{harness_name}. Supported values: opencode"
      end
    end

    def initialize(intent:, staging_dir:, config: {})
      @intent = intent
      @staging_dir = staging_dir
      @config = stringify_keys(config || {})
    end

    def prepare_workspace
      raise NotImplementedError, "#{self.class.name}#prepare_workspace must be implemented"
    end

    def plan_command
      raise NotImplementedError, "#{self.class.name}#plan_command must be implemented"
    end

    def generate_command
      raise NotImplementedError, "#{self.class.name}#generate_command must be implemented"
    end

    def repair_command(_validation_report)
      raise NotImplementedError, "#{self.class.name}#repair_command must be implemented"
    end

    def report
      {
        'harness' => self.class.name,
        'staging_dir' => @staging_dir,
        'phases' => PHASES.map(&:to_s)
      }
    end

    protected

    def self.stringify_static_keys(value)
      case value
      when Hash
        value.each_with_object({}) { |(key, val), result| result[key.to_s] = stringify_static_keys(val) }
      else
        value || {}
      end
    end

    def stringify_keys(value)
      case value
      when Hash
        value.each_with_object({}) { |(key, val), result| result[key.to_s] = stringify_keys(val) }
      when Array
        value.map { |entry| stringify_keys(entry) }
      else
        value
      end
    end
  end
end
