require 'json'
require 'net/http'
require 'uri'

# Abstract base class for LLM providers
# All providers implement: generate(prompt, options) -> String
class LlmProvider
  attr_accessor :config

  def initialize(config = {})
    self.config = default_config.merge(config)
    validate_config
  end

  # Override in subclasses
  def generate(prompt, options = {})
    raise NotImplementedError, "#{self.class.name}#generate must be implemented"
  end

  # Override in subclasses
  def validate_config
    # Base validation - subclasses should call super and add their own
  end

  # Override in subclasses
  def available?
    false
  end

  def provider_name
    self.class.name.sub('LlmProvider', '').downcase
  end

  protected

  def default_config
    {
      'temperature' => 0.7,
      'max_tokens' => 2048,
      'seed' => nil,
      'model' => nil,
      'timeout' => 120
    }
  end

  def http_post(uri, body, headers = {})
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = (uri.scheme == 'https')
    http.read_timeout = config['timeout'] || 120
    http.open_timeout = 30

    request = Net::HTTP::Post.new(uri.path, {
      'Content-Type' => 'application/json'
    }.merge(headers))
    request.body = body.to_json

    response = http.request(request)
    unless response.is_a?(Net::HTTPSuccess)
      raise "LLM API error (#{response.code}): #{response.body}"
    end

    JSON.parse(response.body)
  end
end
