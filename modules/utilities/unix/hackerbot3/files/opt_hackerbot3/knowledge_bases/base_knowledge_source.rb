#!/usr/bin/env ruby

# Base class for all knowledge sources in the RAG/CAG system
class BaseKnowledgeSource
  def initialize(config = {})
    @config = config
    @enabled = config.fetch(:enabled, true)
    @priority = config.fetch(:priority, 0)
    @description = config.fetch(:description, '')
  end

  # Abstract methods that must be implemented by subclasses

  # Load knowledge from the source
  def load_knowledge
    raise NotImplementedError, "Subclasses must implement load_knowledge"
  end

  # Get RAG documents from the source
  def get_rag_documents(collection_name = nil)
    raise NotImplementedError, "Subclasses must implement get_rag_documents"
  end

  # Get CAG triplets from the source
  def get_cag_triplets(collection_name = nil)
    raise NotImplementedError, "Subclasses must implement get_cag_triplets"
  end

  # List available collections in this source
  def list_collections
    raise NotImplementedError, "Subclasses must implement list_collections"
  end

  # Get statistics about this knowledge source
  def get_statistics
    raise NotImplementedError, "Subclasses must implement get_statistics"
  end

  # Validate configuration for this knowledge source
  def validate_config(config)
    raise NotImplementedError, "Subclasses must implement validate_config"
  end

  # Common utility methods

  def enabled?
    @enabled
  end

  def priority
    @priority
  end

  def description
    @description
  end

  # Test if the source is properly configured and can be used
  def test_connection
    begin
      validate_config(@config)
      return true
    rescue => e
      Print.err "Knowledge source validation failed: #{e.message}"
      return false
    end
  end

  # Clean up resources used by this knowledge source
  def cleanup
    # Default implementation does nothing
  end

  protected

  # Helper method to validate common configuration parameters
  def validate_common_config(config)
    return false unless config.is_a?(Hash)

    # Validate enabled flag
    if config.key?(:enabled)
      return false unless [true, false].include?(config[:enabled])
    end

    # Validate priority
    if config.key?(:priority)
      return false unless config[:priority].is_a?(Integer)
    end

    # Validate description
    if config.key?(:description)
      return false unless config[:description].is_a?(String)
    end

    true
  end

  # Helper method to create standardized metadata
  def create_metadata(source_type, additional_metadata = {})
    metadata = {
      source: source_type,
      loaded_at: Time.now.iso8601,
      priority: @priority,
      description: @description
    }

    metadata.merge(additional_metadata)
  end

  # Helper method to log source-specific messages
  def log_source_message(level, message)
    case level
    when :info
      Print.info "[#{@config[:source_type] || 'Unknown'}] #{message}"
    when :warn
      Print.warn "[#{@config[:source_type] || 'Unknown'}] #{message}"
    when :err
      Print.err "[#{@config[:source_type] || 'Unknown'}] #{message}"
    when :debug
      Print.debug "[#{@config[:source_type] || 'Unknown'}] #{message}"
    end
  end
end
