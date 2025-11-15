require './rag/vector_db_interface.rb'
require './rag/embedding_service_interface.rb'
require './print.rb'

# RAG Manager to coordinate retrieval-augmented generation operations
class RAGManager
  def initialize(vector_db_config, embedding_config, rag_config = {})
    @vector_db = create_vector_db(vector_db_config)
    @embedding_service = create_embedding_service(embedding_config)
    @rag_config = {
      max_results: rag_config[:max_results] || 5,
      similarity_threshold: rag_config[:similarity_threshold] || 0.7,
      chunk_size: rag_config[:chunk_size] || 1000,
      chunk_overlap: rag_config[:chunk_overlap] || 200,
      enable_caching: rag_config[:enable_caching] || false
    }
    @cache = {} if @rag_config[:enable_caching]
    @initialized = false
  end

  def setup
    return if @initialized

    Print.info "Initializing RAG Manager..."

    # Connect to vector database
    unless @vector_db.connected?
      Print.info "Connecting to vector database..."
      @vector_db.connect
      unless @vector_db.connected?
        Print.err "Failed to connect to vector database"
        return false
      end
    end

    # Connect to embedding service
    unless @embedding_service.connected?
      Print.info "Connecting to embedding service..."
      @embedding_service.connect
      unless @embedding_service.connected?
        Print.err "Failed to connect to embedding service"
        return false
      end
    end

    @initialized = true
    Print.info "RAG Manager initialized successfully"
    true
  end

  def add_knowledge_base(collection_name, documents, embeddings = nil)
    unless @initialized
      setup unless setup
      return false
    end

    Print.info "Adding knowledge base to collection: #{collection_name}"

    begin
      # Validate collection name
      @vector_db.validate_collection_name(collection_name)
      @vector_db.validate_documents(documents)

      # Create collection if it doesn't exist
      @vector_db.create_collection(collection_name) rescue nil

      # Generate embeddings if not provided
      if embeddings.nil?
        Print.info "Generating embeddings for #{documents.length} documents..."
        text_contents = documents.map { |doc| doc[:content] || doc['content'] }
        embeddings = @embedding_service.generate_batch_embeddings(text_contents)
      end

      # Add documents to vector database
      success = @vector_db.add_documents(collection_name, documents, embeddings)

      if success
        Print.info "Successfully added #{documents.length} documents to collection: #{collection_name}"
        # Clear cache if enabled
        @cache.clear if @rag_config[:enable_caching]
        true
      else
        Print.err "Failed to add documents to collection: #{collection_name}"
        false
      end
    rescue => e
      Print.err "Error adding knowledge base: #{e.message}"
      Print.err e.backtrace.inspect
      false
    end
  end

  def retrieve_relevant_context(query, collection_name, max_results = nil)
    unless @initialized
      setup unless setup
      return nil
    end

    # Check cache first
    cache_key = "#{collection_name}:#{query.hash}"
    if @rag_config[:enable_caching] && @cache.key?(cache_key)
      Print.debug "Using cached RAG results for query: #{query[0..50]}..."
      return @cache[cache_key]
    end

    max_results ||= @rag_config[:max_results]

    Print.info "Retrieving relevant context for query: #{query[0..50]}..."

    begin
      # Generate query embedding
      query_embedding = @embedding_service.generate_embedding(query)
      unless query_embedding
        Print.err "Failed to generate query embedding"
        return nil
      end

      # Search for similar documents
      results = @vector_db.search(collection_name, query_embedding, max_results)
      unless results
        Print.err "Failed to search vector database"
        return nil
      end

      # Filter results by similarity threshold
      filtered_results = results.select do |result|
        result[:score] && result[:score] >= @rag_config[:similarity_threshold]
      end

      # Format context
      # context = format_results_as_context(filtered_results)

      # Return a hash with the documents
      context = { documents: filtered_results }

      # Cache results if enabled
      if @rag_config[:enable_caching]
        @cache[cache_key] = context
        # Simple cache eviction - keep only last 100 entries
        if @cache.length > 100
          oldest_key = @cache.keys.first
          @cache.delete(oldest_key)
        end
      end

      Print.info "Retrieved #{filtered_results.length} relevant documents"
      context
    rescue => e
      Print.err "Error retrieving context: #{e.message}"
      Print.err e.backtrace.inspect
      nil
    end
  end

  def create_collection(collection_name)
    unless @initialized
      setup unless setup
      return false
    end

    Print.info "Creating vector collection: #{collection_name}"
    @vector_db.create_collection(collection_name)
  end

  def delete_collection(collection_name)
    unless @initialized
      setup unless setup
      return false
    end

    Print.info "Deleting vector collection: #{collection_name}"
    success = @vector_db.delete_collection(collection_name)

    # Clear cache for this collection
    if @rag_config[:enable_caching]
      @cache.keys.each do |key|
        @cache.delete(key) if key.start_with?("#{collection_name}:")
      end
    end

    success
  end

  def list_collections
    unless @initialized
      setup unless setup
      return []
    end

    # This method needs to be implemented by specific vector database clients
    # For now, return empty array - subclasses should override
    []
  end

  def test_connection
    Print.info "Testing RAG Manager connections..."

    vector_db_ok = @vector_db.test_connection
    embedding_service_ok = @embedding_service.test_connection

    overall_ok = vector_db_ok && embedding_service_ok

    Print.info "Vector Database: #{vector_db_ok ? 'OK' : 'FAILED'}"
    Print.info "Embedding Service: #{embedding_service_ok ? 'OK' : 'FAILED'}"
    Print.info "RAG Manager: #{overall_ok ? 'OK' : 'FAILED'}"

    overall_ok
  end

  def cleanup
    Print.info "Cleaning up RAG Manager..."
    @vector_db.disconnect if @vector_db.respond_to?(:disconnect)
    @embedding_service.disconnect if @embedding_service.respond_to?(:disconnect)
    @cache.clear if @cache
    @initialized = false
  end

  private

  def create_vector_db(config)
    provider = config[:provider] || 'chromadb'

    case provider.downcase
    when 'chromadb'
      require './rag/chromadb_client.rb'
      ChromaDBClient.new(config)
    when 'pinecone'
      require './rag/pinecone_client.rb'
      PineconeClient.new(config)
    when 'qdrant'
      require './rag/qdrant_client.rb'
      QdrantClient.new(config)
    when 'faiss'
      require './rag/faiss_client.rb'
      FAISSClient.new(config)
    else
      raise ArgumentError, "Unsupported vector database provider: #{provider}"
    end
  end

  def create_embedding_service(config)
    provider = config[:provider] || 'openai'

    case provider.downcase
    when 'openai'
      require './rag/openai_embedding_client.rb'
      OpenAIEmbeddingClient.new(config)
    when 'ollama'
      require './rag/ollama_embedding_client.rb'
      OllamaEmbeddingClient.new(config)
    when 'huggingface'
      require './rag/huggingface_embedding_client.rb'
      HuggingFaceEmbeddingClient.new(config)
    when 'mock'
      # Create a simple mock embedding service for testing
      MockEmbeddingService.new(config)
    else
      raise ArgumentError, "Unsupported embedding service provider: #{provider}"
    end
  end

  # Simple mock embedding service for testing
  class MockEmbeddingService
    def initialize(config)
      @config = config
      @model = config[:model] || 'mock-embed-model'
      @embedding_dimension = config[:embedding_dimension] || 384
      @initialized = false
    end

    def connect
      Print.info "Connecting to mock embedding service..."
      @initialized = true
      Print.info "Connected to mock embedding service successfully"
      true
    end

    def disconnect
      Print.info "Disconnecting from mock embedding service"
      @initialized = false
      true
    end

    def generate_embedding(text)
      return nil unless @initialized
      Print.info "Generating mock embedding for text (length: #{text.length})"
      embedding = generate_deterministic_embedding(text)
      Print.info "Successfully generated mock embedding (dimension: #{embedding.length})"
      embedding
    end

    def generate_batch_embeddings(texts)
      return [] unless @initialized
      Print.info "Generating mock batch embeddings for #{texts.length} texts"
      embeddings = texts.map { |text| generate_embedding(text) }.compact
      Print.info "Successfully generated #{embeddings.length} mock batch embeddings"
      embeddings
    end

    def test_connection
      Print.info "Testing mock embedding service connection..."
      success = @initialized
      Print.info "Mock embedding service connection test #{success ? 'successful' : 'failed'}"
      success
    end

    def connected?
      @initialized
    end

    private

    def generate_deterministic_embedding(text)
      # Generate a deterministic embedding based on text content
      # Create more semantically meaningful embeddings for testing

      # Extract key terms and normalize text
      normalized_text = text.downcase.gsub(/[^\w\s]/, ' ').gsub(/\s+/, ' ').strip
      key_terms = normalized_text.split(' ').select { |word| word.length > 2 }

      # Use text characteristics to generate a more meaningful embedding
      embedding = []

      # Generate base embedding using hash but make it more consistent for similar terms
      base_seed = normalized_text.hash.abs

      @embedding_dimension.times do |i|
        # Create some dimension-specific patterns
        dimension_seed = base_seed + i * 31

        # Check if this dimension should be influenced by key terms
        term_influence = 0.0
        key_terms.each do |term|
          term_seed = term.hash.abs + i * 17
          term_value = ((term_seed * 1103515245 + 12345) & 0x7fffffff).to_f / 0x7fffffff
          term_influence += term_value * 0.3  # Scale down term influence
        end

        # Combine base seed with term influence
        seed = ((dimension_seed * 1103515245 + 12345) & 0x7fffffff)
        base_value = (seed.to_f / 0x7fffffff) * 2 - 1

        # Mix base value with term influence
        final_value = base_value * 0.7 + term_influence * 0.3

        embedding << final_value
      end

      # Normalize the embedding vector
      magnitude = Math.sqrt(embedding.map { |x| x * x }.sum)
      embedding = embedding.map { |x| x / magnitude } if magnitude > 0

      embedding
    end
  end

  def format_results_as_context(results)
    return "" if results.nil? || results.empty?

    context_parts = []
    results.each_with_index do |result, index|
      doc = result[:document]
      score = result[:score]

      # Extract content from document
      content = doc[:content] || doc['content'] || ''

      # Add metadata if available
      metadata = []
      metadata << "ID: #{doc[:id] || doc['id']}" if doc[:id] || doc['id']
      metadata << "Score: #{score.round(4)}" if score
      metadata << "Source: #{doc[:source] || doc['source']}" if doc[:source] || doc['source']

      context_part = "Document #{index + 1}"
      context_part += " (#{metadata.join(', ')})" unless metadata.empty?
      context_part += ":\n#{content}"

      context_parts << context_part
    end

    context_parts.join("\n\n")
  end
end
