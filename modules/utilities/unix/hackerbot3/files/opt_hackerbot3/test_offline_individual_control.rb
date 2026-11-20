#!/usr/bin/env ruby

# Simple test script for offline default and individual RAG/CAG system control
# This script verifies configuration without requiring full bot initialization

require_relative './rag_cag_offline_config'
require_relative './print'

class TestOfflineIndividualControl
  def initialize
    @passed = 0
    @failed = 0
  end

  def run_tests
    Print.info "Running offline default and individual control tests..."
    Print.info "=" * 60

    test_offline_default_configuration
    test_configuration_structure
    test_command_line_help

    Print.info "=" * 60
    Print.info "Test Results: #{@passed} passed, #{@failed} failed"
    @failed == 0
  end

  def test_offline_default_configuration
    Print.info "Test 1: Offline default configuration"
    Print.info "-" * 40

    begin
      # Test that offline configuration defaults to enabled
      offline_config_manager = OfflineConfigurationManager.new
      default_config = offline_config_manager.load_default_configuration

      # Verify offline mode is enabled by default
      if default_config[:offline_mode][:enabled] == true
        Print.info "✓ Offline mode is enabled by default"
      else
        Print.err "✗ Offline mode should be enabled by default"
        @failed += 1
        return
      end

      # Verify RAG defaults to offline
      if default_config[:rag][:offline_mode] == true
        Print.info "✓ RAG defaults to offline mode"
      else
        Print.err "✗ RAG should default to offline mode"
        @failed += 1
        return
      end

      # Verify CAG defaults to offline
      if default_config[:cag][:offline_mode] == true
        Print.info "✓ CAG defaults to offline mode"
      else
        Print.err "✗ CAG should default to offline mode"
        @failed += 1
        return
      end

      Print.info "✓ All offline defaults are correct"
      @passed += 1
    rescue => e
      Print.err "✗ Test failed with error: #{e.message}"
      @failed += 1
    end
  end

  def test_configuration_structure
    Print.info "\nTest 2: Configuration structure validation"
    Print.info "-" * 40

    begin
      offline_config_manager = OfflineConfigurationManager.new
      default_config = offline_config_manager.load_default_configuration

      # Test RAG configuration structure
      rag_config = default_config[:rag]
      required_rag_keys = [:offline_mode, :vector_db, :embedding_service, :document_preprocessing]

      missing_rag_keys = required_rag_keys - rag_config.keys
      if missing_rag_keys.empty?
        Print.info "✓ RAG configuration structure is complete"
      else
        Print.err "✗ Missing RAG configuration keys: #{missing_rag_keys.join(', ')}"
        @failed += 1
        return
      end

      # Test CAG configuration structure
      cag_config = default_config[:cag]
      required_cag_keys = [:offline_mode, :knowledge_graph, :entity_extractor, :graph_traversal]

      missing_cag_keys = required_cag_keys - cag_config.keys
      if missing_cag_keys.empty?
        Print.info "✓ CAG configuration structure is complete"
      else
        Print.err "✗ Missing CAG configuration keys: #{missing_cag_keys.join(', ')}"
        @failed += 1
        return
      end

      # Test vector_db configuration
      vector_db_config = rag_config[:vector_db]
      if vector_db_config[:provider] == "chromadb"
        Print.info "✓ RAG vector_db defaults to chromadb provider"
      else
        Print.err "✗ RAG vector_db should default to chromadb"
        @failed += 1
        return
      end

      # Test knowledge_graph configuration
      knowledge_graph_config = cag_config[:knowledge_graph]
      if knowledge_graph_config[:provider] == "in_memory"
        Print.info "✓ CAG knowledge_graph defaults to in_memory provider"
      else
        Print.err "✗ CAG knowledge_graph should default to in_memory"
        @failed += 1
        return
      end

      Print.info "✓ Configuration structure validation passed"
      @passed += 1
    rescue => e
      Print.err "✗ Test failed with error: #{e.message}"
      @failed += 1
    end
  end

  def test_command_line_help
    Print.info "\nTest 3: Command line help validation"
    Print.info "-" * 40

    begin
      # Read the main hackerbot.rb file to check for new options
      hackerbot_content = File.read('./hackerbot.rb')

      # Check for new command line options in the usage function
      required_options = [
        '--enable-rag-cag',
        '--rag-only',
        '--cag-only',
        '--offline',
        '--online'
      ]

      missing_options = []
      required_options.each do |option|
        unless hackerbot_content.include?(option)
          missing_options << option
        end
      end

      if missing_options.empty?
        Print.info "✓ All required command line options are present in hackerbot.rb"
      else
        Print.err "✗ Missing command line options: #{missing_options.join(', ')}"
        @failed += 1
        return
      end

      # Check for option processing
      option_processing_checks = [
        "'--enable-rag-cag'",
        "'--rag-only'",
        "'--cag-only'",
        "'--offline'",
        "'--online'"
      ]

      missing_processing = []
      option_processing_checks.each do |check|
        unless hackerbot_content.include?(check)
          missing_processing << check
        end
      end

      if missing_processing.empty?
        Print.info "✓ All command line options have processing logic"
      else
        Print.err "✗ Missing processing logic for: #{missing_processing.join(', ')}"
        @failed += 1
        return
      end

      # Check for variable initialization
      variable_checks = [
        '$enable_rag_cag = true',
        '$rag_only = false',
        '$cag_only = false',
        '$offline_mode'
      ]

      missing_variables = []
      variable_checks.each do |check|
        unless hackerbot_content.include?(check)
          missing_variables << check
        end
      end

      if missing_variables.empty?
        Print.info "✓ All required variables are initialized"
      else
        Print.err "✗ Missing variable initialization: #{missing_variables.join(', ')}"
        @failed += 1
        return
      end

      Print.info "✓ Command line help validation passed"
      @passed += 1
    rescue => e
      Print.err "✗ Test failed with error: #{e.message}"
      @failed += 1
    end
  end
end

# Run the tests
if __FILE__ == $0
  test_runner = TestOfflineIndividualControl.new
  success = test_runner.run_tests

  if success
    Print.info "\n🎉 All tests passed! Offline default and individual control are working correctly."
    exit 0
  else
    Print.err "\n❌ Some tests failed. Please check the implementation."
    exit 1
  end
end
