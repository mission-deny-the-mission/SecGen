#!/usr/bin/env ruby

require_relative './bot_manager.rb'
require_relative './print.rb'

# Focused test for personality functionality only
class TestBotManager
  def initialize
    @bots = {}
  end

  def initialize_personalities(bot_name)
    @bots[bot_name] = {
      'personalities' => {},
      'current_personalities' => {},
      'default_personality' => nil,
      'global_system_prompt' => 'Default system prompt',
      'messages' => {
        'greeting' => 'Default greeting',
        'help' => 'Default help'
      }
    }
  end

  def parse_personalities(bot_name, personalities_node)
    require 'nokogiri'

    personalities_node.xpath('personality').each do |personality_node|
      personality_name = personality_node.at_xpath('name')&.text
      next unless personality_name

      personality_config = {
        'name' => personality_name,
        'title' => personality_node.at_xpath('title')&.text || personality_name,
        'description' => personality_node.at_xpath('description')&.text || '',
        'system_prompt' => personality_node.at_xpath('system_prompt')&.text || @bots[bot_name]['global_system_prompt'],
        'messages' => {}
      }

      # Parse personality-specific messages
      %w[greeting help next previous goto ready say_ready correct_answer incorrect_answer no_quiz last_attack first_attack invalid getting_shell got_shell shell_fail_message repeat non_answer].each do |message_type|
        message_node = personality_node.at_xpath(message_type)
        if message_node
          personality_config['messages'][message_type] = message_node.text
        end
      end

      @bots[bot_name]['personalities'][personality_name] = personality_config
      Print.debug "Loaded personality: #{personality_name}"
    end
  end

  def get_current_personality(bot_name, user_id)
    return @bots[bot_name]['default_personality'] unless @bots[bot_name]['current_personalities'].key?(user_id)
    @bots[bot_name]['current_personalities'][user_id]
  end

  def set_current_personality(bot_name, user_id, personality_name)
    if @bots[bot_name]['personalities'].key?(personality_name)
      @bots[bot_name]['current_personalities'][user_id] = personality_name
      true
    else
      false
    end
  end

  def get_personality_config(bot_name, personality_name)
    @bots[bot_name]['personalities'][personality_name]
  end

  def list_personalities(bot_name)
    @bots[bot_name]['personalities'].keys
  end

  def get_personality_system_prompt(bot_name, user_id)
    current_personality = get_current_personality(bot_name, user_id)
    if current_personality && @bots[bot_name]['personalities'].key?(current_personality)
      @bots[bot_name]['personalities'][current_personality]['system_prompt']
    else
      @bots[bot_name]['global_system_prompt']
    end
  end

  def get_personality_messages(bot_name, user_id, message_type)
    current_personality = get_current_personality(bot_name, user_id)
    if current_personality &&
       @bots[bot_name]['personalities'].key?(current_personality) &&
       @bots[bot_name]['personalities'][current_personality]['messages'] &&
       @bots[bot_name]['personalities'][current_personality]['messages'][message_type]
      @bots[bot_name]['personalities'][current_personality]['messages'][message_type]
    else
      @bots[bot_name]['messages'][message_type]
    end
  end

  def load_bot_from_xml(xml_file)
    require 'nokogiri'

    Print.info "Reading bot from #{xml_file}..."
    doc = Nokogiri::XML(File.read(xml_file))
    doc.remove_namespaces!

    bot_name = doc.at_xpath('/hackerbot/name')&.text
    return nil unless bot_name

    Print.info "Found bot: #{bot_name}"
    initialize_personalities(bot_name)

    # Parse personalities if they exist
    personalities_node = doc.at_xpath('//personalities')
    if personalities_node
      parse_personalities(bot_name, personalities_node)

      # Set default personality
      default_personality_node = doc.at_xpath('//default_personality')
      if default_personality_node
        @bots[bot_name]['default_personality'] = default_personality_node.text
      elsif !@bots[bot_name]['personalities'].empty?
        @bots[bot_name]['default_personality'] = @bots[bot_name]['personalities'].keys.first
      end
    end

    bot_name
  end

  def get_bot_config(bot_name)
    @bots[bot_name]
  end
