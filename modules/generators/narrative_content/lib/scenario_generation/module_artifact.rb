module ScenarioGeneration
  class ModuleGenerationError < StandardError; end

  # Immutable, string-keyed descriptor of a generated SecGen vulnerability module.
  # Hand-off object from section 4 (module generation) to sections 5/6/7.
  class ModuleArtifact
    REQUIRED_KEYS = %w[
      module_name
      module_path
      staged_module_dir
      metadata_path
      puppet_entry
      vulnerability_class
      read_facts
      rendered_parameters
      flags
      required_files
      generated_files
      validation_hooks
      selection_regex
    ].freeze

    def initialize(data)
      @data = stringify(data || {})
      missing = REQUIRED_KEYS.reject { |key| @data.key?(key) }
      raise ModuleGenerationError, "ModuleArtifact missing keys: #{missing.join(', ')}" unless missing.empty?
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
