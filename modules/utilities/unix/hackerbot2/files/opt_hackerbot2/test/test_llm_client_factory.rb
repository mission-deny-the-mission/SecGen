require_relative 'test_helper'

class TestLLMClientFactory < Minitest::Test
  def setup
    @default_options = {
      host: 'localhost',
      port: 11434,
      model: 'test-model',
      system_prompt: 'Test system prompt',
      max_tokens: 100,
      temperature: 0.7,
      streaming: true,
      num_thread: 8,
      keepalive: -1,
      api_key: 'test-api-key'
    }
  end

  def test_create_ollama_client
    client = LLMClientFactory.create_client('ollama', **@default_options)

    assert_instance_of OllamaClient, client
    assert_equal 'ollama', client.provider
    assert_equal 'test-model', client.model
    assert_equal 'Test system prompt', client.system_prompt
    assert_equal 100, client.max_tokens
    assert_equal 0.7, client.temperature
    assert_equal true, client.streaming
  end

  def test_create_openai_client
    client = LLMClientFactory.create_client('openai', **@default_options)

    assert_instance_of OpenAIClient, client
    assert_equal 'openai', client.provider
    assert_equal 'test-model', client.model
    assert_equal 'Test system prompt', client.system_prompt
    assert_equal 100, client.max_tokens
    assert_equal 0.7, client.temperature
    assert_equal true, client.streaming
  end

  def test_create_vllm_client
    client = LLMClientFactory.create_client('vllm', **@default_options)

    assert_instance_of VLLMClient, client
    assert_equal 'vllm', client.provider
    assert_equal 'test-model', client.model
    assert_equal 'Test system prompt', client.system_prompt
    assert_equal 100, client.max_tokens
    assert_equal 0.7, client.temperature
    assert_equal true, client.streaming
  end

  def test_create_sglang_client
    client = LLMClientFactory.create_client('sglang', **@default_options)

    assert_instance_of SGLangClient, client
    assert_equal 'sglang', client.provider
    assert_equal 'test-model', client.model
    assert_equal 'Test system prompt', client.system_prompt
    assert_equal 100, client.max_tokens
    assert_equal 0.7, client.temperature
    assert_equal true, client.streaming
  end

  def test_create_ollama_client_with_minimal_options
    minimal_options = {
      model: 'test-model'
    }
    client = LLMClientFactory.create_client('ollama', **minimal_options)

    assert_instance_of OllamaClient, client
    assert_equal 'ollama', client.provider
    assert_equal 'test-model', client.model
    # Should use defaults for missing options
    assert_instance_of String, client.system_prompt
    assert_equal 150, client.max_tokens
    assert_equal 0.7, client.temperature
    assert_equal true, client.streaming
    assert_equal 8, client.instance_variable_get(:@num_thread)
    assert_equal(-1, client.instance_variable_get(:@keepalive))
  end

  def test_create_openai_client_with_minimal_options
    minimal_options = {
      api_key: 'test-api-key',
      model: 'test-model'
    }
    client = LLMClientFactory.create_client('openai', **minimal_options)

    assert_instance_of OpenAIClient, client
    assert_equal 'openai', client.provider
    assert_equal 'test-model', client.model
    # Should use defaults for missing options
    assert_equal 'api.openai.com', client.instance_variable_get(:@host)
    assert_instance_of String, client.system_prompt
    assert_equal 150, client.max_tokens
    assert_equal 0.7, client.temperature
    assert_equal true, client.streaming
  end

  def test_create_vllm_client_with_minimal_options
    minimal_options = {
      model: 'test-model'
    }
    client = LLMClientFactory.create_client('vllm', **minimal_options)

    assert_instance_of VLLMClient, client
    assert_equal 'vllm', client.provider
    assert_equal 'test-model', client.model
    # Should use defaults for missing options
    assert_equal 'localhost', client.instance_variable_get(:@host)
    assert_equal 8000, client.instance_variable_get(:@port)
    assert_instance_of String, client.system_prompt
    assert_equal 150, client.max_tokens
    assert_equal 0.7, client.temperature
    assert_equal true, client.streaming
  end

  def test_create_sglang_client_with_minimal_options
    minimal_options = {
      model: 'test-model'
    }
    client = LLMClientFactory.create_client('sglang', **minimal_options)

    assert_instance_of SGLangClient, client
    assert_equal 'sglang', client.provider
    assert_equal 'test-model', client.model
    # Should use defaults for missing options
    assert_equal 'localhost', client.instance_variable_get(:@host)
    assert_equal 30000, client.instance_variable_get(:@port)
    assert_instance_of String, client.system_prompt
    assert_equal 150, client.max_tokens
    assert_equal 0.7, client.temperature
    assert_equal true, client.streaming
  end

  def test_create_ollama_client_passes_all_parameters
    custom_options = {
      host: 'custom-ollama-host',
      port: 9999,
      model: 'custom-ollama-model',
      system_prompt: 'Custom ollama system prompt',
      max_tokens: 500,
      temperature: 1.5,
      num_thread: 16,
      keepalive: 300,
      streaming: false
    }
    client = LLMClientFactory.create_client('ollama', **custom_options)

    assert_instance_of OllamaClient, client
    assert_equal 'custom-ollama-host', client.instance_variable_get(:@host)
    assert_equal 9999, client.instance_variable_get(:@port)
    assert_equal 'custom-ollama-model', client.model
    assert_equal 'Custom ollama system prompt', client.system_prompt
    assert_equal 500, client.max_tokens
    assert_equal 1.5, client.temperature
    assert_equal 16, client.instance_variable_get(:@num_thread)
    assert_equal 300, client.instance_variable_get(:@keepalive)
    assert_equal false, client.streaming
  end

  def test_create_openai_client_passes_all_parameters
    custom_options = {
      api_key: 'custom-openai-key',
      host: 'custom.openai.com',
      model: 'gpt-4',
      system_prompt: 'Custom openai system prompt',
      max_tokens: 500,
      temperature: 1.5,
      streaming: false
    }
    client = LLMClientFactory.create_client('openai', **custom_options)

    assert_instance_of OpenAIClient, client
    assert_equal 'custom-openai-key', client.instance_variable_get(:@api_key)
    assert_equal 'custom.openai.com', client.instance_variable_get(:@host)
    assert_equal 'gpt-4', client.model
    assert_equal 'Custom openai system prompt', client.system_prompt
    assert_equal 500, client.max_tokens
    assert_equal 1.5, client.temperature
    assert_equal false, client.streaming
  end

  def test_create_vllm_client_passes_all_parameters
    custom_options = {
      host: 'custom-vllm-host',
      port: 9999,
      model: 'custom-vllm-model',
      system_prompt: 'Custom vllm system prompt',
      max_tokens: 500,
      temperature: 1.5,
      streaming: false
    }
    client = LLMClientFactory.create_client('vllm', **custom_options)

    assert_instance_of VLLMClient, client
    assert_equal 'custom-vllm-host', client.instance_variable_get(:@host)
    assert_equal 9999, client.instance_variable_get(:@port)
    assert_equal 'custom-vllm-model', client.model
    assert_equal 'Custom vllm system prompt', client.system_prompt
    assert_equal 500, client.max_tokens
    assert_equal 1.5, client.temperature
    assert_equal false, client.streaming
  end

  def test_create_sglang_client_passes_all_parameters
    custom_options = {
      host: 'custom-sglang-host',
      port: 9999,
      model: 'custom-sglang-model',
      system_prompt: 'Custom sglang system prompt',
      max_tokens: 500,
      temperature: 1.5,
      streaming: false
    }
    client = LLMClientFactory.create_client('sglang', **custom_options)

    assert_instance_of SGLangClient, client
    assert_equal 'custom-sglang-host', client.instance_variable_get(:@host)
    assert_equal 9999, client.instance_variable_get(:@port)
    assert_equal 'custom-sglang-model', client.model
    assert_equal 'Custom sglang system prompt', client.system_prompt
    assert_equal 500, client.max_tokens
    assert_equal 1.5, client.temperature
    assert_equal false, client.streaming
  end

  def test_create_client_case_insensitive
    client = LLMClientFactory.create_client('OLLAMA', model: 'test-model')
    assert_instance_of OllamaClient, client

    client = LLMClientFactory.create_client('OpenAI', api_key: 'test', model: 'test-model')
    assert_instance_of OpenAIClient, client

    client = LLMClientFactory.create_client('VLLM', model: 'test-model')
    assert_instance_of VLLMClient, client

    client = LLMClientFactory.create_client('SGLang', model: 'test-model')
    assert_instance_of SGLangClient, client
  end

  def test_create_client_with_unknown_provider
    exception = assert_raises ArgumentError do
      LLMClientFactory.create_client('unknown_provider', model: 'test-model')
    end

    assert_equal "Unsupported LLM provider: unknown_provider", exception.message
  end

  def test_create_client_with_nil_provider
    exception = assert_raises NoMethodError do
      LLMClientFactory.create_client(nil, model: 'test-model')
    end

    assert_match(/undefined method `downcase' for nil/, exception.message)
  end

  def test_create_client_with_empty_provider
    exception = assert_raises ArgumentError do
      LLMClientFactory.create_client('', model: 'test-model')
    end

    assert_equal "Unsupported LLM provider: ", exception.message
  end

  def test_create_client_without_options
    # This should work because OllamaClient has default model values
    client = LLMClientFactory.create_client('ollama')

    assert_instance_of OllamaClient, client
    assert_equal 'ollama', client.provider
    assert_equal 'gemma3:1b', client.model  # Default model
    assert_equal 'localhost', client.instance_variable_get(:@host)
    assert_equal 11434, client.instance_variable_get(:@port)
  end

  def test_create_openai_client_without_api_key
    client = LLMClientFactory.create_client('openai', model: 'test-model')
    assert_instance_of OpenAIClient, client
    # Should use nil for API key, which is acceptable for testing
    assert_nil client.instance_variable_get(:@api_key)
  end

  def test_all_clients_inherit_from_llm_client
    providers = ['ollama', 'openai', 'vllm', 'sglang']

    providers.each do |provider|
      options = { model: 'test-model' }
      options[:api_key] = 'test-key' if provider == 'openai'

      client = LLMClientFactory.create_client(provider, **options)
      assert_kind_of LLMClient, client, "#{provider.capitalize} client should inherit from LLMClient"
      assert_respond_to client, :generate_response, "#{provider.capitalize} client should respond to generate_response"
      assert_respond_to client, :test_connection, "#{provider.capitalize} client should respond to test_connection"
      assert_respond_to client, :update_system_prompt, "#{provider.capitalize} client should respond to update_system_prompt"
    end
  end

  def test_factory_module_is_singleton
    # Verify that the factory module behaves as a singleton
    client1 = LLMClientFactory.create_client('ollama', model: 'test-model')
    client2 = LLMClientFactory.create_client('ollama', model: 'test-model')

    # They should be different instances with same configuration
    assert_instance_of OllamaClient, client1
    assert_instance_of OllamaClient, client2
    refute_equal client1.object_id, client2.object_id
  end

  def test_factory_supports_all_supported_providers
    supported_providers = %w[ollama openai vllm sglang]

    supported_providers.each do |provider|
      options = { model: 'test-model' }
      options[:api_key] = 'test-key' if provider == 'openai'

      begin
        client = LLMClientFactory.create_client(provider, **options)
        assert_kind_of LLMClient, client
      rescue => e
        flunk "Provider #{provider} failed to create client: #{e.message}"
      end
    end
  end
end
