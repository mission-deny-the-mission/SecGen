require_relative '../test_helper'
require_relative '../rag/chromadb_client'

# Test suite for ChromaDB Client
class TestChromaDBClient < Minitest::Test
  def setup
    @config = {
      host: 'localhost',
      port: 8000
    }
    @client = ChromaDBClient.new(@config)
  end

  def teardown
    @client.disconnect if @client
  end

  def test_initialization
    assert_instance_of ChromaDBClient, @client
    refute @client.connected?, "Client should not be connected initially"
    assert_equal 'localhost', @client.instance_variable_get(:@host)
    assert_equal 8000, @client.instance_variable_get(:@port)
  end

  def test_connect_success
    result = @client.connect
    assert result, "Connection should succeed"
    assert @client.connected?, "Client should be connected after connect"
  end

  def test_disconnect_success
    @client.connect

    result = @client.disconnect
    assert result, "Disconnection should succeed"
    refute @client.connected?, "Client should not be connected after disconnect"
  end

  def test_create_collection_success
    @client.connect

    result = @client.create_collection('test_collection')
    assert result, "Collection creation should succeed"

    # Verify collection exists
    collections = @client.list_collections
    assert_equal 1, collections.length
    assert_equal 'test_collection', collections.first[:name]
  end

  def test_create_collection_invalid_name
    @client.connect

    assert_raises ArgumentError do
      @client.create_collection('')
    end

    assert_raises ArgumentError do
      @client.create_collection('invalid@name')
    end

    assert_raises ArgumentError do
      @client.create_collection('name with spaces')
    end
  end

  def test_create_collection_already_exists
    @client.connect
    @client.create_collection('test_collection')

    # Should succeed even if collection already exists
    result = @client.create_collection('test_collection')
    assert result, "Creating existing collection should succeed"
  end

  def test_create_collection_without_connection
    # Should auto-connect
    result = @client.create_collection('test_collection')
    assert result, "Collection creation should auto-connect"
    assert @client.connected?, "Should be connected after auto-connect"
  end

  def test_add_documents_success
    @client.connect
    @client.create_collection('test_collection')

    documents = [
      {
        id: 'doc1',
        content: 'This is a test document.',
        metadata: { source: 'test', type: 'general' }
      },
      {
        id: 'doc2',
        content: 'Another test document.',
        metadata: { source: 'test', type: 'specific' }
      }
    ]

    embeddings = [
      [0.1, 0.2, 0.3, 0.4, 0.5],
      [0.6, 0.7, 0.8, 0.9, 1.0]
    ]

    result = @client.add_documents('test_collection', documents, embeddings)
    assert result, "Adding documents should succeed"

    # Verify collection stats
    stats = @client.get_collection_stats('test_collection')
    assert_equal 2, stats[:document_count]
  end

  def test_add_documents_without_embeddings
    @client.connect
    @client.create_collection('test_collection')

    documents = [
      {
        id: 'doc1',
        content: 'Test document without embeddings.',
        metadata: { source: 'test' }
      }
    ]

    # Should generate random embeddings
    result = @client.add_documents('test_collection', documents)
    assert result, "Adding documents without embeddings should succeed"
  end

  def test_add_documents_invalid_documents
    @client.connect
    @client.create_collection('test_collection')

    assert_raises ArgumentError do
      @client.add_documents('test_collection', nil)
    end

    assert_raises ArgumentError do
      @client.add_documents('test_collection', [])
    end

    assert_raises ArgumentError do
      @client.add_documents('test_collection', [{}])
    end

    assert_raises ArgumentError do
      @client.add_documents('test_collection', [{ content: 'Missing id' }])
    end

    assert_raises ArgumentError do
      @client.add_documents('test_collection', [{ id: 'missing_content' }])
    end
  end

  def test_add_documents_embedding_mismatch
    @client.connect
    @client.create_collection('test_collection')

    documents = [
      { id: 'doc1', content: 'Test document' },
      { id: 'doc2', content: 'Another document' }
    ]

    embeddings = [[0.1, 0.2, 0.3]]  # Only one embedding for two documents

    result = @client.add_documents('test_collection', documents, embeddings)
    refute result, "Should fail with embedding count mismatch"
  end

  def test_add_documents_to_nonexistent_collection
    @client.connect

    documents = [{ id: 'doc1', content: 'Test document' }]
    embeddings = [[0.1, 0.2, 0.3]]

    result = @client.add_documents('nonexistent_collection', documents, embeddings)
    refute result, "Should fail for nonexistent collection"
  end

  def test_add_documents_update_existing
    @client.connect
    @client.create_collection('test_collection')

    documents = [
      { id: 'doc1', content: 'Original content', metadata: { version: 1 } }
    ]
    embeddings = [[0.1, 0.2, 0.3]]

    @client.add_documents('test_collection', documents, embeddings)

    # Update the same document
    updated_documents = [
      { id: 'doc1', content: 'Updated content', metadata: { version: 2 } }
    ]
    updated_embeddings = [[0.4, 0.5, 0.6]]

    result = @client.add_documents('test_collection', updated_documents, updated_embeddings)
    assert result, "Updating existing document should succeed"

    # Verify only one document exists
    stats = @client.get_collection_stats('test_collection')
    assert_equal 1, stats[:document_count]
  end

  def test_search_success
    @client.connect
    @client.create_collection('test_collection')

    documents = [
      { id: 'doc1', content: 'This is about cybersecurity.' },
      { id: 'doc2', content: 'This is about network security.' },
      { id: 'doc3', content: 'This is about cooking.' }
    ]

    embeddings = [
      [0.9, 0.8, 0.7],  # High similarity to cybersecurity query
      [0.8, 0.7, 0.6],  # Medium similarity
      [0.1, 0.2, 0.3]   # Low similarity
    ]

    @client.add_documents('test_collection', documents, embeddings)

    query_embedding = [0.9, 0.8, 0.7]
    results = @client.search('test_collection', query_embedding, 2)

    refute_nil results, "Search should return results"
    assert_instance_of Array, results
    assert_equal 2, results.length

    # Results should be sorted by similarity (descending)
    assert results.first[:score] >= results.last[:score], "Results should be sorted by similarity"
  end

  def test_search_empty_collection
    @client.connect
    @client.create_collection('empty_collection')

    query_embedding = [0.1, 0.2, 0.3]
    results = @client.search('empty_collection', query_embedding)

    assert_instance_of Array, results
    assert_empty results, "Empty collection should return no results"
  end

  def test_search_nonexistent_collection
    @client.connect

    query_embedding = [0.1, 0.2, 0.3]
    results = @client.search('nonexistent_collection', query_embedding)

    assert_nil results, "Nonexistent collection should return nil"
  end

  def test_search_with_limit
    @client.connect
    @client.create_collection('test_collection')

    documents = []
    embeddings = []

    # Create 10 documents
    10.times do |i|
      documents << { id: "doc#{i}", content: "Document #{i}" }
      embeddings << [rand, rand, rand]
    end

    @client.add_documents('test_collection', documents, embeddings)

    query_embedding = [0.5, 0.5, 0.5]
    results = @client.search('test_collection', query_embedding, 3)

    assert_equal 3, results.length, "Should respect limit parameter"
  end

  def test_delete_collection_success
    @client.connect
    @client.create_collection('test_collection')

    # Add some documents
    documents = [{ id: 'doc1', content: 'Test document' }]
    embeddings = [[0.1, 0.2, 0.3]]
    @client.add_documents('test_collection', documents, embeddings)

    result = @client.delete_collection('test_collection')
    assert result, "Collection deletion should succeed"

    # Verify collection is gone
    collections = @client.list_collections
    assert_empty collections, "Collection should be deleted"
  end

  def test_delete_nonexistent_collection
    @client.connect

    result = @client.delete_collection('nonexistent_collection')
    assert result, "Deleting nonexistent collection should succeed"
  end

  def test_list_collections
    @client.connect

    # Initially empty
    collections = @client.list_collections
    assert_instance_of Array, collections
    assert_empty collections

    # Add collections
    @client.create_collection('collection1')
    @client.create_collection('collection2')

    collections = @client.list_collections
    assert_equal 2, collections.length

    collection_names = collections.map { |c| c[:name] }
    assert_includes collection_names, 'collection1'
    assert_includes collection_names, 'collection2'
  end

  def test_get_collection_stats
    @client.connect
    @client.create_collection('test_collection')

    stats = @client.get_collection_stats('test_collection')
    refute_nil stats
    assert_equal 'test_collection', stats[:name]
    assert_equal 0, stats[:document_count]
    assert_instance_of Time, stats[:created_at]

    # Add documents
    documents = [
      { id: 'doc1', content: 'Test document 1' },
      { id: 'doc2', content: 'Test document 2' }
    ]
    embeddings = [[0.1, 0.2, 0.3], [0.4, 0.5, 0.6]]
    @client.add_documents('test_collection', documents, embeddings)

    stats = @client.get_collection_stats('test_collection')
    assert_equal 2, stats[:document_count]
    assert_instance_of Time, stats[:updated_at]
  end

  def test_get_collection_stats_nonexistent
    @client.connect

    stats = @client.get_collection_stats('nonexistent_collection')
    assert_nil stats, "Nonexistent collection should return nil"
  end

  def test_test_connection_success
    @client.connect

    result = @client.test_connection
    assert result, "Connection test should succeed"
  end

  def test_test_connection_failure
    # Client not connected
    result = @client.test_connection
    refute result, "Connection test should fail when not connected"
  end

  def test_cosine_similarity_calculation
    @client.connect

    # Test identical vectors
    vec1 = [1.0, 0.0, 0.0]
    vec2 = [1.0, 0.0, 0.0]
    similarity = @client.send(:calculate_cosine_similarity, vec1, vec2)
    assert_equal 1.0, similarity

    # Test orthogonal vectors
    vec3 = [1.0, 0.0, 0.0]
    vec4 = [0.0, 1.0, 0.0]
    similarity = @client.send(:calculate_cosine_similarity, vec3, vec4)
    assert_equal 0.0, similarity

    # Test opposite vectors
    vec5 = [1.0, 0.0, 0.0]
    vec6 = [-1.0, 0.0, 0.0]
    similarity = @client.send(:calculate_cosine_similarity, vec5, vec6)
    assert_equal -1.0, similarity

    # Test nil vectors
    similarity = @client.send(:calculate_cosine_similarity, nil, [1.0, 0.0])
    assert_equal 0.0, similarity

    similarity = @client.send(:calculate_cosine_similarity, [1.0, 0.0], nil)
    assert_equal 0.0, similarity
  end

  def test_vector_normalization
    @client.connect

    # Test normal vector
    vec = [3.0, 4.0]
    normalized = @client.send(:normalize_vector, vec)
    expected_magnitude = Math.sqrt(3.0**2 + 4.0**2)
    expected = [3.0/expected_magnitude, 4.0/expected_magnitude]

    assert_in_delta expected[0], normalized[0], 0.0001
    assert_in_delta expected[1], normalized[1], 0.0001

    # Test zero vector
    zero_vec = [0.0, 0.0]
    normalized = @client.send(:normalize_vector, zero_vec)
    assert_equal zero_vec, normalized
  end

  def test_random_embedding_generation
    @client.connect

    embedding = @client.send(:generate_random_embedding, 5)
    assert_instance_of Array, embedding
    assert_equal 5, embedding.length

    # All values should be between -1.0 and 1.0
    embedding.each do |value|
      assert value >= -1.0 && value <= 1.0, "Embedding values should be in range [-1.0, 1.0]"
    end
  end

  def test_concurrent_operations
    @client.connect
    @client.create_collection('test_collection')

    threads = []
    results = []

    # Create multiple threads adding documents
    3.times do |i|
      threads << Thread.new do
        documents = [
          { id: "doc_#{i}_1", content: "Thread #{i} document 1" },
          { id: "doc_#{i}_2", content: "Thread #{i} document 2" }
        ]
        embeddings = [[rand, rand], [rand, rand]]
        result = @client.add_documents('test_collection', documents, embeddings)
        results << result
      end
    end

    threads.each(&:join)

    # All operations should succeed
    assert_equal 3, results.length
    results.each { |result| assert result }

    # Verify all documents were added
    stats = @client.get_collection_stats('test_collection')
    assert_equal 6, stats[:document_count]
  end

  def test_large_document_handling
    @client.connect
    @client.create_collection('test_collection')

    # Create a large document
    large_content = 'Large document content. ' * 1000  # ~20KB
    documents = [{ id: 'large_doc', content: large_content }]
    embeddings = [[0.1, 0.2, 0.3]]

    result = @client.add_documents('test_collection', documents, embeddings)
    assert result, "Should handle large documents"

    # Verify it was stored correctly
    stats = @client.get_collection_stats('test_collection')
    assert_equal 1, stats[:document_count]
  end

  def test_memory_cleanup
    @client.connect

    # Create multiple collections with documents
    5.times do |i|
      @client.create_collection("collection_#{i}")
      documents = [{ id: "doc_#{i}", content: "Document #{i}" }]
      embeddings = [[rand, rand]]
      @client.add_documents("collection_#{i}", documents, embeddings)
    end

    # Verify collections exist
    collections = @client.list_collections
    assert_equal 5, collections.length

    # Disconnect and verify cleanup
    @client.disconnect

    # Reconnect and verify state was cleared
    @client.connect
    collections = @client.list_collections
    assert_empty collections, "Collections should be cleared after disconnect"
  end
end
