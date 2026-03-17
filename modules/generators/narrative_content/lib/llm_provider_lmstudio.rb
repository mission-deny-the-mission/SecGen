require_relative 'llm_provider'

# LM Studio exposes an OpenAI-compatible API endpoint
class LlmProviderLmstudio < LlmProvider
  def generate(prompt, options = {})
    uri = URI.parse("#{config['endpoint']}/v1/chat/completions")

    body = {
      'model' => options['model'] || config['model'] || 'local-model',
      'messages' => [
        { 'role' => 'user', 'content' => prompt }
      ],
      'temperature' => options['temperature'] || config['temperature'],
      'max_tokens' => options['max_tokens'] || config['max_tokens'],
      'stream' => false
    }

    seed = options['seed'] || config['seed']
    body['seed'] = seed if seed

    response = http_post(uri, body)

    if response['choices'] && response['choices'][0]
      response['choices'][0]['message']['content'] || ''
    else
      raise "Unexpected LM Studio response format: #{response}"
    end
  end

  def validate_config
    super
    config['endpoint'] ||= 'http://localhost:1234'
  end

  def available?
    uri = URI.parse("#{config['endpoint']}/v1/models")
    http = Net::HTTP.new(uri.host, uri.port)
    http.open_timeout = 5
    http.read_timeout = 5
    response = http.get(uri.path)
    response.is_a?(Net::HTTPSuccess)
  rescue StandardError
    false
  end

  protected

  def default_config
    super.merge(
      'endpoint' => 'http://localhost:1234',
      'model' => 'local-model'
    )
  end
end
