require 'json'
require 'fileutils'
require 'time'

# Security audit logging for LLM usage in SecGen.
# Logs all LLM API calls for compliance, cost tracking, and security review.
class LlmAuditLogger
  DEFAULT_LOG_DIR = File.expand_path('../../../../../../logs', __FILE__)
  LOG_FILENAME = 'llm_audit.log'

  attr_reader :log_path

  def initialize(log_dir = nil)
    @log_dir = log_dir || DEFAULT_LOG_DIR
    FileUtils.mkdir_p(@log_dir) unless Dir.exist?(@log_dir)
    @log_path = File.join(@log_dir, LOG_FILENAME)
  end

  # Log an LLM generation request
  def log_generation(provider:, model:, prompt_hash:, prompt_length:, response_length:, cached:, seed: nil, duration_ms: nil)
    entry = {
      'timestamp' => Time.now.utc.iso8601,
      'event' => 'llm_generation',
      'provider' => provider,
      'model' => model,
      'prompt_hash' => prompt_hash,
      'prompt_length' => prompt_length,
      'response_length' => response_length,
      'cached' => cached,
      'seed' => seed,
      'duration_ms' => duration_ms,
      'local_only' => local_provider?(provider)
    }
    write_entry(entry)
  end

  # Log a security event (sanitization trigger, student data detection, etc.)
  def log_security_event(event_type:, details:, severity: 'warning')
    entry = {
      'timestamp' => Time.now.utc.iso8601,
      'event' => 'security',
      'event_type' => event_type,
      'severity' => severity,
      'details' => details
    }
    write_entry(entry)
  end

  # Log a configuration change
  def log_config_change(provider:, setting:, old_value: nil, new_value: nil)
    entry = {
      'timestamp' => Time.now.utc.iso8601,
      'event' => 'config_change',
      'provider' => provider,
      'setting' => setting,
      'old_value' => old_value,
      'new_value' => new_value
    }
    write_entry(entry)
  end

  # Read recent log entries
  def recent_entries(count = 50)
    return [] unless File.exist?(@log_path)
    lines = File.readlines(@log_path).last(count)
    lines.map { |line| JSON.parse(line) rescue nil }.compact
  end

  # Get usage statistics
  def usage_stats
    entries = recent_entries(10000)
    gen_entries = entries.select { |e| e['event'] == 'llm_generation' }

    {
      'total_generations' => gen_entries.length,
      'cached_hits' => gen_entries.count { |e| e['cached'] },
      'by_provider' => gen_entries.group_by { |e| e['provider'] }.transform_values(&:length),
      'total_prompt_chars' => gen_entries.sum { |e| e['prompt_length'] || 0 },
      'total_response_chars' => gen_entries.sum { |e| e['response_length'] || 0 },
      'local_only_count' => gen_entries.count { |e| e['local_only'] }
    }
  end

  private

  def write_entry(entry)
    File.open(@log_path, 'a') { |f| f.puts(entry.to_json) }
  rescue StandardError => e
    $stderr.puts "LLM audit log error: #{e.message}"
  end

  def local_provider?(provider)
    %w[ollama llama_cpp lm_studio].include?(provider)
  end
end
