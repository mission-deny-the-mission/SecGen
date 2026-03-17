require_relative 'llm_provider'

class LlmProviderOllama < LlmProvider
  def generate(prompt, options = {})
    uri = URI.parse("#{config['endpoint']}/api/generate")

    body = {
      'model' => options['model'] || config['model'] || 'llama3',
      'prompt' => prompt,
      'stream' => false,
      'options' => {
        'temperature' => options['temperature'] || config['temperature'],
        'seed' => options['seed'] || config['seed'],
        'num_predict' => options['max_tokens'] || config['max_tokens']
      }.compact
    }

    response = http_post(uri, body)
    response['response'] || ''
  end

  def validate_config
    super
    config['endpoint'] ||= 'http://localhost:11434'
  end

  def available?
    uri = URI.parse("#{config['endpoint']}/api/tags")
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
      'endpoint' => 'http://localhost:11434',
      'model' => 'llama3'
    )
  end
end
