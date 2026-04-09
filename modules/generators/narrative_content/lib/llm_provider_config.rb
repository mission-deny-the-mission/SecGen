require 'json'
require 'yaml'
require_relative 'llm_provider_ollama'
require_relative 'llm_provider_openai'
require_relative 'llm_provider_anthropic'
require_relative 'llm_provider_llamacpp'
require_relative 'llm_provider_lmstudio'

# Loads LLM provider configuration and instantiates the appropriate provider
class LlmProviderConfig
  CONFIG_FILENAME = 'llm_config.json'
  ENV_PREFIX = 'SECGEN_LLM_'

  PROVIDERS = {
    'ollama' => LlmProviderOllama,
    'openai' => LlmProviderOpenai,
    'anthropic' => LlmProviderAnthropic,
    'llama_cpp' => LlmProviderLlamacpp,
    'lm_studio' => LlmProviderLmstudio
  }.freeze

  attr_reader :config

  def initialize(config_path = nil)
    @config = load_config(config_path)
  end

  def create_provider
    provider_name = @config['provider'] || detect_available_provider
    unless provider_name
      raise "No LLM provider configured. Set provider in #{CONFIG_FILENAME} or via #{ENV_PREFIX}PROVIDER environment variable."
    end

    provider_class = PROVIDERS[provider_name]
    unless provider_class
      raise "Unknown LLM provider '#{provider_name}'. Available: #{PROVIDERS.keys.join(', ')}"
    end

    provider_config = @config.merge(@config[provider_name] || {})
    # Resolve API key from environment if not in config
    provider_config['api_key'] ||= resolve_api_key(provider_name)

    provider_class.new(provider_config)
  end

  def self.available_providers
    PROVIDERS.keys
  end

  private

  def load_config(config_path)
    config = {}

    # Load from file if available
    paths = config_search_paths(config_path)
    paths.each do |path|
      if File.exist?(path)
        raw = File.read(path)
        config = path.end_with?('.yml', '.yaml') ? YAML.safe_load(raw) : JSON.parse(raw)
        break
      end
    end

    # Override with environment variables
    config['provider'] = ENV["#{ENV_PREFIX}PROVIDER"] if ENV["#{ENV_PREFIX}PROVIDER"]
    config['model'] = ENV["#{ENV_PREFIX}MODEL"] if ENV["#{ENV_PREFIX}MODEL"]
    config['endpoint'] = ENV["#{ENV_PREFIX}ENDPOINT"] if ENV["#{ENV_PREFIX}ENDPOINT"]
    config['temperature'] = ENV["#{ENV_PREFIX}TEMPERATURE"].to_f if ENV["#{ENV_PREFIX}TEMPERATURE"]
    config['max_tokens'] = ENV["#{ENV_PREFIX}MAX_TOKENS"].to_i if ENV["#{ENV_PREFIX}MAX_TOKENS"]
    config['seed'] = ENV["#{ENV_PREFIX}SEED"].to_i if ENV["#{ENV_PREFIX}SEED"]

    config
  end

  def config_search_paths(config_path)
    # Walk upward from this file to find the SecGen project root (contains secgen.rb)
    dir = File.dirname(__FILE__)
    root_dir = nil
    10.times do
      if File.exist?(File.join(dir, 'secgen.rb'))
        root_dir = dir
        break
      end
      parent = File.dirname(dir)
      break if parent == dir # reached filesystem root
      dir = parent
    end
    # Fallback to relative path if secgen.rb not found
    root_dir ||= File.expand_path('../../../../..', __FILE__)

    paths = []
    paths << config_path if config_path
    paths << File.join(root_dir, CONFIG_FILENAME)
    paths << File.join(root_dir, 'llm_config.yml')
    paths << File.join(Dir.home, '.secgen', CONFIG_FILENAME) rescue nil
    paths.compact
  end

  def resolve_api_key(provider_name)
    env_key = "#{ENV_PREFIX}#{provider_name.upcase}_API_KEY"
    ENV[env_key]
  end

  def detect_available_provider
    # Try local providers first, then API-based
    %w[ollama lm_studio llama_cpp openai anthropic].each do |name|
      provider_class = PROVIDERS[name]
      test_config = @config.merge(@config[name] || {})
      test_config['api_key'] ||= resolve_api_key(name)
      begin
        provider = provider_class.new(test_config)
        return name if provider.available?
      rescue StandardError
        next
      end
    end
    nil
  end
end
