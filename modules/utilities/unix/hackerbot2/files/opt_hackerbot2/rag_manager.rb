require './rag/rag_manager.rb'
require './knowledge_bases/mitre_attack_knowledge.rb'
require './knowledge_bases/knowledge_source_manager.rb'
require './print.rb'

# RAG Manager for knowledge retrieval and augmented generation
class RAGOnlyManager
  # Public accessors
  attr_reader :initialized, :rag_manager, :knowledge_source_manager

  def initialize(rag_config, config = {})
    @rag_config = rag_config
    @config = {
      enable_rag: config.key?(:enable_rag) ? config[:enable_rag] : true,
      max_context_length: config[:max_context_length] || 4000,
      knowledge_base_name: config[:knowledge_base_name] || 'cybersecurity',
      enable_caching: config[:enable_caching] || false,
      cache_ttl: config[:cache_ttl] || 3600, # 1 hour
      auto_initialization: config[:auto_initialization] || true,
      enable_knowledge_sources: config[:enable_knowledge_sources] || true,
      knowledge_sources_config: config[:knowledge_sources_config] || [],
      max_results: config[:max_results] || 5,
      similarity_threshold: config[:similarity_threshold] || 0.7
    }

    @cache = {}
    @cache_timestamps = {}
    @initialized = false
    @rag_manager = nil
    @knowledge_source_manager = nil

    # Debug logging for config
    Print.info "RAGOnlyManager initialized with config:"
    Print.info "  knowledge_base_name: #{@config[:knowledge_base_name].inspect}"
    Print.info "  enable_rag: #{@config[:enable_rag].inspect}"
    Print.info "  enable_knowledge_sources: #{@config[:enable_knowledge_sources].inspect}"
  end

  def setup
    return if @initialized

    Print.info "Initializing RAG Manager..."

    success = true

    # Initialize RAG if enabled
    if @config[:enable_rag]
      Print.info "Initializing RAG component..."
      @rag_manager = RAGManager.new(
        @rag_config[:vector_db],
        @rag_config[:embedding_service],
        @rag_config[:rag_settings]
      )

      unless @rag_manager.setup
        Print.err "Failed to initialize RAG Manager"
        success = false
      end
    end

    # Initialize knowledge source manager if enabled
    if @config[:enable_knowledge_sources]
      Print.info "Initializing Knowledge Source Manager..."
      @knowledge_source_manager = KnowledgeSourceManager.new(@config)

      sources_config = @config[:knowledge_sources_config] || default_knowledge_sources_config
      unless @knowledge_source_manager.initialize_sources(sources_config)
        Print.err "Failed to initialize Knowledge Source Manager"
        success = false
      end
    end

    if success
      @initialized = true
      Print.info "RAG Manager initialized successfully"

      # Auto-initialize knowledge base if configured
      if @config[:auto_initialization]
        initialize_knowledge_base
      end
    else
      Print.err "RAG Manager initialization failed"
    end

    success
  end

  def initialize_knowledge_base
    unless @initialized
      setup unless setup
      return false
    end

    Print.info "Initializing knowledge base: #{@config[:knowledge_base_name]}"

    success = true

    # Load knowledge from all sources
    if @config[:enable_knowledge_sources] && @knowledge_source_manager
      Print.info "Loading knowledge from all sources..."
      unless @knowledge_source_manager.load_all_knowledge
        Print.err "Failed to load knowledge from sources"
        success = false
      end

      # Get documents from all sources
      all_rag_documents = @knowledge_source_manager.get_all_rag_documents

      Print.info "Retrieved #{all_rag_documents.length} RAG documents from sources"

      # Initialize RAG knowledge base
      if @config[:enable_rag] && @rag_manager && !all_rag_documents.empty?
        unless @rag_manager.add_knowledge_base(@config[:knowledge_base_name], all_rag_documents)
          Print.err "Failed to add RAG knowledge base"
          success = false
        end
      end
    else
      # Fallback to legacy MITRE Attack knowledge only
      Print.info "Using legacy MITRE Attack knowledge base..."

      # Initialize RAG knowledge base
      if @config[:enable_rag] && @rag_manager
        Print.info "Loading RAG documents..."
        rag_documents = MITREAttackKnowledge.to_rag_documents
        Print.info "Generated #{rag_documents.length} RAG documents"

        unless @rag_manager.add_knowledge_base(@config[:knowledge_base_name], rag_documents)
          Print.err "Failed to add RAG knowledge base"
          success = false
        end
      end
    end

    if success
      Print.info "Knowledge base initialization completed successfully"
    else
      Print.err "Knowledge base initialization failed"
    end

    success
  end

  def get_enhanced_context(query, context_options = {})
    unless @initialized
      setup unless setup
      return nil
    end

    # Check cache first
    cache_key = "enhanced_#{query.hash}"
    if @config[:enable_caching] && cached_response_valid?(cache_key)
      Print.debug "Using cached enhanced context for query: #{query[0..50]}..."
      return @cache[cache_key]
    end

    context_options = {
      max_results: context_options[:max_results] || @config[:max_results],
      max_context_length: context_options[:max_context_length] || @config[:max_context_length]
    }.merge(context_options)

    enhanced_context = {
      original_query: query,
      rag_context: nil,
      combined_context: query,
      sources: [],
      timestamp: Time.now
    }

    # Get RAG context if enabled and available
    if @config[:enable_rag] && @rag_manager
      Print.debug "Getting RAG context for query: #{query[0..50]}..."

      rag_context = @rag_manager.retrieve_relevant_context(
        query,
        @config[:knowledge_base_name],
        context_options[:max_results]
      )

      if rag_context && !rag_context[:documents].empty?
        enhanced_context[:rag_context] = rag_context
        enhanced_context[:sources] += rag_context[:documents].map { |doc| doc[:metadata]&.dig(:source) }.compact

        # Combine with original query
        rag_text = rag_context[:documents].map { |doc| doc[:content] || doc['content'] }.join("\n\n")
        enhanced_context[:combined_context] = "#{query}\n\nRelevant Knowledge:\n#{rag_text}"

        Print.debug "Retrieved #{rag_context[:documents].length} relevant documents"
      else
        Print.debug "No relevant documents found for query"
      end
    end

    # Cache result if enabled
    if @config[:enable_caching]
      @cache[cache_key] = enhanced_context
      @cache_timestamps[cache_key] = Time.now
    end

    enhanced_context
  end

  def search_documents(query, options = {})
    unless @initialized
      setup unless setup
      return { documents: [], total: 0 }
    end

    return { documents: [], total: 0 } unless @config[:enable_rag] && @rag_manager

    max_results = options[:max_results] || @config[:max_results]
    collection_name = options[:collection_name] || @config[:knowledge_base_name]

    @rag_manager.retrieve_relevant_context(query, collection_name, max_results)
  end

  def add_documents(collection_name, documents, embeddings = nil)
    unless @initialized
      setup unless setup
      return false
    end

    return false unless @config[:enable_rag] && @rag_manager

    @rag_manager.add_knowledge_base(collection_name, documents, embeddings)
  end

  def get_statistics
    unless @initialized
      return { initialized: false }
    end

    stats = {
      initialized: @initialized,
      rag_enabled: @config[:enable_rag],
      knowledge_sources_enabled: @config[:enable_knowledge_sources],
      cache_enabled: @config[:enable_caching],
      cache_size: @cache.length
    }

    if @config[:enable_rag] && @rag_manager
      stats[:rag_stats] = @rag_manager.get_statistics if @rag_manager.respond_to?(:get_statistics)
    end

    if @config[:enable_knowledge_sources] && @knowledge_source_manager
      stats[:knowledge_sources_stats] = @knowledge_source_manager.get_statistics
    end

    stats
  end

  def clear_cache
    @cache.clear
    @cache_timestamps.clear
    Print.info "RAG cache cleared"
  end

  private

  def default_knowledge_sources_config
    [
      {
        type: 'mitre_attack',
        name: 'mitre_attack',
        enabled: true,
        priority: 1
      },
      {
        type: 'man_pages',
        name: 'man_pages',
        enabled: true,
        priority: 2,
        config: {
          man_page_paths: ['/usr/share/man', '/usr/local/share/man'],
          sections: [1, 8],  # General commands and system administration
          cache_enabled: true
        }
      },
      {
        type: 'markdown_files',
        name: 'markdown_files',
        enabled: true,
        priority: 3,
        config: {
          directory_paths: ['docs', 'knowledge_bases', 'README.md'],
          file_patterns: ['*.md', '*.markdown'],
          cache_enabled: true
        }
      }
    ]
  end

  def cached_response_valid?(cache_key)
    return false unless @cache.key?(cache_key) && @cache_timestamps.key?(cache_key)

    age = Time.now - @cache_timestamps[cache_key]
    age < @config[:cache_ttl]
  end
end
