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
      'max_tokens' => options['max_tokens'] || config['max_tokens'],
      # Disable reasoning/thinking mode for models that support it (e.g., Qwen 3.5)
      # to ensure output goes to 'content' field, not 'reasoning' field
      'chat_template_kwargs' => { 'enable_thinking' => false }
    }

    seed = options['seed'] || config['seed']
    body['seed'] = seed if seed

    # Structured generation: request JSON output when specified
    if options['response_format']
      body['response_format'] = options['response_format']
    end

    headers = { 'Authorization' => "Bearer #{config['api_key']}" }

    response = http_post(uri, body, headers)

    if response['choices'] && response['choices'][0]
      message = response['choices'][0]['message']
      # Some models (e.g., Qwen 3.5) put output in 'reasoning' field when thinking is enabled
      content = message['content'] || message['reasoning'] || ''
      content
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
