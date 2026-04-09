require 'digest'
require 'json'
require 'fileutils'
require 'time'

# Caches LLM-generated content for reproducibility and cost reduction.
# Cache keys are derived from prompt content hash + generation parameters.
class LlmContentCache
  attr_reader :cache_dir

  def initialize(cache_dir = nil)
    root_dir = File.expand_path('../../../../../../', __FILE__)
    @cache_dir = cache_dir || File.join(root_dir, 'lib', 'cache', 'llm_narratives')
    FileUtils.mkdir_p(@cache_dir) unless Dir.exist?(@cache_dir)
  end

  # Look up cached content by prompt and parameters
  def get(prompt, params = {})
    key = cache_key(prompt, params)
    path = cache_path(key)
    return nil unless File.exist?(path)

    data = JSON.parse(File.read(path))
    data['content']
  rescue JSON::ParserError
    nil
  end

  # Store generated content with metadata
  def put(prompt, params, content, metadata = {})
    key = cache_key(prompt, params)
    path = cache_path(key)

    data = {
      'content' => content,
      'prompt_hash' => Digest::SHA256.hexdigest(prompt),
      'params' => params,
      'metadata' => metadata.merge(
        'cached_at' => Time.now.utc.iso8601,
        'cache_key' => key
      )
    }

    File.write(path, JSON.pretty_generate(data))
    content
  end

  # Check if content exists in cache
  def cached?(prompt, params = {})
    key = cache_key(prompt, params)
    File.exist?(cache_path(key))
  end

  # Invalidate a specific cache entry
  def invalidate(prompt, params = {})
    key = cache_key(prompt, params)
    path = cache_path(key)
    File.delete(path) if File.exist?(path)
  end

  # Clear all cached content
  def clear
    Dir.glob(File.join(@cache_dir, '*.json')).each { |f| File.delete(f) }
  end

  # Return cache statistics
  def stats
    files = Dir.glob(File.join(@cache_dir, '*.json'))
    total_size = files.sum { |f| File.size(f) }
    {
      'entries' => files.length,
      'total_size_bytes' => total_size,
      'total_size_mb' => (total_size / 1024.0 / 1024.0).round(2),
      'cache_dir' => @cache_dir
    }
  end

  private

  def cache_key(prompt, params)
    seed = params['seed'] || params[:seed]
    model = params['model'] || params[:model] || 'default'
    temperature = params['temperature'] || params[:temperature] || 0.7

    key_material = "#{prompt}|#{model}|#{temperature}|#{seed}"
    Digest::SHA256.hexdigest(key_material)
  end

  def cache_path(key)
    File.join(@cache_dir, "#{key}.json")
  end
end
