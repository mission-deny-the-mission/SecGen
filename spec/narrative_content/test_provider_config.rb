require_relative 'spec_helper'
require 'llm_provider_config'

class TestLlmProviderConfig < Minitest::Test
  def test_available_providers_list
    providers = LlmProviderConfig.available_providers
    assert_includes providers, 'ollama'
    assert_includes providers, 'openai'
    assert_includes providers, 'anthropic'
    assert_includes providers, 'llama_cpp'
    assert_includes providers, 'lm_studio'
  end

  def test_env_variable_override
    ENV['SECGEN_LLM_PROVIDER'] = 'ollama'
    ENV['SECGEN_LLM_MODEL'] = 'mistral'
    config = LlmProviderConfig.new
    assert_equal 'ollama', config.config['provider']
    assert_equal 'mistral', config.config['model']
  ensure
    ENV.delete('SECGEN_LLM_PROVIDER')
    ENV.delete('SECGEN_LLM_MODEL')
  end
end
