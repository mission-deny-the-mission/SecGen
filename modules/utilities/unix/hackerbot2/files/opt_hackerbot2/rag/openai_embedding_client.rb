require './rag/embedding_service_interface.rb'
require './print.rb'
require 'uri'
require 'net/http'
require 'json'

# OpenAI API client for generating embeddings
class OpenAIEmbeddingClient < EmbeddingServiceInterface
  def initialize(config)
    super(config)
    @api_key = config[:api_key]
    @model = config[:model] || 'text-embedding-ada-002'
    @host = config[:host] || 'api.openai.com'

    # Use provided base_url, otherwise construct from host
    @base_url = if config[:base_url]
      # Remove trailing slash if present to ensure consistency
      config[:base_url].end_with?('/') ? config[:base_url].chop : config[:base_url]
    else
      "https://#{@host}/v1"
    end

    unless @api_key
      Print.err "OpenAI API key is required"
      raise ArgumentError, "OpenAI API key is required"
    end
  end

  def connect
    Print.info "Connecting to OpenAI embedding service..."

    # Test connection by attempting to get models
    if test_connection
      @initialized = true
      Print.info "Connected to OpenAI embedding service successfully"
      true
    else
      Print.err "Failed to connect to OpenAI embedding service"
      false
    end
  rescue => e
    Print.err "Error connecting to OpenAI embedding service: #{e.message}"
    false
  end

  def disconnect
    Print.info "Disconnecting from OpenAI embedding service"
    @initialized = false
    true
  end

  def generate_embedding(text)
    validate_text(text)

    unless @initialized
      Print.err "OpenAI embedding client not initialized"
      return nil
    end

    Print.info "Generating embedding for text (length: #{text.length})"

    begin
      uri = URI("#{@base_url}/embeddings")

      request_body = {
        input: text,
        model: @model
      }

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.open_timeout = 10
      http.read_timeout = 60
      request = Net::HTTP::Post.new(uri)
      request['Content-Type'] = 'application/json'
      request['Authorization'] = "Bearer #{@api_key}"
      request.body = request_body.to_json

      response = http.request(request)

      if response.code == '200'
        result = JSON.parse(response.body)
        embedding = result['data'][0]['embedding']

        Print.info "Successfully generated embedding (dimension: #{embedding.length})"
        embedding
      else
        Print.err "OpenAI API error: #{response.code} - #{response.body}"
        nil
      end
    rescue => e
      Print.err "Error generating OpenAI embedding: #{e.message}"
      Print.err e.backtrace.inspect
      nil
    end
  end

  def generate_batch_embeddings(texts)
    validate_texts(texts)

    unless @initialized
      Print.err "OpenAI embedding client not initialized"
      return []
    end

    Print.info "Generating batch embeddings for #{texts.length} texts"

    begin
      # OpenAI embedding API supports batch processing
      uri = URI("#{@base_url}/embeddings")

      request_body = {
        input: texts,
        model: @model
      }

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.open_timeout = 10
      http.read_timeout = 120
      request = Net::HTTP::Post.new(uri)
      request['Content-Type'] = 'application/json'
      request['Authorization'] = "Bearer #{@api_key}"
      request.body = request_body.to_json

      response = http.request(request)

      if response.code == '200'
        result = JSON.parse(response.body)
        embeddings = result['data'].map { |item| item['embedding'] }

        Print.info "Successfully generated #{embeddings.length} batch embeddings"
        embeddings
      else
        Print.err "OpenAI API error: #{response.code} - #{response.body}"
        []
      end
    rescue => e
      Print.err "Error generating OpenAI batch embeddings: #{e.message}"
      Print.err e.backtrace.inspect
      []
    end
  end

  def test_connection
    Print.info "Testing OpenAI embedding service connection..."

    begin
      uri = URI("#{@base_url}/models")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.open_timeout = 5
      http.read_timeout = 10
      request = Net::HTTP::Get.new(uri)
      request['Authorization'] = "Bearer #{@api_key}"

      response = http.request(request)
      success = response.code == '200'

      if success
        Print.info "OpenAI embedding service connection test successful"
      else
        Print.err "OpenAI embedding service connection test failed: #{response.code}"
      end

      success
    rescue => e
      Print.err "OpenAI embedding service connection test error: #{e.message}"
      false
    end
  end

  def get_model_info
    {
      provider: 'openai',
      model: @model,
      api_key_present: !@api_key.nil?,
      initialized: @initialized
    }
  end

  private
end
