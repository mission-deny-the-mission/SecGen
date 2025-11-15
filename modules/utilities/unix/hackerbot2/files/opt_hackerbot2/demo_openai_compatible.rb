#!/usr/bin/env ruby

# Demo script to test OpenAI-compatible API providers
# This demonstrates using local and remote OpenAI-compatible APIs like:
# - llama.cpp server
# - ik_llama.cpp
# - chutes
# - togetherai
# - nanogpt
# - any other OpenAI-compatible endpoint

require_relative './print.rb'
require_relative './providers/llm_client_factory.rb'

class OpenAICompatibleDemo
  def initialize
    @demo_running = false
  end

  def run_demo
    Print.banner "OpenAI-Compatible API Demo"
    Print.info "This demo shows how to use OpenAI-compatible APIs with custom base URLs"

    @demo_running = true

    # Test with different providers
    test_openai_official           # Standard OpenAI API
    test_local_llama_cpp           # Local llama.cpp server
    test_together_ai               # Together.ai service
    test_custom_openai_compatible  # Generic example

    Print.banner "All OpenAI-Compatible API tests completed!"
    @demo_running = false
  end

  def test_openai_official
    Print.section "Testing Official OpenAI API"

    begin
      client = LLMClientFactory.create_client(
        'openai',
        api_key: ENV['OPENAI_API_KEY'] || 'your-openai-api-key',
        model: 'gpt-3.5-turbo',
        system_prompt: 'You are a helpful AI assistant.',
        streaming: false
      )

      test_client(client, "official OpenAI API")
    rescue => e
      Print.err "Failed to test official OpenAI API: #{e.message}"
    end
  end

  def test_local_llama_cpp
    Print.section "Testing Local llama.cpp Server"

    begin
      # llama.cpp server typically runs on localhost:8080 with /v1 endpoint
      client = LLMClientFactory.create_client(
        'openai',
        api_key: 'dummy_key',  # llama.cpp server often accepts any key
        base_url: 'http://localhost:8080/v1',
        model: 'llama-2-7b-chat',  # Your local model name
        system_prompt: 'You are a helpful AI assistant.',
        streaming: false
      )

      test_client(client, "local llama.cpp server")
      Print.info "Configuration used:"
      Print.info "  Base URL: http://localhost:8080/v1"
      Print.info "  Model: llama-2-7b-chat"
      Print.info "  API Key: dummy_key (llama.cpp server accepts any key)"
    rescue => e
      Print.err "Failed to test local llama.cpp server: #{e.message}"
      Print.info "Make sure you have llama.cpp server running on localhost:8080"
      Print.info "Start it with: ./server -m your-model.gguf --port 8080"
    end
  end

  def test_together_ai
    Print.section "Testing Together.ai API"

    begin
      # Together.ai uses OpenAI-compatible API format
      client = LLMClientFactory.create_client(
        'openai',
        api_key: ENV['TOGETHER_API_KEY'] || 'your-together-api-key',
        base_url: 'https://api.together.xyz/v1',
        model: 'meta-llama/Llama-2-13b-chat-hf',
        system_prompt: 'You are a helpful AI assistant.',
        streaming: false
      )

      test_client(client, "Together.ai API")
      Print.info "Configuration used:"
      Print.info "  Base URL: https://api.together.xyz/v1"
      Print.info "  Model: meta-llama/Llama-2-13b-chat-hf"
    rescue => e
      Print.err "Failed to test Together.ai API: #{e.message}"
      Print.info "Make sure you have a Together.ai API key set in TOGETHER_API_KEY"
    end
  end

  def test_custom_openai_compatible
    Print.section "Testing Custom OpenAI-Compatible API"

    # This is a template for any OpenAI-compatible provider
    providers = [
      {
        name: "Chutes",
        base_url: "https://api.chutes.ai/v1",
        model: "llama-2-13b-chat",
        api_key_env: "CHUTES_API_KEY"
      },
      {
        name: "Nanogpt",
        base_url: "https://api.nanogpt.co/v1",
        model: "gpt-3.5-turbo",
        api_key_env: "NANOGPT_API_KEY"
      },
      {
        name: "Local ik_llama.cpp",
        base_url: "http://localhost:11434/v1",
        model: "llama-2-7b-chat",
        api_key_env: "IK_API_KEY"
      }
    ]

    providers.each do |provider|
      Print.info "Testing #{provider[:name]} configuration..."

      api_key = ENV[provider[:api_key_env]] || 'your-api-key'
      if api_key == 'your-api-key' && ENV[provider[:api_key_env]].nil?
        Print.info "Skipping #{provider[:name]} - no API key found in #{provider[:api_key_env]}"
        next
      end

      begin
        client = LLMClientFactory.create_client(
          'openai',
          api_key: api_key,
          base_url: provider[:base_url],
          model: provider[:model],
          system_prompt: 'You are a helpful AI assistant.',
          streaming: false
        )

        test_client(client, "#{provider[:name]} API")
      rescue => e
        Print.warn "Failed to test #{provider[:name]}: #{e.message}"
      end
    end
  end

  def test_client(client, provider_name)
    Print.info "Testing connection to #{provider_name}..."

    if client.test_connection
      Print.result "Connection to #{provider_name}: SUCCESS"

      # Test a simple prompt
      test_prompt = "Say 'Hello from Ruby!' and nothing else."
      Print.info "Testing simple prompt..."

      response = client.generate_response(test_prompt)
      if response && !response.empty?
        Print.result "Response received from #{provider_name}:"
        Print.info "  #{response.strip}"
      else
        Print.warn "No response received from #{provider_name}"
      end
    else
      Print.err "Connection to #{provider_name}: FAILED"
    end
  rescue => e
    Print.err "Error testing #{provider_name}: #{e.message}"
  end
end

# Run the demo if this script is executed directly
if __FILE__ == $0
  demo = OpenAICompatibleDemo.new
  demo.run_demo
end
