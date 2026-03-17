require_relative 'spec_helper'
require 'llm_provider'
require 'llm_provider_ollama'
require 'llm_provider_openai'
require 'llm_provider_anthropic'
require 'llm_provider_llamacpp'
require 'llm_provider_lmstudio'

class TestLlmProviders < Minitest::Test
  def test_base_provider_not_implemented
    provider = LlmProvider.new
    assert_raises(NotImplementedError) { provider.generate('test') }
  end

  def test_base_provider_not_available
    provider = LlmProvider.new
    refute provider.available?
  end

  def test_ollama_default_config
    provider = LlmProviderOllama.new
    assert_equal 'http://localhost:11434', provider.config['endpoint']
    assert_equal 'llama3', provider.config['model']
  end

  def test_ollama_custom_config
    provider = LlmProviderOllama.new('endpoint' => 'http://custom:11434', 'model' => 'mistral')
    assert_equal 'http://custom:11434', provider.config['endpoint']
    assert_equal 'mistral', provider.config['model']
  end

  def test_openai_requires_api_key
    assert_raises(RuntimeError) { LlmProviderOpenai.new }
  end

  def test_openai_with_api_key
    provider = LlmProviderOpenai.new('api_key' => 'test-key')
    assert_equal 'https://api.openai.com', provider.config['endpoint']
    assert_equal 'gpt-4o-mini', provider.config['model']
    assert provider.available?
  end

  def test_anthropic_requires_api_key
    assert_raises(RuntimeError) { LlmProviderAnthropic.new }
  end

  def test_anthropic_with_api_key
    provider = LlmProviderAnthropic.new('api_key' => 'test-key')
    assert_equal 'https://api.anthropic.com', provider.config['endpoint']
    assert provider.available?
  end

  def test_llamacpp_default_config
    provider = LlmProviderLlamacpp.new
    assert_equal 'http://localhost:8080', provider.config['endpoint']
  end

  def test_lmstudio_default_config
    provider = LlmProviderLmstudio.new
    assert_equal 'http://localhost:1234', provider.config['endpoint']
  end

  def test_provider_name
    provider = LlmProviderOllama.new
    assert_equal 'ollama', provider.provider_name
  end

  def test_mock_provider
    mock = MockLlmProvider.new('response_text' => 'test response')
    result = mock.generate('test prompt', {})
    assert_equal 'test response', result
    assert_equal 'test prompt', mock.last_prompt
  end
end
