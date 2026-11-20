require_relative 'test_helper'

class TestLLMClientBase < Minitest::Test
  def test_constants_defined
    refute_nil DEFAULT_SYSTEM_PROMPT
    refute_nil DEFAULT_MAX_TOKENS
    refute_nil DEFAULT_TEMPERATURE
    refute_nil DEFAULT_STREAMING
    refute_nil DEFAULT_NUM_THREAD
    refute_nil DEFAULT_KEEPALIVE

    assert_positive_number DEFAULT_MAX_TOKENS
    assert_positive_number DEFAULT_TEMPERATURE
    assert_includes [true, false], DEFAULT_STREAMING
    assert_positive_number DEFAULT_NUM_THREAD
  end

  def test_default_system_prompt_is_string
    assert_instance_of String, DEFAULT_SYSTEM_PROMPT
    refute_empty_string DEFAULT_SYSTEM_PROMPT
    assert_includes DEFAULT_SYSTEM_PROMPT.downcase, 'cybersecurity'
  end

  def test_llm_client_initialization
    client = LLMClient.new('test_provider', 'test_model', 'Test system prompt')

    assert_equal 'test_provider', client.provider
    assert_equal 'test_model', client.model
    assert_equal 'Test system prompt', client.system_prompt
    assert_respond_to client, :max_tokens
    assert_respond_to client, :temperature
    assert_respond_to client, :streaming
  end

  def test_llm_client_initialization_with_defaults
    client = LLMClient.new('test_provider', 'test_model')

    assert_equal 'test_provider', client.provider
    assert_equal 'test_model', client.model
    assert_equal DEFAULT_SYSTEM_PROMPT, client.system_prompt
    assert_equal DEFAULT_MAX_TOKENS, client.max_tokens
    assert_equal DEFAULT_TEMPERATURE, client.temperature
    assert_equal DEFAULT_STREAMING, client.streaming
  end

  def test_llm_client_initialization_with_custom_values
    custom_system_prompt = 'Custom system prompt for testing'
    custom_max_tokens = 500
    custom_temperature = 1.5
    custom_streaming = false

    client = LLMClient.new(
      'test_provider',
      'test_model',
      custom_system_prompt,
      custom_max_tokens,
      custom_temperature,
      custom_streaming
    )

    assert_equal 'test_provider', client.provider
    assert_equal 'test_model', client.model
    assert_equal custom_system_prompt, client.system_prompt
    assert_equal custom_max_tokens, client.max_tokens
    assert_equal custom_temperature, client.temperature
    assert_equal custom_streaming, client.streaming
  end

  def test_llm_client_abstract_methods
    client = LLMClient.new('test_provider', 'test_model')

    assert_raises NotImplementedError do
      client.generate_response('test prompt')
    end

    assert_raises NotImplementedError do
      client.test_connection
    end
  end

  def test_update_system_prompt
    client = LLMClient.new('test_provider', 'test_model', 'Original prompt')
    new_prompt = 'Updated system prompt'

    client.update_system_prompt(new_prompt)

    assert_equal new_prompt, client.system_prompt
    assert_equal new_prompt, client.get_system_prompt
  end

  def test_get_system_prompt
    original_prompt = 'Original system prompt'
    client = LLMClient.new('test_provider', 'test_model', original_prompt)

    assert_equal original_prompt, client.get_system_prompt
  end

  def test_accessor_methods
    client = LLMClient.new('test_provider', 'test_model')

    assert_respond_to client, :provider
    assert_respond_to client, :model
    assert_respond_to client, :system_prompt
    assert_respond_to client, :max_tokens
    assert_respond_to client, :temperature
    assert_respond_to client, :streaming

    # Test that they are readable/writable
    client.provider = 'new_provider'
    assert_equal 'new_provider', client.provider

    client.model = 'new_model'
    assert_equal 'new_model', client.model

    client.max_tokens = 999
    assert_equal 999, client.max_tokens

    client.temperature = 2.0
    assert_equal 2.0, client.temperature

    client.streaming = false
    assert_equal false, client.streaming
  end

  def test_temperature_range_validation
    client = LLMClient.new('test_provider', 'test_model')

    # Test various temperature values
    [0.0, 0.5, 1.0, 1.5, 2.0].each do |temp|
      client.temperature = temp
      assert_equal temp, client.temperature
    end
  end

  def test_max_tokens_range_validation
    client = LLMClient.new('test_provider', 'test_model')

    # Test various max_tokens values
    [1, 10, 100, 1000, 5000].each do |tokens|
      client.max_tokens = tokens
      assert_equal tokens, client.max_tokens
    end
  end

  def test_streaming_boolean_values
    client = LLMClient.new('test_provider', 'test_model')

    [true, false].each do |streaming|
      client.streaming = streaming
      assert_equal streaming, client.streaming
    end
  end

  def test_inheritance
    client = LLMClient.new('test_provider', 'test_model')
    assert_kind_of Object, client
    assert_respond_to client, :generate_response
    assert_respond_to client, :test_connection
    assert_respond_to client, :update_system_prompt
    assert_respond_to client, :get_system_prompt
  end

  def test_instance_variables
    client = LLMClient.new('test_provider', 'test_model', 'Test prompt')

    assert_equal 'test_provider', client.instance_variable_get(:@provider)
    assert_equal 'test_model', client.instance_variable_get(:@model)
    assert_equal 'Test prompt', client.instance_variable_get(:@system_prompt)
    assert_equal DEFAULT_MAX_TOKENS, client.instance_variable_get(:@max_tokens)
    assert_equal DEFAULT_TEMPERATURE, client.instance_variable_get(:@temperature)
    assert_equal DEFAULT_STREAMING, client.instance_variable_get(:@streaming)
  end
