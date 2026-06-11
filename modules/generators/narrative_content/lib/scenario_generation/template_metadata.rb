require 'json'
require 'yaml'
require_relative 'intent'

module ScenarioGeneration
  class TemplateMetadataError < StandardError; end

  class TemplateMetadata
    REQUIRED_FIELDS = %w[
      id
      name
      version
      approved
      vulnerability_class
      supported_platforms
      difficulties
      module
      parameters
      required_files
      flags
      tests
    ].freeze

    REQUIRED_MODULE_FIELDS = %w[
      module_type
      module_path
      puppet_entry
      metadata_path
    ].freeze

    REQUIRED_TEST_FIELDS = %w[
      exploit_expectation
      validation_hooks
    ].freeze

    attr_reader :raw, :data, :errors

    def self.load(path)
      raw = File.read(path)
      data = case File.extname(path).downcase
             when '.yml', '.yaml'
               YAML.safe_load(raw)
             else
               JSON.parse(raw)
             end
      new(data)
    rescue JSON::ParserError, Psych::SyntaxError => e
      raise TemplateMetadataError, "Failed to parse template metadata #{path}: #{e.message}"
    end

    def initialize(data)
      @raw = deep_stringify_keys(data || {})
      @data = normalize(@raw)
      @errors = validate
      raise TemplateMetadataError, @errors.join('; ') unless @errors.empty?
    end

    def [](key)
      @data[key.to_s]
    end

    def to_h
      @data.dup
    end

    def approved?
      @data['approved'] == true
    end

    def parameter_names
      @data['parameters'].map { |parameter| parameter['name'] }
    end

    private

    def validate
      messages = []
      messages.concat(missing_field_errors(@data, REQUIRED_FIELDS, 'template'))
      return messages unless messages.empty?

      messages << 'approved must be true for template use' unless approved?
      messages << unsupported_vulnerability_error unless Intent::SUPPORTED_VULNERABILITY_CLASSES.include?(@data['vulnerability_class'])
      messages.concat(non_empty_array_errors('supported_platforms'))
      messages.concat(non_empty_array_errors('difficulties'))
      messages.concat(non_empty_array_errors('required_files'))
      messages.concat(non_empty_array_errors('flags'))
      messages.concat(validate_module)
      messages.concat(validate_parameters)
      messages.concat(validate_tests)
      messages.compact
    end

    def validate_module
      value = @data['module']
      return ['module must be an object'] unless value.is_a?(Hash)

      missing_field_errors(value, REQUIRED_MODULE_FIELDS, 'module')
    end

    def validate_parameters
      value = @data['parameters']
      return ['parameters must be an array'] unless value.is_a?(Array)

      value.each_with_object([]).with_index do |(parameter, messages), index|
        unless parameter.is_a?(Hash)
          messages << "parameters[#{index}] must be an object"
          next
        end

        messages << "parameters[#{index}] missing name" if blank?(parameter['name'])
        messages << "parameters[#{index}] missing type" if blank?(parameter['type'])
        messages << "parameters[#{index}] missing target" if blank?(parameter['target'])
      end
    end

    def validate_tests
      value = @data['tests']
      return ['tests must be an object'] unless value.is_a?(Hash)

      messages = missing_field_errors(value, REQUIRED_TEST_FIELDS, 'tests')
      hooks = value['validation_hooks']
      messages << 'tests.validation_hooks must be a non-empty array' unless hooks.is_a?(Array) && hooks.any?
      messages
    end

    def missing_field_errors(container, fields, label)
      fields.each_with_object([]) do |field, messages|
        messages << "#{label} missing #{field}" if blank?(container[field])
      end
    end

    def non_empty_array_errors(field)
      value = @data[field]
      return ["#{field} must be a non-empty array"] unless value.is_a?(Array) && value.any? { |entry| !blank?(entry) }

      []
    end

    def unsupported_vulnerability_error
      "Unsupported vulnerability_class: #{@data['vulnerability_class'].inspect}. Supported values: #{Intent::SUPPORTED_VULNERABILITY_CLASSES.join(', ')}"
    end

    def normalize(value)
      normalized = deep_stringify_keys(value)
      normalized['id'] = slug(normalized['id']) if normalized['id']
      normalized['vulnerability_class'] = normalize_vulnerability_class(normalized['vulnerability_class']) if normalized['vulnerability_class']
      normalized['supported_platforms'] = Array(normalized['supported_platforms']).map { |platform| normalize_token(platform) }
      normalized['difficulties'] = Array(normalized['difficulties']).map { |difficulty| normalize_token(difficulty) }
      normalized['required_files'] = Array(normalized['required_files'])
      normalized['flags'] = Array(normalized['flags']).map { |flag| normalize_flag(flag) }
      normalized['parameters'] = Array(normalized['parameters']).map { |parameter| deep_stringify_keys(parameter) }
      normalized
    end

    def normalize_flag(flag)
      case flag
      when Hash
        deep_stringify_keys(flag)
      else
        { 'name' => flag.to_s, 'target' => 'strings_to_leak' }
      end
    end

    def normalize_vulnerability_class(value)
      key = normalize_token(value)
      Intent::VULNERABILITY_ALIASES[key] || key
    end

    def deep_stringify_keys(value)
      case value
      when Hash
        value.each_with_object({}) do |(key, val), result|
          result[key.to_s] = deep_stringify_keys(val)
        end
      when Array
        value.map { |entry| deep_stringify_keys(entry) }
      else
        value
      end
    end

    def normalize_token(value)
      value.to_s.strip.downcase.tr('-', '_').gsub(/\s+/, '_')
    end

    def slug(value)
      value.to_s.strip.downcase.gsub(/[^a-z0-9]+/, '-').gsub(/\A-|-+\z/, '')
    end

    def blank?(value)
      value.nil? || (value.respond_to?(:empty?) && value.empty?) || value.to_s.strip.empty?
    end
  end
end
