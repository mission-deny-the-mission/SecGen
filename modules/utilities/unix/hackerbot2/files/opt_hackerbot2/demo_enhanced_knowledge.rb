#!/usr/bin/env ruby

# Demo script to test enhanced knowledge sources including man pages and markdown files
# This demonstrates the new RAG/CAG system capabilities with man pages and markdown files

require_relative './rag_cag_manager.rb'
require_relative './knowledge_bases/knowledge_source_manager.rb'
require_relative './knowledge_bases/utils/man_page_processor.rb'
require_relative './knowledge_bases/utils/markdown_processor.rb'
require_relative './print.rb'

class EnhancedKnowledgeDemo
  def initialize
    @demo_running = false
  end

  def run_demo
    Print.banner "Enhanced Knowledge Sources Demo"
    Print.info "This demo tests the new man pages and markdown files integration with RAG/CAG system"

    @demo_running = true

    # Test individual components
    test_man_page_processor
    test_markdown_processor
    test_knowledge_source_manager
    test_rag_cag_integration

    Print.banner "Demo Completed Successfully!"
    @demo_running = false
  end

  def test_man_page_processor
    Print.section "Testing Man Page Processor"

    begin
      processor = ManPageProcessor.new

      # Test basic man page availability
      Print.info "Testing man page availability..."
      available_man_pages = ['ls', 'grep', 'ssh', 'nmap']

      available_man_pages.each do |man_page|
        exists = processor.man_page_exists?(man_page)
        Print.result "Man page '#{man_page}' exists: #{exists ? 'YES' : 'NO'}"

        if exists
          # Test getting man page info
          info = processor.get_man_page_info(man_page)
          Print.info "  - Section: #{info[:section]}" if info
          Print.info "  - Title: #{info[:title]}" if info

          # Test RAG document generation
          rag_doc = processor.to_rag_document(man_page)
          Print.result "  RAG document generated: #{rag_doc ? 'YES' : 'NO'}"

          # Test CAG triplets generation
          triplets = processor.to_cag_triplets(man_page)
          Print.result "  CAG triplets generated: #{triplets.length} triplets"
        end
      end

      # Test searching man pages
      Print.info "\nTesting man page search..."
      search_results = processor.list_man_pages('network')
      Print.result "Found #{search_results.length} network-related man pages"

      search_results.first(3).each do |result|
        Print.info "  - #{result[:name]}(#{result[:section]}): #{result[:description][0..60]}..."
      end if search_results.any?

    rescue => e
      Print.err "Man page processor test failed: #{e.message}"
      Print.err e.backtrace.join("\n")
    end
  end

  def test_markdown_processor
    Print.section "Testing Markdown Processor"

    begin
      processor = MarkdownProcessor.new

      # Test with our demo markdown files
      demo_files = [
        './docs/network_security_best_practices.md',
        './docs/incident_response_procedures.md',
        './docs/threat_intelligence/apt_groups.md'
      ]

      demo_files.each do |file_path|
        exists = processor.markdown_file_exists?(file_path)
        Print.result "Markdown file '#{file_path}' exists: #{exists ? 'YES' : 'NO'}"

        if exists
          # Test getting file info
          info = processor.get_markdown_file_info(file_path)
          if info
            Print.info "  - Size: #{info[:size]} bytes"
            Print.info "  - Word count: #{info[:word_count]}"
            Print.info "  - Modified: #{info[:mtime]}"
          end

          # Test RAG document generation
          rag_doc = processor.to_rag_document(file_path)
          Print.result "  RAG document generated: #{rag_doc ? 'YES' : 'NO'}"

          # Test CAG triplets generation
          triplets = processor.to_cag_triplets(file_path)
          Print.result "  CAG triplets generated: #{triplets.length} triplets"

          # Test tag extraction
          tags = processor.get_file_tags(file_path)
          Print.info "  - Tags: #{tags.join(', ')}" if tags.any?
        end
      end

      # Test directory listing
      Print.info "\nTesting directory markdown listing..."
      dir_files = processor.list_markdown_files('./docs/threat_intelligence')
      Print.result "Found #{dir_files.length} markdown files in threat_intelligence directory"

    rescue => e
      Print.err "Markdown processor test failed: #{e.message}"
      Print.err e.backtrace.join("\n")
    end
  end

  def test_knowledge_source_manager
    Print.section "Testing Knowledge Source Manager"

    begin
      # Create knowledge source configuration
      sources_config = [
        {
          type: 'mitre_attack',
          name: 'mitre_attack',
          enabled: true,
          description: 'MITRE ATT&CK framework knowledge base',
          priority: 1
        },
        {
          type: 'man_pages',
          name: 'security_tools',
          enabled: true,
          description: 'Security tools man pages',
          priority: 2,
          man_pages: [
            { name: 'nmap', section: 1, collection_name: 'network_tools' },
            { name: 'ssh', section: 1, collection_name: 'remote_access' },
            { name: 'iptables', section: 8, collection_name: 'firewall_tools' },
            { name: 'tcpdump', section: 1, collection_name: 'network_analysis' },
            { name: 'openssl', section: 1, collection_name: 'crypto_tools' }
          ]
        },
        {
          type: 'markdown_files',
          name: 'cybersecurity_docs',
          enabled: true,
          description: 'Cybersecurity documentation',
          priority: 3,
          markdown_files: [
            { path: './docs/network_security_best_practices.md', collection_name: 'security_guidelines' },
            { path: './docs/incident_response_procedures.md', collection_name: 'incident_response' },
            { path: './docs/threat_intelligence/apt_groups.md', collection_name: 'threat_intel' }
          ]
        }
      ]

      # Initialize knowledge source manager
      manager = KnowledgeSourceManager.new
      Print.info "Initializing knowledge sources..."

      success = manager.initialize_sources(sources_config)
      Print.result "Knowledge sources initialized: #{success ? 'SUCCESS' : 'FAILED'}"

      if success
        # Load knowledge from all sources
        Print.info "Loading knowledge from all sources..."
        load_success = manager.load_all_knowledge
        Print.result "Knowledge loading: #{load_success ? 'SUCCESS' : 'FAILED'}"

        if load_success
          # Test getting statistics
          stats = manager.get_source_statistics
          Print.info "Knowledge source statistics:"
          Print.info "  - Total sources: #{stats[:total_sources]}"
          Print.info "  - Total documents: #{stats[:total_documents]}"
          Print.info "  - Total triplets: #{stats[:total_triplets]}"

          # Test collections
          collections = manager.get_all_collections
          Print.info "Available collections: #{collections.join(', ')}"

          # Test individual source statistics
          stats[:sources].each do |source_name, source_stats|
            Print.info "  - #{source_name}: #{source_stats[:documents]} docs, #{source_stats[:triplets]} triplets"
          end

          # Test getting documents and triplets
          all_docs = manager.get_all_rag_documents
          all_triplets = manager.get_all_cag_triplets

          Print.result "Total RAG documents: #{all_docs.length}"
          Print.result "Total CAG triplets: #{all_triplets.length}"

          # Show sample documents
          if all_docs.any?
            Print.info "\nSample RAG documents:"
            all_docs.first(3).each do |doc|
              metadata = doc[:metadata]
              source_type = metadata[:source]
              title = metadata[:man_name] || metadata[:title] || metadata[:filename] || 'Unknown'
              Print.info "  - [#{source_type}] #{title}"
            end
          end

          # Show sample triplets
          if all_triplets.any?
            Print.info "\nSample CAG triplets:"
            all_triplets.first(5).each do |triplet|
              Print.info "  - #{triplet[:subject]} --#{triplet[:predicate]}--> #{triplet[:object]}"
            end
          end
        end
      end

    rescue => e
      Print.err "Knowledge source manager test failed: #{e.message}"
      Print.err e.backtrace.join("\n")
    end
  end

  def test_rag_cag_integration
    Print.section "Testing RAG/CAG Integration"

    begin
      # Create RAG/CAG configuration with knowledge sources
      sources_config = [
        {
          type: 'man_pages',
          name: 'demo_man_pages',
          enabled: true,
          description: 'Demo man pages',
          priority: 1,
          man_pages: [
            { name: 'ls', section: 1, collection_name: 'demo_unix_tools' },
            { name: 'grep', section: 1, collection_name: 'demo_unix_tools' }
          ]
        },
        {
          type: 'markdown_files',
          name: 'demo_markdown',
          enabled: true,
          description: 'Demo markdown files',
          priority: 2,
          markdown_files: [
            { path: './docs/network_security_best_practices.md', collection_name: 'demo_docs' }
          ]
        }
      ]

      # Configure RAG/CAG manager
      rag_config = {
        vector_db: {
          provider: 'in_memory',  # Use in-memory for demo
          storage_path: './demo_vector_db'
        },
        embedding_service: {
          provider: 'mock',  # Use mock embedding for demo
          model: 'demo-embeddings'
        },
        rag_settings: {
          max_results: 3,
          similarity_threshold: 0.5,
          enable_caching: true
        }
      }

      cag_config = {
        knowledge_graph: {
          provider: 'in_memory',
          storage_path: './demo_graph'
        },
        entity_extractor: {
          provider: 'rule_based'
        },
        cag_settings: {
          max_context_depth: 2,
          max_context_nodes: 10,
          enable_caching: true
        }
      }

      unified_config = {
        enable_rag: true,
        enable_cag: true,
        rag_weight: 0.6,
        cag_weight: 0.4,
        max_context_length: 4000,
        enable_caching: true,
        auto_initialization: true,
        enable_knowledge_sources: true,
        knowledge_sources_config: sources_config
      }

      Print.info "Initializing RAG/CAG Manager with enhanced knowledge sources..."

      # Note: In a real implementation, you would need to have the vector database
      # and embedding service properly set up. For this demo, we'll skip the full
      # initialization since it requires additional dependencies.

      Print.warn "Note: Full RAG/CAG integration requires proper vector database and embedding service setup."
      Print.warn "This demo shows the configuration and structure for enhanced knowledge sources."

      # Show configuration structure
      Print.info "Enhanced knowledge sources configuration:"
      sources_config.each do |source|
        Print.info "  - #{source[:type]}: #{source[:name]} (#{source[:description]})"
        case source[:type]
        when 'man_pages'
          Print.info "    Man pages: #{source[:man_pages].map { |mp| mp[:name] }.join(', ')}"
        when 'markdown_files'
          Print.info "    Files: #{source[:markdown_files].map { |mf| File.basename(mf[:path]) }.join(', ')}"
        end
      end

    rescue => e
      Print.err "RAG/CAG integration test failed: #{e.message}"
      Print.err e.backtrace.join("\n")
    end
  end

  def cleanup
    return unless @demo_running

    Print.info "Cleaning up demo resources..."

    # Clean up any demo files or directories
    demo_dirs = ['./demo_vector_db', './demo_graph']
    demo_dirs.each do |dir|
      if Dir.exist?(dir)
        FileUtils.rm_rf(dir) if defined?(FileUtils)
        Print.info "Cleaned up: #{dir}"
      end
    end
  end
end

# Main execution
if __FILE__ == $0
  demo = EnhancedKnowledgeDemo.new

  # Set up signal handlers for graceful cleanup
  %w[INT TERM].each do |signal|
    trap(signal) do
      Print.info "\nReceived #{signal} signal, cleaning up..."
      demo.cleanup
      exit 0
    end
  end

  begin
    demo.run_demo
  rescue => e
    Print.err "Demo failed with error: #{e.message}"
    Print.err e.backtrace.join("\n")
    demo.cleanup
    exit 1
  ensure
    demo.cleanup
  end
end
