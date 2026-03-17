$LOAD_PATH.unshift File.expand_path('../../modules/generators/narrative_content/lib', __FILE__)

require 'minitest/autorun'
require 'json'
require 'llm_provider'

# Stub Print module to prevent output during tests
module Print
  def self.local(msg); end
  def self.local_verbose(msg); end
  def self.err(msg); end
  def self.std(msg); end
  def self.info(msg); end
end

# Mock LLM provider for testing without real API calls
class MockLlmProvider < LlmProvider
  attr_accessor :response_text

  def initialize(config = {})
    @response_text = config.delete('response_text') || 'Mock LLM response'
    super(config)
  end

  def generate(prompt, options = {})
    @last_prompt = prompt
    @last_options = options
    @response_text
  end

  def available?
    true
  end

  attr_reader :last_prompt, :last_options
end
