#!/usr/bin/env ruby

require 'fileutils'
require 'json'
require 'time'
require File.expand_path('../../../print.rb', __FILE__)

# Utility class for processing markdown files and converting them to RAG/CAG format
class MarkdownProcessor
  def initialize
    @cache_dir = File.join(Dir.pwd, 'cache', 'markdown')
    @supported_extensions = ['.md', '.markdown', '.mdown', '.mkdn']
    ensure_cache_dir
  end

  # Get markdown file content by path
  def get_markdown_file(file_path)
    # Normalize path
    normalized_path = File.expand_path(file_path)

    # Check if file exists and is a markdown file
    unless File.exist?(normalized_path)
      raise ArgumentError, "Markdown file not found: #{normalized_path}"
    end

    unless @supported_extensions.include?(File.extname(normalized_path).downcase)
      raise ArgumentError, "Unsupported file extension: #{File.extname(normalized_path)}"
    end

    cache_key = normalized_path.gsub(/[\/\\]/, '_')
    cached_path = File.join(@cache_dir, "#{cache_key}.json")

    # Check cache first
    if File.exist?(cached_path)
      begin
        cached_data = JSON.parse(File.read(cached_path))
        file_mtime = File.mtime(normalized_path)
        cached_mtime = Time.parse(cached_data['file_mtime']) rescue nil if cached_data['file_mtime']

        # Use cache if file hasn't been modified and cache is less than 24 hours old
        if cached_mtime && file_mtime <= cached_mtime &&
           (Time.now - Time.parse(cached_data['timestamp'])) < 86400
          return cached_data
        end
      rescue JSON::ParserError
        # Cache corrupted, regenerate
      end
    end

    # Read and parse markdown file
    content = File.read(normalized_path)
    parsed_content = parse_markdown_content(content)

    # Cache the result
    cache_data = {
      'timestamp' => Time.now.strftime('%Y-%m-%dT%H:%M:%S%z'),
      'file_mtime' => File.mtime(normalized_path).strftime('%Y-%m-%dT%H:%M:%S%z'),
      'file_path' => normalized_path,
      'file_size' => File.size(normalized_path),
      'content' => content,
      'parsed_content' => parsed_content
    }

    File.write(cached_path, JSON.pretty_generate(cache_data))
    cache_data
  end

  # Convert markdown file to RAG document format
  def to_rag_document(file_path)
    markdown_data = get_markdown_file(file_path)
    return nil unless markdown_data

    content = markdown_data['content']
    return nil unless content && !content.empty?

    # Extract metadata
    metadata = extract_markdown_metadata(content, file_path)

    # Parse and clean content
    cleaned_content = clean_markdown_content(content)

    {
      id: "markdown_#{metadata['filename'].gsub(/[\/\\\.]/, '_')}",
      content: format_markdown_as_document(cleaned_content, metadata),
      metadata: {
        source: 'markdown_file',
        type: 'documentation',
        file_path: metadata['file_path'],
        filename: metadata['filename'],
        title: metadata['title'],
        author: metadata['author'],
        date: metadata['date'],
        tags: metadata['tags'],
        word_count: metadata['word_count'],
        reading_time: metadata['reading_time']
      }
    }
  end

  # Convert markdown file to CAG triplets
  def to_cag_triplets(file_path)
    markdown_data = get_markdown_file(file_path)
    return [] unless markdown_data

    content = markdown_data['content']
    return [] unless content && !content.empty?

    metadata = extract_markdown_metadata(content, file_path)
    cleaned_content = clean_markdown_content(content)

    triplets = []

    # Basic document entity triplets
    triplets << {
      subject: metadata['filename'],
      predicate: 'is_a',
      object: 'markdown_document',
      confidence: 1.0,
      source: 'markdown_file'
    }

    # Title relationships
    if metadata['title'] && metadata['title'] != metadata['filename']
      triplets << {
        subject: metadata['filename'],
        predicate: 'has_title',
        object: metadata['title'],
        confidence: 1.0,
        source: 'markdown_metadata'
      }
    end

    # Author relationships
    if metadata['author']
      triplets << {
        subject: metadata['filename'],
        predicate: 'authored_by',
        object: metadata['author'],
        confidence: 0.9,
        source: 'markdown_metadata'
      }
    end

    # Tag relationships
    metadata['tags'].each do |tag|
      triplets << {
        subject: metadata['filename'],
        predicate: 'has_tag',
        object: tag,
        confidence: 0.8,
        source: 'markdown_metadata'
      }
    end

    # Extract and add relationship triplets from content
    triplets.concat(extract_content_relationships(cleaned_content, metadata['filename']))

    # Extract file references
    triplets.concat(extract_file_references(cleaned_content, metadata['filename']))

    # Extract code relationships
    triplets.concat(extract_code_relationships(cleaned_content, metadata['filename']))

    # Extract link relationships
    triplets.concat(extract_link_relationships(cleaned_content, metadata['filename']))

    triplets
  end

  # List markdown files in a directory matching a pattern
  def list_markdown_files(directory_path, pattern = '*.md')
    normalized_dir = File.expand_path(directory_path)

    unless Dir.exist?(normalized_dir)
      raise ArgumentError, "Directory not found: #{normalized_dir}"
    end

    pattern_path = File.join(normalized_dir, pattern)
    markdown_files = Dir.glob(pattern_path).select do |file|
      @supported_extensions.include?(File.extname(file).downcase) && File.file?(file)
    end

    markdown_files.map do |file|
      {
        path: file,
        filename: File.basename(file),
        size: File.size(file),
        mtime: File.mtime(file)
      }
    end
  end

  # Check if a markdown file exists
  def markdown_file_exists?(file_path)
    normalized_path = File.expand_path(file_path)
    File.exist?(normalized_path) && @supported_extensions.include?(File.extname(normalized_path).downcase)
  end

  private

  def ensure_cache_dir
    FileUtils.mkdir_p(@cache_dir) unless Dir.exist?(@cache_dir)
  end

  def parse_markdown_content(content)
    begin
      # Use Kramdown if available, otherwise basic parsing
      if defined?(Kramdown)
        doc = Kramdown::Document.new(content)
        {
          html: doc.to_html,
          headers: extract_headers(content),
          code_blocks: extract_code_blocks(content),
          links: extract_links(content)
        }
      else
        # Basic parsing without Kramdown
        {
          html: nil,
          headers: extract_headers(content),
          code_blocks: extract_code_blocks(content),
          links: extract_links(content)
        }
      end
    rescue => e
      # Fallback to basic parsing
      {
        html: nil,
        headers: extract_headers(content),
        code_blocks: extract_code_blocks(content),
        links: extract_links(content),
        parse_error: e.message
      }
    end
  end

  def extract_headers(content)
    headers = []
    content.each_line do |line|
      if line.match(/^(\#{1,6})\s+(.+)$/)
        level = $1.length
        text = $2.strip
        headers << { level: level, text: text }
      end
    end
    headers
  end

  def extract_code_blocks(content)
    code_blocks = []
    in_code_block = false
    current_block = []
    language = ''

    content.each_line do |line|
      if line.match(/^```(\w*)$/)
        if in_code_block
          # End of code block
          code_blocks << {
            language: language,
            code: current_block.join("\n")
          }
          current_block = []
          language = ''
          in_code_block = false
        else
          # Start of code block
          language = $1
          in_code_block = true
        end
      elsif in_code_block
        current_block << line.rstrip
      end
    end

    code_blocks
  end

  def extract_links(content)
    links = []
    content.scan(/\[([^\]]+)\]\(([^)]+)\)/).each do |text, url|
      links << { text: text, url: url }
    end
    links
  end

  def clean_markdown_content(content)
    # Remove markdown formatting but preserve structure
    cleaned = content.gsub(/^#+\s+/, '')           # Remove headers
                     .gsub(/\*\*([^*]+)\*\*/, '\1')    # Remove bold
                     .gsub(/\*([^*]+)\*/, '\1')       # Remove italic
                     .gsub(/`([^`]+)`/, '\1')         # Remove inline code
                     .gsub(/\[([^\]]+)\]\([^)]+\)/, '\1')  # Remove links, keep text
                     .gsub(/^>\s*/, '')               # Remove blockquote markers
                     .gsub(/^\s*[-*+]\s*/, '• ')      # Convert list markers to bullets
                     .gsub(/\n{3,}/, "\n\n")         # Reduce multiple newlines
                     .strip
    cleaned
  end

  def extract_markdown_metadata(content, file_path)
    metadata = {
      'file_path' => File.expand_path(file_path),
      'filename' => File.basename(file_path),
      'title' => extract_title_from_content(content) || File.basename(file_path, '.*'),
      'author' => extract_author_from_content(content),
      'date' => extract_date_from_content(content) || File.mtime(file_path).strftime("%Y-%m-%d"),
      'tags' => extract_tags_from_content(content),
      'word_count' => content.split.length,
      'reading_time' => estimate_reading_time(content)
    }

    # Extract YAML frontmatter if present
    frontmatter = extract_yaml_frontmatter(content)
    metadata.merge!(frontmatter) if frontmatter

    metadata
  end

  def extract_yaml_frontmatter(content)
    return {} unless content.start_with?('---')

    # Extract YAML frontmatter between --- delimiters
    if content.match(/^---\s*\n(.*?)\n---\s*\n/m)
      yaml_content = $1
      begin
        require 'yaml'
        YAML.safe_load(yaml_content) || {}
      rescue
        {}
      end
    else
      {}
    end
  end

  def extract_title_from_content(content)
    # Look for first H1 header
    if content.match(/^#\s+(.+)$/m)
      $1.strip
    else
      nil
    end
  end

  def extract_author_from_content(content)
    # Look for author in frontmatter or content
    if content.match(/author:\s*(.+)/i)
      $1.strip
    elsif content.match(/by\s+([A-Z][a-zA-Z\s]+)/i)
      $1.strip
    else
      nil
    end
  end

  def extract_date_from_content(content)
    # Look for date in frontmatter or content
    if content.match(/date:\s*(\d{4}-\d{2}-\d{2})/i)
      $1
    elsif content.match(/(\d{4}-\d{2}-\d{2}|\w+\s+\d{1,2},?\s+\d{4})/)
      $1
    else
      nil
    end
  end

  def extract_tags_from_content(content)
    tags = []

    # Extract from frontmatter
    if content.match(/tags:\s*\[(.*?)\]/m)
      tags_content = $1
      tags.concat(tags_content.split(',').map { |tag| tag.strip.gsub(/['"]/, '') })
    end

    # Extract from content (#tag format)
    content.scan(/#(\w+)/).each do |tag_match|
      tags << tag_match[0]
    end

    # Extract from tag: lines
    content.scan(/tag:\s*(\w+)/i).each do |tag_match|
      tags << tag_match[0]
    end

    tags.uniq
  end

  def estimate_reading_time(content)
    words = content.split.length
    # Average reading speed: 200-250 words per minute
    (words / 200.0).ceil
  end

  def format_markdown_as_document(content, metadata)
    formatted = "Markdown Document: #{metadata['title']}\n\n"

    formatted += "File: #{metadata['filename']}\n"
    formatted += "Path: #{metadata['file_path']}\n"
    formatted += "Author: #{metadata['author']}\n" if metadata['author']
    formatted += "Date: #{metadata['date']}\n"
    formatted += "Tags: #{metadata['tags'].join(', ')}\n" if metadata['tags'].any?
    formatted += "Word Count: #{metadata['word_count']}\n"
    formatted += "Estimated Reading Time: #{metadata['reading_time']} min\n"

    formatted += "\n" + "=" * 60 + "\n\n"
    formatted += content

    formatted
  end

  def extract_content_relationships(content, filename)
    triplets = []

    # Extract command references
    content.scan(/`([a-zA-Z0-9_-]+)`/).each do |command_match|
      command = command_match[0]
      triplets << {
        subject: filename,
        predicate: 'references_command',
        object: command,
        confidence: 0.7,
        source: 'markdown_inline_code'
      }
    end

    # Extract concept mentions
    content.scan(/([A-Z][a-zA-Z\s]+concept|[A-Z][a-zA-Z\s]+technique|[A-Z][a-zA-Z\s]+methodology)/i).each do |concept_match|
      concept = concept_match[0].strip
      triplets << {
        subject: filename,
        predicate: 'discusses_concept',
        object: concept,
        confidence: 0.6,
        source: 'markdown_content_analysis'
      }
    end

    triplets
  end

  def extract_file_references(content, filename)
    triplets = []

    # Extract file path references
    content.scan(/([\/][^\s\)]+)/).each do |file_match|
      file_path = file_match[0]
      triplets << {
        subject: filename,
        predicate: 'references_file',
        object: file_path,
        confidence: 0.8,
        source: 'markdown_file_reference'
      }
    end

    triplets
  end

  def extract_code_relationships(content, filename)
    triplets = []

    # Extract code blocks and their languages
    extract_code_blocks(content).each do |code_block|
      if code_block[:language] && !code_block[:language].empty?
        triplets << {
          subject: filename,
          predicate: 'contains_code_in_language',
          object: code_block[:language],
          confidence: 0.9,
          source: 'markdown_code_block'
        }
      end
    end

    triplets
  end

  def extract_link_relationships(content, filename)
    triplets = []

    # Extract external links
    extract_links(content).each do |link|
      if link[:url].start_with?('http')
        triplets << {
          subject: filename,
          predicate: 'links_to',
          object: link[:url],
          confidence: 0.8,
          source: 'markdown_external_link'
        }
      else
        triplets << {
          subject: filename,
          predicate: 'references_document',
          object: link[:url],
          confidence: 0.7,
          source: 'markdown_internal_link'
        }
      end
    end

    triplets
  end
end
