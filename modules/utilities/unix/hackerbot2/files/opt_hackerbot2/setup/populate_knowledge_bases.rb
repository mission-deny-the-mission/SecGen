#!/usr/bin/env ruby

require_relative '../rag_cag_manager.rb'
require_relative '../knowledge_bases/knowledge_source_manager.rb'
require_relative '../print.rb'

# Script to populate RAG knowledge bases with common cybersecurity knowledge sources
# Including man pages, markdown files, and MITRE ATT&CK data

class KnowledgeBasePopulator
  def initialize
    @rag_cag_manager = nil
  end

  def populate_with_default_sources
    Print.info "=== Populating RAG Knowledge Bases ==="

    # Create comprehensive knowledge sources configuration
    knowledge_sources_config = [
      # MITRE ATT&CK Framework
      {
        type: 'mitre_attack',
        name: 'mitre_attack',
        enabled: true,
        description: 'MITRE ATT&CK framework knowledge base',
        priority: 1
      },

      # Common cybersecurity man pages
      {
        type: 'man_pages',
        name: 'cybersecurity_man_pages',
        enabled: true,
        description: 'Common cybersecurity and security tool man pages',
        priority: 2,
        man_pages: [
          # Network security tools
          { name: 'nmap', section: 1, collection_name: 'cybersecurity' },
          { name: 'wireshark', section: 1, collection_name: 'cybersecurity' },
          { name: 'tcpdump', section: 1, collection_name: 'cybersecurity' },
          { name: 'netcat', section: 1, collection_name: 'cybersecurity' },
          { name: 'curl', section: 1, collection_name: 'cybersecurity' },
          { name: 'wget', section: 1, collection_name: 'cybersecurity' },

          # System security tools
          { name: 'sudo', section: 8, collection_name: 'cybersecurity' },
          { name: 'iptables', section: 8, collection_name: 'cybersecurity' },
          { name: 'ufw', section: 8, collection_name: 'cybersecurity' },
          { name: 'fail2ban', section: 8, collection_name: 'cybersecurity' },
          { name: 'auditd', section: 8, collection_name: 'cybersecurity' },

          # Penetration testing tools
          { name: 'metasploit', section: 1, collection_name: 'cybersecurity' },
          { name: 'burpsuite', section: 1, collection_name: 'cybersecurity' },
          { name: 'sqlmap', section: 1, collection_name: 'cybersecurity' },
          { name: 'john', section: 1, collection_name: 'cybersecurity' },
          { name: 'hashcat', section: 1, collection_name: 'cybersecurity' },

          # Cryptography tools
          { name: 'openssl', section: 1, collection_name: 'cybersecurity' },
          { name: 'gpg', section: 1, collection_name: 'cybersecurity' },
          { name: 'ssh', section: 1, collection_name: 'cybersecurity' },
          { name: 'ssh-keygen', section: 1, collection_name: 'cybersecurity' },

          # File security and permissions
          { name: 'chmod', section: 1, collection_name: 'cybersecurity' },
          { name: 'chown', section: 1, collection_name: 'cybersecurity' },
          { name: 'setfacl', section: 1, collection_name: 'cybersecurity' },
          { name: 'getfacl', section: 1, collection_name: 'cybersecurity' },

          # Logging and monitoring
          { name: 'journalctl', section: 1, collection_name: 'cybersecurity' },
          { name: 'syslog', section: 3, collection_name: 'cybersecurity' },
          { name: 'logrotate', section: 8, collection_name: 'cybersecurity' },

          # Process and system security
          { name: 'ps', section: 1, collection_name: 'cybersecurity' },
          { name: 'top', section: 1, collection_name: 'cybersecurity' },
          { name: 'lsof', section: 8, collection_name: 'cybersecurity' },
          { name: 'strace', section: 1, collection_name: 'cybersecurity' },
          { name: 'netstat', section: 8, collection_name: 'cybersecurity' },

          # Security file systems and tools
          { name: 'mount', section: 8, collection_name: 'cybersecurity' },
          { name: 'cryptsetup', section: 8, collection_name: 'cybersecurity' },
          { name: 'selinux', section: 8, collection_name: 'cybersecurity' },
          { name: 'apparmor', section: 8, collection_name: 'cybersecurity' }
        ]
      },

      # Project documentation and markdown files
      {
        type: 'markdown_files',
        name: 'project_docs',
        enabled: true,
        description: 'Project documentation and guides',
        priority: 3,
        markdown_files: [
          # Project documentation
          { path: 'README.md', collection_name: 'cybersecurity' },
          { path: 'QUICKSTART.md', collection_name: 'cybersecurity' },
          { path: 'docs/*.md', collection_name: 'cybersecurity' },

          # If there are any other documentation directories
          { path: 'documentation/*.md', collection_name: 'cybersecurity' },
          { path: 'guides/*.md', collection_name: 'cybersecurity' }
        ]
      }
    ]

    # Create RAG/CAG manager with comprehensive sources
    success = create_rag_cag_manager_with_sources(knowledge_sources_config)

    if success
      Print.info "✅ Knowledge bases populated successfully!"
      Print.info "The RAG system now has access to:"
      Print.info "  • MITRE ATT&CK framework"
      Print.info "  • 30+ cybersecurity man pages"
      Print.info "  • Project documentation"
      Print.info ""
      Print.info "You can now use the bot to ask about:"
      Print.info "  • Attack patterns and techniques"
      Print.info "  • Security tool usage"
      Print.info "  • System security configuration"
      Print.info "  • Penetration testing methodologies"
    else
      Print.err "❌ Failed to populate knowledge bases"
    end

    success
  end

  private

  def create_rag_cag_manager_with_sources(knowledge_sources_config)
    begin
      Print.info "Creating RAG/CAG manager with knowledge sources..."

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
          max_results: 7,
          similarity_threshold: 0.7,
          chunk_size: 1000,
          chunk_overlap: 200
        }
      }

      # CAG configuration (disabled to avoid provider issues)
      cag_config = {
        knowledge_graph: { provider: 'none' },  # Disable CAG
        entity_extractor: { provider: 'none' }, # Disable CAG
        cag_settings: {
          max_depth: 0,
          max_nodes: 0
        }
      }

      # Unified configuration with knowledge sources
      unified_config = {
        enable_rag: true,
        enable_cag: false,  # Disable CAG to avoid provider issues
        knowledge_base_name: 'cybersecurity',
        enable_caching: true,
        auto_initialization: true,
        enable_knowledge_sources: true,
        knowledge_sources_config: knowledge_sources_config
      }

      # Create and setup RAG/CAG manager
      @rag_cag_manager = RAGCAGManager.new(rag_config, cag_config, unified_config)

      unless @rag_cag_manager.setup
        Print.err "Failed to setup RAG/CAG manager"
        return false
      end

      Print.info "✅ RAG/CAG manager setup successful"
      Print.info "Knowledge sources initialized: #{@rag_cag_manager.knowledge_source_manager.instance_variable_get(:@sources).length}"

      # Get statistics
      stats = @rag_cag_manager.knowledge_source_manager.get_source_statistics
      Print.info "Knowledge base statistics:"
      Print.info "  Total sources: #{stats[:total_sources]}"
      Print.info "  Total documents: #{stats[:total_documents]}"
      Print.info "  Total triplets: #{stats[:total_triplets]}"

      # Show per-source stats
      stats[:sources].each do |source_name, source_stats|
        Print.info "  #{source_name}: #{source_stats[:total_documents]} docs, #{source_stats[:total_triplets]} triplets"
      end

      true

    rescue => e
      Print.err "Error creating RAG/CAG manager: #{e.message}"
      Print.err e.backtrace.first(3).join("\n")
      false
    end
  end

  def test_knowledge_retrieval
    return false unless @rag_cag_manager

    Print.info "Testing knowledge retrieval..."

    test_queries = [
      "What is privilege escalation?",
      "How do I use nmap for port scanning?",
      "What are common lateral movement techniques?",
      "How does MITRE ATT&CK T1003 work?",
      "What is the purpose of iptables?"
    ]

    test_queries.each do |query|
      Print.info "\nQuery: #{query}"
      context = @rag_cag_manager.get_enhanced_context(query, {})

      if context && !context.empty?
        Print.info "✅ Retrieved context (#{context.length} chars)"
        Print.info "Preview: #{context[0..200]}..."
      else
        Print.warn "⚠️  No context retrieved"
      end
    end
  end
end

# Main execution
if __FILE__ == $0
  Print.info "Starting knowledge base population..."

  populator = KnowledgeBasePopulator.new
  success = populator.populate_with_default_sources

  if success
    # Test the knowledge retrieval
    populator.test_knowledge_retrieval
  end

  Print.info "Knowledge base population completed."
end
