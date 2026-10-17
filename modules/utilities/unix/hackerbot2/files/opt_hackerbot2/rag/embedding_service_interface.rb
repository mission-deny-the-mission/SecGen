require './print.rb'

# Base interface for embedding services
class EmbeddingServiceInterface
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

  def generate_embedding(text)
    raise NotImplementedError, "Subclasses must implement generate_embedding"
  end

  def generate_batch_embeddings(texts)
    raise NotImplementedError, "Subclasses must implement generate_batch_embeddings"
  end

  def test_connection
    raise NotImplementedError, "Subclasses must implement test_connection"
  end

  # Helper methods
  def connected?
    @initialized
  end

  def validate_text(text)
    raise ArgumentError, "Text cannot be nil" if text.nil?
    raise ArgumentError, "Text cannot be empty" if text.strip.empty?
    # Increased limit to accommodate comprehensive knowledge documents
    # Default was 8192, increased to 32768 (32K) for better knowledge base support
    max_length = ENV['RAG_MAX_TEXT_LENGTH']&.to_i || 32768
    raise ArgumentError, "Text is too long (#{text.length} > #{max_length})" if text.length > max_length
  end

  def validate_texts(texts)
    raise ArgumentError, "Texts cannot be nil" if texts.nil?
    raise ArgumentError, "Texts must be an array" unless texts.is_a?(Array)
    raise ArgumentError, "Texts array cannot be empty" if texts.empty?

    texts.each do |text|
      validate_text(text)
    end
  end

  def truncate_text(text, max_length = 8192)
    return text if text.length <= max_length
    text[0, max_length - 3] + "..."
  end

  # Helper method to chunk large text into smaller pieces
  def chunk_text(text, chunk_size = 1000, overlap = 200)
    return [] if text.nil? || text.empty?

    words = text.split
    chunks = []

    i = 0
    while i < words.length
      # Calculate end index with overlap consideration
      end_index = [i + chunk_size, words.length].min

      chunk = words[i...end_index].join(' ')
      chunks << chunk

      # Move to next chunk with overlap
      i = end_index - overlap
      i = 0 if i < 0 # Ensure we make progress if overlap is too large
    end

    chunks
  end
end
