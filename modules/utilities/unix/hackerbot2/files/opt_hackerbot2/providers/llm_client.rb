require 'net/http'
require 'json'
require_relative '../print.rb'

# Default configuration constants
DEFAULT_SYSTEM_PROMPT = "You are a helpful cybersecurity training assistant. You help users learn about hacking techniques and security concepts. Be encouraging and educational in your responses. Keep explanations clear and practical."
DEFAULT_MAX_TOKENS = 150
DEFAULT_TEMPERATURE = 0.7
DEFAULT_STREAMING = true
DEFAULT_NUM_THREAD = 8
DEFAULT_KEEPALIVE = -1

# Base class for all LLM clients
class LLMClient
  attr_accessor :provider, :model, :system_prompt, :max_tokens, :temperature, :streaming

  def initialize(provider, model, system_prompt = nil, max_tokens = nil, temperature = nil, streaming = nil)
    @provider = provider
    @model = model
    @system_prompt = system_prompt || DEFAULT_SYSTEM_PROMPT
    @max_tokens = max_tokens || DEFAULT_MAX_TOKENS
    @temperature = temperature || DEFAULT_TEMPERATURE
    @streaming = streaming.nil? ? DEFAULT_STREAMING : streaming
  end

  # Abstract methods that must be implemented by subclasses
  def generate_response(prompt, stream_callback = nil)
    raise NotImplementedError, "Subclasses must implement generate_response"
  end

  def test_connection
    raise NotImplementedError, "Subclasses must implement test_connection"
  end

  # Update the system prompt dynamically
  def update_system_prompt(new_prompt)
    @system_prompt = new_prompt
  end

  # Get the current system prompt
  def get_system_prompt
    @system_prompt
  end
end
