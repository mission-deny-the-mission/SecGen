module ScenarioGeneration
  # String-keyed value object aggregating validation check results and exposing
  # the machine-readable repair_context the harness repair phase consumes.
  class ValidationReport
    attr_reader :passed, :failed, :warnings, :artifact_paths

    def initialize(passed: [], failed: [], warnings: [], artifact_paths: [])
      @passed = passed
      @failed = failed
      @warnings = warnings
      @artifact_paths = artifact_paths
    end

    def add_pass(name)
      @passed << name
      self
    end

    def add_failure(code:, message:, path: nil, hint: nil)
      @failed << { 'code' => code, 'message' => message, 'path' => path, 'hint' => hint }
      self
    end

    def add_warning(message)
      @warnings << message
      self
    end

    def passed?
      @failed.empty?
    end

    # The single gate the pipeline reads before recording promotion eligibility.
    def promotion_ready?
      @failed.empty?
    end

    def to_h
      {
        'passed' => @passed.dup,
        'failed' => deep_dup(@failed),
        'warnings' => @warnings.dup,
        'artifact_paths' => @artifact_paths.dup,
        'promotion_ready' => promotion_ready?
      }
    end

    # Exact input to OpenCodeAdapter#repair_command.
    def repair_context
      {
        'failures' => deep_dup(@failed),
        'summary' => summary
      }
    end

    def summary
      return 'All validation checks passed.' if promotion_ready?

      "#{@failed.length} check(s) failed: #{@failed.map { |failure| failure['code'] }.join(', ')}"
    end

    private

    def deep_dup(value)
      case value
      when Hash
        value.each_with_object({}) { |(key, val), result| result[key] = deep_dup(val) }
      when Array
        value.map { |entry| deep_dup(entry) }
      else
        value
      end
    end
  end
end
