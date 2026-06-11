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
