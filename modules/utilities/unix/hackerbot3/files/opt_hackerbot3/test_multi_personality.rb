#!/usr/bin/env ruby

require_relative './bot_manager.rb'
require_relative './print.rb'

# Simple test script to verify multi-personality bot loading
def test_multi_personality_loading
  Print.std '~' * 50
  Print.std 'Multi-Personality Bot Test'
  Print.std '~' * 50
  Print.std ''

  begin
    # Initialize bot manager with minimal config
    Print.info "Initializing Bot Manager..."

    bot_manager = BotManager.new(
      'localhost',
      'ollama',
      'localhost',
      11434,
      'gemma3:1b',
      nil,
      nil,
      'localhost',
      8000,
      'localhost',
      30000,
      false,  # Disable RAG+CAG for this test
      {}
    )

    Print.info "Loading bot configurations..."
    bots = bot_manager.read_bots

    Print.std "Loaded bots: #{bots.keys.join(', ')}"

    # Look for multi-personality bot
    multi_bot_name = 'CybersecurityMultiPersonalityBot'
    if bots.key?(multi_bot_name)
      Print.success "✓ Found multi-personality bot: #{multi_bot_name}"

      bot_config = bots[multi_bot_name]

      # Check if personalities were loaded
      if bot_config.key?('personalities')
        Print.success "✓ Personalities key exists"

        personalities = bot_config['personalities']
        Print.std "Available personalities: #{personalities.keys.join(', ')}"

        # Show personality details
        personalities.each do |name, config|
          Print.std "\n  Personality: #{name}"
          Print.std "  Title: #{config['title']}"
          Print.std "  Description: #{config['description']}"
          Print.std "  Has system prompt: #{config.key?('system_prompt') && !config['system_prompt'].empty?}"
          Print.std "  Has greeting: #{config.key?('messages') && config['messages'].key?('greeting')}"
        end

        # Test personality management methods
        Print.std "\nTesting personality management..."

        available_personalities = bot_manager.list_personalities(multi_bot_name)
        Print.std "list_personalities result: #{available_personalities}"

        # Test default personality
        default_personality = bot_config['default_personality']
        Print.std "Default personality: #{default_personality}"

        # Test personality switching
        test_user = "test_user"
        initial = bot_manager.get_current_personality(multi_bot_name, test_user)
        Print.std "Initial personality for user: #{initial}"

        # Switch to each personality
        available_personalities.each do |personality_name|
          success = bot_manager.set_current_personality(multi_bot_name, test_user, personality_name)
          current = bot_manager.get_current_personality(multi_bot_name, test_user)
          Print.std "Switch to #{personality_name}: #{success ? '✓' : '✗'}, current: #{current}"

          if success
            system_prompt = bot_manager.get_personality_system_prompt(multi_bot_name, test_user)
            greeting = bot_manager.get_personality_messages(multi_bot_name, test_user, 'greeting')
            Print.std "  System prompt length: #{system_prompt.length}"
            Print.std "  Greeting: #{greeting}"
          end
        end

      else
        Print.err "✗ No personalities key found in bot configuration"
        Print.std "Available keys: #{bot_config.keys.join(', ')}"
      end

    else
      Print.err "✗ Multi-personality bot not found"
      Print.std "Available bots: #{bots.keys.join(', ')}"
    end

  rescue StandardError => e
    Print.err "Test failed: #{e.message}"
    Print.err e.backtrace.first(5).join("\n")
  end

  Print.std ''
  Print.std 'Test completed'
end

# Run the test
test_multi_personality_loading()
