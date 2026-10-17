require './rag/vector_db_interface.rb'
require './print.rb'
require 'json'
require 'fileutils'

# Offline ChromaDB client with persistent file storage
# This client operates entirely from local disk storage without requiring network connectivity
class ChromaDBOfflineClient < VectorDBInterface
  def initialize(config)
    super(config)
    @storage_path = config[:storage_path] || File.join(Dir.pwd, 'knowledge_bases', 'offline', 'vector_db')
    @persist_embeddings = config[:persist_embeddings] != false
    @compression_enabled = config[:compression_enabled] != false
    @collections = {}
    @document_store = {}
    @embedding_store = {}
    @metadata_store = {}
    @indexes = {}
  end

  def connect
    Print.info "Connecting to offline ChromaDB at: #{@storage_path}"

    # Create storage directory if it doesn't exist
    FileUtils.mkdir_p(@storage_path) unless File.exist?(@storage_path)

    # Load existing data from disk
    load_collections_from_disk
    load_documents_from_disk
    load_embeddings_from_disk
    load_metadata_from_disk

    @initialized = true
    Print.info "Connected to offline ChromaDB successfully"

    # Print statistics
    Print.info "Loaded #{@collections.length} collections, #{total_document_count} documents"
    true
  rescue => e
    Print.err "Failed to connect to offline ChromaDB: #{e.message}"
    Print.err e.backtrace.inspect
    false
  end

  def disconnect
    Print.info "Disconnecting from offline ChromaDB"

    # Save all data to disk before disconnecting
    if @persist_embeddings
      save_collections_to_disk
      save_documents_to_disk
      save_embeddings_to_disk
      save_metadata_to_disk
      save_indexes_to_disk
    end

    @collections.clear
    @document_store.clear
    @embedding_store.clear
    @metadata_store.clear
    @indexes.clear
    @initialized = false

    Print.info "Offline ChromaDB disconnected and data saved"
    true
  end

  def create_collection(collection_name)
    validate_collection_name(collection_name)

    Print.info "Creating offline collection: #{collection_name}"

    if @collections.key?(collection_name)
      Print.debug "Collection #{collection_name} already exists"
      return true
    end

    # Initialize collection data structures
    @collections[collection_name] = {
      name: collection_name,
      created_at: Time.now,
      updated_at: Time.now,
      document_count: 0,
      embedding_dimension: nil,  # Will be set when first document is added
      metadata: {}
    }

    @document_store[collection_name] = []
    @embedding_store[collection_name] = []
    @metadata_store[collection_name] = {}
    @indexes[collection_name] = {
      text_index: {},      # Text search index
      metadata_index: {},  # Metadata search index
      id_index: {}        # Document ID index
    }

    # Save to disk immediately if persistence is enabled
    save_collections_to_disk if @persist_embeddings

    Print.info "Created offline collection: #{collection_name}"
    true
  rescue => e
    Print.err "Failed to create offline collection #{collection_name}: #{e.message}"
    false
  end

  def add_documents(collection_name, documents, embeddings = nil)
    validate_collection_name(collection_name)
    validate_documents(documents)

    unless @collections.key?(collection_name)
      Print.err "Offline collection #{collection_name} does not exist"
      return false
    end

    Print.info "Adding #{documents.length} documents to offline collection: #{collection_name}"

    begin
      # Generate embeddings if not provided
      if embeddings.nil?
        Print.warn "No embeddings provided for offline storage, using random embeddings for testing"
        embeddings = documents.map { |doc| generate_test_embedding(doc) }
      end

      # Validate embeddings match documents
      if embeddings.length != documents.length
        Print.err "Embeddings count (#{embeddings.length}) does not match documents count (#{documents.length})"
        return false
      end

      # Set embedding dimension for the collection if not set
      first_embedding = embeddings.first
      if first_embedding && @collections[collection_name][:embedding_dimension].nil?
        @collections[collection_name][:embedding_dimension] = first_embedding.length
        Print.info "Set embedding dimension for collection #{collection_name}: #{first_embedding.length}"
      end

      # Validate embedding dimensions
      expected_dim = @collections[collection_name][:embedding_dimension]
      embeddings.each_with_index do |embedding, index|
        if embedding.length != expected_dim
          Print.err "Embedding dimension mismatch at index #{index}: expected #{expected_dim}, got #{embedding.length}"
          return false
        end
      end

      # Process documents in batches for better memory management
      batch_size = 100
      documents.each_slice(batch_size).with_index do |batch, batch_index|
        add_batch_to_collection(collection_name, batch, embeddings[batch_index * batch_size, batch_size])
        Print.debug "Processed batch #{batch_index + 1} for collection #{collection_name}"
      end

      # Update collection metadata
      @collections[collection_name][:document_count] = @document_store[collection_name].length
      @collections[collection_name][:updated_at] = Time.now

      # Save to disk if persistence is enabled
      if @persist_embeddings
        save_documents_to_disk
        save_embeddings_to_disk
        save_indexes_to_disk
        save_collections_to_disk
      end

      Print.info "Successfully added #{documents.length} documents to offline collection #{collection_name}"
      true
    rescue => e
      Print.err "Failed to add documents to offline collection #{collection_name}: #{e.message}"
      Print.err e.backtrace.inspect
      false
    end
  end

  def search(collection_name, query_embedding, limit = 5)
    validate_collection_name(collection_name)

    unless @collections.key?(collection_name)
      Print.err "Offline collection #{collection_name} does not exist"
      return nil
    end

    if @document_store[collection_name].empty?
      Print.debug "Offline collection #{collection_name} is empty"
      return []
    end

    Print.info "Searching offline collection #{collection_name} with limit #{limit}"

    begin
      documents = @document_store[collection_name]
      embeddings = @embedding_store[collection_name]

      # Validate query embedding dimension
      expected_dim = @collections[collection_name][:embedding_dimension]
      if query_embedding.length != expected_dim
        Print.err "Query embedding dimension mismatch: expected #{expected_dim}, got #{query_embedding.length}"
        return []
      end

      # Calculate similarity scores
      results = []
      documents.each_with_index do |doc, index|
        doc_embedding = embeddings[index]
        similarity = calculate_cosine_similarity(query_embedding, doc_embedding)

        results << {
          document: doc,
          score: similarity,
          embedding: doc_embedding,
          index: index
        }
      end

      # Sort by similarity score (descending) and limit results
      sorted_results = results.sort_by { |r| -r[:score] }
      limited_results = sorted_results.take(limit)

      # Apply similarity threshold if configured
      threshold = 0.0  # No threshold by default for offline mode
      filtered_results = limited_results.select do |result|
        result[:score] >= threshold
      end

      Print.info "Found #{filtered_results.length} similar documents in offline collection"
      filtered_results
    rescue => e
      Print.err "Failed to search offline collection #{collection_name}: #{e.message}"
      Print.err e.backtrace.inspect
      nil
    end
  end

  def delete_collection(collection_name)
    validate_collection_name(collection_name)

    unless @collections.key?(collection_name)
      Print.debug "Offline collection #{collection_name} does not exist"
      return true
    end

    Print.info "Deleting offline collection: #{collection_name}"

    # Remove from memory
    @collections.delete(collection_name)
    @document_store.delete(collection_name)
    @embedding_store.delete(collection_name)
    @metadata_store.delete(collection_name)
    @indexes.delete(collection_name)

    # Remove from disk
    collection_dir = collection_path(collection_name)
    if File.exist?(collection_dir)
      FileUtils.rm_rf(collection_dir)
      Print.debug "Removed collection directory: #{collection_dir}"
    end

    Print.info "Deleted offline collection: #{collection_name}"
    true
  rescue => e
    Print.err "Failed to delete offline collection #{collection_name}: #{e.message}"
    false
  end

  def test_connection
    Print.info "Testing offline ChromaDB connection"

    if @initialized
      # Test that we can read/write to storage directory
      test_file = File.join(@storage_path, '.connection_test')
      begin
        File.write(test_file, "test_#{Time.now.to_i}")
        File.read(test_file)
        File.delete(test_file)

        Print.info "Offline ChromaDB connection test successful"
        true
      rescue => e
        Print.err "Offline ChromaDB storage test failed: #{e.message}"
        false
      end
    else
      Print.err "Offline ChromaDB not initialized"
      false
    end
  end

  def list_collections
    @collections.keys.map do |collection_name|
      {
        name: collection_name,
        document_count: @collections[collection_name][:document_count],
        embedding_dimension: @collections[collection_name][:embedding_dimension],
        created_at: @collections[collection_name][:created_at],
        updated_at: @collections[collection_name][:updated_at],
        size_bytes: calculate_collection_size(collection_name)
      }
    end
  end

  def get_collection_stats(collection_name)
    validate_collection_name(collection_name)

    unless @collections.key?(collection_name)
      Print.err "Offline collection #{collection_name} does not exist"
      return nil
    end

    {
      name: collection_name,
      document_count: @collections[collection_name][:document_count],
      embedding_dimension: @collections[collection_name][:embedding_dimension],
      created_at: @collections[collection_name][:created_at],
      updated_at: @collections[collection_name][:updated_at],
      metadata: @collections[collection_name][:metadata],
      size_bytes: calculate_collection_size(collection_name),
      storage_path: collection_path(collection_name)
    }
  end

  def export_collection(collection_name, export_path)
    validate_collection_name(collection_name)

    unless @collections.key?(collection_name)
      Print.err "Offline collection #{collection_name} does not exist"
      return false
    end

    Print.info "Exporting offline collection #{collection_name} to: #{export_path}"

    begin
      export_data = {
        collection: @collections[collection_name],
        documents: @document_store[collection_name],
        embeddings: @embedding_store[collection_name],
        metadata: @metadata_store[collection_name],
        exported_at: Time.now.iso8601,
        version: "1.0"
      }

      # Apply compression if enabled
      if @compression_enabled
        require 'json'
        require 'zlib'

        File.open(export_path, 'wb') do |file|
          compressed_data = Zlib::Deflate.deflate(JSON.pretty_generate(export_data))
          file.write(compressed_data)
        end
      else
        File.write(export_path, JSON.pretty_generate(export_data))
      end

      Print.info "Successfully exported collection #{collection_name} to: #{export_path}"
      true
    rescue => e
      Print.err "Failed to export collection #{collection_name}: #{e.message}"
      false
    end
  end

  def import_collection(collection_name, import_path)
    validate_collection_name(collection_name)

    unless File.exist?(import_path)
      Print.err "Import file not found: #{import_path}"
      return false
    end

    Print.info "Importing offline collection #{collection_name} from: #{import_path}"

    begin
      # Load data from file
      if @compression_enabled && import_path.end_with?('.gz')
        require 'zlib'
        compressed_data = File.binread(import_path)
        json_data = Zlib::Inflate.inflate(compressed_data)
        import_data = JSON.parse(json_data)
      else
        import_data = JSON.parse(File.read(import_path))
      end

      # Create collection if it doesn't exist
      create_collection(collection_name) unless @collections.key?(collection_name)

      # Import data
      @collections[collection_name] = import_data['collection'].merge(@collections[collection_name])
      @document_store[collection_name] = import_data['documents'] || []
      @embedding_store[collection_name] = import_data['embeddings'] || []
      @metadata_store[collection_name] = import_data['metadata'] || {}

      # Rebuild indexes
      rebuild_indexes(collection_name)

      # Save to disk
      if @persist_embeddings
        save_documents_to_disk
        save_embeddings_to_disk
        save_metadata_to_disk
        save_collections_to_disk
        save_indexes_to_disk
      end

      Print.info "Successfully imported collection #{collection_name}"
      true
    rescue => e
      Print.err "Failed to import collection #{collection_name}: #{e.message}"
      Print.err e.backtrace.inspect
      false
    end
  end

  private

  def collection_path(collection_name)
    File.join(@storage_path, collection_name)
  end

  def documents_path(collection_name)
    File.join(collection_path(collection_name), 'documents.json')
  end

  def embeddings_path(collection_name)
    File.join(collection_path(collection_name), 'embeddings.bin')
  end

  def metadata_path(collection_name)
    File.join(collection_path(collection_name), 'metadata.json')
  end

  def indexes_path(collection_name)
    File.join(collection_path(collection_name), 'indexes.json')
  end

  def collections_metadata_path
    File.join(@storage_path, 'collections.json')
  end

  def load_collections_from_disk
    return unless @persist_embeddings

    metadata_file = collections_metadata_path
    return unless File.exist?(metadata_file)

    begin
      metadata_data = JSON.parse(File.read(metadata_file))
      @collections = metadata_data['collections'] || {}
      Print.debug "Loaded #{@collections.length} collections from metadata"
    rescue => e
      Print.err "Failed to load collections metadata: #{e.message}"
    end
  end

  def save_collections_to_disk
    return unless @persist_embeddings

    metadata_file = collections_metadata_path
    metadata_data = {
      collections: @collections,
      saved_at: Time.now.iso8601,
      version: "1.0"
    }

    begin
      File.write(metadata_file, JSON.pretty_generate(metadata_data))
      Print.debug "Saved collections metadata to disk"
    rescue => e
      Print.err "Failed to save collections metadata: #{e.message}"
    end
  end

  def load_documents_from_disk
    return unless @persist_embeddings

    @collections.each_key do |collection_name|
      docs_file = documents_path(collection_name)
      next unless File.exist?(docs_file)

      begin
        docs_data = JSON.parse(File.read(docs_file))
        @document_store[collection_name] = docs_data['documents'] || []
        Print.debug "Loaded #{@document_store[collection_name].length} documents for collection #{collection_name}"
      rescue => e
        Print.err "Failed to load documents for collection #{collection_name}: #{e.message}"
      end
    end
  end

  def save_documents_to_disk
    return unless @persist_embeddings

    @document_store.each_key do |collection_name|
      docs_file = documents_path(collection_name)
      docs_data = {
        collection: collection_name,
        documents: @document_store[collection_name],
        saved_at: Time.now.iso8601,
        document_count: @document_store[collection_name].length
      }

      begin
        FileUtils.mkdir_p(File.dirname(docs_file)) unless File.exist?(File.dirname(docs_file))
        File.write(docs_file, JSON.pretty_generate(docs_data))
        Print.debug "Saved documents for collection #{collection_name}"
      rescue => e
        Print.err "Failed to save documents for collection #{collection_name}: #{e.message}"
      end
    end
  end

  def load_embeddings_from_disk
    return unless @persist_embeddings

    @collections.each_key do |collection_name|
      embeddings_file = embeddings_path(collection_name)
      next unless File.exist?(embeddings_file)

      begin
        # Read binary data
        binary_data = File.binread(embeddings_file)

        # Deserialize data
        require 'stringio'
        require 'marshal'

        io = StringIO.new(binary_data)
        @embedding_store[collection_name] = Marshal.load(io)

        Print.debug "Loaded #{@embedding_store[collection_name].length} embeddings for collection #{collection_name}"
      rescue => e
        Print.err "Failed to load embeddings for collection #{collection_name}: #{e.message}"
      end
    end
  end

  def save_embeddings_to_disk
    return unless @persist_embeddings

    @embedding_store.each_key do |collection_name|
      embeddings_file = embeddings_path(collection_name)

      begin
        FileUtils.mkdir_p(File.dirname(embeddings_file)) unless File.exist?(File.dirname(embeddings_file))

        # Serialize using Marshal for binary efficiency
        require 'stringio'
        require 'marshal'

        io = StringIO.new
        Marshal.dump(@embedding_store[collection_name], io)
        binary_data = io.string

        File.binwrite(embeddings_file, binary_data)
        Print.debug "Saved embeddings for collection #{collection_name}"
      rescue => e
        Print.err "Failed to save embeddings for collection #{collection_name}: #{e.message}"
      end
    end
  end

  def load_metadata_from_disk
    return unless @persist_embeddings

    @collections.each_key do |collection_name|
      metadata_file = metadata_path(collection_name)
      next unless File.exist?(metadata_file)

      begin
        metadata_data = JSON.parse(File.read(metadata_file))
        @metadata_store[collection_name] = metadata_data['metadata'] || {}
        Print.debug "Loaded metadata for collection #{collection_name}"
      rescue => e
        Print.err "Failed to load metadata for collection #{collection_name}: #{e.message}"
      end
    end
  end

  def save_metadata_to_disk
    return unless @persist_embeddings

    @metadata_store.each_key do |collection_name|
      metadata_file = metadata_path(collection_name)
      metadata_data = {
        collection: collection_name,
        metadata: @metadata_store[collection_name],
        saved_at: Time.now.iso8601
      }

      begin
        FileUtils.mkdir_p(File.dirname(metadata_file)) unless File.exist?(File.dirname(metadata_file))
        File.write(metadata_file, JSON.pretty_generate(metadata_data))
        Print.debug "Saved metadata for collection #{collection_name}"
      rescue => e
        Print.err "Failed to save metadata for collection #{collection_name}: #{e.message}"
      end
    end
  end

  def load_indexes_from_disk
    return unless @persist_embeddings

    @collections.each_key do |collection_name|
      indexes_file = indexes_path(collection_name)
      next unless File.exist?(indexes_file)

      begin
        indexes_data = JSON.parse(File.read(indexes_file))
        @indexes[collection_name] = indexes_data['indexes'] || {}
        Print.debug "Loaded indexes for collection #{collection_name}"
      rescue => e
        Print.err "Failed to load indexes for collection #{collection_name}: #{e.message}"
      end
    end
  end

  def save_indexes_to_disk
    return unless @persist_embeddings

    @indexes.each_key do |collection_name|
      indexes_file = indexes_path(collection_name)
      indexes_data = {
        collection: collection_name,
        indexes: @indexes[collection_name],
        saved_at: Time.now.iso8601
      }

      begin
        FileUtils.mkdir_p(File.dirname(indexes_file)) unless File.exist?(File.dirname(indexes_file))
        File.write(indexes_file, JSON.pretty_generate(indexes_data))
        Print.debug "Saved indexes for collection #{collection_name}"
      rescue => e
        Print.err "Failed to save indexes for collection #{collection_name}: #{e.message}"
      end
    end
  end

  def add_batch_to_collection(collection_name, batch_documents, batch_embeddings)
    batch_documents.each_with_index do |doc, index|
      doc_index = @document_store[collection_name].length + index
      doc_id = doc[:id] || doc['id']

      # Create document data
      document_data = {
        id: doc_id,
        content: doc[:content] || doc['content'],
        metadata: doc[:metadata] || doc['metadata'] || {},
        created_at: doc[:created_at] || Time.now,
        updated_at: Time.now
      }

      # Add to stores
      @document_store[collection_name] << document_data
      @embedding_store[collection_name] << batch_embeddings[index]

      # Update indexes
      update_indexes(collection_name, doc_id, document_data, doc_index)
    end
  end

  def update_indexes(collection_name, doc_id, document_data, doc_index)
    return unless @indexes[collection_name]

    # Update ID index
    @indexes[collection_name][:id_index][doc_id] = doc_index

    # Update text index (simple keyword search)
    content = document_data[:content] || ""
    keywords = content.downcase.scan(/\b\w+\b/)

    keywords.each do |keyword|
      @indexes[collection_name][:text_index][keyword] ||= []
      @indexes[collection_name][:text_index][keyword] << doc_index
      @indexes[collection_name][:text_index][keyword].uniq!
    end

    # Update metadata index
    document_data[:metadata].each do |key, value|
      meta_key = "#{key}:#{value.to_s.downcase}"
      @indexes[collection_name][:metadata_index][meta_key] ||= []
      @indexes[collection_name][:metadata_index][meta_key] << doc_index
      @indexes[collection_name][:metadata_index][meta_key].uniq!
    end
  end

  def rebuild_indexes(collection_name)
    return unless @indexes[collection_name]

    Print.info "Rebuilding indexes for collection: #{collection_name}"

    @indexes[collection_name] = {
      text_index: {},
      metadata_index: {},
      id_index: {}
    }

    @document_store[collection_name].each_with_index do |doc, index|
      doc_id = doc[:id] || doc['id']
      update_indexes(collection_name, doc_id, doc, index)
    end

    Print.info "Indexes rebuilt for collection: #{collection_name}"
  end

  def generate_test_embedding(document)
    # Generate deterministic test embedding based on document content
    content = document[:content] || document['content'] || ""

    # Simple hash-based embedding generation for testing
    hash = content.hash.to_s
    embedding = []

    # Generate 1536-dimensional embedding (OpenAI standard)
    1536.times do |i|
      # Use hash to generate pseudo-random but deterministic values
      seed = hash + i.to_s
      value = (Math.sin(seed.to_f) * 10000).to_f % 2.0 - 1.0
      embedding << value
    end

    normalize_vector(embedding)
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

  def calculate_collection_size(collection_name)
    return 0 unless @collections.key?(collection_name)

    total_size = 0

    # Calculate size of documents
    docs_file = documents_path(collection_name)
    total_size += File.size(docs_file) if File.exist?(docs_file)

    # Calculate size of embeddings
    embeddings_file = embeddings_path(collection_name)
    total_size += File.size(embeddings_file) if File.exist?(embeddings_file)

    # Calculate size of metadata
    metadata_file = metadata_path(collection_name)
    total_size += File.size(metadata_file) if File.exist?(metadata_file)

    # Calculate size of indexes
    indexes_file = indexes_path(collection_name)
    total_size += File.size(indexes_file) if File.exist?(indexes_file)

    total_size
  end

  def total_document_count
    @document_store.values.sum { |docs| docs.length }
  end
end
