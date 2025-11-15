require './rag/vector_db_interface.rb'
require './print.rb'

# In-memory ChromaDB client implementation for testing and local use
class ChromaDBClient < VectorDBInterface
  def initialize(config)
    super(config)
    @host = config[:host] || 'localhost'
    @port = config[:port] || 8000
    @collections = {}
    @document_store = {}
    @embedding_store = {}
  end

  def connect
    Print.info "Connecting to in-memory ChromaDB at #{@host}:#{@port}"

    # For in-memory implementation, we just initialize our data structures
    @collections = {}
    @document_store = {}
    @embedding_store = {}

    @initialized = true
    Print.info "Connected to in-memory ChromaDB"
    true
  rescue => e
    Print.err "Failed to connect to ChromaDB: #{e.message}"
    false
  end

  def disconnect
    Print.info "Disconnecting from in-memory ChromaDB"
    @collections.clear
    @document_store.clear
    @embedding_store.clear
    @initialized = false
    true
  end

  def create_collection(collection_name)
    validate_collection_name(collection_name)

    Print.info "Creating collection: #{collection_name}"

    if @collections.key?(collection_name)
      Print.debug "Collection #{collection_name} already exists"
      return true
    end

    @collections[collection_name] = {
      name: collection_name,
      created_at: Time.now,
      document_count: 0
    }

    @document_store[collection_name] = []
    @embedding_store[collection_name] = []

    Print.info "Created collection: #{collection_name}"
    true
  rescue => e
    Print.err "Failed to create collection #{collection_name}: #{e.message}"
    false
  end

  def add_documents(collection_name, documents, embeddings = nil)
    validate_collection_name(collection_name)
    validate_documents(documents)

    unless @collections.key?(collection_name)
      Print.err "Collection #{collection_name} does not exist"
      return false
    end

    Print.info "Adding #{documents.length} documents to collection: #{collection_name}"

    begin
      # Generate embeddings if not provided
      if embeddings.nil?
        Print.warn "No embeddings provided, using random embeddings for testing"
        embeddings = documents.map { generate_random_embedding }
      end

      # Validate embeddings match documents
      if embeddings.length != documents.length
        Print.err "Embeddings count (#{embeddings.length}) does not match documents count (#{documents.length})"
        return false
      end

      # Add documents and embeddings
      documents.each_with_index do |doc, index|
        doc_id = doc[:id] || doc['id']

        # Check if document already exists
        existing_index = @document_store[collection_name].find_index { |d| d[:id] == doc_id }

        document_data = {
          id: doc_id,
          content: doc[:content] || doc['content'],
          metadata: doc[:metadata] || doc['metadata'] || {},
          created_at: Time.now
        }

        if existing_index
          # Update existing document
          @document_store[collection_name][existing_index] = document_data
          @embedding_store[collection_name][existing_index] = embeddings[index]
          Print.debug "Updated document #{doc_id} in collection #{collection_name}"
        else
          # Add new document
          @document_store[collection_name] << document_data
          @embedding_store[collection_name] << embeddings[index]
          Print.debug "Added document #{doc_id} to collection #{collection_name}"
        end
      end

      # Update collection metadata
      @collections[collection_name][:document_count] = @document_store[collection_name].length
      @collections[collection_name][:updated_at] = Time.now

      Print.info "Successfully added #{documents.length} documents to collection #{collection_name}"
      true
    rescue => e
      Print.err "Failed to add documents to collection #{collection_name}: #{e.message}"
      Print.err e.backtrace.inspect
      false
    end
  end

  def search(collection_name, query_embedding, limit = 5)
    validate_collection_name(collection_name)

    unless @collections.key?(collection_name)
      Print.err "Collection #{collection_name} does not exist"
      return nil
    end

    if @document_store[collection_name].empty?
      Print.debug "Collection #{collection_name} is empty"
      return []
    end

    Print.info "Searching collection #{collection_name} with limit #{limit}"

    begin
      documents = @document_store[collection_name]
      embeddings = @embedding_store[collection_name]

      # Calculate similarity scores
      results = []
      documents.each_with_index do |doc, index|
        doc_embedding = embeddings[index]
        similarity = calculate_cosine_similarity(query_embedding, doc_embedding)

        results << {
          document: doc,
          score: similarity,
          embedding: doc_embedding
        }
      end

      # Sort by similarity score (descending) and limit results
      sorted_results = results.sort_by { |r| -r[:score] }
      limited_results = sorted_results.take(limit)

      Print.info "Found #{limited_results.length} similar documents"
      limited_results
    rescue => e
      Print.err "Failed to search collection #{collection_name}: #{e.message}"
      Print.err e.backtrace.inspect
      nil
    end
  end

  def delete_collection(collection_name)
    validate_collection_name(collection_name)

    unless @collections.key?(collection_name)
      Print.debug "Collection #{collection_name} does not exist"
      return true
    end

    Print.info "Deleting collection: #{collection_name}"

    @collections.delete(collection_name)
    @document_store.delete(collection_name)
    @embedding_store.delete(collection_name)

    Print.info "Deleted collection: #{collection_name}"
    true
  rescue => e
    Print.err "Failed to delete collection #{collection_name}: #{e.message}"
    false
  end

  def test_connection
    Print.info "Testing ChromaDB connection"

    # For in-memory implementation, just check if we're initialized
    if @initialized
      Print.info "ChromaDB connection test successful"
      true
    else
      Print.err "ChromaDB not initialized"
      false
    end
  end

  def list_collections
    @collections.keys.map do |collection_name|
      {
        name: collection_name,
        document_count: @collections[collection_name][:document_count],
        created_at: @collections[collection_name][:created_at]
      }
    end
  end

  def get_collection_stats(collection_name)
    validate_collection_name(collection_name)

    unless @collections.key?(collection_name)
      Print.err "Collection #{collection_name} does not exist"
      return nil
    end

    {
      name: collection_name,
      document_count: @collections[collection_name][:document_count],
      created_at: @collections[collection_name][:created_at],
      updated_at: @collections[collection_name][:updated_at]
    }
  end

  private

  def generate_random_embedding(dim = 1536)
    # Generate random embedding for testing purposes
    Array.new(dim) { rand(-1.0..1.0) }
  end

  def calculate_cosine_similarity(vec1, vec2)
    return 0.0 if vec1.nil? || vec2.nil?
    return 0.0 if vec1.length != vec2.length

    dot_product = vec1.zip(vec2).map { |a, b| a * b }.sum
    magnitude1 = Math.sqrt(vec1.map { |x| x * x }.sum)
    magnitude2 = Math.sqrt(vec2.map { |x| x * x }.sum)

    return 0.0 if magnitude1 == 0.0 || magnitude2 == 0.0

    dot_product / (magnitude1 * magnitude2)
  end

  def normalize_vector(vector)
    magnitude = Math.sqrt(vector.map { |x| x * x }.sum)
    return vector if magnitude == 0.0
    vector.map { |x| x / magnitude }
  end
end
