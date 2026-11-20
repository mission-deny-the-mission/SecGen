#!/usr/bin/env ruby

# Test Runner for Hackerbot Unit Test Suite
# This script runs all unit tests and provides a comprehensive summary

require_relative 'test_helper'
require 'fileutils'
require 'optparse'

# Test configuration
RUNNER_TEST_CONFIG = {
  verbose: false,
  pattern: 'test_*.rb',
  exclude_files: [],
  only_failures: false,
  output_format: :progress
}

# Parse command line options
options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: #{File.basename(__FILE__)} [OPTIONS]"

  opts.on('-v', '--verbose', 'Run tests with verbose output') do
    options[:verbose] = true
  end

  opts.on('-p', '--pattern PATTERN', 'Test file pattern (default: test_*.rb)') do |pattern|
    options[:pattern] = pattern
  end

  opts.on('-e', '--exclude FILES', 'Exclude specific files (comma-separated)') do |files|
    options[:exclude] = files.split(',')
  end

  opts.on('-f', '--failures-only', 'Only show failed tests') do
    options[:failures_only] = true
  end

  opts.on('-o', '--output FORMAT', 'Output format: progress, documentation, or summary') do |format|
    options[:format] = format.to_sym
  end

  opts.on('-h', '--help', 'Show this help message') do
    puts opts
    exit
  end
end.parse!

# Apply configuration
RUNNER_TEST_CONFIG[:verbose] = options[:verbose]
RUNNER_TEST_CONFIG[:pattern] = options[:pattern] if options[:pattern]
RUNNER_TEST_CONFIG[:exclude_files] = options[:exclude].map(&:strip) if options[:exclude]
RUNNER_TEST_CONFIG[:only_failures] = options[:failures_only]
RUNNER_TEST_CONFIG[:output_format] = options[:format] if options[:format]

# Color codes for output
class Colors
  def self.red(text);    "\e[31m#{text}\e[0m"; end
  def self.green(text);  "\e[32m#{text}\e[0m"; end
  def self.yellow(text); "\e[33m#{text}\e[0m"; end
  def self.blue(text);   "\e[34m#{text}\e[0m"; end
  def self.purple(text); "\e[35m#{text}\e[0m"; end
  def self.cyan(text);   "\e[36m#{text}\e[0m"; end
  def self.bold(text);   "\e[1m#{text}\e[0m"; end
end

# Test result collection
class TestResults
  attr_reader :total_tests, :assertions, :failures, :errors, :skips, :passed
  attr_reader :failure_details, :error_details, :skip_details

  def initialize
    @total_tests = 0
    @assertions = 0
    @failures = 0
    @errors = 0
    @skips = 0
    @passed = 0
    @failure_details = []
    @error_details = []
    @skip_details = []
    @start_time = Time.now
  end

  def record_test_result(result)
    @total_tests += 1
    @assertions += result.assertions

    if result.passed?
      @passed += 1
    elsif result.failures.any?
      @failures += 1
      @failure_details << result
    elsif result.errors.any?
      @errors += 1
      @error_details << result
    elsif result.skipped?
      @skips += 1
      @skip_details << result
    end
  end

  def elapsed_time
    Time.now - @start_time
  end

  def success_rate
    return 0 if @total_tests.zero?
    ((@passed.to_f / @total_tests) * 100).round(2)
  end

  def summary
    {
      total: @total_tests,
      passed: @passed,
      failures: @failures,
      errors: @errors,
      skips: @skips,
      assertions: @assertions,
      success_rate: success_rate,
      elapsed_time: elapsed_time,
      failure_details: @failure_details,
      error_details: @error_details,
      skip_details: @skip_details
    }
  end
end

