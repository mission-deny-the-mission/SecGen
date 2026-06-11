module ScenarioGeneration
  class ScenarioAssemblyError < StandardError; end

  # Immutable, string-keyed descriptor of an assembled SecGen scenario.
  # Hand-off object from section 5 (scenario assembly) to sections 6/7.
  class ScenarioArtifact
    REQUIRED_KEYS = %w[
      scenario_file
      staged_scenario_path
      scenario_relpath
      xml
      system_names
      module_selectors
      datastores
      doc_stub_path
      doc_relpath
    ].freeze

    def initialize(data)
      @data = stringify(data || {})
      missing = REQUIRED_KEYS.reject { |key| @data.key?(key) }
      raise ScenarioAssemblyError, "ScenarioArtifact missing keys: #{missing.join(', ')}" unless missing.empty?
    end

    def [](key)
      @data[key.to_s]
    end

    def to_h
      stringify(@data)
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
