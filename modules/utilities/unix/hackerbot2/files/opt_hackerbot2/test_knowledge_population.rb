#!/usr/bin/env ruby

require_relative './rag_cag_manager.rb'
require_relative './print.rb'

# Simple test to verify knowledge base population works correctly
class KnowledgePopulationTest
  def initialize
    @rag_cag_manager = nil
  end

  def test_population
    Print.info "=== Testing Knowledge Base Population ==="

    # Create the same configuration as the bot uses
    knowledge_sources_config = [
      {
        type: 'mitre_attack',
        name: 'mitre_attack',
        enabled: true,
        description: 'MITRE ATT&CK framework knowledge base',
        priority: 1
      },
      {
        type: 'man_pages',
        name: 'cybersecurity_man_pages',
        enabled: true,
        description: 'Common cybersecurity and security tool man pages',
        priority: 2,
        man_pages: [
          { name: 'nmap', section: 1, collection_name: 'cybersecurity' },
          { name: 'ssh', section: 1, collection_name: 'cybersecurity' },
          { name: 'sudo', section: 8, collection_name: 'cybersecurity' }
        ]
      }
    ]

    # RAG configuration
    rag_config = {
      vector_db: { provider: 'chromadb' },
      embedding_service: {
        provider: 'ollama',
        host: 'localhost',
        port: 11434,
        model: 'nomic-embed-text'
      },
      rag_settings: {
        max_results: 5,
        similarity_threshold: 0.3  # Lower threshold for better retrieval
      }
    }

    # CAG configuration (disabled)
    cag_config = {
      knowledge_graph: { provider: 'none' },
      entity_extractor: { provider: 'none' },
      cag_settings: { max_depth: 0, max_nodes: 0 }
    }

    # Unified configuration
    unified_config = {
      enable_rag: true,
      enable_cag: false,
      knowledge_base_name: 'cybersecurity',
      max_context_length: 16000,  # Increased for better knowledge retrieval
      enable_caching: true,
      auto_initialization: true,
      enable_knowledge_sources: true,
      knowledge_sources_config: knowledge_sources_config
    }

    begin
      Print.info "Creating RAG/CAG manager..."
      @rag_cag_manager = RAGCAGManager.new(rag_config, cag_config, unified_config)

      unless @rag_cag_manager.setup
        Print.err "Failed to setup RAG/CAG manager"
        return false
      end

      Print.info "✅ RAG/CAG manager setup successful"

      # Test knowledge retrieval
      test_knowledge_retrieval

      true

    rescue => e
      Print.err "Error during test: #{e.message}"
      Print.err e.backtrace.first(5).join("\n")
      false
    end
  end

  def test_knowledge_retrieval
    return false unless @rag_cag_manager

    Print.info "\n=== Testing Knowledge Retrieval ==="

    test_queries = [
      "What is nmap?",
      "How does SSH work?",
      "What is privilege escalation?"
    ]

    test_queries.each_with_index do |query, index|
      Print.info "\n#{index + 1}. Testing query: #{query}"

      begin
        context = @rag_cag_manager.get_enhanced_context(query, {})

        if context && !context.empty?
          Print.info "✅ Retrieved #{context.length} characters"

          # Check if it contains actual content vs just template
          if context.include?("RETRIEVED DOCUMENTS")
            Print.info "✅ Contains retrieved documents"

            # Extract and show a preview
            if context.match(/Document \d+.*?Score: ([\d.]+)/)
              score = $1
              Print.info "   Top document score: #{score}"
            end
          else
            Print.warn "⚠️  No retrieved documents found"
          end
        else
          Print.warn "⚠️  No context retrieved"
        end
      rescue => e
        Print.err "❌ Error retrieving context: #{e.message}"
      end
    end

    # Check collection status
    if @rag_cag_manager.rag_manager
      collections = @rag_cag_manager.rag_manager.list_collections
      Print.info "\nAvailable collections: #{collections.empty? ? 'None' : collections.join(', ')}"

      if collections.include?('cybersecurity')
        # Try to get collection stats
        begin
          stats = @rag_cag_manager.rag_manager.get_collection_stats('cybersecurity')
          if stats
            Print.info "Cybersecurity collection: #{stats[:document_count]} documents"
          end
        rescue => e
          Print.warn "Could not get collection stats: #{e.message}"
        end
      end
    end
  end
end

# Run the test
if __FILE__ == $0
  test = KnowledgePopulationTest.new
  success = test.test_population

  if success
    Print.info "\n🎉 Knowledge population test completed successfully!"
  else
    Print.err "\n❌ Knowledge population test failed!"
  end
end
