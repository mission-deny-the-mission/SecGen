# Hackerbot Coding Standards

<!-- Powered by BMAD™ Core -->

## Version Information
- **Document Version**: v4.0
- **Creation Date**: 2025-10-17
- **Author**: Winston (Architect)
- **Status**: Complete

## Overview

This document defines the coding standards and best practices for the Hackerbot project. These standards ensure code quality, maintainability, and consistency across the codebase.

## Ruby Coding Standards

### General Guidelines

#### 1. Code Style
- Follow Ruby community standards (Ruby Style Guide)
- Use 2-space indentation (no tabs)
- Maximum line length: 100 characters
- Use soft tabs with 2 spaces

#### 2. Naming Conventions
```ruby
# Classes and Modules: PascalCase
class BotManager
  module LLMProviders
  end
end

# Methods and Variables: snake_case
def get_enhanced_context
  user_chat_history = {}
  rag_cag_manager = nil
end

# Constants: SCREAMING_SNAKE_CASE
DEFAULT_MAX_TOKENS = 2048
DEFAULT_TEMPERATURE = 0.7

# File names: snake_case
# bot_manager.rb
# llm_client_factory.rb
# rag_cag_manager.rb
```

#### 3. Method Definitions
```ruby
# Good: Clear method names with descriptive parameters
def get_enhanced_context(query, context_options = {})
  # Implementation
end

# Good: Single responsibility methods
def initialize_rag_cag_manager
  setup_rag_system
  setup_cag_system
  validate_configuration
end

# Avoid: Long methods with multiple responsibilities
def process_irc_message_and_generate_response_and_update_history(message)
  # Too many responsibilities - split into smaller methods
end
```

#### 4. Class and Module Structure
```ruby
# Class structure order:
# 1. Constants
# 2. Class methods
# 3. Public instance methods
# 4. Protected instance methods
# 5. Private instance methods

class BotManager
  # Constants
  DEFAULT_MAX_HISTORY_LENGTH = 10
  DEFAULT_TIMEOUT = 240
  
  # Class methods
  def self.create_from_config(config_file)
    # Implementation
  end
  
  # Public instance methods
  def initialize(config)
    # Implementation
  end
  
  def start_bots
    # Implementation
  end
  
  protected
  
  def validate_configuration
    # Implementation
  end
  
  private
  
  def setup_llm_providers
    # Implementation
  end
end
```

### Error Handling

#### 1. Exception Handling Patterns
```ruby
# Good: Specific exception handling
begin
  response = llm_client.generate_response(prompt)
rescue LLMConnectionError => e
  Print.err "Failed to connect to LLM provider: #{e.message}"
  return nil
rescue LLMTimeoutError => e
  Print.err "LLM request timed out: #{e.message}"
  return nil
end

# Good: Ensure cleanup
def with_timeout(seconds)
  Timeout.timeout(seconds) do
    yield
  end
rescue Timeout::Error
  cleanup_resources
  raise
end

# Avoid: Bare rescue clauses
begin
  risky_operation
rescue
  # Bad: Hides all errors
end
```

#### 2. Custom Exception Classes
```ruby
# Define specific exceptions for the application
module Hackerbot
  class Error < StandardError; end
  class ConfigurationError < Error; end
  class LLMProviderError < Error; end
  class KnowledgeBaseError < Error; end
  class IRCConnectionError < Error; end
end

# Usage
raise Hackerbot::ConfigurationError, "Invalid LLM provider specified" unless valid_provider?
```

### Documentation Standards

#### 1. Class and Module Documentation
```ruby
# BotManager - Central controller for all bot instances
#
# This class manages multiple bot personalities, coordinates LLM clients,
# and handles IRC event routing. It serves as the main orchestrator
# for the Hackerbot system.
#
# Example:
#   manager = BotManager.new(config)
#   manager.start_bots
#
# Author: Hackerbot Team
# Version: 1.0
class BotManager
  # Implementation
end
```

