require_relative 'test_helper'

class TestIRCMessageCaptureIntegration < BotManagerTest
  def setup
    super
    @bot_manager = create_bot_manager
    @bot_name = 'TestBot'
    @channel = '#TestBot'
  end

  def test_multi_user_conversation_capture
    user1 = 'alice'
    user2 = 'bob'
    
    # User1 sends a message
    @bot_manager.capture_irc_message(@bot_name, user1, 'Hello, what is SQL injection?', @channel)
    
    # Bot responds
    @bot_manager.capture_irc_message(@bot_name, @bot_name, 'SQL injection is a security vulnerability...', @channel, :bot_llm_response, true)
    
    # User2 sends a message
    @bot_manager.capture_irc_message(@bot_name, user2, 'Tell me about XSS', @channel)
    
    # Bot responds
    @bot_manager.capture_irc_message(@bot_name, @bot_name, 'XSS stands for Cross-Site Scripting...', @channel, :bot_llm_response, true)
    
    # User1 sends another message
    @bot_manager.capture_irc_message(@bot_name, user1, 'Thanks!', @channel)
    
    # Verify histories are separate per user
    user1_history = @bot_manager.get_irc_message_history(@bot_name, user1)
    user2_history = @bot_manager.get_irc_message_history(@bot_name, user2)
    bot_history = @bot_manager.get_irc_message_history(@bot_name, @bot_name)
    
    assert_equal 2, user1_history.length, "User1 should have 2 messages"
    assert_equal 'Hello, what is SQL injection?', user1_history[0][:content]
    assert_equal 'Thanks!', user1_history[1][:content]
    
    assert_equal 1, user2_history.length, "User2 should have 1 message"
    assert_equal 'Tell me about XSS', user2_history[0][:content]
    
    assert_equal 2, bot_history.length, "Bot should have 2 responses"
    assert_equal :bot_llm_response, bot_history[0][:type]
    assert_equal :bot_llm_response, bot_history[1][:type]
  end

  def test_mixed_message_types_in_conversation
    user = 'test_user'
    
    # Various message types in sequence
    @bot_manager.capture_irc_message(@bot_name, user, 'Hello!', @channel, :user_message)
    @bot_manager.capture_irc_message(@bot_name, @bot_name, 'Hello, how can I help?', @channel, :bot_llm_response, true)
    @bot_manager.capture_irc_message(@bot_name, user, 'next', @channel, :user_message)
    @bot_manager.capture_irc_message(@bot_name, @bot_name, 'Moving to next attack.', @channel, :bot_command_response, true)
    @bot_manager.capture_irc_message(@bot_name, user, 'What is buffer overflow?', @channel, :user_message)
    @bot_manager.capture_irc_message(@bot_name, @bot_name, 'A buffer overflow occurs when...', @channel, :bot_llm_response, true)
    
    history = @bot_manager.get_irc_message_history(@bot_name, user)
    
    assert_equal 3, history.length
    assert_equal :user_message, history[0][:type]
    assert_equal :user_message, history[1][:type]
    assert_equal :user_message, history[2][:type]
    
    bot_history = @bot_manager.get_irc_message_history(@bot_name, @bot_name)
    assert_equal 3, bot_history.length
    assert_equal :bot_llm_response, bot_history[0][:type]
    assert_equal :bot_command_response, bot_history[1][:type]
    assert_equal :bot_llm_response, bot_history[2][:type]
  end

  def test_chronological_order_across_multiple_users
    user1 = 'user1'
    user2 = 'user2'
    
    # Interleave messages from different users
    t1 = Time.now
    @bot_manager.capture_irc_message(@bot_name, user1, 'Message 1 from user1', @channel)
    sleep(0.01)
    
    @bot_manager.capture_irc_message(@bot_name, user2, 'Message 1 from user2', @channel)
    sleep(0.01)
    
    @bot_manager.capture_irc_message(@bot_name, user1, 'Message 2 from user1', @channel)
    sleep(0.01)
    
    @bot_manager.capture_irc_message(@bot_name, user2, 'Message 2 from user2', @channel)
    
    # Verify each user's history is in chronological order
    user1_history = @bot_manager.get_irc_message_history(@bot_name, user1)
    user2_history = @bot_manager.get_irc_message_history(@bot_name, user2)
    
    assert_equal 2, user1_history.length
    assert user1_history[0][:timestamp] <= user1_history[1][:timestamp]
    
    assert_equal 2, user2_history.length
    assert user2_history[0][:timestamp] <= user2_history[1][:timestamp]
    
    # Verify interleaved ordering by checking timestamps across users
    # First message from user1 should be before second message from user2
    assert user1_history[0][:timestamp] < user2_history[1][:timestamp]
  end

  def test_message_metadata_completeness
    user = 'test_user'
    message_content = 'Test message with metadata'
    timestamp_before = Time.now
    
    @bot_manager.capture_irc_message(@bot_name, user, message_content, @channel, :user_message)
    
    timestamp_after = Time.now
    history = @bot_manager.get_irc_message_history(@bot_name, user)
    
    assert_equal 1, history.length
    message = history.first
    
    # Verify all required metadata fields
    assert_equal user, message[:user]
    assert_equal message_content, message[:content]
    assert_equal @channel, message[:channel]
    assert_equal :user_message, message[:type]
    assert_instance_of Time, message[:timestamp]
    assert message[:timestamp] >= timestamp_before
    assert message[:timestamp] <= timestamp_after
    
    # Verify no unexpected fields
    expected_keys = [:user, :content, :timestamp, :type, :channel]
    assert_equal expected_keys.sort, message.keys.sort
  end

  def test_multiple_bots_message_isolation
    bot1_name = 'Bot1'
    bot2_name = 'Bot2'
    user = 'test_user'
    
    # Capture messages for different bots
    @bot_manager.capture_irc_message(bot1_name, user, 'Message for Bot1', '#Bot1')
    @bot_manager.capture_irc_message(bot2_name, user, 'Message for Bot2', '#Bot2')
    @bot_manager.capture_irc_message(bot1_name, user, 'Another message for Bot1', '#Bot1')
    
    # Verify messages are isolated per bot
    bot1_history = @bot_manager.get_irc_message_history(bot1_name, user)
    bot2_history = @bot_manager.get_irc_message_history(bot2_name, user)
    
    assert_equal 2, bot1_history.length
    assert_equal 'Message for Bot1', bot1_history[0][:content]
    assert_equal 'Another message for Bot1', bot1_history[1][:content]
    assert_equal '#Bot1', bot1_history[0][:channel]
    
    assert_equal 1, bot2_history.length
    assert_equal 'Message for Bot2', bot2_history[0][:content]
    assert_equal '#Bot2', bot2_history[0][:channel]
  end

  def test_history_pruning_maintains_order
    user = 'test_user'
    max_length = @bot_manager.instance_variable_get(:@max_irc_message_history)
    
    # Add messages up to limit + some
    (max_length + 5).times do |i|
      @bot_manager.capture_irc_message(@bot_name, user, "Message #{i}", @channel)
    end
    
    history = @bot_manager.get_irc_message_history(@bot_name, user)
    
    # Verify history is pruned to max length
    assert_equal max_length, history.length
    
    # Verify chronological order is maintained (should be most recent messages)
    timestamps = history.map { |m| m[:timestamp] }
    timestamps.each_cons(2) do |t1, t2|
      assert t1 <= t2, "Timestamps should be in chronological order"
    end
    
    # Verify we kept the most recent messages
    assert_equal "Message 5", history.first[:content]
    assert_equal "Message #{max_length + 4}", history.last[:content]
  end

  def test_conversation_with_command_and_llm_responses
    user = 'test_user'
    
    # Simulate a conversation flow
    @bot_manager.capture_irc_message(@bot_name, user, 'hello', @channel)
    @bot_manager.capture_irc_message(@bot_name, @bot_name, "Hello, test_user!", @channel, :bot_command_response, true)
    
    @bot_manager.capture_irc_message(@bot_name, user, 'What is a firewall?', @channel)
    @bot_manager.capture_irc_message(@bot_name, @bot_name, 'A firewall is a network security device...', @channel, :bot_llm_response, true)
    
    @bot_manager.capture_irc_message(@bot_name, user, 'next', @channel)
    @bot_manager.capture_irc_message(@bot_name, @bot_name, 'Moving to next attack.', @channel, :bot_command_response, true)
    
    @bot_manager.capture_irc_message(@bot_name, user, 'Explain CSRF', @channel)
    @bot_manager.capture_irc_message(@bot_name, @bot_name, 'CSRF stands for Cross-Site Request Forgery...', @channel, :bot_llm_response, true)
    
    user_history = @bot_manager.get_irc_message_history(@bot_name, user)
    bot_history = @bot_manager.get_irc_message_history(@bot_name, @bot_name)
    
    # Verify conversation flow
    assert_equal 4, user_history.length
    assert_equal ['hello', 'What is a firewall?', 'next', 'Explain CSRF'], user_history.map { |m| m[:content] }
    
    assert_equal 4, bot_history.length
    expected_types = [:bot_command_response, :bot_llm_response, :bot_command_response, :bot_llm_response]
    assert_equal expected_types, bot_history.map { |m| m[:type] }
  end
end

