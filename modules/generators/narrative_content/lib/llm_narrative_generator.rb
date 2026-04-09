require 'json'
require_relative 'llm_provider_config'
require_relative 'llm_prompt_template'
require_relative 'llm_content_cache'
require_relative 'llm_content_sanitizer'
require_relative 'llm_cybok'

# Base class for all LLM narrative generators in SecGen.
# Provides shared infrastructure: LLM provider, prompt templates, caching, sanitization.
# Subclasses override #build_prompt and #parse_response.
class LlmNarrativeGenerator
  attr_accessor :provider, :cache, :config
  attr_accessor :seed, :temperature, :max_tokens, :model
  attr_accessor :cybok_ka, :cybok_topic
  attr_accessor :organisation_data
  attr_accessor :narrative_theme, :content_type
  attr_accessor :response_format

  def initialize(options = {})
    @seed = options['seed']
    @temperature = options['temperature'] || 0.7
    @max_tokens = options['max_tokens'] || 2048
    @model = options['model']
    @cybok_ka = options['cybok_ka']
    @cybok_topic = options['cybok_topic']
    @organisation_data = options['organisation'] || {}
    @narrative_theme = options['theme'] || 'investigation'
    @content_type = options['content_type']
    @response_format = options['response_format']

    provider_config = LlmProviderConfig.new(options['config_path'])
    @provider = provider_config.create_provider
    @cache = LlmContentCache.new
    # Use the provider's merged config (includes provider-specific model, endpoint, etc.)
    @config = @provider.config
  end

  # Main generation entry point - handles caching, generation, sanitization
  def generate_content(extra_variables = {})
    prompt = build_prompt(extra_variables)

    # Check for student data in prompt before sending to LLM
    student_issues = LlmContentSanitizer.check_student_data(prompt)
    unless student_issues.empty?
      raise "Student data protection: #{student_issues.join(', ')}"
    end

    gen_params = generation_params

    # Check cache first
    cached = @cache.get(prompt, gen_params)
    return cached if cached

    # Generate via LLM
    raw_content = @provider.generate(prompt, gen_params)

    # Parse and validate
    content = parse_response(raw_content)

    # Sanitize
    content = LlmContentSanitizer.sanitize(content)

    # Quality check
    quality_issues = LlmContentSanitizer.validate_quality(content)
    unless quality_issues.empty?
      $stderr.puts "LLM content quality warnings: #{quality_issues.join(', ')}"
    end

    # Check for inappropriate content
    inappropriate = LlmContentSanitizer.check_inappropriate(content)
    unless inappropriate.empty?
      $stderr.puts "LLM content warnings: #{inappropriate.join(', ')}"
    end

    # Cache the result
    @cache.put(prompt, gen_params, content, {
      'provider' => @provider.provider_name,
      'model' => gen_params['model'],
      'generator' => self.class.name
    })

    content
  end

  protected

  # Override in subclasses: build the full prompt from template + variables
  def build_prompt(extra_variables = {})
    raise NotImplementedError, "#{self.class.name}#build_prompt must be implemented"
  end

  # Override in subclasses: parse raw LLM response into final format
  def parse_response(raw_content)
    raw_content
  end

  # Build variables hash from organisation data and other attributes
  def template_variables(extra = {})
    vars = {}

    if @organisation_data.is_a?(Hash) && !@organisation_data.empty?
      # Flatten organisation data for template access
      vars['organisation'] = @organisation_data
      vars['business_name'] = @organisation_data['business_name']
      vars['industry'] = @organisation_data['industry']
      vars['domain'] = @organisation_data['domain']
      vars['manager'] = @organisation_data['manager']
      vars['employees'] = @organisation_data['employees']
    end

    vars['theme'] = @narrative_theme
    vars['content_type'] = @content_type
    vars['cybok_ka'] = @cybok_ka
    vars['cybok_topic'] = @cybok_topic

    vars.merge(extra)
  end

  # Append CyBOK alignment instructions to a prompt if configured
  def append_cybok_alignment(prompt)
    return prompt unless @cybok_ka
    prompt + "\n\n" + LlmCybok.alignment_prompt(@cybok_ka, @cybok_topic)
  end

  def generation_params
    params = {
      'seed' => @seed,
      'temperature' => @temperature,
      'max_tokens' => @max_tokens,
      'model' => @model || @config['model']
    }.compact
    params['response_format'] = @response_format if @response_format
    params
  end
end