#### 2. Method Documentation
```ruby
# Get enhanced context for AI responses using RAG and CAG systems
#
# @param query [String] The user's query or message
# @param context_options [Hash] Options for context retrieval
# @option context_options [Integer] :max_rag_results Maximum RAG results (default: 5)
# @option context_options [Integer] :max_cag_depth Maximum CAG depth (default: 2)
# @option context_options [Boolean] :include_rag_context Include RAG context (default: true)
# @option context_options [Boolean] :include_cag_context Include CAG context (default: true)
#
# @return [String, nil] Enhanced context string or nil if unavailable
#
# @example
#   context = get_enhanced_context("What is SQL injection?", {
#     max_rag_results: 3,
#     include_cag_context: false
#   })
#
# @raise [KnowledgeBaseError] If knowledge systems are not initialized
def get_enhanced_context(query, context_options = {})
  # Implementation
end
```

#### 3. Inline Comments
```ruby
def process_irc_message(message)
  # Extract user information from IRC message
  user_id = message.user.nick
  user_host = message.user.host
  
  # Get current attack context for this bot
  current_attack = @bots[bot_name]['current_attack']
  
  # Generate enhanced context using RAG + CAG if enabled
  enhanced_context = get_enhanced_context(message.text) if @rag_cag_enabled
  
  # Assemble complete prompt with all context
  prompt = assemble_prompt(system_prompt, attack_context, chat_context, message.text, enhanced_context)
  
  # Generate AI response with streaming if enabled
  response = @llm_client.generate_response(prompt, stream_callback)
  
  response
end
```

## Testing Standards

### 1. Test Structure
```ruby
# test/test_bot_manager.rb
require 'test_helper'

class BotManagerTest < Minitest::Test
  def setup
    @config = load_test_config
    @manager = BotManager.new(@config)
  end
  
  def teardown
    @manager.cleanup if @manager
  end
  
  def test_bot_creation
    assert_instance_of BotManager, @manager
    assert @manager.initialized?
  end
  
  def test_llm_provider_factory
    ollama_client = @manager.create_llm_client('ollama', test_config)
    assert_instance_of OllamaClient, ollama_client
    assert ollama_client.test_connection
  end
  
  private
  
  def load_test_config
    # Test configuration loading
  end
end
```

### 2. Test Naming Conventions
```ruby
# Test method names should describe what they test
def test_bot_manager_initializes_with_valid_config
def test_rag_cag_manager_returns_enhanced_context_for_security_queries
def test_irc_message_routing_delivers_to_correct_bot
def test_error_handling_for_llm_provider_connection_failure
```

### 3. Mock and Stub Usage
```ruby
def test_llm_client_integration_with_mock_response
  # Mock LLM client for testing
  mock_client = Minitest::Mock.new
  mock_client.expect(:generate_response, "Test response", [String])
  
  @manager.llm_client = mock_client
  response = @manager.process_message("test message")
  
  assert_equal "Test response", response
  mock_client.verify
end
```

## Configuration Standards

### 1. XML Configuration Structure
```xml
<!-- Use consistent indentation and structure -->
<hackerbot>
  <name>training_bot</name>
  
  <!-- LLM Provider Configuration -->
  <llm_provider>ollama</llm_provider>
  <ollama_model>llama2:7b</ollama_model>
  <ollama_host>localhost</ollama_host>
  <ollama_port>11434</ollama_port>
  
  <!-- RAG + CAG Configuration -->
  <rag_cag_enabled>true</rag_cag_enabled>
  <rag_enabled>true</rag_enabled>
  <cag_enabled>true</cag_enabled>
  
  <!-- Attack Scenarios -->
  <attacks>
    <attack>
      <name>reconnaissance</name>
      <prompt>Perform reconnaissance on target system</prompt>
      <get_shell>nmap -sV {{chat_ip_address}}</get_shell>
      <condition>
        <output_matches>open</output_matches>
        <message>Found open ports!</message>
      </condition>
    </attack>
  </attacks>
</hackerbot>
```

### 2. Environment Variable Standards
```bash
# Use descriptive names with consistent prefixes
HACKERBOT_IRC_SERVER=localhost
HACKERBOT_IRC_PORT=6667
HACKERBOT_LLM_PROVIDER=ollama
HACKERBOT_OLLAMA_HOST=localhost
HACKERBOT_OLLAMA_PORT=11434
HACKERBOT_ENABLE_RAG_CAG=true
HACKERBOT_OFFLINE_MODE=auto
```

