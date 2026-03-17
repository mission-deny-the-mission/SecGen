require_relative 'llm_provider'

class LlmProviderOpenai < LlmProvider
  def generate(prompt, options = {})
    uri = URI.parse("#{config['endpoint']}/v1/chat/completions")

    body = {
      'model' => options['model'] || config['model'] || 'gpt-4o-mini',
      'messages' => [
        { 'role' => 'user', 'content' => prompt }
      ],
      'temperature' => options['temperature'] || config['temperature'],
      'max_tokens' => options['max_tokens'] || config['max_tokens']
    }

    seed = options['seed'] || config['seed']
    body['seed'] = seed if seed

    headers = { 'Authorization' => "Bearer #{config['api_key']}" }

    response = http_post(uri, body, headers)

    if response['choices'] && response['choices'][0]
      response['choices'][0]['message']['content'] || ''
    else
      raise "Unexpected OpenAI response format: #{response}"
    end
  end

  def validate_config
    super
    config['endpoint'] ||= 'https://api.openai.com'
    unless config['api_key'] && !config['api_key'].empty?
      raise "OpenAI provider requires 'api_key' in configuration"
    end
  end

  def available?
    config['api_key'] && !config['api_key'].empty?
  end

  protected

  def default_config
    super.merge(
      'endpoint' => 'https://api.openai.com',
      'model' => 'gpt-4o-mini',
      'api_key' => nil
    )
  end
end
