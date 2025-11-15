# Hackerbot Unit Test Suite

This document provides comprehensive documentation for the Hackerbot unit test suite, which is designed to ensure the reliability and correctness of the Hackerbot IRC bot framework.

## Overview

The unit test suite covers all major components of the Hackerbot system:

- **Hackerbot Main Application** (`test_hackerbot.rb`) - Tests command-line argument parsing and initialization
- **OpenAI Client** (`test_openai_client.rb`) - Tests OpenAI API integration with streaming and non-streaming modes
- **VLLM Client** (`test_vllm_client.rb`) - Tests VLLM server integration with streaming capabilities
- **LLM Client Factory** (`test_llm_client_factory.rb`) - Tests client creation and provider selection
- **Bot Manager** (`test_bot_manager.rb`) - Tests bot configuration, chat history, and multi-bot management
- **Base LLM Client & Print Utilities** (`test_llm_client_base.rb`) - Tests base classes and utility functions

## Test Structure

### Test Helper (`test_helper.rb`)

The test helper provides common utilities and setup for all tests:

- **Test Configuration**: Default values for testing across different providers
- **HTTP Mocking**: Mock HTTP responses for API testing without actual network calls
- **Test Utilities**: Helper functions for creating temporary files and capturing output
- **Custom Assertions**: Extended test assertions for specific use cases
- **Base Test Classes**: `LLMClientTest` and `BotManagerTest` for common setup

### Test Runner (`run_tests.rb`)

A comprehensive test runner with the following features:

- **Multiple Output Formats**: Progress, documentation, or summary modes
- **Verbose Output**: Detailed test execution information
- **Failure Filtering**: Show only failed tests
- **Color-coded Output**: Visual feedback for test results
- **Comprehensive Reporting**: Detailed statistics and coverage information

## Running Tests

### Basic Test Execution

```bash
# Run all tests
ruby test/run_tests.rb

# Run with verbose output
ruby test/run_tests.rb --verbose

# Run with documentation format
ruby test/run_tests.rb --output documentation

# Show only failures
ruby test/run_tests.rb --failures-only
```

### Individual Test Files

```bash
# Test specific components
ruby test/test_hackerbot.rb
ruby test/test_openai_client.rb
ruby test/test_vllm_client.rb
ruby test/test_llm_client_factory.rb
ruby test/test_bot_manager.rb
ruby test/test_llm_client_base.rb
```

### Command Line Options

| Option | Short | Description |
|--------|--------|-------------|
| `--verbose` | `-v` | Run tests with verbose output |
| `--pattern PATTERN` | `-p` | Test file pattern (default: test_*.rb) |
| `--exclude FILES` | `-e` | Exclude specific files (comma-separated) |
| `--failures-only` | `-f` | Only show failed tests |
| `--output FORMAT` | `-o` | Output format: progress, documentation, or summary |
| `--help` | `-h` | Show help message |

## Test Coverage

### Components Tested

1. **Hackerbot Main Application**
   - Command-line argument parsing
   - Default configuration values
   - Help option functionality
   - Multiple configuration options
   - Error handling for invalid arguments

2. **OpenAI Client**
   - Client initialization with defaults and custom values
   - Non-streaming response generation
   - Streaming response generation
   - API error handling
   - Network error handling
   - Connection testing
   - Request body formatting
   - JSON parsing error handling

3. **VLLM Client**
   - Client initialization with defaults and custom values
   - Non-streaming response generation
   - Streaming response generation
   - API error handling
   - Network error handling
   - Connection testing
   - Request body formatting
   - System prompt integration

4. **LLM Client Factory**
   - Client creation for all supported providers (Ollama, OpenAI, VLLM, SGLang)
   - Parameter passing and validation
   - Case-insensitive provider names
   - Error handling for unsupported providers
   - Default parameter handling
   - Minimal configuration support

5. **Bot Manager**
   - Initialization with default and custom values
   - Chat history management (add, get, clear)
   - History length limits
   - Prompt assembly with various combinations
   - XML configuration parsing
   - Multiple bot configuration handling
   - LLM client creation for different providers
   - Bot creation and IRC integration

6. **Base LLM Client & Print Utilities**
   - Base class initialization and inheritance
   - Abstract method enforcement
   - System prompt management
   - Color methods for all supported colors
   - Logging methods for different output levels
   - Special character handling
   - Error handling for edge cases