end

def test_personalities_only
  Print.std '~' * 50
  Print.std 'Multi-Personality Test (Personality Only)'
  Print.std '~' * 50
  Print.std ''

  begin
    bot_manager = TestBotManager.new

    # Load the multi-personality bot from XML
    xml_file = 'config/example_multi_personality_bot.xml'
    bot_name = bot_manager.load_bot_from_xml(xml_file)

    if bot_name
      Print.std "✓ Successfully loaded bot: #{bot_name}"

      bot_config = bot_manager.get_bot_config(bot_name)

      # Check if personalities were loaded
      if bot_config.key?('personalities') && !bot_config['personalities'].empty?
        Print.std "✓ Personalities loaded successfully!"

        personalities = bot_config['personalities']
        Print.std "\nAvailable personalities:"
        Print.std '-' * 40

        personalities.each do |name, config|
          Print.std "\n🎭 Personality: #{name}"
          Print.std "   Title: #{config['title']}"
          Print.std "   Description: #{config['description']}"
          Print.std "   System prompt length: #{config['system_prompt'].length} characters"
          Print.std "   Custom messages: #{config['messages'].keys.join(', ')}"
        end

        # Test personality management
        Print.std "\n" + "=" * 40
        Print.info "Testing personality management:"
        Print.std "=" * 40

        test_user = "test_user"

        # Test initial state
        initial = bot_manager.get_current_personality(bot_name, test_user)
        Print.std "Initial personality: #{initial || 'none'}"

        # Test listing
        available = bot_manager.list_personalities(bot_name)
        Print.std "Available personalities: #{available.join(', ')}"

        # Test switching to each personality
        Print.std "\nTesting personality switching:"
        available.each do |personality_name|
          Print.std "\n  Switching to #{personality_name}..."

          success = bot_manager.set_current_personality(bot_name, test_user, personality_name)
          if success
            current = bot_manager.get_current_personality(bot_name, test_user)
            config = bot_manager.get_personality_config(bot_name, personality_name)

            Print.std "    ✓ Switch successful! Current: #{current}"
            Print.std "    Title: #{config['title']}"

            # Test getting personality-specific content
            greeting = bot_manager.get_personality_messages(bot_name, test_user, 'greeting')
            system_prompt = bot_manager.get_personality_system_prompt(bot_name, test_user)

            Print.std "    Greeting: #{greeting[0..60]}..."
            Print.std "    System prompt preview: #{system_prompt[0..80]}..."

          else
            Print.std "    ✗ Failed to switch to #{personality_name}"
          end
        end

        # Test error handling
        Print.std "\nTesting error handling:"
        invalid_switch = bot_manager.set_current_personality(bot_name, test_user, 'nonexistent')
        Print.std "  Switch to invalid personality: #{invalid_switch ? '✗ Should have failed' : '✓ Correctly rejected'}"

        # Test fallback behavior
        Print.std "\nTesting fallback behavior:"
        bot_manager.set_current_personality(bot_name, test_user, nil) # Clear personality
        fallback_greeting = bot_manager.get_personality_messages(bot_name, test_user, 'greeting')
        fallback_prompt = bot_manager.get_personality_system_prompt(bot_name, test_user)
        Print.std "  Fallback greeting: #{fallback_greeting}"
        Print.std "  Fallback uses global prompt: #{fallback_prompt == bot_config['global_system_prompt']}"

      else
        Print.err "✗ No personalities found in bot configuration"
        Print.std "Available keys: #{bot_config.keys.join(', ')}"
      end

    else
      Print.err "✗ Failed to load bot from #{xml_file}"
    end

  rescue StandardError => e
    Print.err "Test failed: #{e.message}"
    Print.err e.backtrace.first(10).join("\n")
  end

  Print.std ''
  Print.std '=' * 50
  Print.std 'Multi-Personality Test Completed'
  Print.std '=' * 50
end

# Run the test if this script is executed directly
if __FILE__ == $0
  test_personalities_only
end
