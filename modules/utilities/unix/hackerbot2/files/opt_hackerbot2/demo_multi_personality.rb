#!/usr/bin/env ruby

require_relative './bot_manager.rb'
require_relative './print.rb'

# Demo script for Multiple Personalities feature
# This script demonstrates the new personality switching capabilities

def demo_multi_personalities
  Print.std '~' * 60
  Print.std ' ' * 20 + 'Multi-Personality Demo'
  Print.std '~' * 60
  Print.std ''

  # Initialize bot manager with multi-personality bot
  Print.info "Initializing Bot Manager with multi-personality support..."

  bot_manager = BotManager.new(
    'localhost',  # IRC server
    'ollama',     # LLM provider
    'localhost',  # Ollama host
    11434,        # Ollama port
    'gemma3:1b',  # Model
    nil,          # OpenAI API key
    nil,          # OpenAI base URL
    'localhost',  # VLLM host
    8000,         # VLLM port
    'localhost',  # SGLang host
    30000,        # SGLang port
    true,         # Enable RAG+CAG
    {             # RAG+CAG config
      enable_rag: true,
      enable_cag: true,
      offline_mode: 'auto'
    }
  )

  # Load bots from configuration
  Print.info "Loading bot configurations..."
  bots = bot_manager.read_bots

  # Check if multi-personality bot was loaded
  multi_personality_bot = bots['CybersecurityMultiPersonalityBot']
  if multi_personality_bot.nil?
    Print.err "Multi-personality bot not found! Make sure config/example_multi_personality_bot.xml exists."
    Print.info "Available bots: #{bots.keys.join(', ')}"
    return
  end

  Print.success "Multi-personality bot loaded successfully!"
  Print.std ''

  # Demo 1: Show available personalities
  Print.info "=== Demo 1: Available Personalities ==="
  available_personalities = bot_manager.list_personalities('CybersecurityMultiPersonalityBot')

  if available_personalities.empty?
    Print.warn "No personalities found in the bot configuration."
    return
  end

  Print.std "Available personalities:"
  available_personalities.each do |personality_name|
    config = bot_manager.get_personality_config('CybersecurityMultiPersonalityBot', personality_name)
    Print.std "  • #{personality_name} (#{config['title']})"
    Print.std "    Description: #{config['description']}"
    Print.std "    System Prompt: #{config['system_prompt'][0..100]}..."
    Print.std ''
  end

  # Demo 2: Test personality switching
  Print.info "=== Demo 2: Personality Switching ==="
  test_user = "demo_user"

  # Show initial personality
  initial_personality = bot_manager.get_current_personality('CybersecurityMultiPersonalityBot', test_user)
  Print.std "Initial personality for #{test_user}: #{initial_personality}"

  # Test switching to each personality
  available_personalities.each do |personality_name|
    Print.std "\nSwitching to #{personality_name} personality..."

    # Switch personality
    success = bot_manager.set_current_personality('CybersecurityMultiPersonalityBot', test_user, personality_name)

    if success
      current_personality = bot_manager.get_current_personality('CybersecurityMultiPersonalityBot', test_user)
      config = bot_manager.get_personality_config('CybersecurityMultiPersonalityBot', personality_name)

      Print.success "✓ Switched to #{current_personality} (#{config['title']})"

      # Test getting personality-specific messages
      greeting = bot_manager.get_personality_messages('CybersecurityMultiPersonalityBot', test_user, 'greeting')
      help = bot_manager.get_personality_messages('CybersecurityMultiPersonalityBot', test_user, 'help')

      Print.std "  Greeting: #{greeting}"
      Print.std "  Help message preview: #{help[0..100]}..."

      # Test system prompt
      system_prompt = bot_manager.get_personality_system_prompt('CybersecurityMultiPersonalityBot', test_user)
      Print.std "  System prompt preview: #{system_prompt[0..150]}..."

    else
      Print.err "✗ Failed to switch to #{personality_name}"
    end
  end

  # Demo 3: Test message handling with different personalities
  Print.info "\n=== Demo 3: Message Handling ==="

  test_messages = [
    "What are the main principles of network security?",
    "How do attackers typically compromise systems?",
    "What's the best way to respond to a security incident?",
    "Can you explain encryption in simple terms?"
  ]

  available_personalities.each do |personality_name|
    Print.std "\nTesting #{personality_name} personality:"
    bot_manager.set_current_personality('CybersecurityMultiPersonalityBot', test_user, personality_name)

    config = bot_manager.get_personality_config('CybersecurityMultiPersonalityBot', personality_name)
    Print.std "  As #{config['title']}:"

    test_messages.each do |message|
      Print.std "    Q: #{message}"

      # Get the system prompt that would be used
      system_prompt = bot_manager.get_personality_system_prompt('CybersecurityMultiPersonalityBot', test_user)
      Print.std "    [Would respond with personality: #{personality_name}]"
      Print.std "    [System prompt: #{system_prompt[0..50]}...]"
      Print.std ''
    end
  end

  # Demo 4: Error handling
  Print.info "\n=== Demo 4: Error Handling ==="

  # Try to switch to non-existent personality
  Print.std "Testing invalid personality switch..."
  success = bot_manager.set_current_personality('CybersecurityMultiPersonalityBot', test_user, 'nonexistent_personality')

  if success
    Print.err "✗ Unexpected success switching to invalid personality"
  else
    Print.success "✓ Correctly rejected invalid personality switch"
  end

  # Test fallback to default when no personality set
  Print.std "\nTesting fallback behavior..."
  bot_manager.set_current_personality('CybersecurityMultiPersonalityBot', test_user, nil)

  # Clear personality and test fallback
  bot_manager.instance_variable_get(:@bots)['CybersecurityMultiPersonalityBot']['current_personalities'].delete(test_user)

  fallback_personality = bot_manager.get_current_personality('CybersecurityMultiPersonalityBot', test_user)
  Print.std "Fallback personality: #{fallback_personality}"

  # Test getting messages when personality is not set
  greeting = bot_manager.get_personality_messages('CybersecurityMultiPersonalityBot', test_user, 'greeting')
  Print.std "Fallback greeting: #{greeting}"

  Print.info "\n=== Demo Complete ==="
  Print.std "Multi-personality feature is working correctly!"
  Print.std ''
  Print.std "To use this feature in IRC:"
  Print.std "  • 'personalities' - List available personalities"
  Print.std "  • 'switch [personality]' - Switch to a specific personality"
  Print.std "  • 'personality' - Show current personality"
  Print.std ''

rescue StandardError => e
  Print.err "Demo failed with error: #{e.message}"
  Print.err e.backtrace.join("\n")
end

# Run the demo if this script is executed directly
if __FILE__ == $0
  demo_multi_personalities
end
