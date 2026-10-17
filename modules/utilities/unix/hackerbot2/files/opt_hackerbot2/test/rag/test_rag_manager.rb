require_relative '../test_helper'
require_relative '../rag/rag_manager'
require_relative '../rag/chromadb_client'
require_relative '../rag/ollama_embedding_client'
require_relative '../rag/openai_embedding_client'

# Test suite for RAG Manager
class TestRAGManager < Minitest::Test
  def setup
    @vector_db_config = {
      provider: 'chromadb',
      host: 'localhost',
      port: 8000
    }

    @embedding_config = {
      provider: 'openai',
      api_key: 'test_api_key',
      model: 'text-embedding-ada-002'
    }

    @rag_config = {
      max_results: 5,
      similarity_threshold: 0.7,
      chunk_size: 1000,
      chunk_overlap: 200,
      enable_caching: true
    }

    @manager = RAGManager.new(@vector_db_config, @embedding_config, @rag_config)
  end

  def teardown
    @manager.cleanup if @manager
  end

  def test_initialization
    assert_instance_of RAGManager, @manager
    refute @manager.initialized?, "Manager should not be initialized initially"
  end

  def test_setup_success
    result = @manager.setup
    assert result, "Setup should succeed"
    assert @manager.initialized?, "Manager should be initialized after setup"
  end

  def test_setup_with_invalid_config
    invalid_config = @vector_db_config.merge(provider: 'invalid_provider')

    assert_raises ArgumentError do
      RAGManager.new(invalid_config, @embedding_config, @rag_config)
    end
  end

  def test_create_collection_success
    @manager.setup

    result = @manager.create_collection('test_collection')
    assert result, "Collection creation should succeed"
  end

  def test_create_collection_invalid_name
    @manager.setup

    assert_raises ArgumentError do
      @manager.create_collection('')
    end

    assert_raises ArgumentError do
      @manager.create_collection('invalid@name')
    end
  end

  def test_create_collection_without_setup
    # Should auto-initialize
    result = @manager.create_collection('test_collection')
    assert result, "Collection creation should auto-initialize"
  end

  def test_add_knowledge_base_success
    @manager.setup
    @manager.create_collection('test_collection')

    documents = [
      {
        id: 'doc1',
        content: 'This is a test document about cybersecurity.',
        metadata: { source: 'test', type: 'general' }
      },
      {
        id: 'doc2',
        content: 'Another document about network security.',
        metadata: { source: 'test', type: 'network' }
      }
    ]

    embeddings = [
      [0.1, 0.2, 0.3, 0.4, 0.5],
      [0.6, 0.7, 0.8, 0.9, 1.0]
    ]

    result = @manager.add_knowledge_base('test_collection', documents, embeddings)
    assert result, "Knowledge base addition should succeed"
  end

  def test_add_knowledge_base_without_embeddings
    @manager.setup
    @manager.create_collection('test_collection')

    documents = [
      {
        id: 'doc1',
        content: 'This is a test document.',
        metadata: { source: 'test' }
      }
    ]

    # Should generate embeddings automatically
    result = @manager.add_knowledge_base('test_collection', documents)
    assert result, "Knowledge base addition should succeed with auto-generated embeddings"
  end

  def test_add_knowledge_base_invalid_documents
    @manager.setup
    @manager.create_collection('test_collection')

    assert_raises ArgumentError do
      @manager.add_knowledge_base('test_collection', nil)
    end

    assert_raises ArgumentError do
      @manager.add_knowledge_base('test_collection', [])
    end

    assert_raises ArgumentError do
      @manager.add_knowledge_base('test_collection', [{}])
    end
  end

  def test_retrieve_relevant_context_success
    @manager.setup
    @manager.create_collection('test_collection')

    documents = [
      {
        id: 'doc1',
        content: 'This is about cybersecurity and network attacks.',
        metadata: { source: 'test' }
      }
    ]

    embeddings = [[0.1, 0.2, 0.3, 0.4, 0.5]]
    @manager.add_knowledge_base('test_collection', documents, embeddings)

    context = @manager.retrieve_relevant_context('cybersecurity', 'test_collection')
    refute_nil context, "Should retrieve context"
    refute_empty context, "Context should not be empty"
  end

  def test_retrieve_relevant_context_with_caching
    @manager.setup
    @manager.create_collection('test_collection')

    documents = [
      {
        id: 'doc1',
        content: 'This is about cybersecurity.',
        metadata: { source: 'test' }
      }
    ]

    embeddings = [[0.1, 0.2, 0.3, 0.4, 0.5]]
    @manager.add_knowledge_base('test_collection', documents, embeddings)

    # First call - should cache
    context1 = @manager.retrieve_relevant_context('cybersecurity', 'test_collection')

    # Second call - should use cache
    context2 = @manager.retrieve_relevant_context('cybersecurity', 'test_collection')

    assert_equal context1, context2, "Cached context should match"
  end

  def test_retrieve_relevant_context_no_results
    @manager.setup
    @manager.create_collection('empty_collection')

    context = @manager.retrieve_relevant_context('nonexistent', 'empty_collection')
    assert_empty context, "Should return empty context for no results"
  end

  def test_retrieve_relevant_context_without_setup
    # Should auto-initialize
    @manager.create_collection('test_collection')

    documents = [
      {
        id: 'doc1',
        content: 'Test content.',
        metadata: { source: 'test' }
      }
    ]

    @manager.add_knowledge_base('test_collection', documents)
    context = @manager.retrieve_relevant_context('test', 'test_collection')

    refute_nil context, "Should auto-initialize and retrieve context"
  end

  def test_delete_collection_success
    @manager.setup
    @manager.create_collection('test_collection')

    result = @manager.delete_collection('test_collection')
    assert result, "Collection deletion should succeed"
  end

  def test_delete_collection_with_cache
    @manager.setup
    @manager.create_collection('test_collection')

    documents = [
      {
        id: 'doc1',
        content: 'Test content.',
        metadata: { source: 'test' }
      }
    ]

    @manager.add_knowledge_base('test_collection', documents)
    @manager.retrieve_relevant_context('test', 'test_collection') # Cache it

    result = @manager.delete_collection('test_collection')
    assert result, "Collection deletion should succeed and clear cache"
  end

  def test_delete_nonexistent_collection
    @manager.setup

    result = @manager.delete_collection('nonexistent_collection')
    assert result, "Deleting nonexistent collection should succeed"
  end

  def test_list_collections
    @manager.setup

    # Initially empty
    collections = @manager.list_collections
    assert_instance_of Array, collections
    assert_empty collections, "Should return empty array initially"

    # Add a collection
    @manager.create_collection('test_collection')

    collections = @manager.list_collections
    refute_empty collections, "Should list created collections"
    assert_equal 1, collections.length
    assert_equal 'test_collection', collections.first[:name]
  end

  def test_connection_test_success
    @manager.setup

    result = @manager.test_connection
    assert result, "Connection test should succeed"
  end

  def test_connection_test_failure
    # Create a manager with invalid config
    invalid_embedding_config = @embedding_config.merge(provider: 'invalid_provider')

    assert_raises ArgumentError do
      RAGManager.new(@vector_db_config, invalid_embedding_config, @rag_config)
    end
  end

  def test_cleanup
    @manager.setup
    @manager.create_collection('test_collection')

    assert @manager.initialized?, "Should be initialized before cleanup"

    @manager.cleanup

    refute @manager.initialized?, "Should not be initialized after cleanup"
  end

  def test_similarity_threshold_filtering
    @manager.setup
    @manager.create_collection('test_collection')

    documents = [
      {
        id: 'doc1',
        content: 'High similarity document',
        metadata: { source: 'test' }
      },
      {
        id: 'doc2',
        content: 'Low similarity document',
        metadata: { source: 'test' }
      }
    ]

    # Create embeddings with different similarity scores
    embeddings = [
      [0.9, 0.8, 0.7, 0.6, 0.5],  # High similarity
      [0.1, 0.2, 0.3, 0.4, 0.5]   # Low similarity
    ]

    @manager.add_knowledge_base('test_collection', documents, embeddings)

    # Query with high threshold
    context = @manager.retrieve_relevant_context('test', 'test_collection')
    refute_empty context, "Should return some results"
  end

  def test_max_results_limiting
    @manager.setup
    @manager.create_collection('test_collection')

    documents = []
    embeddings = []

    # Create many documents
    10.times do |i|
      documents << {
        id: "doc#{i}",
        content: "Document #{i} content",
        metadata: { source: 'test' }
      }
      embeddings << [rand, rand, rand, rand, rand]
    end

    @manager.add_knowledge_base('test_collection', documents, embeddings)

    context = @manager.retrieve_relevant_context('test', 'test_collection')

    # Should limit results to max_results (5 by default)
    assert context.include?('Document'), "Should contain document references"
  end

  def test_error_handling_in_retrieval
    @manager.setup
    @manager.create_collection('test_collection')

    # Test with empty query
    context = @manager.retrieve_relevant_context('', 'test_collection')
    refute_nil context, "Should handle empty query gracefully"
  end

  def test_concurrent_operations
    @manager.setup
    @manager.create_collection('test_collection')

    documents = [
      {
        id: 'doc1',
        content: 'Concurrent test document',
        metadata: { source: 'test' }
      }
    ]

    embeddings = [[0.1, 0.2, 0.3, 0.4, 0.5]]
    @manager.add_knowledge_base('test_collection', documents, embeddings)

    # Simulate concurrent retrievals
    threads = []
    results = []

    3.times do |i|
      threads << Thread.new do
        context = @manager.retrieve_relevant_context('concurrent', 'test_collection')
        results << context
      end
    end

    threads.each(&:join)

    assert_equal 3, results.length
    results.each { |result| refute_nil result }
  end
end
