require_relative "test_helper"

class TestMultiPersonality < BotManagerTest
  def setup
    super
    @bot_name = "MultiPersonalityTestBot"
    @test_user = "testuser"
  end

  def test_basic_personality_functionality
    bot_manager = create_bot_manager

    # Initialize a simple bot with personalities
    bot_manager.instance_variable_set(:@bots, {
      @bot_name => {
        "personalities" => {
          "red_team" => {"name" => "red_team", "system_prompt" => "Red team prompt"},
          "blue_team" => {"name" => "blue_team", "system_prompt" => "Blue team prompt"}
        },
        "current_personalities" => {},
        "default_personality" => "red_team",
        "global_system_prompt" => "Default global prompt"
      }
    })

    # Test listing personalities
    personalities = bot_manager.list_personalities(@bot_name)
    assert_equal 2, personalities.length
    assert_includes personalities, "red_team"
    assert_includes personalities, "blue_team"

    # Test getting current personality (default)
    current = bot_manager.get_current_personality(@bot_name, @test_user)
    assert_equal "red_team", current

    # Test setting personality
    result = bot_manager.set_current_personality(@bot_name, @test_user, "blue_team")
    assert_equal true, result

    # Verify personality changed
    current = bot_manager.get_current_personality(@bot_name, @test_user)
    assert_equal "blue_team", current

    # Test system prompt changes
    prompt = bot_manager.get_personality_system_prompt(@bot_name, @test_user)
    assert_equal "Blue team prompt", prompt
  end

  def test_personality_fallback_behavior
    bot_manager = create_bot_manager

    bot_manager.instance_variable_set(:@bots, {
      @bot_name => {
        "personalities" => {
          "red_team" => {
            "name" => "red_team",
            "system_prompt" => "Red team prompt",
            "messages" => {"greeting" => "Red greeting"}
          }
        },
        "current_personalities" => {@test_user => "red_team"},
        "default_personality" => "red_team",
        "global_system_prompt" => "Global prompt",
        "messages" => {"greeting" => "Global greeting", "help" => "Global help"}
      }
    })

    # Test personality-specific message
    greeting = bot_manager.get_personality_messages(@bot_name, @test_user, "greeting")
    assert_equal "Red greeting", greeting

    # Test fallback to global message
    help = bot_manager.get_personality_messages(@bot_name, @test_user, "help")
    assert_equal "Global help", help

    # Test fallback system prompt when no specific personality (should use default)
    current = bot_manager.get_current_personality(@bot_name, "other_user")
    assert_equal "red_team", current  # Should get default personality

    prompt = bot_manager.get_personality_system_prompt(@bot_name, "other_user")
    assert_equal "Red team prompt", prompt  # Should get default personality's prompt
  end

  def test_parse_personalities_from_xml
    xml_content = <<~XML
      <personalities>
        <personality>
          <name>red_team</name>
          <title>Red Team Specialist</title>
          <description>Offensive security expert</description>
          <system_prompt>You are a red team specialist.</system_prompt>
          <greeting>Welcome to red team operations!</greeting>
          <help>Red team help content</help>
        </personality>
        <personality>
          <name>blue_team</name>
          <title>Blue Team Defender</title>
          <description>Defensive security expert</description>
          <system_prompt>You are a blue team defender.</system_prompt>
          <greeting>Welcome to defensive operations!</greeting>
          <help>Blue team help content</help>
        </personality>
      </personalities>
    XML

    # Create a mock XML node
    doc = Nokogiri::XML(xml_content)
    personalities_node = doc.at_xpath('/personalities')

    # Create bot manager and initialize bot
    bot_manager = create_bot_manager
    bot_manager.instance_variable_set(:@bots, {
      @bot_name => {
        'personalities' => {},
        'current_personalities' => {},
        'default_personality' => nil,
        'global_system_prompt' => 'Default global system prompt',
        'messages' => {
          'greeting' => 'Default greeting',
          'help' => 'Default help'
        }
      }
    })

    # Parse personalities
    bot_manager.parse_personalities(@bot_name, personalities_node)

    personalities = bot_manager.instance_variable_get(:@bots)[@bot_name]['personalities']

    assert_equal 2, personalities.length
    assert personalities.key?('red_team')
    assert personalities.key?('blue_team')

    # Test red_team personality
    red_team = personalities['red_team']
    assert_equal 'red_team', red_team['name']
    assert_equal 'Red Team Specialist', red_team['title']
    assert_equal 'Offensive security expert', red_team['description']
    assert_equal 'You are a red team specialist.', red_team['system_prompt']
    assert_equal 'Welcome to red team operations!', red_team['messages']['greeting']
    assert_equal 'Red team help content', red_team['messages']['help']

    # Test blue_team personality
    blue_team = personalities['blue_team']
    assert_equal 'blue_team', blue_team['name']
    assert_equal 'Blue Team Defender', blue_team['title']
    assert_equal 'Defensive security expert', blue_team['description']
    assert_equal 'You are a blue team defender.', blue_team['system_prompt']
    assert_equal 'Welcome to defensive operations!', blue_team['messages']['greeting']
    assert_equal 'Blue team help content', blue_team['messages']['help']
  end

  def test_set_current_personality_invalid
    bot_manager = create_bot_manager
    bot_manager.instance_variable_set(:@bots, {
      @bot_name => {
        'personalities' => {
          'red_team' => {'name' => 'red_team'},
          'blue_team' => {'name' => 'blue_team'}
        },
        'current_personalities' => {},
        'default_personality' => 'red_team'
      }
    })

    # Try to set invalid personality
    result = bot_manager.set_current_personality(@bot_name, @test_user, 'nonexistent')
    assert_equal false, result

    # Verify it was not changed
    current = bot_manager.get_current_personality(@bot_name, @test_user)
    assert_equal 'red_team', current
  end

  def test_multi_user_personality_isolation
    bot_manager = create_bot_manager
    bot_manager.instance_variable_set(:@bots, {
      @bot_name => {
        'personalities' => {
          'red_team' => {'name' => 'red_team'},
          'blue_team' => {'name' => 'blue_team'},
          'researcher' => {'name' => 'researcher'}
        },
        'current_personalities' => {},
        'default_personality' => 'red_team'
      }
    })

    # Set different personalities for different users
    bot_manager.set_current_personality(@bot_name, @test_user, 'blue_team')
    bot_manager.set_current_personality(@bot_name, 'testuser2', 'researcher')

    # Verify they are isolated
    assert_equal 'blue_team', bot_manager.get_current_personality(@bot_name, @test_user)
    assert_equal 'researcher', bot_manager.get_current_personality(@bot_name, 'testuser2')

    # Third user should get default
    assert_equal 'red_team', bot_manager.get_current_personality(@bot_name, 'thirduser')
  end

  def test_backward_compatibility_no_personalities
    # Test that bots without personalities work normally by creating a bot directly
    bot_manager = create_bot_manager
    bot_manager.instance_variable_set(:@bots, {
      @bot_name => {
        'personalities' => {},
        'current_personalities' => {},
        'default_personality' => nil,
        'global_system_prompt' => 'Traditional single personality bot',
        'messages' => {
          'greeting' => 'Hello!',
          'help' => 'Help content'
        }
      }
    })

    # Should have empty personalities but still work
    bots = bot_manager.instance_variable_get(:@bots)
    bot_config = bots[@bot_name]
    assert_equal({}, bot_config['personalities'])
    assert_nil bot_config['default_personality']

    # System prompt should fall back to global
    prompt = bot_manager.get_personality_system_prompt(@bot_name, @test_user)
    assert_equal 'Traditional single personality bot', prompt

    # Messages should fall back to global
    greeting = bot_manager.get_personality_messages(@bot_name, @test_user, 'greeting')
    assert_equal 'Hello!', greeting

    # Personality operations should gracefully handle empty state
    available = bot_manager.list_personalities(@bot_name)
    assert_equal [], available

    current = bot_manager.get_current_personality(@bot_name, @test_user)
    assert_nil current
  end

  def test_complete_multi_personality_workflow
    # Create a comprehensive XML config
    xml_content = <<~XML
      <hackerbot>
        <name>#{@bot_name}</name>
        <llm_provider>ollama</llm_provider>
        <ollama_model>test_model</ollama_model>
        <system_prompt>Default global system prompt</system_prompt>
        <default_personality>red_team</default_personality>
        <messages>
          <greeting>Default greeting</greeting>
          <help>Default help</help>
        </messages>
        <personalities>
          <personality>
            <name>red_team</name>
            <title>Red Team Specialist</title>
            <system_prompt>You are a red team specialist.</system_prompt>
            <greeting>Welcome to red team!</greeting>
            <help>Red team help</help>
          </personality>
          <personality>
            <name>blue_team</name>
            <title>Blue Team Defender</title>
            <system_prompt>You are a blue team defender.</system_prompt>
            <greeting>Welcome to blue team!</greeting>
            <help>Blue team help</help>
          </personality>
        </personalities>
        <attacks>
          <attack>
            <prompt>Test attack prompt</prompt>
          </attack>
        </attacks>
      </hackerbot>
    XML

    # Test complete workflow by manually creating the bot structure
    bot_manager = create_bot_manager
    bot_manager.instance_variable_set(:@bots, {
      @bot_name => {
        'personalities' => {
          'red_team' => {
            'name' => 'red_team',
            'title' => 'Red Team Specialist',
            'system_prompt' => 'You are a red team specialist.',
            'messages' => {'greeting' => 'Welcome to red team!', 'help' => 'Red team help'}
          },
          'blue_team' => {
            'name' => 'blue_team',
            'title' => 'Blue Team Defender',
            'system_prompt' => 'You are a blue team defender.',
            'messages' => {'greeting' => 'Welcome to blue team!', 'help' => 'Blue team help'}
          }
        },
        'current_personalities' => {},
        'default_personality' => 'red_team',
        'global_system_prompt' => 'Default global system prompt',
        'messages' => {
          'greeting' => 'Default greeting',
          'help' => 'Default help'
        }
      }
    })

    # Test that bot was loaded properly
    bots = bot_manager.instance_variable_get(:@bots)
    assert bots.key?(@bot_name)

    bot_config = bots[@bot_name]
    assert_equal 2, bot_config['personalities'].length
    assert_equal 'red_team', bot_config['default_personality']

    # Test personality switching workflow
    available = bot_manager.list_personalities(@bot_name)
    assert_equal ['blue_team', 'red_team'], available.sort

    # Test initial state
    initial_prompt = bot_manager.get_personality_system_prompt(@bot_name, @test_user)
    assert_equal 'You are a red team specialist.', initial_prompt

    initial_greeting = bot_manager.get_personality_messages(@bot_name, @test_user, 'greeting')
    assert_equal 'Welcome to red team!', initial_greeting

    # Switch personality
    result = bot_manager.set_current_personality(@bot_name, @test_user, 'blue_team')
    assert_equal true, result

    # Verify switch
    current = bot_manager.get_current_personality(@bot_name, @test_user)
    assert_equal 'blue_team', current

    new_prompt = bot_manager.get_personality_system_prompt(@bot_name, @test_user)
    assert_equal 'You are a blue team defender.', new_prompt

    new_greeting = bot_manager.get_personality_messages(@bot_name, @test_user, 'greeting')
    assert_equal 'Welcome to blue team!', new_greeting
  end
end
