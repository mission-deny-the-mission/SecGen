#!/usr/bin/env ruby

require_relative '../rag_cag_manager.rb'
require_relative '../print.rb'

# Simple test script to verify knowledge base population and retrieval

class KnowledgeBaseTester
  def initialize
    @rag_cag_manager = nil
  end

  def test_existing_knowledge_base
    Print.info "=== Testing Existing Knowledge Base ==="

    begin
      # Create RAG/CAG manager to test existing knowledge
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
          similarity_threshold: 0.7
        }
      }

      cag_config = {}  # Disable CAG for testing

      unified_config = {
        enable_rag: true,
        enable_cag: false,
        knowledge_base_name: 'cybersecurity',
        enable_caching: true,
        auto_initialization: true,
        enable_knowledge_sources: true,
        knowledge_sources_config: [
          {
            type: 'mitre_attack',
            name: 'mitre_attack',
            enabled: true
          }
        ]
      }

      @rag_cag_manager = RAGCAGManager.new(rag_config, cag_config, unified_config)

      unless @rag_cag_manager.setup
        Print.err "Failed to setup RAG/CAG manager for testing"
        return false
      end

      # Test various cybersecurity queries
      test_queries = [
        "What is MITRE ATT&CK?",
        "How does credential dumping work?",
        "What are common privilege escalation techniques?",
        "Explain lateral movement in cyber attacks",
        "What is the purpose of nmap?",
        "How do I secure a Linux system?",
        "What are common web application vulnerabilities?",
        "Explain the concept of defense in depth"
      ]

      Print.info "Testing #{test_queries.length} cybersecurity queries..."

      test_queries.each_with_index do |query, index|
        Print.info "\n#{index + 1}. Query: #{query}"

        begin
          context = @rag_cag_manager.get_enhanced_context(query, {})

          if context && !context.empty?
            Print.info "✅ Success - Retrieved #{context.length} characters"
            # Show a preview
            preview = context.length > 300 ? context[0..300] + "..." : context
            Print.info "   Preview: #{preview.gsub("\n", " ")}"
          else
            Print.warn "⚠️  No context retrieved - knowledge base may be empty"
          end
        rescue => e
          Print.err "❌ Error retrieving context: #{e.message}"
        end
      end

      # Check collections
      if @rag_cag_manager.rag_manager
        collections = @rag_cag_manager.rag_manager.list_collections
        Print.info "\nAvailable collections: #{collections.join(', ')}"
      end

      true

    rescue => e
      Print.err "Error during testing: #{e.message}"
      Print.err e.backtrace.first(3).join("\n")
      false
    end
  end

  def check_man_pages_availability
    Print.info "\n=== Checking Man Pages Availability ==="

    man_pages_to_check = %w[nmap iptables ssh openssl sudo ps netstat curl]

    man_pages_to_check.each do |man_page|
      begin
        # Try to get man page content
        result = `man #{man_page} 2>/dev/null | head -20`
        if $? == 0 && !result.empty?
          Print.info "✅ #{man_page} - Available"
        else
          Print.warn "⚠️  #{man_page} - Not available"
        end
      rescue => e
        Print.err "❌ Error checking #{man_page}: #{e.message}"
      end
    end
  end
end

# Main execution
if __FILE__ == $0
  Print.info "Testing knowledge base functionality..."

  tester = KnowledgeBaseTester.new

  # Test existing knowledge base
  tester.test_existing_knowledge_base

  # Check man pages availability
  tester.check_man_pages_availability

  Print.info "\nKnowledge base testing completed."
end
