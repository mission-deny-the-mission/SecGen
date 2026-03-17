require_relative 'llm_provider'

class LlmProviderAnthropic < LlmProvider
  ANTHROPIC_API_VERSION = '2023-06-01'

  def generate(prompt, options = {})
    uri = URI.parse("#{config['endpoint']}/v1/messages")

    body = {
      'model' => options['model'] || config['model'] || 'claude-3-haiku-20240307',
      'messages' => [
        { 'role' => 'user', 'content' => prompt }
      ],
      'max_tokens' => options['max_tokens'] || config['max_tokens'],
      'temperature' => options['temperature'] || config['temperature']
    }

    headers = {
      'x-api-key' => config['api_key'],
      'anthropic-version' => ANTHROPIC_API_VERSION
    }

    response = http_post(uri, body, headers)

    if response['content'] && response['content'][0]
      response['content'][0]['text'] || ''
    else
      raise "Unexpected Anthropic response format: #{response}"
    end
  end

  def validate_config
    super
    config['endpoint'] ||= 'https://api.anthropic.com'
    unless config['api_key'] && !config['api_key'].empty?
      raise "Anthropic provider requires 'api_key' in configuration"
    end
  end

  def available?
    config['api_key'] && !config['api_key'].empty?
  end

  protected

  def default_config
    super.merge(
      'endpoint' => 'https://api.anthropic.com',
      'model' => 'claude-3-haiku-20240307',
      'api_key' => nil
    )
  end
end