## Security Coding Standards

### 1. Input Validation
```ruby
# Validate all external inputs
def validate_irc_message(message)
  return false if message.nil? || message.empty?
  return false if message.length > MAX_MESSAGE_LENGTH
  return false if message.include?("\x00") # Null bytes
  
  # Check for malicious patterns
  dangerous_patterns = [/javascript:/i, /<script/i, /on\w+=/i]
  return false if dangerous_patterns.any? { |pattern| message.match?(pattern) }
  
  true
end

# Sanitize shell commands
def sanitize_shell_command(command)
  # Allow only safe characters
  safe_chars = /\A[a-zA-Z0-9\s\-_\.\/:]+\z/
  return nil unless command.match?(safe_chars)
  
  # Remove dangerous sequences
  command.gsub(/[;&|`$(){}[\]]/, '')
end
```

### 2. Secure Configuration Handling
```ruby
# Never hardcode sensitive values
class Configuration
  def self.load_from_file(config_file)
    config = YAML.load_file(config_file)
    
    # Replace placeholders with environment variables
    config['api_key'] = ENV['HACKERBOT_API_KEY'] if config['api_key'] == '${API_KEY}'
    
    config
  end
  
  def self.validate_config(config)
    required_fields = %w[llm_provider irc_server]
    missing = required_fields.select { |field| config[field].nil? || config[field].empty? }
    
    raise ConfigurationError, "Missing required fields: #{missing.join(', ')}" unless missing.empty?
  end
end
```

## Performance Standards

### 1. Memory Management
```ruby
# Clean up resources properly
def cleanup
  @llm_clients&.each_value(&:cleanup)
  @rag_cag_manager&.cleanup
  @user_chat_histories.clear
  @bots.clear
end

# Use weak references for large objects if needed
require 'weakref'

class KnowledgeCache
  def initialize
    @cache = {}
    @weak_refs = {}
  end
  
  def get(key)
    ref = @weak_refs[key]
    return nil unless ref&.weakref_alive?
    
    @cache[key]
  end
  
  def set(key, value)
    @cache[key] = value
    @weak_refs[key] = WeakRef.new(value)
  end
end
```

### 2. Efficient Data Structures
```ruby
# Use appropriate data structures for performance
class ChatHistory
  def initialize(max_length = 10)
    @max_length = max_length
    @histories = Hash.new { |h, k| h[k] = [] }
  end
  
  def add_message(bot_name, user_id, message)
    history = @histories[bot_name][user_id]
    history << message
    
    # Keep only recent messages
    history.shift if history.length > @max_length
  end
  
  def get_history(bot_name, user_id)
    @histories[bot_name][user_id] || []
  end
end
```

## Git and Version Control Standards

### 1. Commit Message Format
```
type(scope): brief description

[optional body]

[optional footer]

Types:
- feat: New feature
- fix: Bug fix
- docs: Documentation changes
- style: Code style changes (formatting, etc.)
- refactor: Code refactoring
- test: Test additions or changes
- chore: Maintenance tasks

Examples:
feat(llm): add support for new LLM provider
fix(rag): resolve memory leak in vector database
docs(api): update LLM client documentation
test(bot): add integration tests for bot manager
```

### 2. Branch Naming
```
feature/llm-provider-integration
bugfix/rag-memory-leak
docs/api-documentation-update
release/v1.2.0
hotfix/critical-security-fix
```

## Code Review Standards

### 1. Review Checklist
- [ ] Code follows style guidelines
- [ ] Methods have appropriate documentation
- [ ] Error handling is comprehensive
- [ ] Security considerations are addressed
- [ ] Performance implications are considered
- [ ] Tests are included and passing
- [ ] Configuration is properly handled
- [ ] No hardcoded secrets or credentials

### 2. Review Process
1. Self-review before submitting PR
2. Automated checks (style, tests, security)
3. Peer review focusing on logic and architecture
4. Integration testing if applicable
5. Documentation updates if needed

## Conclusion

These coding standards ensure the Hackerbot project maintains high code quality, security, and maintainability. All contributors should follow these guidelines to ensure consistency and reliability across the codebase.

Regular updates to these standards should be made as the project evolves and new best practices emerge.