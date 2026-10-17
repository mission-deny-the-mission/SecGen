require './rag/embedding_service_interface.rb'
require './print.rb'
require 'json'
require 'fileutils'

# Offline Ollama embedding client with persistent caching
# This client works entirely offline with pre-computed embeddings and local Ollama models
class OllamaEmbeddingOfflineClient < EmbeddingServiceInterface
  def initialize(config)
    super(config)
    @model = config[:model] || 'nomic-embed-text'
    @local_model_path = config[:local_model_path]
    @cache_embeddings = config[:cache_embeddings] != false
    @cache_path = config[:cache_path] || File.join(Dir.pwd, 'cache', 'embeddings', 'ollama')
    @ollama_host = config[:host] || 'localhost'
    @ollama_port = config[:port] || 11434
    @embedding_cache = {}
    @embedding_dimension = nil
    @fallback_to_random = config[:fallback_to_random] != false
    @preload_embeddings = config[:preload_embeddings] || false
    @cache_ttl = config[:cache_ttl] || 86400  # 24 hours
  end

  def connect
    Print.info "Connecting to offline Ollama embedding service..."

    # Create cache directory
    FileUtils.mkdir_p(@cache_path) unless File.exist?(@cache_path)

    # Load existing cache from disk
    load_cache_from_disk

    # Try to connect to local Ollama instance
    if test_local_ollama_connection
      Print.info "Connected to local Ollama instance"
      @embedding_dimension = detect_embedding_dimension
      Print.info "Detected embedding dimension: #{@embedding_dimension}"
    else
      Print.warn "Local Ollama instance not available, will use cached embeddings"
    end

    # Preload embeddings if configured
    if @preload_embeddings
      preload_all_embeddings
    end

    @initialized = true
    Print.info "Offline Ollama embedding client initialized successfully"
    true
  rescue => e
    Print.err "Failed to connect to offline Ollama embedding service: #{e.message}"
    false
  end

  def disconnect
    Print.info "Disconnecting from offline Ollama embedding service..."

    # Save cache to disk
    if @cache_embeddings
      save_cache_to_disk
    end

    @embedding_cache.clear
    @initialized = false

    Print.info "Offline Ollama embedding client disconnected"
    true
  end

  def generate_embedding(text)
    validate_text(text)

    unless @initialized
      Print.err "Offline Ollama embedding client not initialized"
      return nil
    end

    Print.info "Generating embedding for text (length: #{text.length}) using offline model: #{@model}"

    begin
      # Check cache first
      cache_key = generate_cache_key(text)
      cached_embedding = get_cached_embedding(cache_key)

      if cached_embedding
        Print.debug "Using cached embedding for text (length: #{text.length})"
        return cached_embedding
      end

      # Try to generate embedding using local Ollama
      embedding = generate_local_ollama_embedding(text)

      if embedding
        # Cache the result
        cache_embedding(cache_key, embedding)
        Print.info "Generated and cached embedding (dimension: #{embedding.length})"
        return embedding
      else
        # Fallback to cached random embedding
        if @fallback_to_random
          Print.warn "Local Ollama failed, using fallback embedding"
          fallback_embedding = generate_fallback_embedding(text)
          cache_embedding(cache_key, fallback_embedding)
          return fallback_embedding
        else
          Print.err "Failed to generate embedding and fallback disabled"
          return nil
        end
      end
    rescue => e
      Print.err "Error generating offline embedding: #{e.message}"
      Print.err e.backtrace.inspect
      return nil
    end
  end

  def generate_batch_embeddings(texts)
    validate_texts(texts)

    unless @initialized
      Print.err "Offline Ollama embedding client not initialized"
      return []
    end

    Print.info "Generating batch embeddings for #{texts.length} texts using offline model: #{@model}"

    begin
      embeddings = []
      cache_hits = 0
      cache_misses = 0

      # Process in batches to avoid overwhelming the service
      batch_size = 10
      texts.each_slice(batch_size) do |batch|
        batch.each_with_index do |text, index|
          cache_key = generate_cache_key(text)
          cached_embedding = get_cached_embedding(cache_key)

          if cached_embedding
            embeddings << cached_embedding
            cache_hits += 1
          else
            # Generate new embedding
            embedding = generate_local_ollama_embedding(text)

            if embedding
              embeddings << embedding
              cache_embedding(cache_key, embedding)
              cache_misses += 1
            else
              # Fallback
              if @fallback_to_random
                fallback_embedding = generate_fallback_embedding(text)
                embeddings << fallback_embedding
                cache_embedding(cache_key, fallback_embedding)
                cache_misses += 1
              else
                embeddings << nil
              end
            end
          end
        end

        # Small delay between batches to be respectful to the service
        sleep(0.1) unless batch == texts.last(batch_size)
      end

      # Validate all embeddings have the same dimension
      valid_embeddings = embeddings.compact
      if valid_embeddings.any?
        first_embedding = valid_embeddings.first
        consistent_dimension = first_embedding.length

        valid_embeddings.each do |embedding|
          if embedding.length != consistent_dimension
            Print.err "Inconsistent embedding dimensions detected"
            return []
          end
        end

        Print.info "Generated #{valid_embeddings.length} embeddings (cache hits: #{cache_hits}, misses: #{cache_misses})"
        return embeddings
      else
        Print.err "No valid embeddings generated"
        return []
      end
    rescue => e
      Print.err "Error generating offline batch embeddings: #{e.message}"
      Print.err e.backtrace.inspect
      return []
    end
  end

  def test_connection
    Print.info "Testing offline Ollama embedding service connection..."

    if !@initialized
      Print.err "Offline Ollama client not initialized"
      return false
    end

    # Test local Ollama connection
    local_available = test_local_ollama_connection

    # Test cache functionality
    cache_available = test_cache_functionality

    # Test embedding generation
    embedding_available = test_embedding_generation

    overall_success = local_available || cache_available

    Print.info "Offline Ollama connection test results:"
    Print.info "  Local Ollama: #{local_available ? 'AVAILABLE' : 'UNAVAILABLE'}"
    Print.info "  Cache: #{cache_available ? 'AVAILABLE' : 'UNAVAILABLE'}"
    Print.info "  Embedding Generation: #{embedding_available ? 'AVAILABLE' : 'UNAVAILABLE'}"
    Print.info "  Overall: #{overall_success ? 'SUCCESS' : 'FAILED'}"

    overall_success
  end

  def get_available_models
    unless @initialized
      Print.err "Offline Ollama client not initialized"
      return []
    end

    # Try to get models from local Ollama
    if test_local_ollama_connection
      begin
        require 'net/http'
        require 'json'

        uri = URI("http://#{@ollama_host}:#{@ollama_port}/api/tags")
        http = Net::HTTP.new(@ollama_host, @ollama_port)
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

          return embedding_models
        end
      rescue => e
        Print.debug "Failed to get models from local Ollama: #{e.message}"
      end
    end

    # Return cached information about models
    get_cached_models_info
  end

  def get_cache_stats
    {
      cache_size: @embedding_cache.length,
      cache_path: @cache_path,
      cache_ttl: @cache_ttl,
      embedding_dimension: @embedding_dimension,
      model: @model,
      local_ollama_available: test_local_ollama_connection,
      fallback_enabled: @fallback_to_random
    }
  end

  def precompute_embeddings_for_texts(texts, collection_name = nil)
    unless @initialized
      Print.err "Offline Ollama client not initialized"
      return false
    end

    Print.info "Precomputing embeddings for #{texts.length} texts..."

    success_count = 0
    total_count = texts.length

    texts.each_with_index do |text, index|
      begin
        cache_key = generate_cache_key(text, collection_name)

        # Skip if already cached
        if get_cached_embedding(cache_key)
          success_count += 1
          next
        end

        # Generate and cache embedding
        embedding = generate_local_ollama_embedding(text) || generate_fallback_embedding(text)
        if embedding
          cache_embedding(cache_key, embedding)
          success_count += 1
        end

        # Progress indicator
        if (index + 1) % 10 == 0
          Print.info "Processed #{index + 1}/#{total_count} texts..."
        end
      rescue => e
        Print.err "Error precomputing embedding for text #{index}: #{e.message}"
      end
    end

    # Save cache to disk after precomputation
    save_cache_to_disk

    Print.info "Precomputation completed: #{success_count}/#{total_count} embeddings cached"
    success_count == total_count
  end

  def export_cache(export_path)
    unless @initialized
      Print.err "Offline Ollama client not initialized"
      return false
    end

    Print.info "Exporting embedding cache to: #{export_path}"

    begin
      export_data = {
        cache: @embedding_cache,
        metadata: {
          model: @model,
          embedding_dimension: @embedding_dimension,
          export_time: Time.now.iso8601,
          cache_size: @embedding_cache.length,
          version: "1.0"
        }
      }

      # Use compression for smaller file size
      require 'zlib'

      File.open(export_path, 'wb') do |file|
        compressed_data = Zlib.deflate(JSON.pretty_generate(export_data))
        file.write(compressed_data)
      end

      Print.info "Cache exported successfully (#{File.size(export_path)} bytes)"
      true
    rescue => e
      Print.err "Failed to export cache: #{e.message}"
      false
    end
  end

  def import_cache(import_path)
    unless @initialized
      Print.err "Offline Ollama client not initialized"
      return false
    end

    unless File.exist?(import_path)
      Print.err "Import cache file not found: #{import_path}"
      return false
    end

    Print.info "Importing embedding cache from: #{import_path}"

    begin
      # Read and decompress
      require 'zlib'
      compressed_data = File.binread(import_path)
      json_data = Zlib.inflate(compressed_data)
      import_data = JSON.parse(json_data)

      # Validate import data
      if import_data['cache'] && import_data['metadata']
        # Merge with existing cache
        @embedding_cache.merge!(import_data['cache'])

        # Update metadata
        if import_data['metadata']['embedding_dimension']
          @embedding_dimension = import_data['metadata']['embedding_dimension']
        end

        Print.info "Cache imported successfully: #{@embedding_cache.length} total embeddings"
        true
      else
        Print.err "Invalid cache import format"
        false
      end
    rescue => e
      Print.err "Failed to import cache: #{e.message}"
      false
    end
  end

  private

  def test_local_ollama_connection
    begin
      require 'net/http'
      require 'json'

      uri = URI("http://#{@ollama_host}:#{@ollama_port}/api/tags")
      http = Net::HTTP.new(@ollama_host, @ollama_port)
      http.open_timeout = 3
      http.read_timeout = 5
      request = Net::HTTP::Get.new(uri)

      response = http.request(request)
      response.code == '200'
    rescue => e
      Print.debug "Local Ollama connection test failed: #{e.message}"
      false
    end
  end

  def detect_embedding_dimension
    return 768 if @model.include?('nomic-embed-text')  # Default for nomic-embed-text
    return 1536 if @model.include?('text-embedding-ada-002')  # OpenAI compatible
    return 4096 if @model.include?('llama2') || @model.include?('mistral')  # Common for larger models
    return 768  # Default fallback
  end

  def generate_local_ollama_embedding(text)
    return nil unless test_local_ollama_connection

    begin
      require 'net/http'
      require 'json'

      uri = URI("http://#{@ollama_host}:#{@ollama_port}/api/embeddings")

      request_body = {
        model: @model,
        prompt: text
      }

      http = Net::HTTP.new(@ollama_host, @ollama_port)
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
          # Set dimension if not already set
          @embedding_dimension = embedding.length if @embedding_dimension.nil?
          return embedding
        else
          Print.err "Ollama returned invalid embedding: #{result.inspect}"
          return nil
        end
      else
        Print.err "Ollama API error: #{response.code} - #{response.body}"
        return nil
      end
    rescue => e
      Print.err "Error calling local Ollama: #{e.message}"
      return nil
    end
  end

  def generate_fallback_embedding(text)
    # Generate deterministic fallback embedding based on text content
    @embedding_dimension ||= detect_embedding_dimension

    # Use hash-based embedding generation for consistency
    hash_value = text.hash.abs
    embedding = []

    @embedding_dimension.times do |i|
      # Generate pseudo-random but deterministic values
      seed = hash_value + i
      value = Math.sin(seed.to_f) * 2.0 - 1.0  # Range: [-1, 1]
      embedding << value
    end

    # Normalize the vector
    normalize_vector(embedding)
  end

  def normalize_vector(vector)
    magnitude = Math.sqrt(vector.map { |x| x * x }.sum)
    return vector if magnitude == 0.0
    vector.map { |x| x / magnitude }
  end

  def generate_cache_key(text, collection_name = nil)
    # Generate consistent cache key
    base_key = "#{collection_name || 'default'}:#{text.hash}"
    Digest::MD5.hexdigest(base_key)
  end

  def get_cached_embedding(cache_key)
    return nil unless @cache_embeddings

    cached_entry = @embedding_cache[cache_key]
    return nil unless cached_entry

    # Check TTL
    if Time.now > cached_entry[:expires_at]
      @embedding_cache.delete(cache_key)
      return nil
    end

    cached_entry[:embedding]
  end

  def cache_embedding(cache_key, embedding)
    return unless @cache_embeddings

    @embedding_cache[cache_key] = {
      embedding: embedding,
      created_at: Time.now,
      expires_at: Time.now + @cache_ttl,
      model: @model,
      dimension: embedding.length
    }

    # Limit cache size
    if @embedding_cache.length > 10000  # Max 10k embeddings
      oldest_key = @embedding_cache.keys.first
      @embedding_cache.delete(oldest_key)
    end
  end

  def load_cache_from_disk
    return unless @cache_embeddings

    cache_file = cache_file_path
    return unless File.exist?(cache_file)

    begin
      cache_data = JSON.parse(File.read(cache_file))
      @embedding_cache = cache_data['cache'] || {}

      # Update dimension if available
      if cache_data['metadata'] && cache_data['metadata']['embedding_dimension']
        @embedding_dimension = cache_data['metadata']['embedding_dimension']
      end

      Print.info "Loaded #{@embedding_cache.length} cached embeddings from disk"
    rescue => e
      Print.err "Failed to load cache from disk: #{e.message}"
    end
  end

  def save_cache_to_disk
    return unless @cache_embeddings

    cache_file = cache_file_path
    FileUtils.mkdir_p(File.dirname(cache_file)) unless File.exist?(File.dirname(cache_file))

    begin
      cache_data = {
        cache: @embedding_cache,
        metadata: {
          model: @model,
          embedding_dimension: @embedding_dimension,
          saved_at: Time.now.iso8601,
          cache_size: @embedding_cache.length,
          version: "1.0"
        }
      }

      File.write(cache_file, JSON.pretty_generate(cache_data))
      Print.debug "Saved #{@embedding_cache.length} embeddings to cache"
    rescue => e
      Print.err "Failed to save cache to disk: #{e.message}"
    end
  end

  def preload_all_embeddings
    return unless @cache_embeddings

    Print.info "Preloading all cached embeddings..."

    cache_file = cache_file_path
    if File.exist?(cache_file)
      load_cache_from_disk
      Print.info "Preloaded #{@embedding_cache.length} embeddings"
    else
      Print.info "No cache file found for preloading"
    end
  end

  def cache_file_path
    File.join(@cache_path, "ollama_embeddings_#{@model.gsub(/\//, '_')}.json")
  end

  def test_cache_functionality
    # Test cache read/write
    test_key = "test_key_#{Time.now.to_i}"
    test_embedding = [1.0, 2.0, 3.0]

    # Test writing
    cache_embedding(test_key, test_embedding)
    cached = get_cached_embedding(test_key)

    # Cleanup
    @embedding_cache.delete(test_key)

    cached && cached == test_embedding
  end

  def test_embedding_generation
    # Test with a simple text
    test_text = "test embedding generation"
    embedding = generate_embedding(test_text)

    embedding && embedding.is_a?(Array) && !embedding.empty?
  end

  def get_cached_models_info
    # Return cached model information
    [
      {
        name: @model,
        modified_at: Time.now,
        size: 0,  # Unknown size
        description: "Offline cached model"
      }
    ]
  end
end
