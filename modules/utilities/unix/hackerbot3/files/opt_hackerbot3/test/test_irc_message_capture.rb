require_relative 'test_helper'

class TestIRCMessageCapture < BotManagerTest
  def setup
    super
    @bot_manager = create_bot_manager
    @bot_name = 'TestBot'
    @user_id = 'test_user'
  end

  def test_capture_irc_message_user_message
    message_content = 'Hello, how are you?'
    channel = '#TestBot'
    
    @bot_manager.capture_irc_message(@bot_name, @user_id, message_content, channel)
    
    history = @bot_manager.get_irc_message_history(@bot_name, @user_id)
    assert_equal 1, history.length
    
    message = history.first
    assert_equal @user_id, message[:user]
    assert_equal message_content, message[:content]
    assert_equal :user_message, message[:type]
    assert_equal channel, message[:channel]
    assert_instance_of Time, message[:timestamp]
  end

  def test_capture_irc_message_bot_llm_response
    message_content = 'I am doing well, thank you!'
    channel = '#TestBot'
    
    @bot_manager.capture_irc_message(@bot_name, @bot_name, message_content, channel, :bot_llm_response, true)
    
    history = @bot_manager.get_irc_message_history(@bot_name, @bot_name)
    assert_equal 1, history.length
    
    message = history.first
    assert_equal @bot_name, message[:user]
    assert_equal message_content, message[:content]
    assert_equal :bot_llm_response, message[:type]
    assert_equal channel, message[:channel]
  end

  def test_capture_irc_message_bot_command_response
    message_content = 'Moving to next attack.'
    channel = '#TestBot'
    
    @bot_manager.capture_irc_message(@bot_name, @bot_name, message_content, channel, :bot_command_response, true)
    
    history = @bot_manager.get_irc_message_history(@bot_name, @bot_name)
    assert_equal 1, history.length
    
    message = history.first
    assert_equal :bot_command_response, message[:type]
  end

  def test_capture_irc_message_system_message
    message_content = 'JOIN #channel'
    channel = '#TestBot'
    
    @bot_manager.capture_irc_message(@bot_name, @user_id, message_content, channel, :system_message)
    
    history = @bot_manager.get_irc_message_history(@bot_name, @user_id)
    message = history.first
    assert_equal :system_message, message[:type]
  end

  def test_capture_irc_message_auto_classify_user_message
    message_content = 'What is SQL injection?'
    channel = '#TestBot'
    
    @bot_manager.capture_irc_message(@bot_name, @user_id, message_content, channel)
    
    history = @bot_manager.get_irc_message_history(@bot_name, @user_id)
    message = history.first
    assert_equal :user_message, message[:type]
  end

  def test_capture_irc_message_auto_classify_bot_command_response
    message_content = 'Moving to next attack.'
    channel = '#TestBot'
    
    @bot_manager.capture_irc_message(@bot_name, @bot_name, message_content, channel, nil, true)
    
    history = @bot_manager.get_irc_message_history(@bot_name, @bot_name)
    message = history.first
    assert_equal :bot_command_response, message[:type]
  end

  def test_capture_irc_message_chronological_ordering
    channel = '#TestBot'
    
    @bot_manager.capture_irc_message(@bot_name, @user_id, 'Message 1', channel)
    sleep(0.01) # Small delay to ensure different timestamps
    @bot_manager.capture_irc_message(@bot_name, @user_id, 'Message 2', channel)
    sleep(0.01)
    @bot_manager.capture_irc_message(@bot_name, @user_id, 'Message 3', channel)
    
    history = @bot_manager.get_irc_message_history(@bot_name, @user_id)
    assert_equal 3, history.length
    assert_equal 'Message 1', history[0][:content]
    assert_equal 'Message 2', history[1][:content]
    assert_equal 'Message 3', history[2][:content]
    
    # Verify timestamps are in order
    timestamps = history.map { |m| m[:timestamp] }
    assert timestamps[0] <= timestamps[1]
    assert timestamps[1] <= timestamps[2]
  end

  def test_capture_irc_message_max_length_enforcement
    channel = '#TestBot'
    max_messages = @bot_manager.instance_variable_get(:@max_irc_message_history)
    
    # Add more messages than max_irc_message_history
    (max_messages + 5).times do |i|
      @bot_manager.capture_irc_message(@bot_name, @user_id, "Message #{i}", channel)
    end
    
    history = @bot_manager.get_irc_message_history(@bot_name, @user_id)
    # Should be limited to max_irc_message_history
    assert_equal max_messages, history.length
    
    # Should keep the most recent messages
    assert_equal "Message 5", history.first[:content] # First message kept is from index 5
    assert_equal "Message #{max_messages + 4}", history.last[:content]
  end

  def test_capture_irc_message_multiple_users
    channel = '#TestBot'
    user1 = 'user1'
    user2 = 'user2'
    
    @bot_manager.capture_irc_message(@bot_name, user1, 'Hello from user1', channel)
    @bot_manager.capture_irc_message(@bot_name, user2, 'Hello from user2', channel)
    @bot_manager.capture_irc_message(@bot_name, user1, 'Another from user1', channel)
    
    history1 = @bot_manager.get_irc_message_history(@bot_name, user1)
    history2 = @bot_manager.get_irc_message_history(@bot_name, user2)
    
    assert_equal 2, history1.length
    assert_equal 1, history2.length
    assert_equal 'Hello from user1', history1[0][:content]
    assert_equal 'Another from user1', history1[1][:content]
    assert_equal 'Hello from user2', history2[0][:content]
  end

  def test_classify_message_type_user_message
    result = @bot_manager.classify_message_type('What is SQL injection?', false)
    assert_equal :user_message, result
  end

  def test_classify_message_type_bot_llm_response
    result = @bot_manager.classify_message_type('SQL injection is a type of security vulnerability...', true)
    assert_equal :bot_llm_response, result
  end

  def test_classify_message_type_bot_command_response_next
    result = @bot_manager.classify_message_type('next', true)
    assert_equal :bot_command_response, result
  end

  def test_classify_message_type_bot_command_response_ready
    result = @bot_manager.classify_message_type('ready', true)
    assert_equal :bot_command_response, result
  end

  def test_classify_message_type_bot_command_response_pattern
    result = @bot_manager.classify_message_type('Moving to next attack.', true)
    assert_equal :bot_command_response, result
  end

  def test_classify_message_type_system_message
    result = @bot_manager.classify_message_type('JOIN #channel', false)
    assert_equal :system_message, result
  end

  def test_clear_irc_message_history
    channel = '#TestBot'
    
    @bot_manager.capture_irc_message(@bot_name, @user_id, 'Message 1', channel)
    @bot_manager.capture_irc_message(@bot_name, @user_id, 'Message 2', channel)
    
    history = @bot_manager.get_irc_message_history(@bot_name, @user_id)
    assert_equal 2, history.length
    
    @bot_manager.clear_irc_message_history(@bot_name, @user_id)
    
    history = @bot_manager.get_irc_message_history(@bot_name, @user_id)
    assert_equal 0, history.length
  end

  def test_get_irc_message_history_empty
    history = @bot_manager.get_irc_message_history(@bot_name, 'nonexistent_user')
    assert_equal [], history
  end

  def test_capture_irc_message_ignores_empty
    channel = '#TestBot'
    
    @bot_manager.capture_irc_message(@bot_name, @user_id, '', channel)
    @bot_manager.capture_irc_message(@bot_name, @user_id, '   ', channel)
    @bot_manager.capture_irc_message(@bot_name, @user_id, nil, channel)
    
    history = @bot_manager.get_irc_message_history(@bot_name, @user_id)
    assert_equal 0, history.length
  end

  def test_capture_irc_message_multiple_message_types
    channel = '#TestBot'
    
    # Capture different message types
    @bot_manager.capture_irc_message(@bot_name, @user_id, 'User message', channel, :user_message)
    @bot_manager.capture_irc_message(@bot_name, @bot_name, 'LLM response', channel, :bot_llm_response, true)
    @bot_manager.capture_irc_message(@bot_name, @bot_name, 'Command response', channel, :bot_command_response, true)
    @bot_manager.capture_irc_message(@bot_name, 'system', 'System message', channel, :system_message)
    
    # Get histories
    user_history = @bot_manager.get_irc_message_history(@bot_name, @user_id)
    bot_history = @bot_manager.get_irc_message_history(@bot_name, @bot_name)
    
    assert_equal 1, user_history.length
    assert_equal :user_message, user_history.first[:type]
    
    assert_equal 2, bot_history.length
    assert_equal :bot_llm_response, bot_history[0][:type]
    assert_equal :bot_command_response, bot_history[1][:type]
  end
end

