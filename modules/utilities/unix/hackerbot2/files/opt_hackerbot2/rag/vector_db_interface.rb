require './print.rb'

# Base interface for vector database clients
class VectorDBInterface
  def initialize(config)
    @config = config
    @initialized = false
  end

  # Abstract methods that must be implemented by subclasses
  def connect
    raise NotImplementedError, "Subclasses must implement connect"
  end

  def disconnect
    raise NotImplementedError, "Subclasses must implement disconnect"
  end

  def create_collection(collection_name)
    raise NotImplementedError, "Subclasses must implement create_collection"
  end

  def add_documents(collection_name, documents, embeddings = nil)
    raise NotImplementedError, "Subclasses must implement add_documents"
  end

  def search(collection_name, query_embedding, limit = 5)
    raise NotImplementedError, "Subclasses must implement search"
  end

  def delete_collection(collection_name)
    raise NotImplementedError, "Subclasses must implement delete_collection"
  end

  def test_connection
    raise NotImplementedError, "Subclasses must implement test_connection"
  end

  # Helper methods
  def connected?
    @initialized
  end

  def validate_collection_name(collection_name)
    raise ArgumentError, "Collection name cannot be empty" if collection_name.nil? || collection_name.strip.empty?
    raise ArgumentError, "Collection name contains invalid characters" unless collection_name.match?(/^[a-zA-Z0-9_-]+$/)
  end

  def validate_documents(documents)
    raise ArgumentError, "Documents cannot be nil" if documents.nil?
    raise ArgumentError, "Documents must be an array" unless documents.is_a?(Array)
    raise ArgumentError, "Documents array cannot be empty" if documents.empty?

    documents.each do |doc|
      raise ArgumentError, "Each document must have an 'id' field" unless doc.key?('id') || doc.key?(:id)
      raise ArgumentError, "Each document must have a 'content' field" unless doc.key?('content') || doc.key?(:content)
    end
  end
end
