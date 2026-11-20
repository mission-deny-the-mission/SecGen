
require './rag/embedding_service_interface.rb'
require './print.rb'
require 'uri'
require 'net/http'
require 'json'

# Ollama API client for generating embeddings
class OllamaEmbeddingClient < EmbeddingServiceInterface
  def initialize(config)
    super(config)
    @host = config[:host] || 'localhost'
    @port = config[:port] || 11434
    @model = config[:model] || 'nomic-embed-text'
    @base_url = "http://#{@host}:#{@port}"
  end

  def connect
    Print.info "Connecting to Ollama embedding service at #{@host}:#{@port}..."

    if test_connection
      @initialized = true
      Print.info "Connected to Ollama embedding service successfully"
      true
    else
      Print.err "Failed to connect to Ollama embedding service"
      false
    end
  rescue => e
    Print.err "Error connecting to Ollama embedding service: #{e.message}"
    false
  end

  def disconnect
    Print.info "Disconnecting from Ollama embedding service"
    @initialized = false
    true
  end

  def generate_embedding(text)
    validate_text(text)

    unless @initialized
      Print.err "Ollama embedding client not initialized"
      return nil
    end

    Print.info "Generating embedding for text (length: #{text.length}) using model: #{@model}"

    begin
      uri = URI("#{@base_url}/api/embeddings")

      request_body = {
        model: @model,
        prompt: text
      }

      http = Net::HTTP.new(@host, @port)
      http.open_timeout = 10
      http.read_timeout = 60
      request = Net::HTTP::Post.new(uri)
      request['Content-Type'] = 'application/json'
      request.body = request_body.to_json

      response = http.request(request)

      if response.code == '200'
        result = JSON.parse(response.body)
        embedding = result['embedding']

        if embedding && embedding.is_a?(Array) && !embedding.empty?
          Print.info "Successfully generated embedding (dimension: #{embedding.length})"
          embedding
        else
          Print.err "Ollama returned invalid embedding: #{result.inspect}"
          nil
        end
      else
        Print.err "Ollama API error: #{response.code} - #{response.body}"
        nil
      end
    rescue => e
      Print.err "Error generating Ollama embedding: #{e.message}"
      Print.err e.backtrace.inspect
      nil
    end
  end

  def generate_batch_embeddings(texts)
    validate_texts(texts)

    unless @initialized
      Print.err "Ollama embedding client not initialized"
      return []
    end

    Print.info "Generating batch embeddings for #{texts.length} texts using model: #{@model}"

    begin
      embeddings = []

      # Process in batches to avoid overwhelming the service
      batch_size = 10
      texts.each_slice(batch_size) do |batch|
        batch_embeddings = batch.map do |text|
          generate_embedding(text)
        end.compact

        embeddings.concat(batch_embeddings)

        # Small delay between batches to be respectful to the service
        sleep(0.1) unless batch == texts.last(batch_size)
      end

      if embeddings.length == texts.length
        Print.info "Successfully generated #{embeddings.length} batch embeddings"
        embeddings
      else
        Print.std "Generated only #{embeddings.length} embeddings out of #{texts.length} requested"
        embeddings
      end
    rescue => e
      Print.err "Error generating Ollama batch embeddings: #{e.message}"
      Print.err e.backtrace.inspect
      []
    end
  end

  def test_connection
    Print.info "Testing Ollama embedding service connection..."

    begin
      uri = URI("#{@base_url}/api/tags")
      http = Net::HTTP.new(@host, @port)
      http.open_timeout = 5
      http.read_timeout = 10
      request = Net::HTTP::Get.new(uri)

      response = http.request(request)
      success = response.code == '200'

      if success
        Print.info "Ollama embedding service connection test successful"

        # Also check if the embedding model is available
        models_response = JSON.parse(response.body)
        models = models_response['models'] || []
        embedding_models = models.select { |m| m['name'].include?(@model) || m['name'].include?('embed') }

        if embedding_models.any?
          Print.info "Found #{embedding_models.length} embedding models"
        else
          Print.std "No embedding models found. Consider pulling an embedding model with: ollama pull #{@model}"
        end
      else
        Print.err "Ollama embedding service connection test failed: #{response.code}"
      end

      success
    rescue => e
      Print.err "Ollama embedding service connection test error: #{e.message}"
      false
    end
  end

  def get_available_models
    unless @initialized
      Print.err "Ollama embedding client not initialized"
      return []
    end

    begin
      uri = URI("#{@base_url}/api/tags")
      http = Net::HTTP.new(@host, @port)
      http.open_timeout = 5
      http.read_timeout = 10
      request = Net::HTTP::Get.new(uri)

      response = http.request(request)
      if response.code == '200'
        models_response = JSON.parse(response.body)
        models = models_response['models'] || []

        # Filter for models that are likely to support embeddings
        embedding_models = models.select { |m|
          m['name'].downcase.include?('embed') ||
          m['name'].downcase.include?('nomic') ||
          m['name'].downcase.include?('llama2') ||
          m['name'].downcase.include?('mistral')
        }

        embedding_models
      else
        Print.err "Failed to get available models: #{response.code}"
        []
      end
    rescue => e
      Print.err "Error getting available models: #{e.message}"
      []
    end
  end

  def get_model_info
    {
      provider: 'ollama',
      model: @model,
      host: @host,
      port: @port,
      initialized: @initialized,
      base_url: @base_url
    }
  end

  def pull_model(model_name = nil)
    model_name ||= @model
    Print.info "Pulling Ollama model: #{model_name}"

    begin
      uri = URI("#{@base_url}/api/pull")
      request_body = { name: model_name }

      http = Net::HTTP.new(@host, @port)
      http.open_timeout = 10
      http.read_timeout = 300 # 5 minutes timeout for model download
      request = Net::HTTP::Post.new(uri)
      request['Content-Type'] = 'application/json'
      request.body = request_body.to_json

      response = http.request(request)
      if response.code == '200'
        Print.info "Successfully pulled model: #{model_name}"
        true
      else
        Print.err "Failed to pull model #{model_name}: #{response.code} - #{response.body}"
        false
      end
    rescue => e
      Print.err "Error pulling model: #{e.message}"
      false
    end
  end

  private
end