# Custom Minitest reporter for better output
class CustomReporter < Minitest::AbstractReporter
  def initialize(results, options = {})
    @results = results
    @verbose = options[:verbose]
    @show_progress = options[:output_format] == :progress
    @show_documentation = options[:output_format] == :documentation
    @show_summary = options[:output_format] == :summary
    @only_failures = options[:failures_only]
  end

  def start
    puts '=' * 80
    puts Colors.bold("HACKERBOT UNIT TEST SUITE")
    puts '=' * 80
    puts "Starting test run at #{Time.now.strftime('%Y-%m-%d %H:%M:%S')}"
    puts "Ruby version: #{RUBY_VERSION}"
    puts "Minitest version: #{Minitest::VERSION}"
    puts "" if @show_progress || @show_documentation
  end

  def record(result)
    @results.record_test_result(result)

    if @show_documentation
      print_test_result_documentation(result)
    elsif @show_progress
      print_test_result_progress(result)
    end
  end

  def report
    if @show_summary
      print_summary_report
    else
      print_detailed_report
    end
  end

  private

  def print_test_result_progress(result)
    if result.passed?
      print Colors.green(".") unless @only_failures
    elsif result.failures.any?
      print Colors.red("F")
    elsif result.errors.any?
      print Colors.red("E")
    elsif result.skipped?
      print Colors.yellow("S") unless @only_failures
    end
  end

  def print_test_result_documentation(result)
    if result.passed? && !@only_failures
      print Colors.green("✓ #{result.name}\n")
    elsif result.failures.any?
      print Colors.red("✗ #{result.name}\n")
    elsif result.errors.any?
      print Colors.red("✗ #{result.name} (ERROR)\n")
    end
  end

  def print_detailed_report
    puts "" if @show_progress

    # Print failures
    unless @results.failure_details.empty?
      puts Colors.red("\nFailures:")
      puts "=" * 40
      @results.failure_details.each_with_index do |result, index|
        puts "#{index + 1}) #{result.name}"
        puts Colors.bold("   Failure: #{result.failures.first.location}")
        puts "   #{result.failures.first.message}"
        puts ""
      end
    end

    # Print errors
    unless @results.error_details.empty?
      puts Colors.red("\nErrors:")
      puts "=" * 40
      @results.error_details.each_with_index do |result, index|
        puts "#{index + 1}) #{result.name}"
        puts Colors.bold("   Error: #{result.errors.first.location}")
        puts "   #{result.errors.first.message}"
        puts ""
      end
    end



    print_summary_report
  end

  def print_summary_report
    puts "\n" + "=" * 80
    puts Colors.bold("TEST SUMMARY")
    puts "=" * 80

    summary = @results.summary

    # Test statistics
    puts "Total Tests:     #{summary[:total]}"
    puts "Passed:          #{Colors.green(summary[:passed].to_s)}"
    puts "Failures:        #{Colors.red(summary[:failures].to_s)}"
    puts "Errors:          #{Colors.red(summary[:errors].to_s)}"
    puts "Skipped:         #{Colors.yellow(summary[:skips].to_s)}"
    puts "Assertions:      #{summary[:assertions]}"
    rate = summary[:success_rate]
    color = rate > 80 ? Colors.green : (rate > 60 ? Colors.yellow : Colors.red)
    puts "Success Rate:    #{color("#{rate}%")}"
    puts "Elapsed Time:    #{summary[:elapsed_time].round(2)}s"

    # Overall status
    if summary[:failures].zero? && summary[:errors].zero?
      puts "\n#{Colors.green('✓ ALL TESTS PASSED!')}"
      exit_code = 0
    else
      puts "\n#{Colors.red('✗ SOME TESTS FAILED!')}"
      exit_code = summary[:failures] + summary[:errors]
    end

    # Coverage information
    puts "\n" + "=" * 80
    puts Colors.bold("COVERAGE SUMMARY")
    puts "=" * 80
    puts "Test files covered: #{test_files_covered}"
    puts "Components tested:"
    puts "  ✓ Hackerbot main application (hackerbot.rb)"
    puts "  ✓ OpenAI client (openai_client.rb)"
    puts "  ✓ VLLM client (vllm_client.rb)"
    puts "  ✓ LLM client factory (llm_client_factory.rb)"
    puts "  ✓ Bot manager (bot_manager.rb)"
    puts "  ✓ Print utilities (print.rb)"
    puts "  ✓ LLM client base class (llm_client.rb)"

    # Additional information
    puts "\n" + "=" * 80
    puts Colors.bold("ADDITIONAL INFORMATION")
    puts "=" * 80
    puts "For more detailed test analysis, run with:"
    puts "  ruby #{__FILE__} --verbose"
    puts "  ruby #{__FILE__} --output documentation"
    puts "  ruby #{__FILE__} --failures-only"
    puts "\nTo run individual test files:"
    puts "  ruby test/test_hackerbot.rb"
    puts "  ruby test/test_openai_client.rb"
    puts "  ruby test/test_vllm_client.rb"
    puts "  ruby test/test_llm_client_factory.rb"
    puts "  ruby test/test_bot_manager.rb"

    exit exit_code
  end

  def test_files_covered
    test_files = Dir.glob(File.join(File.dirname(__FILE__), RUNNER_TEST_CONFIG[:pattern]))
    excluded = RUNNER_TEST_CONFIG[:exclude_files]
    covered_files = test_files.reject { |f| excluded.any? { |ex| f.include?(ex) } }
    covered_files.length
  end
end

# Main test execution
def run_tests
  # Set up Minitest
  Minitest.run if Minitest.respond_to?(:run)

  # Customize Minitest options
  Minitest::Test.useforce_parallel = true if defined?(Minitest::Test.useforce_parallel)

  # Set up reporter
  results = TestResults.new
  reporter = CustomReporter.new(
    results,
    verbose: RUNNER_TEST_CONFIG[:verbose],
    output_format: RUNNER_TEST_CONFIG[:output_format],
    failures_only: RUNNER_TEST_CONFIG[:only_failures]
  )

  Minitest.reporter = reporter

  # Find and load test files
  test_dir = File.dirname(__FILE__)
  test_files = Dir.glob(File.join(test_dir, RUNNER_TEST_CONFIG[:pattern]))

  # Exclude specified files
  if RUNNER_TEST_CONFIG[:exclude_files].any?
    test_files.reject! { |file|
      RUNNER_TEST_CONFIG[:exclude_files].any? { |exclude| file.include?(exclude) }
    }
  end

  if test_files.empty?
    puts Colors.yellow("No test files found matching pattern: #{RUNNER_TEST_CONFIG[:pattern]}")
    exit 0
  end

  puts "Found #{test_files.length} test file(s):"
  test_files.each { |file| puts "  • #{File.basename(file)}" }
  puts ""

  # Load test files
  test_files.each do |file|
    begin
      load File.expand_path(file)
    rescue LoadError => e
      puts Colors.red("Failed to load test file #{file}: #{e.message}")
    end
  end

  # Run tests
  reporter.start

  # Override Minitest's run method to capture results
  Minitest.instance_variable_set(:@reporter, reporter)

  # This will trigger the test run with our custom reporter
  Minitest.__run(reporter, {})

  # Generate final report
  reporter.report

rescue Interrupt
  puts "\n#{Colors.yellow('Test execution interrupted by user.')}"
  exit 130
rescue StandardError => e
  puts "\n#{Colors.red("Unexpected error during test execution: #{e.message}")}"
  puts e.backtrace
  exit 1
end

# Run the test suite
if __FILE__ == $0
  run_tests
end
