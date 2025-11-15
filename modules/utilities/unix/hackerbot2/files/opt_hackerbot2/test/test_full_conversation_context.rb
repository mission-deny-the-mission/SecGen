require_relative 'test_helper'
require 'stringio'

class TestFullConversationContext < BotManagerTest
  def setup
    super
    @bot_manager = create_bot_manager
    @bot_name = 'TestBot'
    @user_id = 'alice'
    @channel = "#TestBot"
  end

  def test_get_chat_context_returns_complete_conversation_thread
    # Capture a conversation sequence
    @bot_manager.capture_irc_message(@bot_name, @user_id, 'Hello bot', @channel)
    @bot_manager.capture_irc_message(@bot_name, @bot_name, 'Hello! How can I help?', @channel, :bot_llm_response, true)
    @bot_manager.capture_irc_message(@bot_name, @user_id, 'What is SQL injection?', @channel)
    @bot_manager.capture_irc_message(@bot_name, @bot_name, 'SQL injection is...', @channel, :bot_llm_response, true)
    
    context = @bot_manager.get_chat_context(@bot_name, @user_id)
    
    # Should include all messages in chronological order
    assert_includes context, 'User alice:'
    assert_includes context, 'Bot:'
    assert_includes context, 'Hello bot'
    assert_includes context, 'Hello! How can I help?'
    assert_includes context, 'What is SQL injection?'
    assert_includes context, 'SQL injection is...'
    
    # Verify chronological order (earlier messages should appear first)
    hello_pos = context.index('Hello bot')
    response_pos = context.index('Hello! How can I help?')
    sql_question_pos = context.index('What is SQL injection?')
    
    assert hello_pos < response_pos, "User message should appear before bot response"
    assert response_pos < sql_question_pos, "Bot response should appear before next user message"
  end

  def test_get_chat_context_formats_speakers_clearly
    @bot_manager.capture_irc_message(@bot_name, @user_id, 'Hello', @channel)
    @bot_manager.capture_irc_message(@bot_name, @bot_name, 'Hi there!', @channel, :bot_llm_response, true)
    
    context = @bot_manager.get_chat_context(@bot_name, @user_id)
    
    # Verify speaker identification format
    assert_match(/User #{@user_id}:/, context)
    assert_match(/Bot:/, context)
  end

  def test_get_chat_context_preserves_chronological_order
    # Capture messages with small delays to ensure different timestamps
    @bot_manager.capture_irc_message(@bot_name, @user_id, 'Message 1', @channel)
    sleep(0.01)
    @bot_manager.capture_irc_message(@bot_name, @bot_name, 'Response 1', @channel, :bot_llm_response, true)
    sleep(0.01)
    @bot_manager.capture_irc_message(@bot_name, @user_id, 'Message 2', @channel)
    sleep(0.01)
    @bot_manager.capture_irc_message(@bot_name, @bot_name, 'Response 2', @channel, :bot_llm_response, true)
    
    context = @bot_manager.get_chat_context(@bot_name, @user_id)
    
    # Verify order is chronological
    msg1_pos = context.index('Message 1')
    resp1_pos = context.index('Response 1')
    msg2_pos = context.index('Message 2')
    resp2_pos = context.index('Response 2')
    
    assert msg1_pos < resp1_pos, "Message 1 should appear before Response 1"
    assert resp1_pos < msg2_pos, "Response 1 should appear before Message 2"
    assert msg2_pos < resp2_pos, "Message 2 should appear before Response 2"
  end

  def test_get_chat_context_includes_full_conversation_in_prompt
    @bot_manager.capture_irc_message(@bot_name, @user_id, 'First message', @channel)
    @bot_manager.capture_irc_message(@bot_name, @bot_name, 'First response', @channel, :bot_llm_response, true)
    @bot_manager.capture_irc_message(@bot_name, @user_id, 'Second message', @channel)
    
    chat_context = @bot_manager.get_chat_context(@bot_name, @user_id, exclude_message: 'Second message')
    prompt = @bot_manager.assemble_prompt('System prompt', '', chat_context, 'Second message')
    
    # Verify full conversation is included in prompt
    assert_includes prompt, 'Chat History:'
    assert_includes prompt, 'First message'
    assert_includes prompt, 'First response'
    assert_includes prompt, 'Second message'  # Current message is in prompt separately
  end

  def test_get_chat_context_configurable_message_filtering
    @bot_manager.capture_irc_message(@bot_name, @user_id, 'User message', @channel)
    @bot_manager.capture_irc_message(@bot_name, @bot_name, 'LLM response', @channel, :bot_llm_response, true)
    @bot_manager.capture_irc_message(@bot_name, @bot_name, 'Command response', @channel, :bot_command_response, true)
    @bot_manager.capture_irc_message(@bot_name, 'system', 'System message', @channel, :system_message)
    
    # Test filtering to include only user messages and LLM responses
    context = @bot_manager.get_chat_context(@bot_name, @user_id, include_types: [:user_message, :bot_llm_response])
    
    assert_includes context, 'User message'
    assert_includes context, 'LLM response'
    refute_includes context, 'Command response'
    refute_includes context, 'System message'
    
    # Test including command responses too
    context_all = @bot_manager.get_chat_context(@bot_name, @user_id, include_types: [:user_message, :bot_llm_response, :bot_command_response])
    
    assert_includes context_all, 'User message'
    assert_includes context_all, 'LLM response'
    assert_includes context_all, 'Command response'
    refute_includes context_all, 'System message'
  end

  def test_get_chat_context_context_length_management
    # Create many messages
    30.times do |i|
      @bot_manager.capture_irc_message(@bot_name, @user_id, "Message #{i}", @channel)
      @bot_manager.capture_irc_message(@bot_name, @bot_name, "Response #{i}", @channel, :bot_llm_response, true)
    end
    
    # Get context without length limit
    full_context = @bot_manager.get_chat_context(@bot_name, @user_id)
    full_length = full_context.length
    
    # Get context with length limit
    limited_context = @bot_manager.get_chat_context(@bot_name, @user_id, max_context_length: 500)
    
    assert limited_context.length <= 500 + 100, "Context should be truncated (allowing some buffer for truncation marker)"
    assert limited_context.length < full_length, "Limited context should be shorter than full context"
    
    # Verify truncation marker is present
    if limited_context.length < full_length
      assert_includes limited_context, '... (earlier messages truncated) ...'
    end
    
    # Verify most recent messages are included
    assert_includes limited_context, 'Message 29'
    assert_includes limited_context, 'Response 29'
  end

  def test_get_chat_context_excludes_current_message
    @bot_manager.capture_irc_message(@bot_name, @user_id, 'Previous message', @channel)
    @bot_manager.capture_irc_message(@bot_name, @bot_name, 'Previous response', @channel, :bot_llm_response, true)
    @bot_manager.capture_irc_message(@bot_name, @user_id, 'Current message', @channel)
    
    # Get context excluding current message
    context = @bot_manager.get_chat_context(@bot_name, @user_id, exclude_message: 'Current message')
    
    assert_includes context, 'Previous message'
    assert_includes context, 'Previous response'
    refute_includes context, 'Current message'
  end

  def test_get_chat_context_backward_compatibility_with_traditional_history
    # Add to traditional chat history
    @bot_manager.add_to_history(@bot_name, @user_id, 'User message', 'Assistant response')
    
    # Get context (should fall back to traditional format when no IRC history)
    context = @bot_manager.get_chat_context(@bot_name, @user_id)
    
    assert_includes context, 'User:'
    assert_includes context, 'Assistant:'
    assert_includes context, 'User message'
    assert_includes context, 'Assistant response'
  end

  def test_get_chat_context_per_channel_mode
    # Switch to per_channel mode
    @bot_manager.instance_variable_set(:@message_storage_mode, :per_channel)
    
    @bot_manager.capture_irc_message(@bot_name, @user_id, 'User message', @channel)
    @bot_manager.capture_irc_message(@bot_name, @bot_name, 'Bot response', @channel, :bot_llm_response, true)
    
    # In per_channel mode, context should include all messages from the channel
    context = @bot_manager.get_chat_context(@bot_name, @user_id)
    
    assert_includes context, 'User message'
    assert_includes context, 'Bot response'
    
    # Reset to per_user mode
    @bot_manager.instance_variable_set(:@message_storage_mode, :per_user)
  end

  def test_get_chat_context_multi_user_conversation_in_per_channel_mode
    # Switch to per_channel mode
    @bot_manager.instance_variable_set(:@message_storage_mode, :per_channel)
    
    @bot_manager.capture_irc_message(@bot_name, 'alice', 'Hello from alice', @channel)
    @bot_manager.capture_irc_message(@bot_name, @bot_name, 'Bot response', @channel, :bot_llm_response, true)
    @bot_manager.capture_irc_message(@bot_name, 'bob', 'Hello from bob', @channel)
    
    # Context should include all users' messages
    context = @bot_manager.get_chat_context(@bot_name, 'alice')
    
    assert_includes context, 'User alice:'
    assert_includes context, 'Hello from alice'
    assert_includes context, 'Bot response'
    assert_includes context, 'User bob:'
    assert_includes context, 'Hello from bob'
    
    # Reset to per_user mode
    @bot_manager.instance_variable_set(:@message_storage_mode, :per_user)
  end

  def test_get_chat_context_with_timestamps
    @bot_manager.capture_irc_message(@bot_name, @user_id, 'Message with timestamp', @channel)
    
    context = @bot_manager.get_chat_context(@bot_name, @user_id, include_timestamps: true)
    
    # Should include timestamp format [HH:MM:SS]
    assert_match(/\[\d{2}:\d{2}:\d{2}\]/, context)
  end

  def test_message_type_filter_xml_configuration_parsing
    # Create a bot configuration with message type filter
    config_with_filter = <<~XML
      <hackerbot>
        <name>FilteredBot</name>
        <llm_provider>ollama</llm_provider>
        <ollama_model>gemma3:1b</ollama_model>
        <system_prompt>Test bot with message filtering.</system_prompt>
        <get_shell>bash</get_shell>
        <messages>
          <greeting>Hello!</greeting>
          <help>Help message.</help>
          <say_ready>Ready.</say_ready>
          <next>Next.</next>
          <previous>Previous.</previous>
          <goto>Go to.</goto>
          <last_attack>Last attack.</last_attack>
          <first_attack>First attack.</first_attack>
          <getting_shell>Getting shell...</getting_shell>
          <got_shell>Got shell.</got_shell>
          <repeat>Repeat.</repeat>
          <correct_answer>Correct!</correct_answer>
          <incorrect_answer>Incorrect!</incorrect_answer>
          <no_quiz>No quiz.</no_quiz>
          <non_answer>Non answer.</non_answer>
          <shell_fail_message>Shell failed.</shell_fail_message>
          <invalid>Invalid.</invalid>
        </messages>
        <attacks>
          <attack>
            <prompt>Attack 1.</prompt>
          </attack>
        </attacks>
        <message_type_filter>
          <type>user_message</type>
          <type>bot_llm_response</type>
        </message_type_filter>
      </hackerbot>
    XML

    # Create temporary config file
    temp_file = TestUtils.create_temp_xml_file(config_with_filter)
    begin
      # Mock read_bots to use our temp file
      original_glob = Dir.method(:glob)
      Dir.define_singleton_method(:glob) { |pattern| [temp_file] }
      
      # Create bot manager and read config
      bot_manager = create_bot_manager
      bot_manager.read_bots
      
      # Verify configuration was parsed
      filter_config = bot_manager.instance_variable_get(:@bots)['FilteredBot']['message_type_filter']
      assert_equal [:user_message, :bot_llm_response], filter_config
      
      # Restore original glob
      Dir.define_singleton_method(:glob, original_glob)
    ensure
      TestUtils.cleanup_temp_file(temp_file)
    end
  end

  def test_message_type_filter_uses_bot_configuration_as_default
    # Manually set bot configuration (simulating XML config)
    @bot_manager.instance_variable_get(:@bots)[@bot_name] = {} unless @bot_manager.instance_variable_get(:@bots)[@bot_name]
    @bot_manager.instance_variable_get(:@bots)[@bot_name]['message_type_filter'] = [:user_message, :bot_command_response]
    
    # Capture messages of different types
    @bot_manager.capture_irc_message(@bot_name, @user_id, 'User message', @channel)
    @bot_manager.capture_irc_message(@bot_name, @bot_name, 'LLM response', @channel, :bot_llm_response, true)
    @bot_manager.capture_irc_message(@bot_name, @bot_name, 'Command response', @channel, :bot_command_response, true)
    @bot_manager.capture_irc_message(@bot_name, 'system', 'System message', @channel, :system_message)
    
    # Get context without explicit include_types (should use bot config)
    context = @bot_manager.get_chat_context(@bot_name, @user_id)
    
    # Should include only user messages and command responses (per bot config)
    assert_includes context, 'User message'
    assert_includes context, 'Command response'
    refute_includes context, 'LLM response'
    refute_includes context, 'System message'
  end

  def test_message_type_filter_explicit_override_overrides_configuration
    # Set bot configuration
    @bot_manager.instance_variable_get(:@bots)[@bot_name] = {} unless @bot_manager.instance_variable_get(:@bots)[@bot_name]
    @bot_manager.instance_variable_get(:@bots)[@bot_name]['message_type_filter'] = [:user_message]
    
    # Capture messages
    @bot_manager.capture_irc_message(@bot_name, @user_id, 'User message', @channel)
    @bot_manager.capture_irc_message(@bot_name, @bot_name, 'LLM response', @channel, :bot_llm_response, true)
    @bot_manager.capture_irc_message(@bot_name, @bot_name, 'Command response', @channel, :bot_command_response, true)
    
    # Explicit include_types should override bot configuration
    context = @bot_manager.get_chat_context(@bot_name, @user_id, include_types: [:bot_llm_response, :bot_command_response])
    
    # Should include only explicitly requested types
    refute_includes context, 'User message'
    assert_includes context, 'LLM response'
    assert_includes context, 'Command response'
  end

  def test_message_type_filter_default_when_no_configuration
    # Ensure bot has no message_type_filter configuration
    @bot_manager.instance_variable_get(:@bots)[@bot_name] = {} unless @bot_manager.instance_variable_get(:@bots)[@bot_name]
    @bot_manager.instance_variable_get(:@bots)[@bot_name].delete('message_type_filter')
    
    # Capture messages
    @bot_manager.capture_irc_message(@bot_name, @user_id, 'User message', @channel)
    @bot_manager.capture_irc_message(@bot_name, @bot_name, 'LLM response', @channel, :bot_llm_response, true)
    @bot_manager.capture_irc_message(@bot_name, @bot_name, 'Command response', @channel, :bot_command_response, true)
    @bot_manager.capture_irc_message(@bot_name, 'system', 'System message', @channel, :system_message)
    
    # Should use default filter (user_message, bot_llm_response, bot_command_response)
    context = @bot_manager.get_chat_context(@bot_name, @user_id)
    
    assert_includes context, 'User message'
    assert_includes context, 'LLM response'
    assert_includes context, 'Command response'
    refute_includes context, 'System message'
  end

  def test_message_type_filter_invalid_types_handled_gracefully
    # Create config with invalid message type
    config_with_invalid = <<~XML
      <hackerbot>
        <name>InvalidFilterBot</name>
        <llm_provider>ollama</llm_provider>
        <ollama_model>gemma3:1b</ollama_model>
        <system_prompt>Test bot.</system_prompt>
        <get_shell>bash</get_shell>
        <messages>
          <greeting>Hello!</greeting>
          <help>Help.</help>
          <say_ready>Ready.</say_ready>
          <next>Next.</next>
          <previous>Previous.</previous>
          <goto>Go to.</goto>
          <last_attack>Last.</last_attack>
          <first_attack>First.</first_attack>
          <getting_shell>Getting...</getting_shell>
          <got_shell>Got.</got_shell>
          <repeat>Repeat.</repeat>
          <correct_answer>Correct!</correct_answer>
          <incorrect_answer>Incorrect!</incorrect_answer>
          <no_quiz>No quiz.</no_quiz>
          <non_answer>Non answer.</non_answer>
          <shell_fail_message>Failed.</shell_fail_message>
          <invalid>Invalid.</invalid>
        </messages>
        <attacks>
          <attack>
            <prompt>Attack 1.</prompt>
          </attack>
        </attacks>
        <message_type_filter>
          <type>user_message</type>
          <type>invalid_type</type>
          <type>bot_llm_response</type>
          <type>another_invalid</type>
        </message_type_filter>
      </hackerbot>
    XML

    temp_file = TestUtils.create_temp_xml_file(config_with_invalid)
    begin
      original_glob = Dir.method(:glob)
      Dir.define_singleton_method(:glob) { |pattern| [temp_file] }
      
      bot_manager = create_bot_manager
      # Capture stderr to check for warning
      stderr_output = StringIO.new
      original_stderr = $stderr
      $stderr = stderr_output
      
      begin
        bot_manager.read_bots
      ensure
        $stderr = original_stderr
      end
      
      # Verify that valid types were parsed and invalid ones were ignored
      filter_config = bot_manager.instance_variable_get(:@bots)['InvalidFilterBot']['message_type_filter']
      assert_equal [:user_message, :bot_llm_response], filter_config
      
      # Verify warning was issued (check stderr output contains warning text)
      assert_includes stderr_output.string, 'Warning' if stderr_output.string.length > 0
      
      Dir.define_singleton_method(:glob, original_glob)
    ensure
      TestUtils.cleanup_temp_file(temp_file)
    end
  end

  def test_message_type_filter_empty_configuration_uses_default
    # Create config with empty message_type_filter
    config_empty = <<~XML
      <hackerbot>
        <name>EmptyFilterBot</name>
        <llm_provider>ollama</llm_provider>
        <ollama_model>gemma3:1b</ollama_model>
        <system_prompt>Test bot.</system_prompt>
        <get_shell>bash</get_shell>
        <messages>
          <greeting>Hello!</greeting>
          <help>Help.</help>
          <say_ready>Ready.</say_ready>
          <next>Next.</next>
          <previous>Previous.</previous>
          <goto>Go to.</goto>
          <last_attack>Last.</last_attack>
          <first_attack>First.</first_attack>
          <getting_shell>Getting...</getting_shell>
          <got_shell>Got.</got_shell>
          <repeat>Repeat.</repeat>
          <correct_answer>Correct!</correct_answer>
          <incorrect_answer>Incorrect!</incorrect_answer>
          <no_quiz>No quiz.</no_quiz>
          <non_answer>Non answer.</non_answer>
          <shell_fail_message>Failed.</shell_fail_message>
          <invalid>Invalid.</invalid>
        </messages>
        <attacks>
          <attack>
            <prompt>Attack 1.</prompt>
          </attack>
        </attacks>
        <message_type_filter>
        </message_type_filter>
      </hackerbot>
    XML

    temp_file = TestUtils.create_temp_xml_file(config_empty)
    begin
      original_glob = Dir.method(:glob)
      Dir.define_singleton_method(:glob) { |pattern| [temp_file] }
      
      bot_manager = create_bot_manager
      bot_manager.read_bots
      
      # Should use default when empty
      filter_config = bot_manager.instance_variable_get(:@bots)['EmptyFilterBot']['message_type_filter']
      assert_equal [:user_message, :bot_llm_response, :bot_command_response], filter_config
      
      Dir.define_singleton_method(:glob, original_glob)
    ensure
      TestUtils.cleanup_temp_file(temp_file)
    end
  end

  def test_message_type_filter_all_types_included
    # Test configuration that includes all message types including system messages
    # Use per_channel mode so all channel messages (including system) are included
    @bot_manager.instance_variable_set(:@message_storage_mode, :per_channel)
    
    @bot_manager.instance_variable_get(:@bots)[@bot_name] = {} unless @bot_manager.instance_variable_get(:@bots)[@bot_name]
    @bot_manager.instance_variable_get(:@bots)[@bot_name]['message_type_filter'] = [
      :user_message, :bot_llm_response, :bot_command_response, :system_message
    ]
    
    @bot_manager.capture_irc_message(@bot_name, @user_id, 'User message', @channel)
    @bot_manager.capture_irc_message(@bot_name, @bot_name, 'LLM response', @channel, :bot_llm_response, true)
    @bot_manager.capture_irc_message(@bot_name, @bot_name, 'Command response', @channel, :bot_command_response, true)
    @bot_manager.capture_irc_message(@bot_name, 'system', 'System message', @channel, :system_message)
    
    context = @bot_manager.get_chat_context(@bot_name, @user_id)
    
    # All message types should be included
    assert_includes context, 'User message'
    assert_includes context, 'LLM response'
    assert_includes context, 'Command response'
    assert_includes context, 'System message'
    
    # Reset to per_user mode
    @bot_manager.instance_variable_set(:@message_storage_mode, :per_user)
  end
end