end

class TestPrintUtilities < Minitest::Test
  def test_colorize_method_exists
    assert_respond_to Print, :colorize
  end

  def test_colorize_formats_text
    text = "Test text"
    color_code = "\e[31m"  # Red
    reset_code = "\e[0m"

    result = Print.colorize(text, color_code)
    expected = "#{color_code}#{text}#{reset_code}"

    assert_equal expected, result
  end

  def test_red_color_method
    result = Print.red("Red text")
    assert_equal "\e[31mRed text\e[0m", result
  end

  def test_green_color_method
    result = Print.green("Green text")
    assert_equal "\e[32mGreen text\e[0m", result
  end

  def test_yellow_color_method
    result = Print.yellow("Yellow text")
    assert_equal "\e[33mYellow text\e[0m", result
  end

  def test_blue_color_method
    result = Print.blue("Blue text")
    assert_equal "\e[34mBlue text\e[0m", result
  end

  def test_purple_color_method
    result = Print.purple("Purple text")
    assert_equal "\e[35mPurple text\e[0m", result
  end

  def test_cyan_color_method
    result = Print.cyan("Cyan text")
    assert_equal "\e[36mCyan text\e[0m", result
  end

  def test_grey_color_method
    result = Print.grey("Grey text")
    assert_equal "\e[37mGrey text\e[0m", result
  end

  def test_bold_color_method
    result = Print.bold("Bold text")
    assert_equal "\e[2mBold text\e[0m", result
  end

  def test_all_color_methods_return_strings
    color_methods = [:red, :green, :yellow, :blue, :purple, :cyan, :grey, :bold]

    color_methods.each do |method|
      result = Print.send(method, "Test")
      assert_instance_of String, result, "Print.#{method} should return a String"
    end
  end

  def test_debug_method
    stdout, stderr = TestUtils.capture_print_output do
      Print.debug("Debug message")
    end

    assert_match(/Debug message/, stdout)
    assert_empty stderr
  end

  def test_verbose_method
    stdout, stderr = TestUtils.capture_print_output do
      Print.verbose("Verbose message")
    end

    assert_match(/Verbose message/, stdout)
    assert_empty stderr
  end

  def test_err_method
    stdout, stderr = TestUtils.capture_print_output do
      Print.err("Error message")
    end

    assert_match(/Error message/, stderr)
    assert_empty stdout
  end

  def test_info_method
    stdout, stderr = TestUtils.capture_print_output do
      Print.info("Info message")
    end

    assert_match(/Info message/, stdout)
    assert_empty stderr
  end

  def test_std_method
    stdout, stderr = TestUtils.capture_print_output do
      Print.std("Standard message")
    end

    assert_match(/Standard message/, stdout)
    assert_empty stderr
  end

  def test_local_method
    stdout, stderr = TestUtils.capture_print_output do
      Print.local("Local message")
    end

    assert_empty stdout
    assert_match(/Local message/, stderr)
  end

  def test_local_verbose_method
    stdout, stderr = TestUtils.capture_print_output do
      Print.local_verbose("Local verbose message")
    end

    assert_empty stdout
    assert_match(/Local verbose message/, stderr)
  end

  def test_logging_methods_handle_empty_messages
    logging_methods = [:debug, :verbose, :err, :info, :std, :local, :local_verbose]

    logging_methods.each do |method|
      stdout, stderr = TestUtils.capture_print_output do
        Print.send(method, "")
      end
    end
    # Should not raise any errors
  end

  def test_logging_methods_handle_nil_messages
    logging_methods = [:debug, :verbose, :err, :info, :std, :local, :local_verbose]

    logging_methods.each do |method|
      begin
        stdout, stderr = TestUtils.capture_print_output do
          Print.send(method, nil)
        end
      rescue => e
        flunk "Print.#{method} should handle nil values without raising #{e.class}: #{e.message}"
      end
    end
  end

  def test_logging_methods_handle_special_characters
    special_chars = "Special chars: \n\t\"\'\\"

    logging_methods = [:debug, :verbose, :err, :info, :std, :local, :local_verbose]

    logging_methods.each do |method|
      stdout, stderr = TestUtils.capture_print_output do
        Print.send(method, special_chars)
      end
    end
    # Should not raise any errors
  end

  def test_color_methods_handle_special_characters
    special_chars = "Special: \n\t\"\'\\"
    color_methods = [:red, :green, :yellow, :blue, :purple, :cyan, :grey, :bold]

    color_methods.each do |method|
      result = Print.send(method, special_chars)
      assert_instance_of String, result
      assert_includes result, special_chars
    end
  end

  def test_color_methods_handle_empty_strings
    color_methods = [:red, :green, :yellow, :blue, :purple, :cyan, :grey, :bold]

    color_methods.each do |method|
      result = Print.send(method, "")
      assert_instance_of String, result
      assert_match(/\e\[\d+m/, result)  # Should contain color codes
      assert_match(/\e\[0m/, result)     # Should contain reset code
    end
  end

  def test_color_methods_handle_nil
    color_methods = [:red, :green, :yellow, :blue, :purple, :cyan, :grey, :bold]

    color_methods.each do |method|
      result = Print.send(method, nil)
      assert_instance_of String, result
      assert_match(/\e\[\d+m/, result)  # Should contain color codes
      assert_match(/\e\[0m/, result)     # Should contain reset code
    end
  end

  def test_print_class_is_module
    assert_kind_of Module, Print
  end

  def test_all_expected_methods_exist
    expected_methods = [
      :colorize, :red, :green, :yellow, :blue, :purple, :cyan, :grey, :bold,
      :debug, :verbose, :err, :info, :std, :local, :local_verbose
    ]

    expected_methods.each do |method|
      assert_respond_to Print, method, "Print should respond to #{method}"
    end
  end

  def test_color_codes_are_correct
    # Verify color codes are standard ANSI color codes
    assert_equal "\e[31m", Print.red("")[0..4]  # Red
    assert_equal "\e[32m", Print.green("")[0..4]  # Green
    assert_equal "\e[33m", Print.yellow("")[0..4]  # Yellow
    assert_equal "\e[34m", Print.blue("")[0..4]  # Blue
    assert_equal "\e[35m", Print.purple("")[0..4]  # Purple
    assert_equal "\e[36m", Print.cyan("")[0..4]  # Cyan
    assert_equal "\e[37m", Print.grey("")[0..4]  # Grey
    assert_equal "\e[2m", Print.bold("")[0..3]   # Bold (dim)
  end

  def test_reset_code_is_appended
    text = "Test"
    color_methods = [:red, :green, :yellow, :blue, :purple, :cyan, :grey, :bold]

    color_methods.each do |method|
      result = Print.send(method, text)
      assert_match(/\e\[0m$/, result, "Reset code should be appended to #{method} output")
    end
  end
end
