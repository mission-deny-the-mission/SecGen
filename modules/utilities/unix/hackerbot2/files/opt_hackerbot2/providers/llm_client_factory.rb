require_relative './llm_client.rb'
require_relative './ollama_client.rb'
require_relative './openai_client.rb'
require_relative './vllm_client.rb'
require_relative './sglang_client.rb'

module LLMClientFactory
  def self.create_client(provider, **options)
    case provider.downcase
    when 'ollama'
      OllamaClient.new(
        options[:host],
        options[:port],
        options[:model],
        options[:system_prompt],
        options[:max_tokens],
        options[:temperature],
        options[:num_thread],
        options[:keepalive],
        options[:streaming]
      )
    when 'openai'
      OpenAIClient.new(
        options[:api_key],
        options[:host],
        options[:model],
        options[:system_prompt],
        options[:max_tokens],
        options[:temperature],
        options[:streaming],
        options[:base_url]
      )
    when 'vllm'
      VLLMClient.new(
        options[:host],
        options[:port],
        options[:model],
        options[:system_prompt],
        options[:max_tokens],
        options[:temperature],
        options[:streaming]
      )
    when 'sglang'
      SGLangClient.new(
        options[:host],
        options[:port],
        options[:model],
        options[:system_prompt],
        options[:max_tokens],
        options[:temperature],
        options[:streaming]
      )
    else
      raise ArgumentError, "Unsupported LLM provider: #{provider}"
    end
  end
end
