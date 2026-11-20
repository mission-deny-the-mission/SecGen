require_relative 'test_helper'

class TestHackerbot < Minitest::Test
  def setup
    @original_args =ARGV.dup
    @default_config = {
      irc_server_ip_address: 'localhost',
      llm_provider: 'ollama',
      ollama_host: 'localhost',
      ollama_port: 11434,
      ollama_model: 'gemma3:1b',
      openai_api_key: nil,
      vllm_host: 'localhost',
      vllm_port: 8000,
      sglang_host: 'localhost',
      sglang_port: 30000
    }
  end

  def teardown
    ARGV.replace(@original_args)
  end

  def test_command_line_parsing_with_no_arguments
    ARGV.clear

    # Suppress print output during loading
    stdout, stderr = TestUtils.capture_print_output do
      require_relative '../hackerbot'
    end

    # Verify default values are set
    assert_equal 'localhost', $irc_server_ip_address
    assert_equal 'ollama', $llm_provider
    assert_equal 'localhost', $ollama_host
    assert_equal 11434, $ollama_port
    assert_equal 'gemma3:1b', $ollama_model
    assert_nil $openai_api_key
    assert_equal 'localhost', $vllm_host
    assert_equal 8000, $vllm_port
    assert_equal 'localhost', $sglang_host
    assert_equal 30000, $sglang_port
  end

  def test_help_option
    ARGV.replace(['--help'])

    stdout, stderr = TestUtils.capture_print_output do
      assert_raises SystemExit do
        load_relative '../hackerbot'
      end
    end

    # Verify help message is displayed
    assert_match(/USAGE/, stdout)
    assert_match(/OPTIONS/, stdout)
    assert_match(/--irc-server/, stdout)
    assert_match(/--llm-provider/, stdout)
    assert_match(/--help/, stdout)
  end

  def test_short_help_option
    ARGV.replace(['-h'])

    stdout, stderr = TestUtils.capture_print_output do
      assert_raises SystemExit do
        load_relative '../hackerbot'
      end
    end

    # Verify help message is displayed
    assert_match(/USAGE/, stdout)
    assert_match(/OPTIONS/, stdout)
  end

  def test_irc_server_option
    ARGV.replace(['--irc-server', '192.168.1.100'])

    stdout, stderr = TestUtils.capture_print_output do
      load_relative '../hackerbot'
    end

    assert_equal '192.168.1.100', $irc_server_ip_address
  end

  def test_short_irc_server_option
    ARGV.replace(['-i', '192.168.1.100'])

    stdout, stderr = TestUtils.capture_print_output do
      load_relative '../hackerbot'
    end

    assert_equal '192.168.1.100', $irc_server_ip_address
  end

  def test_llm_provider_option
    ARGV.replace(['--llm-provider', 'openai'])

    stdout, stderr = TestUtils.capture_print_output do
      load_relative '../hackerbot'
    end

    assert_equal 'openai', $llm_provider
  end

  def test_short_llm_provider_option
    ARGV.replace(['-l', 'vllm'])

    stdout, stderr = TestUtils.capture_print_output do
      load_relative '../hackerbot'
    end

    assert_equal 'vllm', $llm_provider
  end

  def test_ollama_host_option
    ARGV.replace(['--ollama-host', 'ollama.example.com'])

    stdout, stderr = TestUtils.capture_print_output do
      load_relative '../hackerbot'
    end

    assert_equal 'ollama.example.com', $ollama_host
  end

  def test_short_ollama_host_option
    ARGV.replace(['-o', 'ollama.example.com'])

    stdout, stderr = TestUtils.capture_print_output do
      load_relative '../hackerbot'
    end

    assert_equal 'ollama.example.com', $ollama_host
  end

  def test_ollama_port_option
    ARGV.replace(['--ollama-port', '9999'])

    stdout, stderr = TestUtils.capture_print_output do
      load_relative '../hackerbot'
    end

    assert_equal 9999, $ollama_port
  end

  def test_short_ollama_port_option
    ARGV.replace(['-p', '9999'])

    stdout, stderr = TestUtils.capture_print_output do
      load_relative '../hackerbot'
    end

    assert_equal 9999, $ollama_port
  end

  def test_ollama_model_option
    ARGV.replace(['--ollama-model', 'llama2'])

    stdout, stderr = TestUtils.capture_print_output do
      load_relative '../hackerbot'
    end

    assert_equal 'llama2', $ollama_model
  end

  def test_short_ollama_model_option
    ARGV.replace(['-m', 'mistral'])

    stdout, stderr = TestUtils.capture_print_output do
      load_relative '../hackerbot'
    end

    assert_equal 'mistral', $ollama_model
  end

  def test_openai_api_key_option
    ARGV.replace(['--openai-api-key', 'sk-test123456'])

    stdout, stderr = TestUtils.capture_print_output do
      load_relative '../hackerbot'
    end

    assert_equal 'sk-test123456', $openai_api_key
  end

  def test_short_openai_api_key_option
    ARGV.replace(['-k', 'sk-test789'])

    stdout, stderr = TestUtils.capture_print_output do
      load_relative '../hackerbot'
    end

    assert_equal 'sk-test789', $openai_api_key
  end

  def test_vllm_host_option
    ARGV.replace(['--vllm-host', 'vllm.example.com'])

    stdout, stderr = TestUtils.capture_print_output do
      load_relative '../hackerbot'
    end

    assert_equal 'vllm.example.com', $vllm_host
  end

  def test_vllm_port_option
    ARGV.replace(['--vllm-port', '8888'])

    stdout, stderr = TestUtils.capture_print_output do
      load_relative '../hackerbot'
    end

    assert_equal 8888, $vllm_port
  end

  def test_sglang_host_option
    ARGV.replace(['--sglang-host', 'sglang.example.com'])

    stdout, stderr = TestUtils.capture_print_output do
      load_relative '../hackerbot'
    end

    assert_equal 'sglang.example.com', $sglang_host
  end

  def test_sglang_port_option
    ARGV.replace(['--sglang-port', '7777'])

    stdout, stderr = TestUtils.capture_print_output do
      load_relative '../hackerbot'
    end

    assert_equal 7777, $sglang_port
  end

  def test_streaming_option_true
    ARGV.replace(['--streaming', 'true'])

    stdout, stderr = TestUtils.capture_print_output do
      load_relative '../hackerbot'
    end

    assert_equal true, $DEFAULT_STREAMING
  end

  def test_streaming_option_false
    ARGV.replace(['--streaming', 'false'])

    stdout, stderr = TestUtils.capture_print_output do
      load_relative '../hackerbot'
    end

    assert_equal false, $DEFAULT_STREAMING
  end

  def test_short_streaming_option
    ARGV.replace(['-s', 'false'])

    stdout, stderr = TestUtils.capture_print_output do
      load_relative '../hackerbot'
    end

    assert_equal false, $DEFAULT_STREAMING
  end

  def test_invalid_streaming_option
    ARGV.replace(['--streaming', 'invalid'])

    stdout, stderr = TestUtils.capture_print_output do
      assert_raises SystemExit do
        load_relative '../hackerbot'
      end
    end

    assert_match(/Streaming argument must be 'true' or 'false'/, stderr)
  end

  def test_invalid_argument
    ARGV.replace(['--invalid-option'])

    stdout, stderr = TestUtils.capture_print_output do
      assert_raises SystemExit do
        load_relative '../hackerbot'
      end
    end

    assert_match(/Argument not valid/, stderr)
  end

  def test_multiple_options
    ARGV.replace([
      '--irc-server', 'irc.example.com',
      '--llm-provider', 'openai',
      '--ollama-host', 'ollama.example.com',
      '--ollama-port', '9999',
      '--ollama-model', 'gpt-3.5-turbo',
      '--openai-api-key', 'sk-test123',
      '--vllm-host', 'vllm.example.com',
      '--vllm-port', '8888',
      '--sglang-host', 'sglang.example.com',
      '--sglang-port', '7777',
      '--streaming', 'true'
    ])

    stdout, stderr = TestUtils.capture_print_output do
      load_relative '../hackerbot'
    end

    assert_equal 'irc.example.com', $irc_server_ip_address
    assert_equal 'openai', $llm_provider
    assert_equal 'ollama.example.com', $ollama_host
    assert_equal 9999, $ollama_port
    assert_equal 'gpt-3.5-turbo', $ollama_model
    assert_equal 'sk-test123', $openai_api_key
    assert_equal 'vllm.example.com', $vllm_host
    assert_equal 8888, $vllm_port
    assert_equal 'sglang.example.com', $sglang_host
    assert_equal 7777, $sglang_port
    assert_equal true, $DEFAULT_STREAMING
  end

  def test_main_application_initialization
    # Skip the main execution for testing purposes
    skip "This test would require actual BotManager initialization"

    # This would test the main execution block:
    # if __FILE__ == $0
    #   bot_manager = BotManager.new(...)
    #   bots = bot_manager.read_bots
    #   bot_manager.start_bots
    # end
  end

  private

  def load_relative(file_path)
    # Reset global variables to nil
    $irc_server_ip_address = nil
    $llm_provider = nil
    $ollama_host = nil
    $ollama_port = nil
    $ollama_model = nil
    $openai_api_key = nil
    $vllm_host = nil
    $vllm_port = nil
    $sglang_host = nil
    $sglang_port = nil
    $DEFAULT_STREAMING = nil

    # Load the file
    load File.expand_path(file_path + '.rb', __dir__)
  end
end
