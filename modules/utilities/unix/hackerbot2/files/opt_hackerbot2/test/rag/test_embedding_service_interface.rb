require_relative '../test_helper'
require_relative '../rag/embedding_service_interface'

# Mock embedding service for testing
class MockEmbeddingService < EmbeddingServiceInterface
  def connect
    @initialized = true
    true
  end

  def disconnect
    @initialized = false
    true
  end

  def generate_embedding(text)
    return nil if text.nil? || text.empty?
    # Generate mock embedding based on text hash
    hash = text.hash.abs
    Array.new(1536) { (hash * (i + 1)) % 1000 / 1000.0 }
  end

  def generate_batch_embeddings(texts)
    return nil if texts.nil? || texts.empty?
    texts.map { |text| generate_embedding(text) }
  end

  def test_connection
    @initialized
  end
end

# Test suite for Embedding Service Interface
class TestEmbeddingServiceInterface < Minitest::Test
  def setup
    @config = {
      provider: 'mock',
      api_key: 'test_key',
      model: 'test_model'
    }
    @service = MockEmbeddingService.new(@config)
  end

  def teardown
    @service.disconnect if @service
  end

  def test_initialization
    assert_instance_of MockEmbeddingService, @service
    refute @service.connected?, "Service should not be connected initially"
    assert_equal @config, @service.instance_variable_get(:@config)
  end

  def test_connect_success
    result = @service.connect
    assert result, "Connection should succeed"
    assert @service.connected?, "Service should be connected after connect"
  end

  def test_disconnect_success
    @service.connect

    result = @service.disconnect
    assert result, "Disconnection should succeed"
    refute @service.connected?, "Service should not be connected after disconnect"
  end

  def test_generate_embedding_success
    @service.connect

    text = "This is a test text for embedding generation."
    embedding = @service.generate_embedding(text)

    refute_nil embedding, "Should generate embedding"
    assert_instance_of Array, embedding
    refute_empty embedding, "Embedding should not be empty"
    assert_equal 1536, embedding.length, "Embedding should have correct dimension"

    # All values should be numeric
    embedding.each do |value|
      assert_kind_of Numeric, value, "Embedding values should be numeric"
    end
  end

  def test_generate_embedding_empty_text
    @service.connect

    embedding = @service.generate_embedding("")
    assert_nil embedding, "Should return nil for empty text"
  end

  def test_generate_embedding_nil_text
    @service.connect

    embedding = @service.generate_embedding(nil)
    assert_nil embedding, "Should return nil for nil text"
  end

  def test_generate_embedding_consistency
    @service.connect

    text = "Consistent test text"
    embedding1 = @service.generate_embedding(text)
    embedding2 = @service.generate_embedding(text)

    assert_equal embedding1, embedding2, "Same text should generate same embedding"
  end

  def test_generate_embedding_different_texts
    @service.connect

    text1 = "First test text"
    text2 = "Second test text"
    embedding1 = @service.generate_embedding(text1)
    embedding2 = @service.generate_embedding(text2)

    refute_equal embedding1, embedding2, "Different texts should generate different embeddings"
  end

  def test_generate_batch_embeddings_success
    @service.connect

    texts = [
      "First text for batch processing",
      "Second text for batch processing",
      "Third text for batch processing"
    ]

    embeddings = @service.generate_batch_embeddings(texts)

    refute_nil embeddings, "Should generate batch embeddings"
    assert_instance_of Array, embeddings
    assert_equal texts.length, embeddings.length, "Should generate one embedding per text"

    embeddings.each do |embedding|
      assert_instance_of Array, embedding
      refute_empty embedding
      assert_equal 1536, embedding.length
    end
  end

  def test_generate_batch_embeddings_empty_array
    @service.connect

    embeddings = @service.generate_batch_embeddings([])
    assert_nil embeddings, "Should return nil for empty array"
  end

  def test_generate_batch_embeddings_nil_input
    @service.connect

    embeddings = @service.generate_batch_embeddings(nil)
    assert_nil embeddings, "Should return nil for nil input"
  end

  def test_generate_batch_embeddings_with_empty_strings
    @service.connect

    texts = ["Valid text", "", "Another valid text"]
    embeddings = @service.generate_batch_embeddings(texts)

    # Should handle empty strings gracefully
    refute_nil embeddings
    assert_equal texts.length, embeddings.length

    # Empty string should generate nil embedding
    assert_nil embeddings[1]
    refute_nil embeddings[0]
    refute_nil embeddings[2]
  end

  def test_test_connection_connected
    @service.connect

    result = @service.test_connection
    assert result, "Connection test should succeed when connected"
  end

  def test_test_connection_disconnected
    result = @service.test_connection
    refute result, "Connection test should fail when disconnected"
  end

  def test_large_text_handling
    @service.connect

    # Create a large text (100KB)
    large_text = "Large text content. " * 5000
    embedding = @service.generate_embedding(large_text)

    refute_nil embedding, "Should handle large texts"
    assert_equal 1536, embedding.length
  end

  def test_special_characters_handling
    @service.connect

    special_texts = [
      "Text with special chars: áéíóú ñ ¿ ¡",
      "Text with emojis: 🚀 🔒 🛡️",
      "Text with symbols: @#$%^&*()_+-=[]{}|;':\",./<>?",
      "Text with newlines:\nLine 1\nLine 2\nLine 3",
      "Text with tabs:\tTabbed\tcontent"
    ]

    special_texts.each do |text|
      embedding = @service.generate_embedding(text)
      refute_nil embedding, "Should handle special characters in: #{text}"
      assert_equal 1536, embedding.length
    end
  end

  def test_concurrent_embedding_generation
    @service.connect

    texts = 10.times.map { |i| "Concurrent test text #{i}" }
    threads = []
    results = []

    texts.each do |text|
      threads << Thread.new do
        embedding = @service.generate_embedding(text)
        results << embedding
      end
    end

    threads.each(&:join)

    assert_equal texts.length, results.length
    results.each { |result| refute_nil result }
  end

  def test_concurrent_batch_embedding_generation
    @service.connect

    text_batches = [
      ["Batch 1 text 1", "Batch 1 text 2"],
      ["Batch 2 text 1", "Batch 2 text 2"],
      ["Batch 3 text 1", "Batch 3 text 2"]
    ]

    threads = []
    results = []

    text_batches.each do |batch|
      threads << Thread.new do
        embeddings = @service.generate_batch_embeddings(batch)
        results << embeddings
      end
    end

    threads.each(&:join)

    assert_equal text_batches.length, results.length
    results.each { |result| refute_nil result }
  end

  def test_embedding_dimension_consistency
    @service.connect

    texts = [
      "Short text",
      "Medium length text with more content",
      "Very long text with lots of content to test dimension consistency across different text lengths"
    ]

    embeddings = texts.map { |text| @service.generate_embedding(text) }

    embeddings.each do |embedding|
      assert_equal 1536, embedding.length, "All embeddings should have consistent dimension"
    end
  end

  def test_embedding_value_ranges
    @service.connect

    text = "Test text for value range validation"
    embedding = @service.generate_embedding(text)

    embedding.each do |value|
      assert value >= 0.0 && value <= 1.0, "Embedding values should be in range [0.0, 1.0]"
    end
  end

  def test_memory_usage_large_batch
    @service.connect

    # Generate a large batch to test memory handling
    texts = 1000.times.map { |i| "Large batch test text #{i}" }

    # This should not cause memory issues
    embeddings = @service.generate_batch_embeddings(texts)

    refute_nil embeddings
    assert_equal texts.length, embeddings.length

    # Verify all embeddings are valid
    embeddings.each do |embedding|
      assert_instance_of Array, embedding
      assert_equal 1536, embedding.length
    end
  end

  def test_error_handling_edge_cases
    @service.connect

    # Test with very long text that might cause issues
    very_long_text = "x" * 1_000_000  # 1MB text
    embedding = @service.generate_embedding(very_long_text)
    refute_nil embedding, "Should handle very long texts"

    # Test with Unicode text
    unicode_text = "Unicode test: 你好 こんにちは 안녕하세요 مرحبا"
    embedding = @service.generate_embedding(unicode_text)
    refute_nil embedding, "Should handle Unicode text"

    # Test with text containing only whitespace
    whitespace_text = "   \n\t  \r\n  "
    embedding = @service.generate_embedding(whitespace_text)
    refute_nil embedding, "Should handle whitespace-only text"
  end

  def test_embedding_service_interface_abstract_methods
    # Test that abstract methods raise NotImplementedError
    abstract_service = EmbeddingServiceInterface.new({})

    assert_raises NotImplementedError do
      abstract_service.connect
    end

    assert_raises NotImplementedError do
      abstract_service.disconnect
    end

    assert_raises NotImplementedError do
      abstract_service.generate_embedding("test")
    end

    assert_raises NotImplementedError do
      abstract_service.generate_batch_embeddings(["test"])
    end

    assert_raises NotImplementedError do
      abstract_service.test_connection
    end
  end

  def test_connected_helper_method
    refute @service.connected?, "Should not be connected initially"

    @service.connect
    assert @service.connected?, "Should be connected after connect"

    @service.disconnect
    refute @service.connected?, "Should not be connected after disconnect"
  end
end
