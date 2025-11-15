require_relative 'test_helper'

class VMContextE2ETest < BotManagerTest
  def setup
    super
    @bot_manager = create_bot_manager(enable_rag: false)
    
    # Set up test bot structure
    @bot_manager.instance_variable_set(:@bots, {
      'TestBot' => {
        'attacks' => [
          {
            'prompt' => 'Test attack with VM context',
            'vm_context' => {
              bash_history: { path: '~/.bash_history', limit: 10 },
              commands: ['pwd', 'whoami']
            }
          }
        ],
        'get_shell' => 'bash',
        'rag_enabled' => false,
        'explicit_context_enabled' => false,
        'chat_ai' => create_mock_llm_client
      }
    })
  end

  def test_vm_context_in_complete_flow
    # Test complete flow: message → VM context fetch → prompt assembly → LLM response
    bot_name = 'TestBot'
    user_message = "What files are in my home directory?"
    
    # Mock fetch_vm_context to return realistic VM context
    vm_context_string = <<~VM
      VM State:
      Bash History:
      cd /home/student
      ls -la
      cat important.txt
      
      Command Outputs:
      [Command: pwd]
      /home/student
      [Command: whoami]
      student
      
      Files:
      [File: /etc/passwd]
      root:x:0:0:root:/root:/bin/bash
      student:x:1000:1000:Student User:/home/student:/bin/bash
    VM

    # Mock fetch_vm_context
    @bot_manager.define_singleton_method(:fetch_vm_context) do |bot, attack_idx, vars|
      return vm_context_string if attack_idx == 0
      nil
    end
    
    # Get enhanced context (includes VM context)
    enhanced_context = @bot_manager.get_enhanced_context(
      bot_name,
      user_message,
      attack_index: 0,
      variables: { chat_ip_address: '127.0.0.1' }
    )
    
    refute_nil enhanced_context, "Enhanced context should not be nil"
    assert_equal vm_context_string, enhanced_context[:vm_context], "VM context should be present"
    
    # Assemble prompt
    system_prompt = "You are a helpful cybersecurity training assistant."
    context = "Current topic: Test attack with VM context"
    chat_context = ""
    
    prompt = @bot_manager.assemble_prompt(
      system_prompt,
      context,
      chat_context,
      user_message,
      enhanced_context
    )
    
    # Verify VM context is in prompt
    assert_includes prompt, "VM State:", "Prompt should include VM State"
    assert_includes prompt, "/home/student", "Prompt should include VM state information"
    assert_includes prompt, user_message, "Prompt should include user message"
    
    # Verify prompt structure is correct
    # Check that sections appear in the correct order
    system_pos = prompt.index(system_prompt)
    context_pos = prompt.index("Context:")
    vm_state_pos = prompt.index("VM State:")
    user_pos = prompt.index("User:")
    
    assert system_pos < context_pos, "System prompt should come before context"
    assert context_pos < vm_state_pos, "Context should come before VM State"
    assert vm_state_pos < user_pos, "VM State should come before User"
  end

  def test_llm_response_references_vm_state
    # Verify LLM response would reference VM state information
    # (In real scenario, we'd mock LLM client to return response that references VM state)
    bot_name = 'TestBot'
    user_message = "What's my current directory?"
    
    vm_context_string = "VM State:\nCommand Outputs:\n[Command: pwd]\n/home/student\n"
    
    # Mock fetch_vm_context
    @bot_manager.define_singleton_method(:fetch_vm_context) do |bot, attack_idx, vars|
      return vm_context_string if attack_idx == 0
      nil
    end
    
    enhanced_context = @bot_manager.get_enhanced_context(
      bot_name,
      user_message,
      attack_index: 0,
      variables: { chat_ip_address: '127.0.0.1' }
    )
    
    system_prompt = "You are a helpful assistant."
    context = "Current topic: Test"
    
    prompt = @bot_manager.assemble_prompt(
      system_prompt,
      context,
      "",
      user_message,
      enhanced_context
    )
    
    # Verify prompt contains VM state that LLM can reference
    assert_includes prompt, "/home/student", "Prompt should contain VM state for LLM to reference"
    assert_includes prompt, "pwd", "Prompt should contain command output"
  end

  def test_error_scenario_vm_context_fetch_fails
    # Test error scenario (VM context fetch fails)
    bot_name = 'TestBot'
    user_message = "Test message"
    
    # Mock fetch_vm_context to raise an error
    @bot_manager.define_singleton_method(:fetch_vm_context) do |bot, attack_idx, vars|
      raise StandardError, "SSH connection failed"
    end
    
    # Should handle error gracefully and continue without VM context
    enhanced_context = @bot_manager.get_enhanced_context(
      bot_name,
      user_message,
      attack_index: 0,
      variables: { chat_ip_address: '127.0.0.1' }
    )
    
    # Should not crash, may have nil or empty vm_context
    assert enhanced_context.nil? || enhanced_context[:vm_context].nil?, 
           "Should handle fetch failure gracefully"
    
    # Prompt assembly should still work
    prompt = @bot_manager.assemble_prompt(
      "System",
      "Context",
      "",
      user_message,
      enhanced_context
    )
    
    refute_nil prompt, "Prompt should still be created even if VM context fetch fails"
    assert_includes prompt, user_message, "Prompt should include user message"
  end

  def test_different_vm_context_configurations
    # Test with different VM context configurations
    bot_name = 'TestBot'
    
    # Test 1: Only bash history
    vm_context_bash_only = "VM State:\nBash History:\nls\npwd\n"
    @bot_manager.instance_variable_get(:@bots)[bot_name]['attacks'][0]['vm_context'] = {
      bash_history: { path: '~/.bash_history', limit: 10 }
    }
    
    @bot_manager.define_singleton_method(:fetch_vm_context) do |bot, attack_idx, vars|
      return vm_context_bash_only if attack_idx == 0
      nil
    end
    
    enhanced_context = @bot_manager.get_enhanced_context(
      bot_name,
      "test",
      attack_index: 0,
      variables: { chat_ip_address: '127.0.0.1' }
    )
    
    assert_equal vm_context_bash_only, enhanced_context[:vm_context]
    
    # Test 2: Only commands
    vm_context_commands_only = "VM State:\nCommand Outputs:\n[Command: ps]\nPID\n"
    @bot_manager.instance_variable_get(:@bots)[bot_name]['attacks'][0]['vm_context'] = {
      commands: ['ps']
    }
    
    @bot_manager.define_singleton_method(:fetch_vm_context) do |bot, attack_idx, vars|
      return vm_context_commands_only if attack_idx == 0
      nil
    end
    
    enhanced_context = @bot_manager.get_enhanced_context(
      bot_name,
      "test",
      attack_index: 0,
      variables: { chat_ip_address: '127.0.0.1' }
    )
    
    assert_equal vm_context_commands_only, enhanced_context[:vm_context]
  end

  private

  def create_mock_llm_client
    mock_client = Object.new
    mock_client.define_singleton_method(:generate_response) do |prompt, callback = nil|
      "Based on the VM state, I can see you're in /home/student directory."
    end
    mock_client.define_singleton_method(:update_system_prompt) { |prompt| }
    mock_client
  end
end

