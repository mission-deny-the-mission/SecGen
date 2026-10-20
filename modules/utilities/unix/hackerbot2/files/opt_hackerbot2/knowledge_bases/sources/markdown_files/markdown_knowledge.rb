#!/usr/bin/env ruby

require_relative '../../utils/markdown_processor.rb'
require_relative '../../base_knowledge_source.rb'

# Knowledge source for markdown files that can be integrated into the RAG/CAG system
class MarkdownKnowledgeSource < BaseKnowledgeSource
  def initialize(config = {})
    super(config)
    @processor = MarkdownProcessor.new
    @markdown_files = config[:markdown_files] || []
    @collections = {}
    @loaded = false
  end

  def load_knowledge
    return false if @loaded

    Print.info "Loading markdown file knowledge source..."

    success = true
    @collections = {}

    # Load each configured markdown file
    @markdown_files.each do |file_config|
      collection_name = file_config[:collection_name] || 'default_markdown_files'

      unless @collections.key?(collection_name)
        @collections[collection_name] = {
          rag_documents: [],
          cag_triplets: []
        }
      end

      # Load individual markdown file
      result = load_markdown_file(file_config)
      if result
        @collections[collection_name][:rag_documents].concat(result[:rag_documents])
        @collections[collection_name][:cag_triplets].concat(result[:cag_triplets])
      else
        Print.warn "Failed to load markdown file: #{file_config[:path]}"
        success = false
      end
    end

    @loaded = success
    if success
      total_docs = @collections.values.sum { |c| c[:rag_documents].length }
      total_triplets = @collections.values.sum { |c| c[:cag_triplets].length }
      Print.info "Loaded #{total_docs} markdown file documents and #{total_triplets} triplets"
    else
      Print.err "Failed to load markdown file knowledge source"
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

  def add_markdown_file(file_path, collection_name = 'default_markdown_files')
    file_config = {
      path: file_path,
      collection_name: collection_name
    }

    result = load_markdown_file(file_config)
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

    Print.info "Added markdown file '#{file_path}' to collection '#{collection_name}'"
    true
  end

  def remove_markdown_file(file_path, collection_name = nil)
    load_knowledge unless @loaded

    removed = false
    normalized_path = File.expand_path(file_path)

    collections_to_search = collection_name ? [collection_name] : @collections.keys

    collections_to_search.each do |col_name|
      next unless @collections.key?(col_name)

      # Remove from RAG documents
      @collections[col_name][:rag_documents].reject! do |doc|
        doc[:metadata][:file_path] == normalized_path
      end

      # Remove from CAG triplets
      @collections[col_name][:cag_triplets].reject! do |triplet|
        triplet[:subject] == File.basename(normalized_path) ||
        triplet[:object] == File.basename(normalized_path)
      end

      removed = true
    end

    if removed
      Print.info "Removed markdown file '#{file_path}' from knowledge base"
    else
      Print.warn "Markdown file '#{file_path}' not found in knowledge base"
    end

    removed
  end

  def list_markdown_files(directory_path, pattern = '*.md')
    @processor.list_markdown_files(directory_path, pattern)
  end

  def markdown_file_exists?(file_path)
    @processor.markdown_file_exists?(file_path)
  end

  def get_markdown_file_info(file_path)
    return nil unless markdown_file_exists?(file_path)

    begin
      markdown_data = @processor.get_markdown_file(file_path)
      return nil unless markdown_data

      {
        path: markdown_data['file_path'],
        filename: markdown_data['filename'],
        size: markdown_data['file_size'],
        mtime: Time.parse(markdown_data['file_mtime']),
        word_count: markdown_data['content'].split.length,
        has_frontmatter: markdown_data['content'].start_with?('---')
      }
    rescue => e
      Print.err "Error getting markdown file info: #{e.message}"
      nil
    end
  end

  def get_statistics
    load_knowledge unless @loaded

    stats = {
      source_type: 'markdown_files',
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

    # Validate markdown_files array
    markdown_files = config[:markdown_files] || []
    return false unless markdown_files.is_a?(Array)

    # Validate each markdown file configuration
    markdown_files.each do |file_config|
      return false unless file_config.is_a?(Hash)
      return false unless file_config[:path].is_a?(String) && !file_config[:path].empty?

      # Validate that file exists
      unless File.exist?(File.expand_path(file_config[:path]))
        Print.warn "Markdown file does not exist: #{file_config[:path]}"
        return false
      end

      # Validate optional collection_name
      if file_config.key?(:collection_name)
        return false unless file_config[:collection_name].is_a?(String) && !file_config[:collection_name].empty?
      end

      # Validate optional tags
      if file_config.key?(:tags)
        return false unless file_config[:tags].is_a?(Array)
        file_config[:tags].each do |tag|
          return false unless tag.is_a?(String) && !tag.empty?
        end
      end
    end

    true
  end

  def add_markdown_directory(directory_path, collection_name = nil, pattern = '*.md')
    normalized_dir = File.expand_path(directory_path)

    unless Dir.exist?(normalized_dir)
      Print.err "Directory does not exist: #{normalized_dir}"
      return false
    end

    collection_name ||= "markdown_#{File.basename(normalized_dir).gsub(/[^\w\-]/, '_')}"

    # Find all markdown files in directory
    markdown_files = list_markdown_files(normalized_dir, pattern)
    return false if markdown_files.empty?

    success = true
    added_count = 0

    markdown_files.each do |file_info|
      if add_markdown_file(file_info[:path], collection_name)
        added_count += 1
      else
        success = false
      end
    end

    Print.info "Added #{added_count}/#{markdown_files.length} markdown files from directory '#{directory_path}' to collection '#{collection_name}'"
    success
  end

  def reload_markdown_file(file_path)
    # Remove existing version first
    remove_markdown_file(file_path)

    # Add fresh version
    add_markdown_file(file_path)
  end

  def get_file_tags(file_path)
    load_knowledge unless @loaded

    normalized_path = File.expand_path(file_path)

    # Find the document in our collections
    @collections.each do |_col_name, collection|
      doc = collection[:rag_documents].find do |doc|
        doc[:metadata][:file_path] == normalized_path
      end

      return doc[:metadata][:tags] if doc
    end

    []
  end

  # Retrieve a specific markdown document by file path
  #
  # @param file_path [String] The file path (e.g., "attack-guide.md", "docs/pentest-primer.md")
  # @return [Hash, nil] Returns hash with { rag_document: {...}, found: true } or nil if not found
  #
  # @example
  #   result = get_document_by_path("docs/attack-guide.md")
  #   result[:rag_document] # => { id: "...", content: "...", metadata: {...} }
  #
  def get_document_by_path(file_path)
    return nil unless file_path.is_a?(String) && !file_path.empty?

    begin
      # Normalize file path for consistent lookup
      normalized_path = File.expand_path(file_path)

      # Check if file exists
      unless markdown_file_exists?(normalized_path)
        Print.warn "Markdown document '#{file_path}' not found"
        return nil
      end

      # Use processor to get RAG document
      rag_document = @processor.to_rag_document(normalized_path)
      return nil unless rag_document

      # Enhance metadata with lookup-specific fields
      rag_document[:metadata] ||= {}
      rag_document[:metadata][:source_type] = 'markdown'
      rag_document[:metadata][:file_path] = normalized_path
      rag_document[:metadata][:source] ||= "document '#{File.basename(normalized_path)}'"

      {
        rag_document: rag_document,
        found: true
      }
    rescue => e
      Print.err "Error retrieving markdown document '#{file_path}': #{e.message}"
      nil
    end
  end

  private

  def load_markdown_file(file_config)
    file_path = file_config[:path]

    return nil unless markdown_file_exists?(file_path)

    begin
      rag_document = @processor.to_rag_document(file_path)
      cag_triplets = @processor.to_cag_triplets(file_path)

      return nil unless rag_document

      # Add custom tags from configuration
      if file_config[:tags] && file_config[:tags].any?
        custom_tags = file_config[:tags]
        rag_document[:metadata][:tags].concat(custom_tags)
        rag_document[:metadata][:tags].uniq!

        # Add tag relationships to CAG triplets
        custom_tags.each do |tag|
          cag_triplets << {
            subject: rag_document[:metadata][:filename],
            predicate: 'has_custom_tag',
            object: tag,
            confidence: 1.0,
            source: 'markdown_configuration'
          }
        end
      end

      {
        rag_documents: [rag_document],
        cag_triplets: cag_triplets
      }
    rescue => e
      Print.err "Error loading markdown file '#{file_path}': #{e.message}"
      nil
    end
  end
end
