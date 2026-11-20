require 'minitest/autorun'
require 'minitest/spec'
require_relative '../providers/llm_client'
require_relative '../print'
require_relative '../providers/ollama_client' if File.exist?('../providers/ollama_client.rb')
require_relative '../providers/openai_client' if File.exist?('../providers/openai_client.rb')
require_relative '../providers/vllm_client' if File.exist?('../providers/vllm_client.rb')
require_relative '../providers/sglang_client' if File.exist?('../providers/sglang_client.rb')
require_relative '../providers/llm_client_factory'
require_relative '../bot_manager'
require 'nokogiri'
require 'net/http'
require 'json'

# Test configuration
TEST_CONFIG = {
  default_irc_server: 'localhost',
  default_ollama_host: 'localhost',
  default_ollama_port: 11434,
  default_ollama_model: 'gemma3:1b',
  default_vllm_host: 'localhost',
  default_vllm_port: 8000,
  default_sglang_host: 'localhost',
  default_sglang_port: 30000,
  openai_api_key: 'test_api_key',
  test_system_prompt: 'You are a test assistant for unit testing.',
  test_prompt: 'Hello, this is a test prompt.',
  minimax_tokens: 10,
  max_temperature: 2.0
}

# Mock net/http responses for API testing
module HTTPMock
  def self.mock_success_response(body = '{}')
    mock_response = Object.new
    mock_response.define_singleton_method(:code) { '200' }
    mock_response.define_singleton_method(:body) { body.is_a?(String) ? body : body.to_json }
    mock_response
  end

  def self.mock_error_response(code = '500', body = 'Error')
    mock_response = Object.new
    mock_response.define_singleton_method(:code) { code }
    mock_response.define_singleton_method(:body) { body }
    mock_response
  end

  def self.mock_streaming_response(chunks = [])
    mock_response = Object.new
    mock_response.define_singleton_method(:code) { '200' }

    chunks.each do |chunk|
      mock_response.define_singleton_method(:read_body) do |&block|
        chunks.each { |c| block.call(c) }
      end
    end
    mock_response
  end
end

# Test utility functions
module TestUtils
  def self.create_temp_xml_file(content)
    require 'tempfile'
    file = Tempfile.new(['test_bot', '.xml'])
    file.write(content)
    file.close
    file.path
  end

  def self.cleanup_temp_file(file_path)
    File.delete(file_path) if File.exist?(file_path)
  end

  def self.create_sample_bot_config
    <<~XML
      <hackerbot>
        <name>TestBot</name>
        <llm_provider>ollama</llm_provider>
        <ollama_model>gemma3:1b</ollama_model>
        <system_prompt>You are a test bot.</system_prompt>
        <get_shell>bash</get_shell>
        <messages>
          <greeting>Hello test user!</greeting>
          <help>This is a test help message.</help>
          <say_ready>Ready when you are!</say_ready>
          <next>Moving to next attack.</next>
          <previous>Moving to previous attack.</previous>
          <goto>Going to specified attack.</goto>
          <last_attack>This was the last attack.</last_attack>
          <first_attack>This is the first attack.</first_attack>
          <getting_shell>Gaining shell access...</getting_shell>
          <got_shell>Shell access granted.</got_shell>
          <repeat>Try again!</repeat>
          <correct_answer>Correct!</correct_answer>
          <incorrect_answer>Incorrect!</incorrect_answer>
          <no_quiz>No quiz available.</no_quiz>
          <non_answer>I don't understand.</non_answer>
          <shell_fail_message>Shell access failed.</shell_fail_message>
          <invalid>Invalid attack number.</invalid>
        </messages>
        <attacks>
          <attack>
            <prompt>This is attack 1.</prompt>
            <system_prompt>Attack 1 system prompt.</system_prompt>
          </attack>
          <attack>
            <prompt>This is attack 2.</prompt>
            <system_prompt>Attack 2 system prompt.</system_prompt>
            <quiz>
              <question>What is 2+2?</question>
              <answer>4</answer>
              <correct_answer_response>Correct!</correct_answer_response>
            </quiz>
          </attack>
        </attacks>
      </hackerbot>
    XML
  end

  def self.capture_print_output(&block)
    original_stdout = $stdout
    original_stderr = $stderr

    $stdout = StringIO.new
    $stderr = StringIO.new

    begin
      block.call
      [$stdout.string, $stderr.string]
    ensure
      $stdout = original_stdout
      $stderr = original_stderr
    end
  end

  def self.suppress_print_output(&block)
    capture_print_output(&block)
    nil
  end
