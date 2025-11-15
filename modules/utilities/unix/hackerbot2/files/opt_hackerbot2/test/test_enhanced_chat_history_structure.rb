require_relative 'test_helper'

# Tests for Story 2I.2: Enhance Chat History Structure and Storage
class TestEnhancedChatHistoryStructure < BotManagerTest
  def setup
    super
    @bot_manager = create_bot_manager
    @bot_name = 'TestBot'
    @user_id = 'test_user'
  end

  # Test: Chat history structure enhanced to store message metadata
  def test_irc_message_history_stores_complete_metadata
    message_content = 'Test message with metadata'
    channel = '#TestBot'
    
    @bot_manager.capture_irc_message(@bot_name, @user_id, message_content, channel)
    
    history = @bot_manager.get_irc_message_history(@bot_name, @user_id)
    assert_equal 1, history.length
    
    message = history.first
    # Verify all required metadata fields are present
    assert message.key?(:user), "Message should have :user key"
    assert message.key?(:content), "Message should have :content key"
    assert message.key?(:timestamp), "Message should have :timestamp key"
    assert message.key?(:type), "Message should have :type key"
    assert message.key?(:channel), "Message should have :channel key"
    
    # Verify metadata values
    assert_equal @user_id, message[:user]
    assert_equal message_content, message[:content]
    assert_equal channel, message[:channel]
    assert_instance_of Time, message[:timestamp]
    assert_instance_of Symbol, message[:type]
  end

  # Test: Support for multi-user conversation history
  def test_multi_user_conversation_history_isolation
    channel = '#TestBot'
    user1 = 'alice'
    user2 = 'bob'
    user3 = 'charlie'
    
    # Each user sends messages
    3.times do |i|
      @bot_manager.capture_irc_message(@bot_name, user1, "Alice message #{i}", channel)
      @bot_manager.capture_irc_message(@bot_name, user2, "Bob message #{i}", channel)
      @bot_manager.capture_irc_message(@bot_name, user3, "Charlie message #{i}", channel)
    end
    
    # Verify each user has their own isolated history
    alice_history = @bot_manager.get_irc_message_history(@bot_name, user1)
    bob_history = @bot_manager.get_irc_message_history(@bot_name, user2)
    charlie_history = @bot_manager.get_irc_message_history(@bot_name, user3)
    
    assert_equal 3, alice_history.length
    assert_equal 3, bob_history.length
    assert_equal 3, charlie_history.length
    
    # Verify message isolation - each user's history only contains their messages
    alice_history.each do |msg|
      assert_equal user1, msg[:user]
    end
    
    bob_history.each do |msg|
      assert_equal user2, msg[:user]
    end
    
    charlie_history.each do |msg|
      assert_equal user3, msg[:user]
    end
  end

  # Test: Chronological ordering of messages maintained
  def test_chronological_message_ordering
    channel = '#TestBot'
    
    # Capture messages with delays to ensure different timestamps
    times = []
    10.times do |i|
      time_before = Time.now
      @bot_manager.capture_irc_message(@bot_name, @user_id, "Message #{i}", channel)
      times << time_before
      sleep(0.01) # Small delay between messages
    end
    
    history = @bot_manager.get_irc_message_history(@bot_name, @user_id)
    
    # Verify chronological order
    assert_equal 10, history.length
    (0...history.length - 1).each do |i|
      assert history[i][:timestamp] <= history[i + 1][:timestamp],
             "Message #{i} timestamp should be <= message #{i + 1} timestamp"
    end
    
    # Verify content order matches chronological order
    history.each_with_index do |msg, index|
      assert_equal "Message #{index}", msg[:content]
    end
  end

  # Test: Message history window size configurable (default: last N messages)
  def test_default_history_window_size
    channel = '#TestBot'
    default_max = @bot_manager.instance_variable_get(:@max_irc_message_history)
    
    # Add more messages than default window
    (default_max + 5).times do |i|
      @bot_manager.capture_irc_message(@bot_name, @user_id, "Message #{i}", channel)
    end
    
    history = @bot_manager.get_irc_message_history(@bot_name, @user_id)
    
    # Should be limited to default max
    assert_equal default_max, history.length,
                 "History should be limited to default max_irc_message_history (#{default_max})"
    
    # Should keep the most recent messages
    assert_equal "Message 5", history.first[:content]
    assert_equal "Message #{default_max + 4}", history.last[:content]
  end

  # Test: Configurable history window size via bot configuration
  def test_bot_specific_history_window_size
    channel = '#TestBot'
    custom_max = 15
    
    # Manually set bot-specific max history (simulating XML config)
    @bot_manager.instance_variable_get(:@bots)[@bot_name] = {
      'max_irc_message_history' => custom_max
    }
    
    # Add more messages than custom window
    (custom_max + 5).times do |i|
      @bot_manager.capture_irc_message(@bot_name, @user_id, "Message #{i}", channel)
    end
    
    history = @bot_manager.get_irc_message_history(@bot_name, @user_id)
    
    # Should be limited to custom max
    assert_equal custom_max, history.length,
                 "History should be limited to bot-specific max (#{custom_max})"
    
    # Should keep the most recent messages
    assert_equal "Message 5", history.first[:content]
    assert_equal "Message #{custom_max + 4}", history.last[:content]
  end

  # Test: Backward compatibility - existing history format still supported
  def test_backward_compatibility_traditional_chat_history
    user_message = 'What is SQL injection?'
    assistant_response = 'SQL injection is a security vulnerability...'
    
    # Test traditional add_to_history method still works
    @bot_manager.add_to_history(@bot_name, @user_id, user_message, assistant_response)
    
    # Verify traditional history structure is maintained
    traditional_history = @bot_manager.instance_variable_get(:@user_chat_histories)[@bot_name][@user_id]
    refute_nil traditional_history
    assert_equal 1, traditional_history.length
    
    exchange = traditional_history.first
    assert exchange.key?(:user), "Traditional history should have :user key"
    assert exchange.key?(:assistant), "Traditional history should have :assistant key"
    assert_equal user_message, exchange[:user]
    assert_equal assistant_response, exchange[:assistant]
  end

  # Test: Backward compatibility - get_chat_context still works
  def test_backward_compatibility_get_chat_context
    user_message1 = 'What is SQL injection?'
    assistant_response1 = 'SQL injection is a security vulnerability...'
    user_message2 = 'How do I prevent it?'
    assistant_response2 = 'Use parameterized queries...'
    
    # Add multiple exchanges using traditional method
    @bot_manager.add_to_history(@bot_name, @user_id, user_message1, assistant_response1)
    @bot_manager.add_to_history(@bot_name, @user_id, user_message2, assistant_response2)
    
    # Verify get_chat_context still works with traditional format
    context = @bot_manager.get_chat_context(@bot_name, @user_id)
    
    refute_empty context
    assert_includes context, user_message1
    assert_includes context, assistant_response1
    assert_includes context, user_message2
    assert_includes context, assistant_response2
    assert_includes context, 'User:'
    assert_includes context, 'Assistant:'
  end

  # Test: Traditional history respects bot-specific max length
  def test_traditional_history_respects_bot_specific_max_length
    custom_max = 5
    
    # Set bot-specific max history for traditional format
    @bot_manager.instance_variable_get(:@bots)[@bot_name] = {
      'max_history_length' => custom_max
    }
    
    # Add more exchanges than max
    (custom_max + 3).times do |i|
      @bot_manager.add_to_history(@bot_name, @user_id, "Question #{i}", "Answer #{i}")
    end
    
    traditional_history = @bot_manager.instance_variable_get(:@user_chat_histories)[@bot_name][@user_id]
    
    # Should be limited to custom max
    assert_equal custom_max, traditional_history.length,
                 "Traditional history should respect bot-specific max_length (#{custom_max})"
    
    # Should keep most recent exchanges
    assert_equal "Question 3", traditional_history.first[:user]
    assert_equal "Answer #{custom_max + 2}", traditional_history.last[:assistant]
  end

  # Test: History cleanup/pruning when exceeding max size
  def test_prune_irc_message_history
    channel = '#TestBot'
    max_length = 10
    
    # Set bot-specific max
    @bot_manager.instance_variable_get(:@bots)[@bot_name] = {
      'max_irc_message_history' => max_length
    }
    
    # Add more messages than max
    (max_length + 8).times do |i|
      @bot_manager.capture_irc_message(@bot_name, @user_id, "Message #{i}", channel)
    end
    
    # Manually prune (would normally happen automatically)
    @bot_manager.prune_irc_message_history(@bot_name)
    
    history = @bot_manager.get_irc_message_history(@bot_name, @user_id)
    assert_equal max_length, history.length,
                 "Pruned history should be limited to max_length (#{max_length})"
  end

  # Test: Prune multiple users' histories
  def test_prune_irc_message_history_multiple_users
    channel = '#TestBot'
    max_length = 5
    user1 = 'user1'
    user2 = 'user2'
    
    # Set bot-specific max
    @bot_manager.instance_variable_get(:@bots)[@bot_name] = {
      'max_irc_message_history' => max_length
    }
    
    # Add messages for both users exceeding max
    (max_length + 3).times do |i|
      @bot_manager.capture_irc_message(@bot_name, user1, "User1 message #{i}", channel)
      @bot_manager.capture_irc_message(@bot_name, user2, "User2 message #{i}", channel)
    end
    
    # Prune all histories
    @bot_manager.prune_irc_message_history(@bot_name)
    
    history1 = @bot_manager.get_irc_message_history(@bot_name, user1)
    history2 = @bot_manager.get_irc_message_history(@bot_name, user2)
    
    assert_equal max_length, history1.length
    assert_equal max_length, history2.length
  end

  # Test: Prune traditional chat history for specific user
  def test_prune_chat_history_specific_user
    max_length = 3
    user1 = 'user1'
    user2 = 'user2'
    
    # First add exchanges without max limit (using default)
    # Then set the max and verify pruning works correctly
    (max_length + 2).times do |i|
      @bot_manager.add_to_history(@bot_name, user1, "Q#{i}", "A#{i}")
      @bot_manager.add_to_history(@bot_name, user2, "Q#{i}", "A#{i}")
    end
    
    # Initially both should have max_length exchanges (due to default limit of 10)
    history1_before = @bot_manager.instance_variable_get(:@user_chat_histories)[@bot_name][user1]
    history2_before = @bot_manager.instance_variable_get(:@user_chat_histories)[@bot_name][user2]
    
    # Now set bot-specific max lower and prune only user1
    @bot_manager.instance_variable_get(:@bots)[@bot_name] = {
      'max_history_length' => max_length
    }
    
    # Manually prune only user1's history
    @bot_manager.prune_chat_history(@bot_name, user1)
    
    history1 = @bot_manager.instance_variable_get(:@user_chat_histories)[@bot_name][user1]
    history2 = @bot_manager.instance_variable_get(:@user_chat_histories)[@bot_name][user2]
    
    assert_equal max_length, history1.length,
                 "User1 history should be pruned to max_length (#{max_length})"
    assert_equal history2_before.length, history2.length,
                 "User2 history should remain unchanged (still #{history2_before.length} entries)"
  end

  # Test: Prune all users' traditional chat history
  def test_prune_chat_history_all_users
    max_length = 4
    user1 = 'user1'
    user2 = 'user2'
    user3 = 'user3'
    
    # Set bot-specific max
    @bot_manager.instance_variable_get(:@bots)[@bot_name] = {
      'max_history_length' => max_length
    }
    
    # Add exchanges for all users exceeding max
    (max_length + 2).times do |i|
      @bot_manager.add_to_history(@bot_name, user1, "Q#{i}", "A#{i}")
      @bot_manager.add_to_history(@bot_name, user2, "Q#{i}", "A#{i}")
      @bot_manager.add_to_history(@bot_name, user3, "Q#{i}", "A#{i}")
    end
    
    # Prune all users' histories
    @bot_manager.prune_chat_history(@bot_name)
    
    [user1, user2, user3].each do |user|
      history = @bot_manager.instance_variable_get(:@user_chat_histories)[@bot_name][user]
      assert_equal max_length, history.length,
                   "User #{user} history should be pruned to max_length (#{max_length})"
    end
  end

  # Test: Independent history limits for IRC and traditional chat
  def test_independent_history_limits
    channel = '#TestBot'
    irc_max = 15
    chat_max = 8
    
    # Set different limits for each
    @bot_manager.instance_variable_get(:@bots)[@bot_name] = {
      'max_irc_message_history' => irc_max,
      'max_history_length' => chat_max
    }
    
    # Add messages to both systems exceeding their respective limits
    (irc_max + 5).times do |i|
      @bot_manager.capture_irc_message(@bot_name, @user_id, "IRC message #{i}", channel)
    end
    
    (chat_max + 3).times do |i|
      @bot_manager.add_to_history(@bot_name, @user_id, "Question #{i}", "Answer #{i}")
    end
    
    # Verify limits are independent
    irc_history = @bot_manager.get_irc_message_history(@bot_name, @user_id)
    chat_history = @bot_manager.instance_variable_get(:@user_chat_histories)[@bot_name][@user_id]
    
    assert_equal irc_max, irc_history.length,
                 "IRC history should respect irc_max (#{irc_max})"
    assert_equal chat_max, chat_history.length,
                 "Chat history should respect chat_max (#{chat_max})"
  end

  # Test: Empty history handling
  def test_empty_history_handling
    # Test IRC message history for non-existent user
    irc_history = @bot_manager.get_irc_message_history(@bot_name, 'nonexistent')
    assert_equal [], irc_history
    
    # Test traditional chat history for non-existent user
    chat_context = @bot_manager.get_chat_context(@bot_name, 'nonexistent')
    assert_equal '', chat_context
  end

  # Test: Message history structure consistency
  def test_message_history_structure_consistency
    channel = '#TestBot'
    
    # Add various message types
    @bot_manager.capture_irc_message(@bot_name, @user_id, 'User message', channel, :user_message)
    @bot_manager.capture_irc_message(@bot_name, @bot_name, 'LLM response', channel, :bot_llm_response, true)
    @bot_manager.capture_irc_message(@bot_name, @bot_name, 'Command response', channel, :bot_command_response, true)
    
    history = @bot_manager.get_irc_message_history(@bot_name, @user_id)
    
    # Verify all messages have consistent structure
    history.each do |msg|
      assert msg.is_a?(Hash), "Each message should be a Hash"
      assert_equal 5, msg.keys.length, "Each message should have 5 keys"
      assert msg.key?(:user), "Message should have :user"
      assert msg.key?(:content), "Message should have :content"
      assert msg.key?(:timestamp), "Message should have :timestamp"
      assert msg.key?(:type), "Message should have :type"
      assert msg.key?(:channel), "Message should have :channel"
    end
  end
end

