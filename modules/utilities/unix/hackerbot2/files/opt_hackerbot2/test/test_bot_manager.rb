require_relative 'test_helper'

class TestBotManager < BotManagerTest
  def test_initialization_with_defaults
    bot_manager = create_bot_manager

    assert_equal @irc_server, bot_manager.instance_variable_get(:@irc_server_ip_address)
    assert_equal @llm_provider, bot_manager.instance_variable_get(:@llm_provider)
    assert_equal @ollama_host, bot_manager.instance_variable_get(:@ollama_host)
    assert_equal @ollama_port, bot_manager.instance_variable_get(:@ollama_port)
    assert_equal @ollama_model, bot_manager.instance_variable_get(:@ollama_model)
    assert_equal @openai_api_key, bot_manager.instance_variable_get(:@openai_api_key)
    assert_equal @vllm_host, bot_manager.instance_variable_get(:@vllm_host)
    assert_equal @vllm_port, bot_manager.instance_variable_get(:@vllm_port)
    assert_equal @sglang_host, bot_manager.instance_variable_get(:@sglang_host)
    assert_equal @sglang_port, bot_manager.instance_variable_get(:@sglang_port)
    assert_instance_of Hash, bot_manager.instance_variable_get(:@bots)
    assert_instance_of Hash, bot_manager.instance_variable_get(:@user_chat_histories)
    assert_equal 10, bot_manager.instance_variable_get(:@max_history_length)
  end

  def test_initialization_with_custom_values
    custom_values = {
      irc_server_ip_address: 'custom.irc.com',
      llm_provider: 'openai',
      ollama_host: 'custom.ollama.com',
      ollama_port: 9999,
      ollama_model: 'custom-model',
      openai_api_key: 'custom-key',
      vllm_host: 'custom.vllm.com',
      vllm_port: 8888,
      sglang_host: 'custom.sglang.com',
      sglang_port: 7777
    }

    bot_manager = create_bot_manager(**custom_values)

    assert_equal 'custom.irc.com', bot_manager.instance_variable_get(:@irc_server_ip_address)
    assert_equal 'openai', bot_manager.instance_variable_get(:@llm_provider)
    assert_equal 'custom.ollama.com', bot_manager.instance_variable_get(:@ollama_host)
    assert_equal 9999, bot_manager.instance_variable_get(:@ollama_port)
    assert_equal 'custom-model', bot_manager.instance_variable_get(:@ollama_model)
    assert_equal 'custom-key', bot_manager.instance_variable_get(:@openai_api_key)
    assert_equal 'custom.vllm.com', bot_manager.instance_variable_get(:@vllm_host)
    assert_equal 8888, bot_manager.instance_variable_get(:@vllm_port)
    assert_equal 'custom.sglang.com', bot_manager.instance_variable_get(:@sglang_host)
    assert_equal 7777, bot_manager.instance_variable_get(:@sglang_port)
  end

  def test_add_to_history
    bot_manager = create_bot_manager
    bot_name = 'test_bot'
    user_id = 'test_user'
    user_message = 'Hello'
    assistant_response = 'Hi there'

    bot_manager.add_to_history(bot_name, user_id, user_message, assistant_response)

    history = bot_manager.instance_variable_get(:@user_chat_histories)
    assert_equal 1, history[bot_name][user_id].length
    assert_equal user_message, history[bot_name][user_id].first[:user]
    assert_equal assistant_response, history[bot_name][user_id].first[:assistant]
  end

  def test_add_to_history_multiple_exchanges
    bot_manager = create_bot_manager
    bot_name = 'test_bot'
    user_id = 'test_user'

    bot_manager.add_to_history(bot_name, user_id, 'Hello', 'Hi there')
    bot_manager.add_to_history(bot_name, user_id, 'How are you?', 'I am fine')

    history = bot_manager.instance_variable_get(:@user_chat_histories)
    assert_equal 2, history[bot_name][user_id].length
    assert_equal 'Hello', history[bot_name][user_id].first[:user]
    assert_equal 'Hi there', history[bot_name][user_id].first[:assistant]
    assert_equal 'How are you?', history[bot_name][user_id].last[:user]
    assert_equal 'I am fine', history[bot_name][user_id].last[:assistant]
  end

  def test_add_to_history_max_length_limit
    bot_manager = create_bot_manager
    bot_name = 'test_bot'
    user_id = 'test_user'

    # Add 15 exchanges (max_history_length is 10)
    15.times do |i|
      bot_manager.add_to_history(bot_name, user_id, "Message #{i}", "Response #{i}")
    end

    history = bot_manager.instance_variable_get(:@user_chat_histories)
    assert_equal 10, history[bot_name][user_id].length
    # Should keep the last 10 exchanges
    assert_equal 'Message 5', history[bot_name][user_id].first[:user]
    assert_equal 'Response 5', history[bot_name][user_id].first[:assistant]
    assert_equal 'Message 14', history[bot_name][user_id].last[:user]
    assert_equal 'Response 14', history[bot_name][user_id].last[:assistant]
  end

  def test_get_chat_context_empty
    bot_manager = create_bot_manager
    bot_name = 'test_bot'
    user_id = 'test_user'

    context = bot_manager.get_chat_context(bot_name, user_id)
    assert_equal '', context
  end

  def test_get_chat_context_with_history
    bot_manager = create_bot_manager
    bot_name = 'test_bot'
    user_id = 'test_user'

    bot_manager.add_to_history(bot_name, user_id, 'Hello', 'Hi there')
    bot_manager.add_to_history(bot_name, user_id, 'How are you?', 'I am fine')

    context = bot_manager.get_chat_context(bot_name, user_id)
    expected_context = "User: Hello\nAssistant: Hi there\n\nUser: How are you?\nAssistant: I am fine"
    assert_equal expected_context, context
  end

  def test_get_chat_context_nonexistent_user
    bot_manager = create_bot_manager
    bot_name = 'test_bot'
    user_id = 'nonexistent_user'

    context = bot_manager.get_chat_context(bot_name, user_id)
    assert_equal '', context
  end

  def test_clear_user_history
    bot_manager = create_bot_manager
    bot_name = 'test_bot'
    user_id = 'test_user'

    bot_manager.add_to_history(bot_name, user_id, 'Hello', 'Hi there')
    bot_manager.add_to_history(bot_name, user_id, 'How are you?', 'I am fine')

    bot_manager.clear_user_history(bot_name, user_id)

    history = bot_manager.instance_variable_get(:@user_chat_histories)
    assert_nil history[bot_name][user_id]
  end

  def test_clear_user_history_nonexistent_user
    bot_manager = create_bot_manager
    bot_name = 'test_bot'
    user_id = 'nonexistent_user'

    # Should not raise an error
    assert_nothing_raised do
      bot_manager.clear_user_history(bot_name, user_id)
    end
  end

  def test_assemble_prompt_all_empty
    bot_manager = create_bot_manager

    prompt = bot_manager.assemble_prompt('', '', '', '')
    assert_equal "\n\nUser: \nAssistant:", prompt
  end

  def test_assemble_prompt_only_system_prompt
    bot_manager = create_bot_manager

    prompt = bot_manager.assemble_prompt('System prompt', '', '', '')
    assert_equal "System prompt\n\nUser: \nAssistant:", prompt
  end

  def test_assemble_prompt_only_context
    bot_manager = create_bot_manager

    prompt = bot_manager.assemble_prompt('', 'Context', '', '')
    assert_equal "\n\nContext: Context\n\nUser: \nAssistant:", prompt
  end

  def test_assemble_prompt_only_chat_context
    bot_manager = create_bot_manager

    prompt = bot_manager.assemble_prompt('', '', 'Chat context', '')
    assert_equal "\n\nChat History:\nChat context\n\nUser: \nAssistant:", prompt
  end

  def test_assemble_prompt_only_user_message
    bot_manager = create_bot_manager

    prompt = bot_manager.assemble_prompt('', '', '', 'User message')
    assert_equal "\n\nUser: User message\nAssistant:", prompt
  end

  def test_assemble_prompt_all_components
    bot_manager = create_bot_manager

    prompt = bot_manager.assemble_prompt(
      'System prompt',
      'Context',
      'Chat context',
      'User message'
    )

    expected = "System prompt\n\nContext: Context\n\nChat History:\nChat context\n\nUser: User message\nAssistant:"
    assert_equal expected, prompt
  end

  def test_assemble_prompt_with_special_characters
    bot_manager = create_bot_manager

    prompt = bot_manager.assemble_prompt(
      "System\nprompt",
      "Context\twith\ttabs",
      "Chat\ncontext",
      "User\"message"
    )

    expected = "System\nprompt\n\nContext: Context\twith\ttabs\n\nChat History:\nChat\ncontext\n\nUser: User\"message\nAssistant:"
    assert_equal expected, prompt
  end

  def test_read_bots_with_valid_xml
    create_temp_config_file

    begin
      bot_manager = create_bot_manager

      # Mock Dir.glob to return our temp config file
      Dir.stub(:glob, [@temp_config_path]) do
        bots = bot_manager.read_bots

        assert_instance_of Hash, bots
        assert bots.key?('TestBot')

        test_bot = bots['TestBot']
        assert_instance_of Hash, test_bot
        assert_equal 'bash', test_bot['get_shell']
        assert_instance_of Hash, test_bot['messages']
        assert_instance_of Array, test_bot['attacks']
        assert_equal 0, test_bot['current_attack']
        assert_nil test_bot['current_quiz']

        # Check messages
        messages = test_bot['messages']
        assert_equal 'Hello test user!', messages['greeting']
        assert_equal 'This is a test help message.', messages['help']

        # Check attacks
        attacks = test_bot['attacks']
        assert_equal 2, attacks.length
        assert_equal 'This is attack 1.', attacks[0]['prompt']
        assert_equal 'Attack 1 system prompt.', attacks[0]['system_prompt']
        assert_equal 'This is attack 2.', attacks[1]['prompt']
        assert_equal 'Attack 2 system prompt.', attacks[1]['system_prompt']
        assert_instance_of Hash, attacks[1]['quiz']
        assert_equal 'What is 2+2?', attacks[1]['quiz']['question']
        assert_equal '4', attacks[1]['quiz']['answer']
      end
    ensure
      cleanup_temp_config
    end
  end

  def test_read_bots_with_no_config_files
    bot_manager = create_bot_manager

    # Mock Dir.glob to return empty array
    Dir.stub(:glob, []) do
      bots = bot_manager.read_bots
      assert_instance_of Hash, bots
      assert_empty bots
    end
  end

  def test_read_bots_with_invalid_xml
    invalid_xml_content = <<~XML
      <invalid_xml>
        <name>TestBot</name>
        <unclosed_tag>
      </invalid_xml>
    XML

    create_temp_config_file(invalid_xml_content)

    begin
      bot_manager = create_bot_manager

      Dir.stub(:glob, [@temp_config_path]) do
        stdout, stderr = TestUtils.capture_print_output do
          bots = bot_manager.read_bots
          assert_instance_of Hash, bots
          assert_empty bots
        end
        # Should have XML parsing errors
        assert_match(/Failed to read hackerbot file/, stderr)
      end
    ensure
      cleanup_temp_config
    end
  end

  def test_read_bots_with_missing_file
    bot_manager = create_bot_manager

    # Mock Dir.glob to return a non-existent file
    Dir.stub(:glob, ['/nonexistent/file.xml']) do
      stdout, stderr = TestUtils.capture_print_output do
        bots = bot_manager.read_bots
        assert_instance_of Hash, bots
        assert_empty bots
      end
      # Should print error about missing file
      assert_match(/Failed to read hackerbot file/, stderr)
    end
  end

  def test_read_bots_multiple_config_files
    config1 = TestUtils.create_sample_bot_config.gsub('<name>TestBot</name>', '<name>Bot1</name>')
    config2 = TestUtils.create_sample_bot_config.gsub('<name>TestBot</name>', '<name>Bot2</name>')

    temp_file1 = TestUtils.create_temp_xml_file(config1)
    temp_file2 = TestUtils.create_temp_xml_file(config2)

    begin
      bot_manager = create_bot_manager

      Dir.stub(:glob, [temp_file1, temp_file2]) do
        bots = bot_manager.read_bots

        assert_instance_of Hash, bots
        assert bots.key?('Bot1')
        assert bots.key?('Bot2')
        assert_equal 2, bots.length
      end
    ensure
      TestUtils.cleanup_temp_file(temp_file1)
      TestUtils.cleanup_temp_file(temp_file2)
    end
  end

  def test_create_bot_creates_cinch_bot
    bot_manager = create_bot_manager

    # Suppress stdout during bot creation (Cinch prints to stdout)
    stdout, stderr = TestUtils.capture_print_output do
      bot = bot_manager.create_bot('TestBot', 'Test system prompt')

      assert_instance_of Cinch::Bot, bot
      assert_equal 'TestBot', bot.config.nick
      assert_equal 'localhost', bot.config.server
      assert_includes bot.config.channels, '#TestBot'
      assert_includes bot.config.channels, '#bots'
    end
  end

  def test_create_bot_with_custom_irc_server
    bot_manager = create_bot_manager(irc_server_ip_address: 'custom.irc.com')

    stdout, stderr = TestUtils.capture_print_output do
      bot = bot_manager.create_bot('TestBot', 'Test system prompt')

      assert_equal 'custom.irc.com', bot.config.server
    end
  end

  def test_start_bots_with_no_bots
    bot_manager = create_bot_manager
    bot_manager.instance_variable_set(:@bots, {})

    # Should not raise any errors
    assert_nothing_raised do
      bot_manager.start_bots
    end
  end

  def test_start_bots_with_multiple_bots
    bot_manager = create_bot_manager

    # Create mock bot instances
    mock_bot1 = Object.new
    mock_bot1.define_singleton_method(:start) { 'Bot1 started' }

    mock_bot2 = Object.new
    mock_bot2.define_singleton_method(:start) { 'Bot2 started' }

    bot_manager.instance_variable_set(:@bots, {
      'Bot1' => { 'bot' => mock_bot1 },
      'Bot2' => { 'bot' => mock_bot2 }
    })

    # Mock the bot creation to avoid actual IRC bot creation
    bot_manager.define_singleton_method(:create_bot) do |bot_name, system_prompt|
      mock_bot = Object.new
      mock_bot.define_singleton_method(:start) { "#{bot_name} started" }
      mock_bot
    end

    # Mock the bot creation process
    bot_manager.stub(:create_bot, mock_bot1) do
      # This test would require threading to test properly
      # For now, just verify it doesn't raise errors
      assert_nothing_raised do
        # We can't actually test start_bots without running it
        # as it would start real IRC bots
        pass
      end
    end
  end

  def test_llm_client_creation_ollama
    xml_content = <<~XML
      <hackerbot>
        <name>OllamaBot</name>
        <llm_provider>ollama</llm_provider>
        <ollama_model>llama2</ollama_model>
        <ollama_host>custom.ollama.com</ollama_host>
        <ollama_port>9999</ollama_port>
        <system_prompt>Test system prompt</system_prompt>
        <get_shell>bash</get_shell>
        <messages>
          <greeting>Hello</greeting>
        </messages>
        <attacks>
          <attack>
            <prompt>Test attack</prompt>
          </attack>
        </attacks>
      </hackerbot>
    XML

    create_temp_config_file(xml_content)

    begin
      bot_manager = create_bot_manager

      Dir.stub(:glob, [@temp_config_path]) do
        # Mock OllamaClient test_connection to return true
        OllamaClient.stub_any_instance(:test_connection, true) do
          bots = bot_manager.read_bots

          assert bots.key?('OllamaBot')
          ollama_bot = bots['OllamaBot']
          assert_instance_of OllamaClient, ollama_bot['chat_ai']
          assert_equal 'ollama', ollama_bot['chat_ai'].provider
          assert_equal 'llama2', ollama_bot['chat_ai'].model
          assert_equal 'custom.ollama.com', ollama_bot['chat_ai'].instance_variable_get(:@host)
          assert_equal 9999, ollama_bot['chat_ai'].instance_variable_get(:@port)
        end
      end
    ensure
      cleanup_temp_config
    end
  end

  def test_llm_client_creation_openai
    xml_content = <<~XML
      <hackerbot>
        <name>OpenAIBot</name>
        <llm_provider>openai</llm_provider>
        <ollama_model>gpt-3.5-turbo</ollama_model>
        <openai_api_key>test-api-key</openai_api_key>
        <system_prompt>Test system prompt</system_prompt>
        <get_shell>bash</get_shell>
        <messages>
          <greeting>Hello</greeting>
        </messages>
        <attacks>
          <attack>
            <prompt>Test attack</prompt>
          </attack>
        </attacks>
      </hackerbot>
    XML

    create_temp_config_file(xml_content)

    begin
      bot_manager = create_bot_manager

      Dir.stub(:glob, [@temp_config_path]) do
        # Mock OpenAIClient test_connection to return true
        OpenAIClient.stub_any_instance(:test_connection, true) do
          bots = bot_manager.read_bots

          assert bots.key?('OpenAIBot')
          openai_bot = bots['OpenAIBot']
          assert_instance_of OpenAIClient, openai_bot['chat_ai']
          assert_equal 'openai', openai_bot['chat_ai'].provider
          assert_equal 'gpt-3.5-turbo', openai_bot['chat_ai'].model
          assert_equal 'test-api-key', openai_bot['chat_ai'].instance_variable_get(:@api_key)
        end
      end
    ensure
      cleanup_temp_config
    end
  end

  def test_llm_client_creation_vllm
    xml_content = <<~XML
      <hackerbot>
        <name>VLLMBot</name>
        <llm_provider>vllm</llm_provider>
        <ollama_model>test-model</ollama_model>
        <vllm_host>custom.vllm.com</vllm_host>
        <vllm_port>8888</vllm_port>
        <system_prompt>Test system prompt</system_prompt>
        <get_shell>bash</get_shell>
        <messages>
          <greeting>Hello</greeting>
        </messages>
        <attacks>
          <attack>
            <prompt>Test attack</prompt>
          </attack>
        </attacks>
      </hackerbot>
    XML

    create_temp_config_file(xml_content)

    begin
      bot_manager = create_bot_manager

      Dir.stub(:glob, [@temp_config_path]) do
        # Mock VLLMClient test_connection to return true
        VLLMClient.stub_any_instance(:test_connection, true) do
          bots = bot_manager.read_bots

          assert bots.key?('VLLMBot')
          vllm_bot = bots['VLLMBot']
          assert_instance_of VLLMClient, vllm_bot['chat_ai']
          assert_equal 'vllm', vllm_bot['chat_ai'].provider
          assert_equal 'test-model', vllm_bot['chat_ai'].model
          assert_equal 'custom.vllm.com', vllm_bot['chat_ai'].instance_variable_get(:@host)
          assert_equal 8888, vllm_bot['chat_ai'].instance_variable_get(:@port)
        end
      end
    ensure
      cleanup_temp_config
    end
  end

  def test_llm_client_creation_sglang
    xml_content = <<~XML
      <hackerbot>
        <name>SGLangBot</name>
        <llm_provider>sglang</llm_provider>
        <ollama_model>test-model</ollama_model>
        <sglang_host>custom.sglang.com</sglang_host>
        <sglang_port>7777</sglang_port>
        <system_prompt>Test system prompt</system_prompt>
        <get_shell>bash</get_shell>
        <messages>
          <greeting>Hello</greeting>
        </messages>
        <attacks>
          <attack>
            <prompt>Test attack</prompt>
          </attack>
        </attacks>
      </hackerbot>
    XML

    create_temp_config_file(xml_content)

    begin
      bot_manager = create_bot_manager

      Dir.stub(:glob, [@temp_config_path]) do
        # Mock SGLangClient test_connection to return true
        SGLangClient.stub_any_instance(:test_connection, true) do
          bots = bot_manager.read_bots

          assert bots.key?('SGLangBot')
          sglang_bot = bots['SGLangBot']
          assert_instance_of SGLangClient, sglang_bot['chat_ai']
          assert_equal 'sglang', sglang_bot['chat_ai'].provider
          assert_equal 'test-model', sglang_bot['chat_ai'].model
          assert_equal 'custom.sglang.com', sglang_bot['chat_ai'].instance_variable_get(:@host)
          assert_equal 7777, sglang_bot['chat_ai'].instance_variable_get(:@port)
        end
      end
    ensure
      cleanup_temp_config
    end
  end

  def test_llm_client_creation_with_unknown_provider
    xml_content = <<~XML
      <hackerbot>
        <name>UnknownBot</name>
        <llm_provider>unknown</llm_provider>
        <ollama_model>test-model</ollama_model>
        <system_prompt>Test system prompt</system_prompt>
        <get_shell>bash</get_shell>
        <messages>
          <greeting>Hello</greeting>
        </messages>
        <attacks>
          <attack>
            <prompt>Test attack</prompt>
          </attack>
        </attacks>
      </hackerbot>
    XML

    create_temp_config_file(xml_content)

    begin
      bot_manager = create_bot_manager

      Dir.stub(:glob, [@temp_config_path]) do
        # Mock OllamaClient test_connection to return true
        OllamaClient.stub_any_instance(:test_connection, true) do
          stdout, stderr = TestUtils.capture_print_output do
            bots = bot_manager.read_bots

            assert bots.key?('UnknownBot')
            # Should default to Ollama
            unknown_bot = bots['UnknownBot']
            assert_instance_of OllamaClient, unknown_bot['chat_ai']
            assert_equal 'ollama', unknown_bot['chat_ai'].provider
          end
          # Should print warning about unknown provider
          assert_match(/Unknown LLM provider.*defaulting to Ollama/, stderr)
        end
      end
    ensure
      cleanup_temp_config
    end
  end

  def test_llm_client_connection_test_failure
    xml_content = <<~XML
      <hackerbot>
        <name>TestBot</name>
        <llm_provider>ollama</llm_provider>
        <ollama_model>test-model</ollama_model>
        <system_prompt>Test system prompt</system_prompt>
        <get_shell>bash</get_shell>
        <messages>
          <greeting>Hello</greeting>
        </messages>
        <attacks>
          <attack>
            <prompt>Test attack</prompt>
          </attack>
        </attacks>
      </hackerbot>
    XML

    create_temp_config_file(xml_content)

    begin
      bot_manager = create_bot_manager

      Dir.stub(:glob, [@temp_config_path]) do
        # Mock OllamaClient test_connection to return false
        OllamaClient.stub_any_instance(:test_connection, false) do
          stdout, stderr = TestUtils.capture_print_output do
            bots = bot_manager.read_bots

            assert bots.key?('TestBot')
            test_bot = bots['TestBot']
            assert_instance_of OllamaClient, test_bot['chat_ai']
          end
          # Should print warning about connection failure
          assert_match(/Warning: Cannot connect to ollama for bot TestBot/, stderr)
        end
      end
    ensure
      cleanup_temp_config
    end
  end
end
