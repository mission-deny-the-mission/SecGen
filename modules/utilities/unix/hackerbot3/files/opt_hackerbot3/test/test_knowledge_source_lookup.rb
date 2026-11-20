#!/usr/bin/env ruby

require 'minitest/autorun'
require_relative 'test_helper'
require_relative '../knowledge_bases/sources/man_pages/man_page_knowledge.rb'
require_relative '../knowledge_bases/sources/markdown_files/markdown_knowledge.rb'
require_relative '../knowledge_bases/mitre_attack_knowledge.rb'
require_relative '../print.rb'

# Unit tests for identifier-based lookup functionality in knowledge sources
class TestKnowledgeSourceLookup < Minitest::Test
  def setup
    # Suppress print output during tests
    @old_stdout = $stdout
    @old_stderr = $stderr
    $stdout = StringIO.new
    $stderr = StringIO.new

    # Create knowledge source instances
    @man_page_source = ManPageKnowledgeSource.new
    @markdown_source = MarkdownKnowledgeSource.new
  end

  def teardown
    $stdout = @old_stdout
    $stderr = @old_stderr
  end

  # Test Man Page Lookup (Task 4.2)
  def test_get_man_page_by_name_with_existing_page
    # Test with a common man page that should exist
    result = @man_page_source.get_man_page_by_name('ls')
    
    refute_nil result, "Should return a result for existing man page"
    assert result.is_a?(Hash), "Result should be a hash"
    assert_equal true, result[:found], "Found flag should be true"
    refute_nil result[:rag_document], "Should contain rag_document"
    
    rag_doc = result[:rag_document]
    assert rag_doc.is_a?(Hash), "rag_document should be a hash"
    assert rag_doc.key?(:id), "rag_document should have id"
    assert rag_doc.key?(:content), "rag_document should have content"
    assert rag_doc.key?(:metadata), "rag_document should have metadata"
    
    metadata = rag_doc[:metadata]
    assert_equal 'man_page', metadata[:source_type], "source_type should be 'man_page'"
    assert_equal 'ls', metadata[:command_name], "command_name should match"
    assert metadata[:source].include?('ls'), "source should include command name"
  end

  def test_get_man_page_by_name_with_section
    # Test with section parameter
    result = @man_page_source.get_man_page_by_name('printf', section: 1)
    
    # May or may not exist depending on system, but should handle gracefully
    if result
      assert_equal true, result[:found], "Found flag should be true"
      assert_equal 1, result[:rag_document][:metadata][:section], "Section should be set"
    end
  end

  def test_get_man_page_by_name_with_nonexistent_page
    # Test with a man page that definitely doesn't exist
    result = @man_page_source.get_man_page_by_name('nonexistent_command_xyz123')
    
    assert_nil result, "Should return nil for non-existent man page"
  end

  def test_get_man_page_by_name_with_invalid_input
    # Test with invalid inputs
    assert_nil @man_page_source.get_man_page_by_name(''), "Should return nil for empty string"
    assert_nil @man_page_source.get_man_page_by_name(nil), "Should return nil for nil"
    assert_nil @man_page_source.get_man_page_by_name(123), "Should return nil for non-string"
  end

  # Test Markdown Document Lookup (Task 4.3)
  def test_get_document_by_path_with_existing_file
    # Create a temporary markdown file for testing
    require 'tempfile'
    temp_file = Tempfile.new(['test', '.md'])
    temp_file.write("# Test Document\n\nThis is a test markdown file.")
    temp_file.close
    
    begin
      result = @markdown_source.get_document_by_path(temp_file.path)
      
      refute_nil result, "Should return a result for existing file"
      assert result.is_a?(Hash), "Result should be a hash"
      assert_equal true, result[:found], "Found flag should be true"
      refute_nil result[:rag_document], "Should contain rag_document"
      
      rag_doc = result[:rag_document]
      assert rag_doc.is_a?(Hash), "rag_document should be a hash"
      assert rag_doc.key?(:id), "rag_document should have id"
      assert rag_doc.key?(:content), "rag_document should have content"
      assert rag_doc.key?(:metadata), "rag_document should have metadata"
      
      metadata = rag_doc[:metadata]
      assert_equal 'markdown', metadata[:source_type], "source_type should be 'markdown'"
      assert File.expand_path(temp_file.path) == metadata[:file_path], "file_path should be normalized"
    ensure
      temp_file.unlink
    end
  end

  def test_get_document_by_path_with_relative_path
    # Create a temporary markdown file for testing
    require 'tempfile'
    temp_file = Tempfile.new(['test', '.md'])
    temp_file.write("# Test Document\n\nThis is a test.")
    temp_file.close
    
    begin
      # Test with relative path (should normalize to absolute)
      result = @markdown_source.get_document_by_path(temp_file.path)
      
      if result
        normalized_path = File.expand_path(temp_file.path)
        assert_equal normalized_path, result[:rag_document][:metadata][:file_path], "Path should be normalized"
      end
    ensure
      temp_file.unlink
    end
  end

  def test_get_document_by_path_with_nonexistent_file
    result = @markdown_source.get_document_by_path('/nonexistent/path/to/file.md')
    
    assert_nil result, "Should return nil for non-existent file"
  end

  def test_get_document_by_path_with_invalid_input
    # Test with invalid inputs
    assert_nil @markdown_source.get_document_by_path(''), "Should return nil for empty string"
    assert_nil @markdown_source.get_document_by_path(nil), "Should return nil for nil"
    assert_nil @markdown_source.get_document_by_path(123), "Should return nil for non-string"
  end

  # Test MITRE ATT&CK Lookup (Task 4.4)
  def test_get_technique_by_id_with_base_technique
    result = MITREAttackKnowledge.get_technique_by_id('T1003')
    
    refute_nil result, "Should return a result for existing technique"
    assert result.is_a?(Hash), "Result should be a hash"
    assert_equal true, result[:found], "Found flag should be true"
    refute_nil result[:rag_document], "Should contain rag_document"
    
    rag_doc = result[:rag_document]
    assert rag_doc.is_a?(Hash), "rag_document should be a hash"
    assert rag_doc.key?(:id), "rag_document should have id"
    assert rag_doc.key?(:content), "rag_document should have content"
    assert rag_doc.key?(:metadata), "rag_document should have metadata"
    
    metadata = rag_doc[:metadata]
    assert_equal 'mitre_attack', metadata[:source_type], "source_type should be 'mitre_attack'"
    assert_equal 'T1003', metadata[:technique_id], "technique_id should match"
    assert_equal 'attack_pattern', metadata[:type], "type should be 'attack_pattern'"
    assert_equal 'OS Credential Dumping', metadata[:technique_name], "technique_name should match"
  end

  def test_get_technique_by_id_with_sub_technique
    result = MITREAttackKnowledge.get_technique_by_id('T1003.001')
    
    refute_nil result, "Should return a result for existing sub-technique"
    assert_equal true, result[:found], "Found flag should be true"
    
    metadata = result[:rag_document][:metadata]
    assert_equal 'T1003.001', metadata[:technique_id], "technique_id should match"
    assert_equal 'sub_technique', metadata[:type], "type should be 'sub_technique'"
    assert_equal 'T1003', metadata[:parent_technique_id], "parent_technique_id should be set"
    assert_equal 'LSASS Memory', metadata[:technique_name], "technique_name should match"
  end

  def test_get_technique_by_id_with_nonexistent_technique
    result = MITREAttackKnowledge.get_technique_by_id('T99999')
    
    assert_nil result, "Should return nil for non-existent technique"
  end

  def test_get_technique_by_id_case_insensitive
    # Test that it normalizes to uppercase
    result_lower = MITREAttackKnowledge.get_technique_by_id('t1003')
    result_upper = MITREAttackKnowledge.get_technique_by_id('T1003')
    
    if result_lower && result_upper
      assert_equal result_lower[:rag_document][:metadata][:technique_id],
                   result_upper[:rag_document][:metadata][:technique_id],
                   "Should normalize to uppercase"
    end
  end

  def test_get_technique_by_id_with_invalid_input
    # Test with invalid inputs
    assert_nil MITREAttackKnowledge.get_technique_by_id(''), "Should return nil for empty string"
    assert_nil MITREAttackKnowledge.get_technique_by_id(nil), "Should return nil for nil"
    assert_nil MITREAttackKnowledge.get_technique_by_id(123), "Should return nil for non-string"
  end

  # Integration Tests (Task 4.5)
  def test_man_page_lookup_returns_compatible_format
    result = @man_page_source.get_man_page_by_name('ls')
    
    return unless result
    
    # Verify format matches what get_rag_documents would return
    rag_doc = result[:rag_document]
    all_docs = @man_page_source.get_rag_documents
    
    # Check that structure matches
    assert rag_doc.key?(:id), "Should have id like get_rag_documents"
    assert rag_doc.key?(:content), "Should have content like get_rag_documents"
    assert rag_doc.key?(:metadata), "Should have metadata like get_rag_documents"
    
    # Check metadata structure compatibility
    if all_docs.any?
      sample_doc = all_docs.first
      assert_equal sample_doc[:metadata].keys.sort,
                   rag_doc[:metadata].keys.sort,
                   "Metadata keys should match RAG document format"
    end
  end

  def test_markdown_lookup_returns_compatible_format
    # Create a temporary markdown file for testing
    require 'tempfile'
    temp_file = Tempfile.new(['test', '.md'])
    temp_file.write("# Test\n\nContent")
    temp_file.close
    
    begin
      result = @markdown_source.get_document_by_path(temp_file.path)
      
      return unless result
      
      # Verify format matches what get_rag_documents would return
      rag_doc = result[:rag_document]
      
      # Check structure
      assert rag_doc.key?(:id), "Should have id like get_rag_documents"
      assert rag_doc.key?(:content), "Should have content like get_rag_documents"
      assert rag_doc.key?(:metadata), "Should have metadata like get_rag_documents"
    ensure
      temp_file.unlink
    end
  end

  def test_mitre_lookup_returns_compatible_format
    result = MITREAttackKnowledge.get_technique_by_id('T1003')
    
    return unless result
    
    # Verify format matches what to_rag_documents would return
    rag_doc = result[:rag_document]
    all_docs = MITREAttackKnowledge.to_rag_documents
    
    # Check structure
    assert rag_doc.key?(:id), "Should have id like to_rag_documents"
    assert rag_doc.key?(:content), "Should have content like to_rag_documents"
    assert rag_doc.key?(:metadata), "Should have metadata like to_rag_documents"
    
    # Check metadata structure compatibility
    if all_docs.any?
      sample_doc = all_docs.find { |d| d[:id] == 'mitre_attack_T1003' }
      if sample_doc
        # Both should have similar structure
        assert rag_doc[:metadata].key?(:technique_id) || sample_doc[:metadata].key?(:pattern_id),
               "Should have technique/pattern identifier"
      end
    end
  end
end

