#!/usr/bin/env ruby

require_relative './base_knowledge_source.rb'
require_relative './sources/man_pages/man_page_knowledge.rb'
require_relative './sources/markdown_files/markdown_knowledge.rb'
require_relative './mitre_attack_knowledge.rb'
require File.expand_path('../../print.rb', __FILE__)

# Manager for coordinating multiple knowledge sources in the RAG/CAG system
class KnowledgeSourceManager
  def initialize(config = {})
    @config = config
    @sources = {}
    @initialized = false
    @source_order = []
  end

  def initialize_sources(sources_config)
    Print.info "Initializing knowledge sources..."

    @sources = {}
    @source_order = []
    success = true

    sources_config.each do |source_config|
      source_type = source_config[:type]
      source_name = source_config[:name] || source_type

      next unless source_config[:enabled] != false  # Skip disabled sources

      begin
        source = create_knowledge_source(source_config)
        if source && source.test_connection
          @sources[source_name] = source
          @source_order << source_name
          Print.info "Initialized knowledge source: #{source_name} (#{source_type})"
        else
          Print.warn "Failed to initialize knowledge source: #{source_name}"
          success = false
        end
      rescue => e
        Print.err "Error initializing knowledge source #{source_name}: #{e.message}"
        success = false
      end
    end

    @initialized = success
    if success
      Print.info "Successfully initialized #{@sources.length} knowledge sources"
    else
      Print.err "Failed to initialize some knowledge sources"
    end

    success
  end

  def load_all_knowledge
    return false unless @initialized

    Print.info "Loading knowledge from all sources..."

    success = true
    total_docs = 0
    total_triplets = 0

    @sources.each do |name, source|
      begin
        Print.info "Loading knowledge from source: #{name}"
        source_success = source.load_knowledge

        if source_success
          stats = source.get_statistics
          total_docs += stats[:total_documents] || 0
          total_triplets += stats[:total_triplets] || 0
          Print.info "Loaded #{stats[:total_documents]} documents and #{stats[:total_triplets]} triplets from #{name}"
        else
          Print.err "Failed to load knowledge from source: #{name}"
          success = false
        end
      rescue => e
        Print.err "Error loading knowledge from source #{name}: #{e.message}"
        success = false
      end
    end

    if success
      Print.info "Successfully loaded #{total_docs} documents and #{total_triplets} triplets from all sources"
    else
      Print.err "Failed to load knowledge from some sources"
    end

    success
  end

  def get_all_rag_documents(collection_name = nil)
    return [] unless @initialized

    all_documents = []

    @source_order.each do |source_name|
      source = @sources[source_name]
      next unless source

      begin
        documents = source.get_rag_documents(collection_name)
        all_documents.concat(documents) if documents
      rescue => e
        Print.err "Error getting RAG documents from source #{source_name}: #{e.message}"
      end
    end

    all_documents
  end

  def get_all_cag_triplets(collection_name = nil)
    return [] unless @initialized

    all_triplets = []

    @source_order.each do |source_name|
      source = @sources[source_name]
      next unless source

      begin
        triplets = source.get_cag_triplets(collection_name)
        all_triplets.concat(triplets) if triplets
      rescue => e
        Print.err "Error getting CAG triplets from source #{source_name}: #{e.message}"
      end
    end

    all_triplets
  end

  def get_all_collections
    return [] unless @initialized

    all_collections = Set.new

    @sources.each do |name, source|
      begin
        collections = source.list_collections
        all_collections.merge(collections) if collections
      rescue => e
        Print.err "Error getting collections from source #{name}: #{e.message}"
      end
    end

    all_collections.to_a
  end

  def add_knowledge_source(source_config)
    source_name = source_config[:name] || source_config[:type]

    begin
      source = create_knowledge_source(source_config)
      return false unless source

      unless source.test_connection
        Print.err "Knowledge source validation failed: #{source_name}"
        return false
      end

      @sources[source_name] = source
      @source_order << source_name unless @source_order.include?(source_name)

      Print.info "Added knowledge source: #{source_name}"
      true
    rescue => e
      Print.err "Error adding knowledge source #{source_name}: #{e.message}"
      false
    end
  end

  def remove_knowledge_source(source_name)
    return false unless @sources.key?(source_name)

    begin
      source = @sources[source_name]
      source.cleanup if source.respond_to?(:cleanup)

      @sources.delete(source_name)
      @source_order.delete(source_name)

      Print.info "Removed knowledge source: #{source_name}"
      true
    rescue => e
      Print.err "Error removing knowledge source #{source_name}: #{e.message}"
      false
    end
  end

  def get_source_statistics(source_name = nil)
    return {} unless @initialized

    if source_name
      source = @sources[source_name]
      return {} unless source

      begin
        source.get_statistics
      rescue => e
        Print.err "Error getting statistics for source #{source_name}: #{e.message}"
        {}
      end
    else
      all_stats = {
        total_sources: @sources.length,
        total_documents: 0,
        total_triplets: 0,
        sources: {}
      }

      @sources.each do |name, source|
        begin
          stats = source.get_statistics
          all_stats[:total_documents] += stats[:total_documents] || 0
          all_stats[:total_triplets] += stats[:total_triplets] || 0
          all_stats[:sources][name] = stats
        rescue => e
          Print.err "Error getting statistics for source #{name}: #{e.message}"
        end
      end

      all_stats
    end
  end

  def reload_source(source_name)
    return false unless @sources.key?(source_name)

    source = @sources[source_name]
    begin
      # Reload the knowledge
      source.load_knowledge
      Print.info "Reloaded knowledge source: #{source_name}"
      true
    rescue => e
      Print.err "Error reloading knowledge source #{source_name}: #{e.message}"
      false
    end
  end

  def reload_all_sources
    return false unless @initialized

    Print.info "Reloading all knowledge sources..."

    success = true
    @sources.each do |name, source|
      begin
        unless source.load_knowledge
          Print.err "Failed to reload knowledge source: #{name}"
          success = false
        end
      rescue => e
        Print.err "Error reloading knowledge source #{name}: #{e.message}"
        success = false
      end
    end

    if success
      Print.info "Successfully reloaded all knowledge sources"
    else
      Print.err "Failed to reload some knowledge sources"
    end

    success
  end

  def search_across_sources(query, options = {})
    return [] unless @initialized

    all_results = []

    @sources.each do |name, source|
      begin
        # Search in RAG documents if the source supports it
        if source.respond_to?(:search_documents)
          results = source.search_documents(query, options)
          all_results.concat(results) if results
        end
      rescue => e
        Print.err "Error searching in source #{name}: #{e.message}"
      end
    end

    # Sort results by relevance/score
    all_results.sort_by { |result| result[:score] || 0 }.reverse
  end

  def test_all_connections
    return false unless @initialized

    Print.info "Testing all knowledge source connections..."

    all_ok = true
    @sources.each do |name, source|
      begin
        if source.test_connection
          Print.info "Source #{name}: OK"
        else
          Print.err "Source #{name}: FAILED"
          all_ok = false
        end
      rescue => e
        Print.err "Source #{name}: ERROR - #{e.message}"
        all_ok = false
      end
    end

    Print.info "Knowledge sources test: #{all_ok ? 'OK' : 'FAILED'}"
    all_ok
  end

  def cleanup
    Print.info "Cleaning up knowledge sources..."

    @sources.each do |name, source|
      begin
        source.cleanup if source.respond_to?(:cleanup)
      rescue => e
        Print.err "Error cleaning up source #{name}: #{e.message}"
      end
    end

    @sources = {}
    @source_order = []
    @initialized = false

    Print.info "Knowledge sources cleanup completed"
  end

  private

  def create_knowledge_source(config)
    source_type = config[:type]

    case source_type.to_s.downcase
    when 'man_pages', 'manpage', 'man'
      ManPageKnowledgeSource.new(config)
    when 'markdown_files', 'markdown', 'md'
      MarkdownKnowledgeSource.new(config)
    when 'mitre_attack', 'mitre'
      # Create a wrapper for MITRE Attack knowledge
      create_mitre_wrapper(config)
    else
      raise ArgumentError, "Unknown knowledge source type: #{source_type}"
    end
  end

  def create_mitre_wrapper(config)
    # Create a wrapper class that implements the BaseKnowledgeSource interface
    # for the existing MITRE Attack knowledge
    Class.new(BaseKnowledgeSource) do
      def initialize(config)
        super(config)
        @loaded = false
      end

      def load_knowledge
        @loaded = true
        true
      end

      def get_rag_documents(collection_name = nil)
        return [] unless @loaded
        MITREAttackKnowledge.to_rag_documents
      end

      def get_cag_triplets(collection_name = nil)
        return [] unless @loaded
        MITREAttackKnowledge.to_cag_triplets
      end

      def list_collections
        ['mitre_attack']
      end

      def get_statistics
        {
          source_type: 'mitre_attack',
          total_collections: 1,
          total_documents: MITREAttackKnowledge.to_rag_documents.length,
          total_triplets: MITREAttackKnowledge.to_cag_triplets.length,
          collections: {
            'mitre_attack' => {
              documents: MITREAttackKnowledge.to_rag_documents.length,
              triplets: MITREAttackKnowledge.to_cag_triplets.length
            }
          }
        }
      end

      def validate_config(config)
        true  # MITRE Attack source doesn't require special configuration
      end
    end.new(config)
  end
end