end

# Custom assertions for testing
class Minitest::Test
  def assert_includes_in_order(collection, *expected_items)
    index = 0
    expected_items.each do |item|
      assert collection.include?(item), "Expected #{collection.inspect} to include #{item.inspect}"
      new_index = collection.index(item)
      assert new_index >= index, "Expected #{item.inspect} to come after previous items"
      index = new_index
    end
  end

  def assert_valid_json(json_string)
    JSON.parse(json_string)
  rescue JSON::ParserError => e
    flunk "Invalid JSON: #{e.message}"
  end

  def assert_message_format(message, *expected_keywords)
    expected_keywords.each do |keyword|
      assert message.include?(keyword.to_s), "Expected message '#{message}' to contain keyword '#{keyword}'"
    end
  end

  def refute_empty_string(string)
    refute string.empty?, "Expected string not to be empty"
  end

  def assert_positive_number(number)
    assert number > 0, "Expected number to be positive, got #{number}"
  end

  def assert_valid_url(url)
    uri = URI.parse(url)
    uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)
  rescue URI::InvalidURIError
    flunk "Invalid URL: #{url}"
  end
end

# Base test class for all LLM client tests
class LLMClientTest < Minitest::Test
  def setup
    @default_provider = 'test'
    @default_model = 'test_model'
    @default_system_prompt = TEST_CONFIG[:test_system_prompt]
    @default_max_tokens = TEST_CONFIG[:minimax_tokens]
    @default_temperature = 1.0
    @default_streaming = true
  end

  protected

  def create_client(**options)
    raise NotImplementedError, "Subclasses must implement create_client"
  end

  def default_client_options
    {
      provider: @default_provider,
      model: @default_model,
      system_prompt: @default_system_prompt,
      max_tokens: @default_max_tokens,
      temperature: @default_temperature,
      streaming: @default_streaming
    }
  end
end

# Base test class for BotManager tests
class BotManagerTest < Minitest::Test
  def setup
    @irc_server = TEST_CONFIG[:default_irc_server]
    @llm_provider = 'ollama'
    @ollama_host = TEST_CONFIG[:default_ollama_host]
    @ollama_port = TEST_CONFIG[:default_ollama_port]
    @ollama_model = TEST_CONFIG[:default_ollama_model]
    @openai_api_key = TEST_CONFIG[:openai_api_key]
    @vllm_host = TEST_CONFIG[:default_vllm_host]
    @vllm_port = TEST_CONFIG[:default_vllm_port]
    @sglang_host = TEST_CONFIG[:default_sglang_host]
    @sglang_port = TEST_CONFIG[:default_sglang_port]

    # Suppress print output during tests
    @old_stdout = $stdout
    @old_stderr = $stderr
    $stdout = StringIO.new
    $stderr = StringIO.new
  end

  def teardown
    $stdout = @old_stdout
    $stderr = @old_stderr
  end

  protected

  def create_bot_manager(**options)
    defaults = {
      irc_server_ip_address: @irc_server,
      llm_provider: @llm_provider,
      ollama_host: @ollama_host,
      ollama_port: @ollama_port,
      ollama_model: @ollama_model,
      openai_api_key: @openai_api_key,
      vllm_host: @vllm_host,
      vllm_port: @vllm_port,
      sglang_host: @sglang_host,
      sglang_port: @sglang_port
    }

    BotManager.new(**defaults.merge(options))
  end

  def create_temp_config_file(content = TestUtils.create_sample_bot_config)
    @temp_config_path = TestUtils.create_temp_xml_file(content)
  end

  def cleanup_temp_config
    TestUtils.cleanup_temp_file(@temp_config_path) if @temp_config_path
  end
end
