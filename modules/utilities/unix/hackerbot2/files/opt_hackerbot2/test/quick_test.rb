#!/usr/bin/env ruby

# Quick Test Execution Script for Hackerbot
# This script provides a simple way to run individual test components
# and verify basic functionality without complex setup.

require_relative 'test_helper'
require 'fileutils'

class QuickTestRunner
  attr_reader :test_results

  def initialize
    @test_results = {
      passed: 0,
      failed: 0,
      errors: 0,
      total: 0,
      details: []
    }
  end

  def run_all_tests
    puts "=" * 60
    puts "HACKERBOT QUICK TEST EXECUTION"
    puts "=" * 60
    puts "Running quick verification tests..."
    puts ""

    # Test 1: Basic file loading
    test_file_loading

    # Test 2: Core classes exist
    test_core_classes

    # Test 3: LLM Client Factory
    test_llm_client_factory

    # Test 4: Print utilities
    test_print_utilities

    # Test 5: Base LLM Client
    test_base_llm_client

    # Print summary
    print_summary
  end

  def run_specific_test(test_name)
    case test_name.downcase
    when 'factory'
      test_llm_client_factory
    when 'print'
      test_print_utilities
    when 'base'
      test_base_llm_client
    when 'loading'
      test_file_loading
    when 'classes'
      test_core_classes
    else
      puts "Unknown test: #{test_name}"
      puts "Available tests: factory, print, base, loading, classes"
    end
  end

  private

  def test_file_loading
    print_test_header("File Loading")

    begin
      # Test if core files exist and are loadable
      files_to_check = [
        'llm_client.rb',
        'llm_client_factory.rb',
        'print.rb',
        'bot_manager.rb',
        'hackerbot.rb'
      ]

      files_to_check.each do |file|
        if File.exist?(file)
          print_result("✓ #{file} exists")
        else
          print_result("✗ #{file} missing", :error)
        end
      end

      # Test if we can load the basic modules without errors
      begin
        require_relative '../providers/llm_client'
        print_result("✓ llm_client.rb loads successfully")
      rescue LoadError => e
        print_result("✗ llm_client.rb failed to load: #{e.message}", :error)
      end

      begin
        require_relative '../print'
        print_result("✓ print.rb loads successfully")
      rescue LoadError => e
        print_result("✗ print.rb failed to load: #{e.message}", :error)
      end

    rescue => e
      print_result("✗ File loading test failed: #{e.message}", :error)
    end
  end

  def test_core_classes
    print_test_header("Core Classes")

    begin
      # Load required modules
      require_relative '../providers/llm_client'
      require_relative '../providers/llm_client_factory'
      require_relative '../print'

      # Test if classes are defined
      classes_to_check = [
        'LLMClient',
        'LLMClientFactory',
        'Print'
      ]

      classes_to_check.each do |class_name|
        if Object.const_defined?(class_name)
          print_result("✓ #{class_name} class is defined")
        else
          print_result("✗ #{class_name} class is missing", :error)
        end
      end

      # Test if constants are defined
      constants_to_check = [
        'DEFAULT_SYSTEM_PROMPT',
        'DEFAULT_MAX_TOKENS',
        'DEFAULT_TEMPERATURE',
        'DEFAULT_STREAMING'
      ]

      constants_to_check.each do |const_name|
        if Object.const_defined?(const_name)
          value = Object.const_get(const_name)
          print_result("✓ #{const_name} = #{value.inspect}")
        else
          print_result("✗ #{const_name} constant is missing", :error)
        end
      end

    rescue => e
      print_result("✗ Core classes test failed: #{e.message}", :error)
    end
  end

  def test_llm_client_factory
    print_test_header("LLM Client Factory")

    begin
      require_relative '../providers/llm_client_factory'

      # Test factory methods exist
      if LLMClientFactory.respond_to?(:create_client)
        print_result("✓ LLMClientFactory.create_client method exists")
      else
        print_result("✗ LLMClientFactory.create_client method missing", :error)
      end

      # Test creating different types of clients (without actually connecting)
      supported_providers = ['ollama', 'openai', 'vllm', 'sglang']

      # Test client creation for each provider with appropriate parameters
      supported_providers.each do |provider|
        begin
          case provider
          when 'ollama'
            client = LLMClientFactory.create_client(provider,
              host: 'localhost',
              port: 11434,
              model: 'test-model',
              system_prompt: 'test prompt',
              max_tokens: 100,
              temperature: 0.7,
              num_thread: 8,
              keepalive: -1,
              streaming: false
            )
          when 'openai'
            client = LLMClientFactory.create_client(provider,
              api_key: 'test-key',
              host: 'api.openai.com',
              model: 'test-model',
              system_prompt: 'test prompt',
              max_tokens: 100,
              temperature: 0.7,
              streaming: false
            )
          when 'vllm'
            client = LLMClientFactory.create_client(provider,
              host: 'localhost',
              port: 8000,
              model: 'test-model',
              system_prompt: 'test prompt',
              max_tokens: 100,
              temperature: 0.7,
              streaming: false
            )
          when 'sglang'
            client = LLMClientFactory.create_client(provider,
              host: 'localhost',
              port: 30000,
              model: 'test-model',
              system_prompt: 'test prompt',
              max_tokens: 100,
              temperature: 0.7,
              streaming: false
            )
          else
            raise "Unknown provider: #{provider}"
          end

          print_result("✓ #{provider.capitalize} client created successfully")
        rescue => e
          print_result("✗ #{provider.capitalize} client creation error: #{e.message}", :error)
        end
      end

    rescue => e
      print_result("✗ LLM Client Factory test failed: #{e.message}", :error)
    end
  end

  def test_print_utilities
    print_test_header("Print Utilities")

    begin
      require_relative '../print'

      # Test if color methods exist
      color_methods = [:red, :green, :yellow, :blue, :purple, :cyan, :grey, :bold]

      color_methods.each do |method|
        if Print.respond_to?(method)
          result = Print.send(method, "test")
          if result.is_a?(String) && result.include?("\e[")
            print_result("✓ Print.#{method} method works")
          else
            print_result("✗ Print.#{method} method doesn't return colored string", :error)
          end
        else
          print_result("✗ Print.#{method} method missing", :error)
        end
      end

      # Test if logging methods exist
      log_methods = [:debug, :verbose, :err, :info, :std, :local, :local_verbose]

      log_methods.each do |method|
        if Print.respond_to?(method)
          # Test that they don't crash with normal input
          stdout, stderr = TestUtils.capture_print_output do
            Print.send(method, "test message")
          end
          print_result("✓ Print.#{method} method works")
        else
          print_result("✗ Print.#{method} method missing", :error)
        end
      end

    rescue => e
      print_result("✗ Print Utilities test failed: #{e.message}", :error)
    end
  end

  def test_base_llm_client
    print_test_header("Base LLM Client")

    begin
      require_relative '../providers/llm_client'

      # Test if we can create a base LLM client
      begin
        client = LLMClient.new('test_provider', 'test_model', 'Test system prompt')
        print_result("✓ LLMClient instantiation works")
      rescue => e
        print_result("✗ LLMClient instantiation failed: #{e.message}", :error)
      end

      # Test if abstract methods raise NotImplementedError
      client = LLMClient.new('test_provider', 'test_model')

      abstract_methods = [:generate_response, :test_connection]

      abstract_methods.each do |method|
        begin
          if method == :test_connection
            client.send(method)
          else
            client.send(method, 'test')
          end
          print_result("✗ LLMClient.#{method} should raise NotImplementedError", :error)
        rescue NotImplementedError
          print_result("✓ LLMClient.#{method} correctly raises NotImplementedError")
        rescue => e
          print_result("✗ LLMClient.#{method} raised unexpected error: #{e.message}", :error)
        end
      end

      # Test if system prompt methods work
      client = LLMClient.new('test_provider', 'test_model', 'Original prompt')

      if client.respond_to?(:update_system_prompt) && client.respond_to?(:get_system_prompt)
        client.update_system_prompt('New prompt')
        if client.get_system_prompt == 'New prompt'
          print_result("✓ System prompt methods work correctly")
        else
          print_result("✗ System prompt methods don't work correctly", :error)
        end
      else
        print_result("✗ System prompt methods are missing", :error)
      end

    rescue => e
      print_result("✗ Base LLM Client test failed: #{e.message}", :error)
    end
  end

  def print_test_header(test_name)
    @test_results[:total] += 1
    puts "\n🧪 #{test_name}"
    puts "-" * 40
  end

  def print_result(message, type = :success)
    case type
    when :success
      puts "  #{message}"
      @test_results[:passed] += 1
    when :error
      puts "  #{message}"
      @test_results[:failed] += 1
    end

    @test_results[:details] << { test: @test_results[:total], message: message, type: type }
  end

  def print_summary
    puts "\n" + "=" * 60
    puts "QUICK TEST SUMMARY"
    puts "=" * 60

    puts "Total Tests Run: #{@test_results[:total]}"
    puts "Passed:         #{@test_results[:passed]}"
    puts "Failed:         #{@test_results[:failed]}"

    success_rate = @test_results[:total] > 0 ?
      ((@test_results[:passed].to_f / @test_results[:total]) * 100).round(1) : 0

    if success_rate >= 80
      puts "Success Rate:   #{success_rate}% ✅"
    elsif success_rate >= 60
      puts "Success Rate:   #{success_rate}% ⚠️"
    else
      puts "Success Rate:   #{success_rate}% ❌"
    end

    puts "\nFor detailed testing, run:"
    puts "  ruby test/run_tests.rb --verbose"
    puts "  ruby test/test_llm_client_factory.rb"
    puts "  ruby test/test_llm_client_base.rb"

    exit_code = @test_results[:failed]
    puts "\nTest suite completed with exit code: #{exit_code}"

    exit exit_code
  end
end

# Main execution
if __FILE__ == $0
  runner = QuickTestRunner.new

  if ARGV.empty?
    runner.run_all_tests
  elsif ARGV[0] == '--help' || ARGV[0] == '-h'
    puts "Usage: ruby #{File.basename(__FILE__)} [TEST_NAME]"
    puts ""
    puts "Available tests:"
    puts "  factory    - Test LLM Client Factory"
    puts "  print      - Test Print Utilities"
    puts "  base       - Test Base LLM Client"
    puts "  loading    - Test File Loading"
    puts "  classes    - Test Core Classes"
    puts ""
    puts "Run with no arguments for all tests."
  else
    runner.run_specific_test(ARGV[0])
  end
end
