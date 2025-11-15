#!/usr/bin/env ruby

require 'minitest/autorun'
require_relative 'test_helper'
require 'tempfile'

# Integration tests for explicit knowledge retrieval during attack stages
class TestExplicitKnowledgeRetrieval < BotManagerTest
  def setup
    super
    # Create a bot manager with RAG enabled
    # Note: BotManager.new uses positional parameters for enable_rag and rag_config
    rag_config = {
      enable_rag: true,
      enable_knowledge_sources: true,
      knowledge_base_name: 'test_cybersecurity',
      auto_initialization: false  # Don't auto-initialize to speed up tests
    }
    @bot_manager = BotManager.new(
      @irc_server,
      @llm_provider,
      @ollama_host,
      @ollama_port,
      @ollama_model,
      @openai_api_key,
      nil,  # openai_base_url
      @vllm_host,
      @vllm_port,
      @sglang_host,
      @sglang_port,
      true,  # enable_rag
      rag_config
    )
  end

  def teardown
    super
    # Cleanup any test config files
    Dir.glob('config/test_explicit_*.xml').each do |file|
      File.delete(file) if File.exist?(file)
    end
    cleanup_temp_config if @temp_config_path
  end

  # Test retrieval of man pages during attack stage
  def test_retrieve_man_pages_during_attack
    config_xml = <<~XML
      <hackerbot>
        <name>TestManPages</name>
        <llm_provider>ollama</llm_provider>
        <ollama_model>gemma3:1b</ollama_model>
        <rag_cag_enabled>true</rag_cag_enabled>
        <rag_enabled>true</rag_enabled>
        <system_prompt>You are a test bot.</system_prompt>
        <get_shell>false</get_shell>
        <messages>
          <greeting>Hello!</greeting>
          <help>Help message.</help>
          <say_ready>Ready!</say_ready>
          <next>Next</next>
          <previous>Previous</previous>
        </messages>
        <attacks>
          <attack>
            <prompt>Test attack with man pages</prompt>
            <context_config>
              <man_pages>
                <page>ls</page>
                <page>printf</page>
              </man_pages>
            </context_config>
          </attack>
        </attacks>
      </hackerbot>
    XML

    # Write config file to config directory for read_bots to find
    config_path = File.join('config', 'test_explicit_man_pages.xml')
    File.write(config_path, config_xml)
    
    begin
      # Read bots
      TestUtils.suppress_print_output do
        @bot_manager.read_bots
      end

      bot_name = 'TestManPages'
      bots = @bot_manager.instance_variable_get(:@bots)
      assert bots.key?(bot_name), "Bot should be loaded. Found bots: #{bots.keys.inspect}"

      # Get enhanced context with attack index
      user_message = "How do I list files?"
      attack_index = 0
      
      enhanced_context = @bot_manager.get_enhanced_context(bot_name, user_message, attack_index: attack_index)
      
      refute_nil enhanced_context, "Enhanced context should not be nil"
      assert enhanced_context[:has_explicit], "Should have explicit knowledge"
      refute enhanced_context[:explicit_context].empty?, "Explicit context should not be empty"
      assert_equal 2, enhanced_context[:explicit_context].length, "Should retrieve 2 man pages"
      
      # Verify source attribution
      assert enhanced_context[:combined_context].include?("Source:"), "Should include source attribution"
      assert enhanced_context[:combined_context].include?("man page"), "Should mention man page"
    ensure
      # Cleanup config file
      File.delete(config_path) if File.exist?(config_path)
    end
  end

  # Test retrieval of documents during attack stage
  def test_retrieve_documents_during_attack
    # Create a temporary markdown file for testing
    temp_doc = Tempfile.new(['test_doc', '.md'])
    temp_doc.write("# Test Document\n\nThis is a test document for explicit knowledge retrieval.")
    temp_doc.close

    config_xml = <<~XML
      <hackerbot>
        <name>TestDocuments</name>
        <llm_provider>ollama</llm_provider>
        <ollama_model>gemma3:1b</ollama_model>
        <rag_cag_enabled>true</rag_cag_enabled>
        <rag_enabled>true</rag_enabled>
        <system_prompt>You are a test bot.</system_prompt>
        <get_shell>false</get_shell>
        <messages>
          <greeting>Hello!</greeting>
          <help>Help message.</help>
          <say_ready>Ready!</say_ready>
        </messages>
        <attacks>
          <attack>
            <prompt>Test attack with documents</prompt>
            <context_config>
              <documents>
                <doc>#{temp_doc.path}</doc>
              </documents>
            </context_config>
          </attack>
        </attacks>
      </hackerbot>
    XML

    # Write config file to config directory
    config_path = File.join('config', 'test_explicit_documents.xml')
    File.write(config_path, config_xml)
    
    begin
      TestUtils.suppress_print_output do
        @bot_manager.read_bots
      end

      bot_name = 'TestDocuments'
      user_message = "What does the document say?"
      attack_index = 0
      
      enhanced_context = @bot_manager.get_enhanced_context(bot_name, user_message, attack_index: attack_index)
      
      refute_nil enhanced_context, "Enhanced context should not be nil"
      assert enhanced_context[:has_explicit], "Should have explicit knowledge"
      assert_equal 1, enhanced_context[:explicit_context].length, "Should retrieve 1 document"
      
      # Verify source attribution
      assert enhanced_context[:combined_context].include?("Source:"), "Should include source attribution"
      assert enhanced_context[:combined_context].include?("document"), "Should mention document"
    ensure
      File.delete(config_path) if File.exist?(config_path)
      temp_doc.unlink if temp_doc
    end
  end

  # Test retrieval of MITRE techniques during attack stage
  def test_retrieve_mitre_techniques_during_attack
    config_xml = <<~XML
      <hackerbot>
        <name>TestMITRE</name>
        <llm_provider>ollama</llm_provider>
        <ollama_model>gemma3:1b</ollama_model>
        <rag_cag_enabled>true</rag_cag_enabled>
        <rag_enabled>true</rag_enabled>
        <system_prompt>You are a test bot.</system_prompt>
        <get_shell>false</get_shell>
        <messages>
          <greeting>Hello!</greeting>
          <help>Help message.</help>
          <say_ready>Ready!</say_ready>
        </messages>
        <attacks>
          <attack>
            <prompt>Test attack with MITRE techniques</prompt>
            <context_config>
              <mitre_techniques>
                <technique>T1003</technique>
                <technique>T1059.001</technique>
              </mitre_techniques>
            </context_config>
          </attack>
        </attacks>
      </hackerbot>
    XML

    config_path = File.join('config', 'test_explicit_mitre.xml')
    File.write(config_path, config_xml)
    
    begin
      TestUtils.suppress_print_output do
        @bot_manager.read_bots
      end

      bot_name = 'TestMITRE'
      user_message = "What is credential dumping?"
      attack_index = 0
      
      enhanced_context = @bot_manager.get_enhanced_context(bot_name, user_message, attack_index: attack_index)
      
      refute_nil enhanced_context, "Enhanced context should not be nil"
      assert enhanced_context[:has_explicit], "Should have explicit knowledge"
      assert_equal 2, enhanced_context[:explicit_context].length, "Should retrieve 2 MITRE techniques"
      
      # Verify source attribution
      assert enhanced_context[:combined_context].include?("Source:"), "Should include source attribution"
      assert enhanced_context[:combined_context].include?("MITRE ATT&CK"), "Should mention MITRE ATT&CK"
    ensure
      File.delete(config_path) if File.exist?(config_path)
    end
  end

  # Test combination of all three types
  def test_retrieve_all_types_combined
    temp_doc = Tempfile.new(['test_doc', '.md'])
    temp_doc.write("# Test Document\n\nTest content.")
    temp_doc.close

    config_xml = <<~XML
      <hackerbot>
        <name>TestCombined</name>
        <llm_provider>ollama</llm_provider>
        <ollama_model>gemma3:1b</ollama_model>
        <rag_cag_enabled>true</rag_cag_enabled>
        <rag_enabled>true</rag_enabled>
        <system_prompt>You are a test bot.</system_prompt>
        <get_shell>false</get_shell>
        <messages>
          <greeting>Hello!</greeting>
          <help>Help message.</help>
          <say_ready>Ready!</say_ready>
        </messages>
        <attacks>
          <attack>
            <prompt>Test attack with all types</prompt>
            <context_config>
              <man_pages>
                <page>ls</page>
              </man_pages>
              <documents>
                <doc>#{temp_doc.path}</doc>
              </documents>
              <mitre_techniques>
                <technique>T1003</technique>
              </mitre_techniques>
            </context_config>
          </attack>
        </attacks>
      </hackerbot>
    XML

    config_path = File.join('config', 'test_explicit_combined.xml')
    File.write(config_path, config_xml)
    
    begin
      TestUtils.suppress_print_output do
        @bot_manager.read_bots
      end

      bot_name = 'TestCombined'
      user_message = "Tell me about these tools"
      attack_index = 0
      
      enhanced_context = @bot_manager.get_enhanced_context(bot_name, user_message, attack_index: attack_index)
      
      refute_nil enhanced_context, "Enhanced context should not be nil"
      assert enhanced_context[:has_explicit], "Should have explicit knowledge"
      assert_equal 3, enhanced_context[:explicit_context].length, "Should retrieve all 3 items"
    ensure
      File.delete(config_path) if File.exist?(config_path)
      temp_doc.unlink if temp_doc
    end
  end

  # Test retrieval with missing items (not found cases)
  def test_retrieve_with_missing_items
    config_xml = <<~XML
      <hackerbot>
        <name>TestMissing</name>
        <llm_provider>ollama</llm_provider>
        <ollama_model>gemma3:1b</ollama_model>
        <rag_cag_enabled>true</rag_cag_enabled>
        <rag_enabled>true</rag_enabled>
        <system_prompt>You are a test bot.</system_prompt>
        <get_shell>false</get_shell>
        <messages>
          <greeting>Hello!</greeting>
          <help>Help message.</help>
          <say_ready>Ready!</say_ready>
        </messages>
        <attacks>
          <attack>
            <prompt>Test attack with missing items</prompt>
            <context_config>
              <man_pages>
                <page>nonexistent_command_xyz123</page>
                <page>ls</page>
              </man_pages>
              <mitre_techniques>
                <technique>T99999</technique>
                <technique>T1003</technique>
              </mitre_techniques>
            </context_config>
          </attack>
        </attacks>
      </hackerbot>
    XML

    config_path = File.join('config', 'test_explicit_missing.xml')
    File.write(config_path, config_xml)
    
    begin
      TestUtils.suppress_print_output do
        @bot_manager.read_bots
      end

      bot_name = 'TestMissing'
      user_message = "What about these?"
      attack_index = 0
      
      enhanced_context = @bot_manager.get_enhanced_context(bot_name, user_message, attack_index: attack_index)
      
      refute_nil enhanced_context, "Enhanced context should not be nil"
      assert enhanced_context[:has_explicit], "Should have explicit knowledge"
      # Should retrieve 2 items (ls and T1003), skipping the missing ones
      assert_equal 2, enhanced_context[:explicit_context].length, "Should retrieve only found items"
    ensure
      File.delete(config_path) if File.exist?(config_path)
    end
  end

  # Test that correct attack's context_config is used
  def test_correct_attack_context_config_used
    config_xml = <<~XML
      <hackerbot>
        <name>TestMultiAttack</name>
        <llm_provider>ollama</llm_provider>
        <ollama_model>gemma3:1b</ollama_model>
        <rag_cag_enabled>true</rag_cag_enabled>
        <rag_enabled>true</rag_enabled>
        <system_prompt>You are a test bot.</system_prompt>
        <get_shell>false</get_shell>
        <messages>
          <greeting>Hello!</greeting>
          <help>Help message.</help>
          <say_ready>Ready!</say_ready>
        </messages>
        <attacks>
          <attack>
            <prompt>Attack 1</prompt>
            <context_config>
              <man_pages>
                <page>ls</page>
              </man_pages>
            </context_config>
          </attack>
          <attack>
            <prompt>Attack 2</prompt>
            <context_config>
              <mitre_techniques>
                <technique>T1003</technique>
              </mitre_techniques>
            </context_config>
          </attack>
        </attacks>
      </hackerbot>
    XML

    config_path = File.join('config', 'test_explicit_multi_attack.xml')
    File.write(config_path, config_xml)
    
    begin
      TestUtils.suppress_print_output do
        @bot_manager.read_bots
      end

      bot_name = 'TestMultiAttack'
      user_message = "Test message"
      
      # Test attack 0 (should have man page)
      enhanced_context_0 = @bot_manager.get_enhanced_context(bot_name, user_message, attack_index: 0)
      refute_nil enhanced_context_0, "Enhanced context 0 should not be nil"
      assert enhanced_context_0[:has_explicit], "Attack 0 should have explicit knowledge"
      assert_equal 1, enhanced_context_0[:explicit_context].length, "Attack 0 should retrieve 1 man page"
      assert enhanced_context_0[:combined_context].include?("man page"), "Should include man page"
      
      # Test attack 1 (should have MITRE technique)
      enhanced_context_1 = @bot_manager.get_enhanced_context(bot_name, user_message, attack_index: 1)
      refute_nil enhanced_context_1, "Enhanced context 1 should not be nil"
      assert enhanced_context_1[:has_explicit], "Attack 1 should have explicit knowledge"
      assert_equal 1, enhanced_context_1[:explicit_context].length, "Attack 1 should retrieve 1 MITRE technique"
      assert enhanced_context_1[:combined_context].include?("MITRE ATT&CK"), "Should include MITRE ATT&CK"
    ensure
      File.delete(config_path) if File.exist?(config_path)
    end
  end

  # Test attacks without context_config use existing RAG behavior
  def test_attacks_without_context_config_use_existing_rag
    config_xml = <<~XML
      <hackerbot>
        <name>TestNoContext</name>
        <llm_provider>ollama</llm_provider>
        <ollama_model>gemma3:1b</ollama_model>
        <rag_cag_enabled>true</rag_cag_enabled>
        <rag_enabled>true</rag_enabled>
        <system_prompt>You are a test bot.</system_prompt>
        <get_shell>false</get_shell>
        <messages>
          <greeting>Hello!</greeting>
          <help>Help message.</help>
          <say_ready>Ready!</say_ready>
        </messages>
        <attacks>
          <attack>
            <prompt>Attack without context_config</prompt>
          </attack>
        </attacks>
      </hackerbot>
    XML

    config_path = File.join('config', 'test_explicit_no_context.xml')
    File.write(config_path, config_xml)
    
    begin
      TestUtils.suppress_print_output do
        @bot_manager.read_bots
      end

      bot_name = 'TestNoContext'
      user_message = "Test message"
      attack_index = 0
      
      enhanced_context = @bot_manager.get_enhanced_context(bot_name, user_message, attack_index: attack_index)
      
      # Should not have explicit knowledge (enhanced_context may be nil if RAG not fully initialized, which is OK)
      if enhanced_context
        assert !enhanced_context[:has_explicit], "Should not have explicit knowledge"
      end
    ensure
      File.delete(config_path) if File.exist?(config_path)
    end
  end

  # Test backward compatibility - bots without context_config work unchanged
  def test_backward_compatibility_no_context_config
    config_xml = <<~XML
      <hackerbot>
        <name>TestBackwardCompat</name>
        <llm_provider>ollama</llm_provider>
        <ollama_model>gemma3:1b</ollama_model>
        <rag_cag_enabled>true</rag_cag_enabled>
        <rag_enabled>true</rag_enabled>
        <system_prompt>You are a test bot.</system_prompt>
        <get_shell>false</get_shell>
        <messages>
          <greeting>Hello!</greeting>
          <help>Help message.</help>
          <say_ready>Ready!</say_ready>
        </messages>
        <attacks>
          <attack>
            <prompt>Attack with no context config</prompt>
          </attack>
        </attacks>
      </hackerbot>
    XML

    config_path = File.join('config', 'test_explicit_backward_compat.xml')
    File.write(config_path, config_xml)
    
    begin
      TestUtils.suppress_print_output do
        @bot_manager.read_bots
      end

      bot_name = 'TestBackwardCompat'
      user_message = "Test message"
      
      # Calling without attack_index should work as before
      enhanced_context_no_index = @bot_manager.get_enhanced_context(bot_name, user_message)
      
      # Calling with attack_index but no context_config should also work
      enhanced_context_with_index = @bot_manager.get_enhanced_context(bot_name, user_message, attack_index: 0)
      
      # Both should work (may return nil if RAG not fully initialized, but shouldn't crash)
      assert_kind_of [Hash, NilClass], enhanced_context_no_index
      assert_kind_of [Hash, NilClass], enhanced_context_with_index
    ensure
      File.delete(config_path) if File.exist?(config_path)
    end
  end

  # Test that explicit context can work without RAG enabled
  def test_explicit_context_without_rag
    # Create bot manager with RAG disabled but explicit context enabled
    rag_config = {
      enable_rag: false,
      enable_explicit_context: true,
      knowledge_sources_config: [
        {
          type: 'mitre_attack',
          name: 'mitre_attack',
          enabled: true
        }
      ]
    }
    
    bot_manager = BotManager.new(
      @irc_server,
      @llm_provider,
      @ollama_host,
      @ollama_port,
      @ollama_model,
      @openai_api_key,
      nil,
      @vllm_host,
      @vllm_port,
      @sglang_host,
      @sglang_port,
      false,  # enable_rag
      rag_config
    )
    
    # Verify explicit context is enabled
    assert bot_manager.send(:explicit_context_enabled?), "Explicit context should be enabled"
    
    # Verify RAG is disabled
    refute bot_manager.instance_variable_get(:@enable_rag), "RAG should be disabled"
    assert_nil bot_manager.instance_variable_get(:@rag_manager), "RAG manager should be nil"
    
    # Verify knowledge source manager is initialized
    ksm = bot_manager.instance_variable_get(:@knowledge_source_manager)
    assert ksm, "Knowledge source manager should be initialized for explicit context"
  end

  private

  def assert_kind_of(expected_classes, actual)
    assert expected_classes.include?(actual.class), "Expected one of #{expected_classes}, got #{actual.class}"
  end
end

