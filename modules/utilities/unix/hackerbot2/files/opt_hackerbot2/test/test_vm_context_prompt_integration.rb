require_relative 'test_helper'
require 'fileutils'

class VMContextPromptIntegrationTest < BotManagerTest
  def setup
    super
    @bot_manager = create_bot_manager(enable_rag: false)
    
    # Create test config directory
    @test_config_dir = File.join(Dir.tmpdir, "hackerbot_test_vm_prompt_#{Time.now.to_i}")
    FileUtils.mkdir_p(@test_config_dir) unless File.exist?(@test_config_dir)
    
    # Set up test bot structure manually
    @bot_manager.instance_variable_set(:@bots, {
      'TestBot' => {
        'attacks' => [
          {
            'prompt' => 'Test attack with VM context',
            'vm_context' => {
              bash_history: { path: '~/.bash_history', limit: 10 }
            }
          },
          {
            'prompt' => 'Test attack without VM context'
          }
        ],
        'rag_enabled' => false,
        'explicit_context_enabled' => false
      }
    })
  end

  def teardown
    super
    FileUtils.rm_rf(@test_config_dir) if File.exist?(@test_config_dir)
  end

  def test_vm_context_in_enhanced_context
    # Test that VM context is included in get_enhanced_context return value
    bot_name = 'TestBot'
    
    # Mock fetch_vm_context to return test VM context
    vm_context_string = "VM State:\nBash History:\nls -la\npwd\n"
    
    @bot_manager.define_singleton_method(:fetch_vm_context) do |bot, attack_idx, vars|
      return vm_context_string if attack_idx == 0
      nil
    end
    
    enhanced_context = @bot_manager.get_enhanced_context(
      bot_name,
      "test message",
      attack_index: 0,
      variables: { chat_ip_address: '127.0.0.1' }
    )
    
    refute_nil enhanced_context, "Enhanced context should not be nil"
    assert enhanced_context.is_a?(Hash), "Enhanced context should be a hash"
    assert_equal vm_context_string, enhanced_context[:vm_context], "VM context should be present in enhanced context"
    assert_equal "test message", enhanced_context[:original_query], "Original query should be preserved"
  end

  def test_vm_context_not_included_when_attack_disabled
    # Test that VM context is not included when attack-level flag disables it
    bot_name = 'TestBot'
    
    # Set attack-level vm_context_enabled to false
    @bot_manager.instance_variable_get(:@bots)[bot_name]['attacks'][0]['vm_context_enabled'] = false
    
    enhanced_context = @bot_manager.get_enhanced_context(
      bot_name,
      "test message",
      attack_index: 0,
      variables: { chat_ip_address: '127.0.0.1' }
    )
    
    # Should not have vm_context key
    assert_nil enhanced_context&.dig(:vm_context), "VM context should not be present when disabled"
  end

  def test_vm_context_not_included_when_bot_disabled
    # Test that VM context is not included when bot-level flag disables it
    bot_name = 'TestBot'
    
    # Set bot-level vm_context_enabled to false
    @bot_manager.instance_variable_get(:@bots)[bot_name]['vm_context_enabled'] = false
    
    enhanced_context = @bot_manager.get_enhanced_context(
      bot_name,
      "test message",
      attack_index: 0,
      variables: { chat_ip_address: '127.0.0.1' }
    )
    
    # Should not have vm_context key
    assert_nil enhanced_context&.dig(:vm_context), "VM context should not be present when bot disabled"
  end

  def test_vm_context_in_assembled_prompt
    # Test that VM context appears in assembled prompt string
    system_prompt = "You are a helpful assistant."
    context = "Current topic: Test attack"
    chat_context = ""
    user_message = "Hello"
    
    vm_context_string = "VM State:\nBash History:\nls -la\n"
    enhanced_context = {
      original_query: user_message,
      vm_context: vm_context_string
    }
    
    prompt = @bot_manager.assemble_prompt(system_prompt, context, chat_context, user_message, enhanced_context)
    
    assert_includes prompt, "VM State:", "Prompt should include VM State header"
    assert_includes prompt, "Bash History:", "Prompt should include bash history section"
    
    # Verify order: System Prompt -> Context -> VM State -> User Message
    system_idx = prompt.index(system_prompt)
    context_idx = prompt.index("Context:")
    vm_state_idx = prompt.index("VM State:")
    user_idx = prompt.index("User:")
    
    assert system_idx < context_idx, "System prompt should come before context"
    assert context_idx < vm_state_idx, "Context should come before VM State"
    assert vm_state_idx < user_idx, "VM State should come before user message"
  end

  def test_context_ordering_is_correct
    # Verify VM context appears in correct position: after attack context, before RAG/enhanced context
    system_prompt = "System"
    context = "Attack context"
    chat_context = "Chat history"
    user_message = "User message"
    
    vm_context = "VM State:\nTest VM context\n"
    
    enhanced_context = {
      vm_context: vm_context,
      combined_context: "RAG context"
    }
    
    prompt = @bot_manager.assemble_prompt(system_prompt, context, chat_context, user_message, enhanced_context)
    
    # Find positions
    system_pos = prompt.index(system_prompt)
    context_pos = prompt.index("Context:")
    vm_pos = prompt.index("VM State:")
    enhanced_pos = prompt.index("Enhanced Context:")
    chat_pos = prompt.index("Chat History:")
    user_pos = prompt.index("User:")
    
    assert system_pos < context_pos, "System should come first"
    assert context_pos < vm_pos, "Context should come before VM State"
    assert vm_pos < enhanced_pos, "VM State should come before Enhanced Context"
    assert enhanced_pos < chat_pos, "Enhanced Context should come before Chat History"
    assert chat_pos < user_pos, "Chat History should come before User"
  end

  def test_vm_context_without_config
    # Test that prompts without VM context work unchanged
    system_prompt = "System"
    context = "Attack"
    chat_context = "History"
    user_message = "Message"
    
    enhanced_context = nil
    
    prompt = @bot_manager.assemble_prompt(system_prompt, context, chat_context, user_message, enhanced_context)
    
    assert_includes prompt, system_prompt, "Should include system prompt"
    assert_includes prompt, context, "Should include context"
    assert_includes prompt, chat_context, "Should include chat context"
    assert_includes prompt, user_message, "Should include user message"
    refute_includes prompt, "VM State:", "Should not include VM State when no VM context"
  end

  def test_vm_context_truncation_when_too_long
    # Test that VM context is truncated when prompt exceeds max_context_length
    system_prompt = "System"
    context = "Context"
    chat_context = ""
    user_message = "Message"
    
    # Create very long VM context
    long_vm_context = "VM State:\n" + ("Bash History:\n" + "ls -la\n" * 1000)
    
    enhanced_context = {
      vm_context: long_vm_context
    }
    
    # Mock get_max_context_length to return a small value
    @bot_manager.define_singleton_method(:get_max_context_length) { 1000 }
    
    prompt = @bot_manager.assemble_prompt(system_prompt, context, chat_context, user_message, enhanced_context)
    
    # Prompt should be truncated (allowing some overhead)
    assert prompt.length <= 1500, "Prompt should be close to max length (allowing small overhead)"
    assert_includes prompt, "VM State:", "Should still include VM State header"
    assert_includes prompt, "... (VM context truncated", "Should indicate truncation"
  end
end
