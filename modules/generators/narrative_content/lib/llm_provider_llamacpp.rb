require_relative 'llm_provider'

class LlmProviderLlamacpp < LlmProvider
  def generate(prompt, options = {})
    uri = URI.parse("#{config['endpoint']}/completion")

    body = {
      'prompt' => prompt,
      'temperature' => options['temperature'] || config['temperature'],
      'n_predict' => options['max_tokens'] || config['max_tokens'],
      'stream' => false
    }

    seed = options['seed'] || config['seed']
    body['seed'] = seed if seed

    response = http_post(uri, body)
    response['content'] || ''
  end

  def validate_config
    super
    config['endpoint'] ||= 'http://localhost:8080'
  end

  def available?
    uri = URI.parse("#{config['endpoint']}/health")
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
      'endpoint' => 'http://localhost:8080'
    )
  end
end
