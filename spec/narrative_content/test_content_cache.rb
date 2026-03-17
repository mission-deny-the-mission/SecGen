require_relative 'spec_helper'
require 'llm_content_cache'
require 'tmpdir'

class TestLlmContentCache < Minitest::Test
  def setup
    @cache_dir = Dir.mktmpdir('llm_cache_test')
    @cache = LlmContentCache.new(@cache_dir)
  end

  def teardown
    FileUtils.rm_rf(@cache_dir)
  end

  def test_put_and_get
    @cache.put('test prompt', { 'model' => 'test' }, 'generated content')
    result = @cache.get('test prompt', { 'model' => 'test' })
    assert_equal 'generated content', result
  end

  def test_get_returns_nil_for_missing
    result = @cache.get('nonexistent prompt', {})
    assert_nil result
  end

  def test_cached_returns_true_for_existing
    @cache.put('test prompt', { 'model' => 'test' }, 'content')
    assert @cache.cached?('test prompt', { 'model' => 'test' })
  end

  def test_cached_returns_false_for_missing
    refute @cache.cached?('nonexistent', {})
  end

  def test_different_params_different_cache
    @cache.put('prompt', { 'model' => 'a' }, 'content a')
    @cache.put('prompt', { 'model' => 'b' }, 'content b')
    assert_equal 'content a', @cache.get('prompt', { 'model' => 'a' })
    assert_equal 'content b', @cache.get('prompt', { 'model' => 'b' })
  end

  def test_invalidate
    @cache.put('prompt', { 'model' => 'test' }, 'content')
    @cache.invalidate('prompt', { 'model' => 'test' })
    assert_nil @cache.get('prompt', { 'model' => 'test' })
  end

  def test_clear
    @cache.put('prompt1', {}, 'content1')
    @cache.put('prompt2', {}, 'content2')
    @cache.clear
    assert_nil @cache.get('prompt1', {})
    assert_nil @cache.get('prompt2', {})
  end

  def test_stats
    @cache.put('prompt1', {}, 'content1')
    @cache.put('prompt2', {}, 'content2')
    stats = @cache.stats
    assert_equal 2, stats['entries']
    assert stats['total_size_bytes'] > 0
    assert_equal @cache_dir, stats['cache_dir']
  end

  def test_seed_affects_cache_key
    @cache.put('prompt', { 'seed' => 1 }, 'content with seed 1')
    @cache.put('prompt', { 'seed' => 2 }, 'content with seed 2')
    assert_equal 'content with seed 1', @cache.get('prompt', { 'seed' => 1 })
    assert_equal 'content with seed 2', @cache.get('prompt', { 'seed' => 2 })
  end

  def test_metadata_stored
    @cache.put('prompt', { 'model' => 'test' }, 'content', { 'provider' => 'ollama' })
    path = Dir.glob(File.join(@cache_dir, '*.json')).first
    data = JSON.parse(File.read(path))
    assert_equal 'ollama', data['metadata']['provider']
    assert data['metadata'].key?('cached_at')
  end
end
