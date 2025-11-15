#!/usr/bin/env ruby

require_relative '../../utils/man_page_processor.rb'
require_relative '../../base_knowledge_source.rb'

# Knowledge source for man pages that can be integrated into the RAG/CAG system
class ManPageKnowledgeSource < BaseKnowledgeSource
  def initialize(config = {})
    super(config)
    @processor = ManPageProcessor.new
    @man_pages = config[:man_pages] || []
    @collections = {}
    @loaded = false
  end

  def load_knowledge
    return false if @loaded

    Print.info "Loading man page knowledge source..."

    success = true
    @collections = {}

    # Load each configured man page
    @man_pages.each do |man_config|
      collection_name = man_config[:collection_name] || 'default_man_pages'

      unless @collections.key?(collection_name)
        @collections[collection_name] = {
          rag_documents: [],
          cag_triplets: []
        }
      end

      # Load individual man page
      result = load_man_page(man_config)
      if result
        @collections[collection_name][:rag_documents].concat(result[:rag_documents])
        @collections[collection_name][:cag_triplets].concat(result[:cag_triplets])
      else
        Print.warn "Failed to load man page: #{man_config[:name]}"
        success = false
      end
    end

    @loaded = success
    if success
      total_docs = @collections.values.sum { |c| c[:rag_documents].length }
      total_triplets = @collections.values.sum { |c| c[:cag_triplets].length }
      Print.info "Loaded #{total_docs} man page documents and #{total_triplets} triplets"
    else
      Print.err "Failed to load man page knowledge source"
    end

    success
  end

  def get_rag_documents(collection_name = nil)
    load_knowledge unless @loaded

    if collection_name
      @collections.dig(collection_name, :rag_documents) || []
    else
      @collections.values.flat_map { |c| c[:rag_documents] }
    end
  end

  def get_cag_triplets(collection_name = nil)
    load_knowledge unless @loaded

    if collection_name
      @collections.dig(collection_name, :cag_triplets) || []
    else
      @collections.values.flat_map { |c| c[:cag_triplets] }
    end
  end

  def list_collections
    load_knowledge unless @loaded
    @collections.keys
  end

  def add_man_page(man_name, section = nil, collection_name = 'default_man_pages')
    man_config = {
      name: man_name,
      section: section,
      collection_name: collection_name
    }

    result = load_man_page(man_config)
    return false unless result

    # Add to collections
    unless @collections.key?(collection_name)
      @collections[collection_name] = {
        rag_documents: [],
        cag_triplets: []
      }
    end

    @collections[collection_name][:rag_documents].concat(result[:rag_documents])
    @collections[collection_name][:cag_triplets].concat(result[:cag_triplets])

    Print.info "Added man page '#{man_name}' to collection '#{collection_name}'"
    true
  end

  def remove_man_page(man_name, collection_name = nil)
    load_knowledge unless @loaded

    removed = false

    collections_to_search = collection_name ? [collection_name] : @collections.keys

    collections_to_search.each do |col_name|
      next unless @collections.key?(col_name)

      # Remove from RAG documents
      @collections[col_name][:rag_documents].reject! do |doc|
        doc[:metadata][:man_name] == man_name
      end

      # Remove from CAG triplets
      @collections[col_name][:cag_triplets].reject! do |triplet|
        triplet[:subject] == man_name || triplet[:object] == man_name
      end

      removed = true
    end

    if removed
      Print.info "Removed man page '#{man_name}' from knowledge base"
    else
      Print.warn "Man page '#{man_name}' not found in knowledge base"
    end

    removed
  end

  def search_man_pages(pattern = '')
    @processor.list_man_pages(pattern)
  end

  def man_page_exists?(man_name, section = nil)
    @processor.man_page_exists?(man_name, section)
  end

  def get_man_page_info(man_name, section = nil)
    return nil unless man_page_exists?(man_name, section)

    man_data = @processor.get_man_page(man_name, section)
    return nil unless man_data

    {
      name: man_data['man_name'],
      section: man_data['section'],
      title: extract_title_from_content(man_data['content']),
      content_length: man_data['content'].length,
      source_system: extract_system_from_content(man_data['content'])
    }
  end

  # Retrieve a specific man page by command name
  #
  # @param command_name [String] The name of the command (e.g., "nmap", "netcat")
  # @param section [Integer, nil] Optional man page section (1-8)
  # @return [Hash, nil] Returns hash with { rag_document: {...}, found: true } or nil if not found
  #
  # @example
  #   result = get_man_page_by_name("nmap")
  #   result[:rag_document] # => { id: "...", content: "...", metadata: {...} }
  #
  def get_man_page_by_name(command_name, section: nil)
    return nil unless command_name.is_a?(String) && !command_name.empty?

    begin
      # Check if man page exists
      unless man_page_exists?(command_name, section)
        Print.warn "Man page '#{command_name}'#{section ? " (section #{section})" : ''} not found"
        return nil
      end

      # Use processor to get RAG document
      rag_document = @processor.to_rag_document(command_name, section)
      return nil unless rag_document

      # Enhance metadata with lookup-specific fields
      rag_document[:metadata] ||= {}
      rag_document[:metadata][:source_type] = 'man_page'
      rag_document[:metadata][:command_name] = command_name
      rag_document[:metadata][:section] = section if section
      # Override source with more descriptive lookup-specific format
      rag_document[:metadata][:source] = "man page '#{command_name}'#{section ? " (#{section})" : ''}"

      {
        rag_document: rag_document,
        found: true
      }
    rescue => e
      Print.err "Error retrieving man page '#{command_name}': #{e.message}"
      nil
    end
  end

  def get_statistics
    load_knowledge unless @loaded

    stats = {
      source_type: 'man_pages',
      total_collections: @collections.length,
      total_documents: @collections.values.sum { |c| c[:rag_documents].length },
      total_triplets: @collections.values.sum { |c| c[:cag_triplets].length },
      collections: {}
    }

    @collections.each do |name, data|
      stats[:collections][name] = {
        documents: data[:rag_documents].length,
        triplets: data[:cag_triplets].length
      }
    end

    stats
  end

  def validate_config(config)
    return false unless config.is_a?(Hash)

    # Validate man_pages array
    man_pages = config[:man_pages] || []
    return false unless man_pages.is_a?(Array)

    # Validate each man page configuration
    man_pages.each do |man_config|
      return false unless man_config.is_a?(Hash)
      return false unless man_config[:name].is_a?(String) && !man_config[:name].empty?

      # Validate optional section
      if man_config.key?(:section)
        return false unless man_config[:section].nil? ||
                          (man_config[:section].is_a?(Integer) && (1..8).include?(man_config[:section]))
      end

      # Validate optional collection_name
      if man_config.key?(:collection_name)
        return false unless man_config[:collection_name].is_a?(String) && !man_config[:collection_name].empty?
      end
    end

    true
  end

  private

  def load_man_page(man_config)
    man_name = man_config[:name]
    section = man_config[:section]

    return nil unless man_page_exists?(man_name, section)

    rag_document = @processor.to_rag_document(man_name, section)
    cag_triplets = @processor.to_cag_triplets(man_name, section)

    return nil unless rag_document

    {
      rag_documents: [rag_document],
      cag_triplets: cag_triplets
    }
  end

  def extract_title_from_content(content)
    return nil unless content && !content.empty?

    # Try to extract title from first line
    first_line = content.split("\n").first
    if first_line && first_line.match(/^([A-Z][A-Z0-9_]+)\s*\((\d+)\)/)
      return $1
    end

    nil
  end

  def extract_system_from_content(content)
    return "General" unless content && !content.empty?

    if content.match(/linux|gnu/i)
      "Linux/GNU"
    elsif content.match(/bsd|freebsd|openbsd|netbsd/i)
      "BSD"
    elsif content.match(/unix|system v/i)
      "UNIX"
    elsif content.match(/posix/i)
      "POSIX"
    else
      "General"
    end
  end
end
