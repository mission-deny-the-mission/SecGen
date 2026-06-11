require 'json'
require 'yaml'

module ScenarioGeneration
  class IntentError < StandardError; end

  class Intent
    REQUIRED_FIELDS = %w[
      name
      scenario_type
      target_platform
      difficulty
      vulnerability_classes
      learning_outcomes
      cybok
      flags
      evidence
      seed
    ].freeze

    SUPPORTED_SCENARIO_TYPES = %w[
      ctf
      attack_ctf
      lab
      security_audit
    ].freeze

    SUPPORTED_PLATFORMS = %w[
      linux
      debian
      windows
      web
    ].freeze

    SUPPORTED_DIFFICULTIES = %w[
      easy
      medium
      hard
      advanced
    ].freeze

    VULNERABILITY_ALIASES = {
      'sql injection' => 'sql_injection',
      'sqli' => 'sql_injection',
      'sql_injection' => 'sql_injection',
      'cross-site scripting' => 'xss',
      'cross site scripting' => 'xss',
      'xss' => 'xss',
      'broken access control' => 'broken_access_control',
      'idor' => 'broken_access_control',
      'broken_access_control' => 'broken_access_control',
      'command injection' => 'command_injection',
      'command_injection' => 'command_injection',
      'path traversal' => 'path_traversal',
      'directory traversal' => 'path_traversal',
      'path_traversal' => 'path_traversal',
      'insecure file upload' => 'insecure_file_upload',
      'file upload' => 'insecure_file_upload',
      'insecure_file_upload' => 'insecure_file_upload',
      'weak authentication' => 'weak_authentication',
      'weak auth' => 'weak_authentication',
      'weak_authentication' => 'weak_authentication',
      'insecure configuration' => 'insecure_configuration',
      'misconfiguration' => 'insecure_configuration',
      'insecure_configuration' => 'insecure_configuration'
    }.freeze

    SUPPORTED_VULNERABILITY_CLASSES = VULNERABILITY_ALIASES.values.uniq.freeze

    ALIASES = {
      'title' => 'name',
      'type' => 'scenario_type',
      'platform' => 'target_platform',
      'vulnerabilities' => 'vulnerability_classes',
      'learning_objectives' => 'learning_outcomes',
      'agent' => 'harness',
      'agent_generation' => 'harness'
    }.freeze

    attr_reader :raw, :data, :normalized, :errors

    def self.load(path)
      new(parse_file(path), source_path: path)
    end

    def self.parse_file(path)
      raw = File.read(path)
      case File.extname(path).downcase
      when '.yml', '.yaml'
        YAML.safe_load(raw)
      else
        JSON.parse(raw)
      end
    rescue JSON::ParserError, Psych::SyntaxError => e
      raise IntentError, "Failed to parse intent file #{path}: #{e.message}"
    end

    def initialize(data = nil, source_path: nil, **kwargs)
      data = kwargs if data.nil? && !kwargs.empty?
      @source_path = source_path
      @raw = deep_stringify_keys(data || {})
      @data = apply_aliases(@raw)
      @errors = validate_intent
      raise IntentError, @errors.join('; ') unless @errors.empty?

      @normalized = normalize
    end

    def [](key)
      @data[key.to_s]
    end

    def to_h
      @data.dup
    end

    def identifiers
      @normalized['identifiers']
    end

    def llm_options
      @normalized['narrative_generation'] || {}
    end

    def harness_options
      @normalized['harness'] || {}
    end

    private

    def validate_intent
      validation_errors = []
      validation_errors.concat(missing_required_field_errors)
      return validation_errors unless validation_errors.empty?

      validation_errors << unsupported_value_error('scenario_type', @data['scenario_type'], SUPPORTED_SCENARIO_TYPES)
      validation_errors << unsupported_value_error('target_platform', @data['target_platform'], SUPPORTED_PLATFORMS)
      validation_errors << unsupported_value_error('difficulty', @data['difficulty'], SUPPORTED_DIFFICULTIES)
      validation_errors.concat(validate_vulnerability_classes)
      validation_errors.concat(validate_non_empty_array('learning_outcomes'))
      validation_errors.concat(validate_non_empty_array('flags'))
      validation_errors.concat(validate_non_empty_array('evidence'))
      validation_errors.concat(validate_cybok)
      validation_errors.concat(validate_seed)
      validation_errors.concat(validate_narrative_generation)
      validation_errors.concat(validate_harness)
      validation_errors.compact
    end

    def missing_required_field_errors
      REQUIRED_FIELDS.each_with_object([]) do |field, messages|
        value = @data[field]
        messages << "Missing required field: #{field}" if blank?(value)
      end
    end

    def unsupported_value_error(field, value, supported)
      normalized = normalize_token(value)
      return nil if supported.include?(normalized)

      "Unsupported #{field}: #{value.inspect}. Supported values: #{supported.join(', ')}"
    end

    def validate_vulnerability_classes
      values = Array(@data['vulnerability_classes'])
      return ["vulnerability_classes must be a non-empty array"] if values.empty?

      values.each_with_object([]) do |value, messages|
        normalized = normalize_vulnerability_class(value)
        next if SUPPORTED_VULNERABILITY_CLASSES.include?(normalized)

        messages << "Unsupported vulnerability class: #{value.inspect}. Supported values: #{SUPPORTED_VULNERABILITY_CLASSES.join(', ')}"
      end
    end

    def validate_non_empty_array(field)
      value = @data[field]
      return ["#{field} must be a non-empty array"] unless value.is_a?(Array) && value.any? { |entry| !blank?(entry) }

      []
    end

    def validate_cybok
      value = @data['cybok']
      entries = value.is_a?(Array) ? value : [value]
      return ["cybok must contain at least one entry"] if entries.empty?

      entries.each_with_object([]) do |entry, messages|
        unless entry.is_a?(Hash)
          messages << "cybok entries must be objects"
          next
        end

        messages << "cybok entry missing KA" if blank?(entry['ka'] || entry['KA'])
        messages << "cybok entry missing topic" if blank?(entry['topic'])
      end
    end

    def validate_seed
      Integer(@data['seed'])
      []
    rescue ArgumentError, TypeError
      ["seed must be an integer"]
    end

    def validate_narrative_generation
      value = @data['narrative_generation']
      return [] if value.nil?
      return ["narrative_generation must be an object"] unless value.is_a?(Hash)

      provider = value['provider']
      return [] if blank?(provider)

      # Keep this list aligned with LlmProviderConfig without requiring provider
      # keys during deterministic intent loading.
      supported = %w[ollama openai anthropic llama_cpp lm_studio]
      return [] if supported.include?(provider.to_s)

      ["Unsupported narrative_generation provider: #{provider.inspect}. Supported values: #{supported.join(', ')}"]
    end

    def validate_harness
      value = @data['harness']
      return [] if value.nil?
      return ["harness must be an object"] unless value.is_a?(Hash)

      name = value['name'] || value['harness']
      messages = []
      messages << "Unsupported harness: #{name.inspect}. Supported values: opencode" if !blank?(name) && normalize_token(name) != 'opencode'
      if value.key?('retry_limit')
        begin
          retry_limit = Integer(value['retry_limit'])
          messages << 'harness retry_limit must be greater than 0' if retry_limit <= 0
        rescue ArgumentError, TypeError
          messages << 'harness retry_limit must be an integer'
        end
      end
      messages
    end

    def normalize
      vulnerability_classes = Array(@data['vulnerability_classes']).map { |value| normalize_vulnerability_class(value) }
      scenario_slug = slug(@data['name'])

      normalized_data = deep_stringify_keys(@data)
      normalized_data['scenario_type'] = normalize_token(@data['scenario_type'])
      normalized_data['target_platform'] = normalize_token(@data['target_platform'])
      normalized_data['difficulty'] = normalize_token(@data['difficulty'])
      normalized_data['vulnerability_classes'] = vulnerability_classes
      normalized_data['seed'] = Integer(@data['seed'])
      normalized_data['cybok'] = normalize_cybok(@data['cybok'])
      normalized_data['identifiers'] = {
        'scenario_slug' => scenario_slug,
        'scenario_file' => "#{scenario_slug}.xml",
        'system_name' => snake(@data['system_name'] || "#{scenario_slug}_target"),
        'module_name' => snake(@data['module_name'] || scenario_slug),
        'module_path' => File.join('modules', 'vulnerabilities', 'generated', snake(@data['module_name'] || scenario_slug)),
        'datastore_prefix' => snake(@data['datastore_prefix'] || scenario_slug)
      }
      normalized_data['narrative_generation'] = normalize_narrative_generation(@data['narrative_generation'])
      normalized_data['harness'] = normalize_harness(@data['harness'])
      normalized_data
    end

    def normalize_cybok(value)
      entries = value.is_a?(Array) ? value : [value]
      entries.map do |entry|
        {
          'ka' => entry['ka'] || entry['KA'],
          'topic' => entry['topic'],
          'keywords' => Array(entry['keywords'] || entry['keyword']).compact
        }
      end
    end

    def normalize_narrative_generation(value)
      return {} unless value.is_a?(Hash)

      deep_stringify_keys(value).compact
    end

    def normalize_harness(value)
      harness = value.is_a?(Hash) ? deep_stringify_keys(value) : {}
      harness['name'] = normalize_token(harness['name'] || harness['harness'] || 'opencode')
      harness['retry_limit'] = Integer(harness['retry_limit'] || 3)
      harness
    end

    def apply_aliases(input)
      input.each_with_object({}) do |(key, value), result|
        result[ALIASES.fetch(key, key)] = value
      end
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

    def normalize_vulnerability_class(value)
      VULNERABILITY_ALIASES[normalize_token(value)] || normalize_token(value)
    end

    def normalize_token(value)
      value.to_s.strip.downcase.tr('-', '_').gsub(/\s+/, '_')
    end

    def slug(value)
      value.to_s.strip.downcase.gsub(/[^a-z0-9]+/, '-').gsub(/\A-|-+\z/, '')
    end

    def snake(value)
      value.to_s.strip.downcase.gsub(/[^a-z0-9]+/, '_').gsub(/\A_|_+\z/, '')
    end

    def blank?(value)
      value.nil? || (value.respond_to?(:empty?) && value.empty?) || value.to_s.strip.empty?
    end
  end
end