### Mocking and Isolation

The test suite uses comprehensive mocking to isolate tests from external dependencies:

- **HTTP Mocking**: All API calls are mocked to avoid actual network requests
- **File System Mocking**: Configuration files use temporary files for isolation
- **Output Capture**: Print statements are captured to avoid test pollution
- **Time Mocking**: Time-based operations use controlled time values

## Test Categories

### Unit Tests
Individual component testing in isolation:
- Method behavior verification
- Edge case handling
- Error condition testing
- Default value validation

### Integration Tests
Component interaction testing:
- Configuration loading and bot creation
- Multi-bot coordination
- Chat history persistence
- Prompt assembly workflows

### Error Handling Tests
Robustness testing:
- Network failures
- API errors
- Invalid configurations
- Missing dependencies
- Malformed input data

### Performance Tests
Efficiency and scalability testing:
- Multiple bot instances
- Large chat histories
- Complex configuration parsing
- Memory usage patterns

## Test Data and Fixtures

### Sample Configuration
```xml
<hackerbot>
  <name>TestBot</name>
  <llm_provider>ollama</llm_provider>
  <ollama_model>gemma3:1b</ollama_model>
  <system_prompt>You are a test bot.</system_prompt>
  <get_shell>bash</get_shell>
  <messages>
    <greeting>Hello test user!</greeting>
    <!-- Other message templates -->
  </messages>
  <attacks>
    <attack>
      <prompt>This is attack 1.</prompt>
      <system_prompt>Attack 1 system prompt.</system_prompt>
    </attack>
  </attacks>
</hackerbot>
```

### Mock HTTP Responses
The test suite provides mock HTTP responses for testing:
- Success responses with structured data
- Error responses with various status codes
- Streaming responses with chunked data
- Network timeout and connection failures

## Best Practices

### Writing New Tests
1. **Use Base Test Classes**: Inherit from `LLMClientTest` or `BotManagerTest` when appropriate
2. **Mock External Dependencies**: Use `HTTPMock` and `TestUtils` for isolation
3. **Test Edge Cases**: Include empty strings, nil values, and special characters
4. **Follow Naming Conventions**: Use descriptive test method names
5. **Group Related Tests**: Organize tests by functionality

### Test Maintenance
- **Update Test Data**: Keep sample configurations current with actual code
- **Add New Tests**: Cover new features and bug fixes
- **Review Mock Data**: Ensure mock responses match actual API behavior
- **Monitor Test Coverage**: Aim for comprehensive coverage of all components

### Running Tests in CI/CD
```bash
# For continuous integration
ruby test/run_tests.rb --output summary --failures-only

# For detailed logs
ruby test/run_tests.rb --verbose --output documentation > test_results.log
```

## Troubleshooting

### Common Issues

1. **Missing Dependencies**
   ```
   Error: LoadError: cannot load such file
   ```
   Ensure all required gems are installed and Ruby files exist

2. **Test Failures Due to Environment Changes**
   ```
   Error: Expected "localhost" but got "custom.host"
   ```
   Check test configuration and default values

3. **Mocking Issues**
   ```
   Error: Mock not receiving expected calls
   ```
   Verify method signatures and mock expectations

### Debugging Tests

1. **Verbose Output**: Use `--verbose` flag for detailed execution
2. **Individual Tests**: Run specific test files to isolate issues
3. **Output Capture**: Use `TestUtils.capture_print_output` to debug print statements
4. **Breakpoints**: Add `binding.pry` or `byebug` for interactive debugging

## Contributing

### Adding New Tests
1. Create new test file in `test/` directory following naming convention
2. Include required dependencies and test helper
3. Write comprehensive tests for new functionality
4. Update test documentation as needed

### Test Standards
- Maintain high test coverage (>90%)
- Ensure tests are independent and isolated
- Use descriptive test names and clear documentation
- Follow the established test patterns and structure

## License

This test suite is part of the Hackerbot project and follows the same license terms as the main application.

## Support

For issues related to the test suite:
1. Check the troubleshooting section above
2. Review existing test cases for similar patterns
3. Consult the main Hackerbot documentation
4. Create an issue with test output and error details