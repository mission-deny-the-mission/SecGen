#!/usr/bin/env ruby

require 'open3'
require 'fileutils'
require 'json'
require 'time'
require File.expand_path('../../../print.rb', __FILE__)

# Utility class for processing man pages and converting them to RAG/CAG format
class ManPageProcessor
  def initialize
    @cache_dir = File.join(Dir.pwd, 'cache', 'man_pages')
    @supported_sections = [1, 2, 3, 4, 5, 6, 7, 8] # Standard man sections
    ensure_cache_dir
  end

  # Get man page content by name
  def get_man_page(man_name, section = nil)
    cache_key = "#{man_name}.#{section || 'all'}"
    cached_path = File.join(@cache_dir, "#{cache_key}.json")

    # Check cache first
    if File.exist?(cached_path)
      begin
        cached_data = JSON.parse(File.read(cached_path))
        return cached_data if cached_data['timestamp'] && (Time.now - Time.parse(cached_data['timestamp'])) < 86400 # 24 hour cache
      rescue JSON::ParserError
        # Cache corrupted, regenerate
      end
    end

    # Get fresh man page content
    content = fetch_man_page_content(man_name, section)

    if content && !content.empty?
      # Cache the result
      cache_data = {
        'timestamp' => Time.now.strftime('%Y-%m-%dT%H:%M:%S%z'),
        'man_name' => man_name,
        'section' => section,
        'content' => content
      }

      File.write(cached_path, JSON.pretty_generate(cache_data))
      return cache_data
    end

    nil
  end

  # Convert man page to RAG document format
  def to_rag_document(man_name, section = nil)
    man_data = get_man_page(man_name, section)
    return nil unless man_data

    content = man_data['content']
    return nil unless content && !content.empty?

    # Clean and format the man page content
    cleaned_content = clean_man_page_content(content)

    # Extract metadata
    metadata = extract_man_page_metadata(cleaned_content, man_name, section)

    {
      id: "man_#{metadata['section']}_#{metadata['name']}",
      content: format_man_page_as_document(cleaned_content, metadata),
      metadata: {
        source: 'man_page',
        type: 'command_documentation',
        man_name: metadata['name'],
        man_section: metadata['section'],
        man_title: metadata['title'],
        man_date: metadata['date'],
        source_system: metadata['source_system']
      }
    }
  end

  # Convert man page to CAG triplets
  def to_cag_triplets(man_name, section = nil)
    man_data = get_man_page(man_name, section)
    return [] unless man_data

    content = man_data['content']
    return [] unless content && !content.empty?

    cleaned_content = clean_man_page_content(content)
    metadata = extract_man_page_metadata(cleaned_content, man_name, section)

    triplets = []

    # Basic entity triplets
    triplets << {
      subject: metadata['name'],
      predicate: 'is_a',
      object: 'command',
      confidence: 1.0,
      source: 'man_page'
    }

    triplets << {
      subject: metadata['name'],
      predicate: 'documented_in_section',
      object: "man_section_#{metadata['section']}",
      confidence: 1.0,
      source: 'man_page'
    }

    # Extract and add relationship triplets from content
    triplets.concat(extract_relationship_triplets(cleaned_content, metadata['name']))

    # Add system-related triplets
    if metadata['source_system']
      triplets << {
        subject: metadata['name'],
        predicate: 'part_of_system',
        object: metadata['source_system'],
        confidence: 0.8,
        source: 'man_page'
      }
    end

    # Extract file relationships
    triplets.concat(extract_file_relationships(cleaned_content, metadata['name']))

    triplets
  end

  # List available man pages matching a pattern
  def list_man_pages(pattern = '')
    stdout, stderr, status = Open3.capture3("man -k #{pattern.shellescape} 2>/dev/null")
    return [] unless status.success?

    man_pages = []
    stdout.each_line do |line|
      # Parse man -k output format: "name (section) - description"
      if line.match(/^([^(]+)\s*\((\d+)\)\s*-\s*(.+)$/)
        name = $1.strip
        section = $2.to_i
        description = $3.strip
        man_pages << { name: name, section: section, description: description }
      end
    end

    man_pages
  end

  # Check if a man page exists
  def man_page_exists?(man_name, section = nil)
    cmd = section ? "man #{section} #{man_name}" : "man #{man_name}"
    stdout, stderr, status = Open3.capture3("#{cmd} 2>/dev/null")
    status.success?
  end

  private

  def ensure_cache_dir
    FileUtils.mkdir_p(@cache_dir) unless Dir.exist?(@cache_dir)
  end

  def fetch_man_page_content(man_name, section = nil)
    cmd = section ? "man #{section} #{man_name}" : "man #{man_name}"

    stdout, stderr, status = Open3.capture3("#{cmd} 2>/dev/null")
    return nil unless status.success?

    # Clean up man page output (remove control characters, formatting)
    clean_output = stdout.gsub(/\x1b\[[0-9;]*m/, '')  # Remove ANSI color codes
                      .gsub(/\x08/, '')                # Remove backspace characters
                      .gsub(/[\x00-\x1f\x7f]/, '')     # Remove other control characters
                      .gsub(/\s+/, ' ')               # Normalize whitespace
                      .strip

    clean_output
  end

  def clean_man_page_content(content)
    # Remove common man page formatting artifacts
    content.gsub(/\x1b\[[0-9;]*m/, '')  # ANSI color codes
           .gsub(/\x08/, '')            # Backspace characters
           .gsub(/[\x00-\x1f\x7f]/, '') # Control characters
           .gsub(/\s+/, ' ')           # Normalize whitespace
           .gsub(/NAME\s*\n\s*/, "NAME\n")
           .gsub(/SYNOPSIS\s*\n\s*/, "SYNOPSIS\n")
           .gsub(/DESCRIPTION\s*\n\s*/, "DESCRIPTION\n")
           .gsub(/OPTIONS\s*\n\s*/, "OPTIONS\n")
           .gsub(/EXAMPLES\s*\n\s*/, "EXAMPLES\n")
           .gsub(/SEE ALSO\s*\n\s*/, "SEE ALSO\n")
           .gsub(/BUGS\s*\n\s*/, "BUGS\n")
           .gsub(/AUTHOR\s*\n\s*/, "AUTHOR\n")
           .strip
  end

  def extract_man_page_metadata(content, man_name, section)
    metadata = {
      'name' => man_name,
      'section' => section || determine_section_from_content(content),
      'title' => extract_title(content),
      'date' => extract_date(content),
      'source_system' => extract_source_system(content)
    }

    metadata
  end

  def determine_section_from_content(content)
    # Try to determine section from content patterns
    if content.match(/user commands|general commands/i)
      1
    elsif content.match(/system calls/i)
      2
    elsif content.match(/library functions/i)
      3
    elsif content.match(/devices|special files/i)
      4
    elsif content.match(/file formats/i)
      5
    elsif content.match(/games/i)
      6
    elsif content.match(/miscellaneous/i)
      7
    elsif content.match(/administration|maintenance/i)
      8
    else
      1 # Default to user commands
    end
  end

  def extract_title(content)
    # Extract title from first few lines
    first_lines = content.split("\n").first(5).join(" ")
    if first_lines.match(/([A-Z][A-Z0-9_]+)\s*\((\d+)\)/)
      $1
    else
      "Unknown"
    end
  end

  def extract_date(content)
    # Try to extract date from content
    if content.match(/(\d{4}-\d{2}-\d{2}|\w+\s+\d{1,2},?\s+\d{4})/)
      $1
    else
      Time.now.strftime("%Y-%m-%d")
    end
  end

  def extract_source_system(content)
    # Try to determine which system this command belongs to
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

  def format_man_page_as_document(content, metadata)
    # Create header
    formatted = "Man Page: #{metadata['name']} (#{metadata['section']})\n\n"

    if metadata['title'] && metadata['title'] != 'Unknown'
      formatted += "Title: #{metadata['title']}\n"
    end

    if metadata['source_system']
      formatted += "System: #{metadata['source_system']}\n"
    end

    if metadata['date']
      formatted += "Date: #{metadata['date']}\n"
    end

    formatted += "\n" + "=" * 60 + "\n\n"

    # Add content with chunking to prevent text being too long
    max_content_length = 3000  # Very conservative to avoid any text length issues
    truncation_note = "\n\n[Note: Full man page truncated for length. Use 'man #{metadata['name']}' for complete documentation.]"

    require_relative 'content_truncator'
    truncated_content = ContentTruncator.truncate_with_fallback(
      content,
      max_length: max_content_length,
      truncation_note: truncation_note
    )

    formatted += truncated_content

    formatted
  end

  def extract_relationship_triplets(content, command_name)
    triplets = []

    # Extract "see also" references
    if content.match(/SEE ALSO\s*\n(.*?)(?=\n[A-Z]+\s*\n|$)/m)
      see_also = $1
      see_also.scan(/([a-zA-Z0-9_-]+)\s*\((\d+)\)/).each do |ref_name, ref_section|
        triplets << {
          subject: command_name,
          predicate: 'see_also',
          object: ref_name,
          confidence: 0.9,
          source: 'man_page_see_also'
        }
      end
    end

    # Extract file relationships
    content.scan(/([\/][^\s]+)/).each do |file_match|
      file_path = file_match[0]
      triplets << {
        subject: command_name,
        predicate: 'uses_file',
        object: file_path,
        confidence: 0.7,
        source: 'man_page_file_reference'
      }
    end

    # Extract option relationships
    content.scan(/(-[a-zA-Z0-9]+)\s+([^\n]+)/).each do |option, description|
      triplets << {
        subject: command_name,
        predicate: 'has_option',
        object: option,
        confidence: 0.8,
        source: 'man_page_option'
      }
    end

    triplets
  end

  def extract_file_relationships(content, command_name)
    triplets = []

    # Extract configuration files
    if content.match(/([\/][^\s]+\.conf)/)
      config_file = $1
      triplets << {
        subject: command_name,
        predicate: 'reads_config_from',
        object: config_file,
        confidence: 0.8,
        source: 'man_page_config_file'
      }
    end

    # Extract log files
    if content.match(/([\/][^\s]+\.log)/)
      log_file = $1
      triplets << {
        subject: command_name,
        predicate: 'writes_log_to',
        object: log_file,
        confidence: 0.8,
        source: 'man_page_log_file'
      }
    end

    triplets
  end
end
