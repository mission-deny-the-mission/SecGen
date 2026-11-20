# OpenAI-Compatible API Support Changes

This document summarizes the changes made to support OpenAI-compatible APIs (local llama.cpp, Together.ai, Chutes, etc.) in the Hackerbot framework.

## Overview

The OpenAI provider has been enhanced to support any OpenAI-compatible API endpoint, not just the official OpenAI API. This enables the use of local models running through llama.cpp server, Together.ai, Chutes, nanogpt, and other services that implement the OpenAI API format.

## Key Changes

### 1. Enhanced OpenAI Client (`providers/openai_client.rb`)

- Added `base_url` parameter to constructor (8th parameter)
- Modified URL construction to use provided `base_url` when available
- Handles trailing slashes automatically for consistency
- Falls back to constructing URL from host parameter when base_url is not provided
- Maintains full backward compatibility with existing configurations

### 2. Updated LLM Client Factory (`providers/llm_client_factory.rb`)

- Added `base_url` parameter support for OpenAI client creation
- Maintains existing parameter order for other providers

### 3. Enhanced Bot Manager (`bot_manager.rb`)

- Added `openai_base_url` parameter to constructor
- Added XML parsing support for `<openai_base_url>` configuration element
- Maintains backward compatibility with existing configurations

### 4. Updated Command-Line Interface (`hackerbot.rb`)

- Added `--openai-base-url` command-line option
- Added usage documentation for the new option
- Maintains compatibility with existing command-line usage

### 5. Enhanced OpenAI Embedding Client (`rag/openai_embedding_client.rb`)

- Added `base_url` configuration option
- Maintains consistency with main OpenAI client implementation
- Handles trailing slashes automatically

### 6. Comprehensive Testing (`test/test_openai_client.rb`)

- Added tests for custom base_url parameter
- Added tests for base_url with trailing slash handling
- Added tests for base_url precedence over host parameter

## Usage Examples

### Command Line Usage

```bash
# Local llama.cpp server
ruby hackerbot.rb \
  --llm-provider openai \
  --openai-api-key dummy_key \
  --openai-model llama-2-7b-chat \
  --openai-base-url http://localhost:8080/v1

# Together.ai service
ruby hackerbot.rb \
  --llm-provider openai \
  --openai-api-key your-together-key \
  --openai-model meta-llama/Llama-2-13b-chat-hf \
  --openai-base-url https://api.together.xyz/v1

# Chutes API
ruby hackerbot.rb \
  --llm-provider openai \
  --openai-api-key your-chutes-key \
  --openai-model llama-2-13b-chat \
  --openai-base-url https://api.chutes.ai/v1
```

### XML Configuration Usage

```xml
<hackerbot>
  <name>LocalLLaMABot</name>
  <llm_provider>openai</llm_provider>
  <openai_api_key>dummy_key</openai_api_key>
  <openai_base_url>http://localhost:8080/v1</openai_base_url>
  <ollama_model>llama-2-7b-chat</ollama_model>
  <!-- ... rest of configuration ... -->
</hackerbot>
```

### Programmatic Usage

```ruby
client = LLMClientFactory.create_client(
  'openai',
  api_key: 'your-api-key',
  base_url: 'http://localhost:8080/v1',
  model: 'llama-2-7b-chat',
  system_prompt: 'You are a helpful assistant.',
  streaming: false
)
```

## Supported Providers

The enhanced OpenAI client now supports any provider implementing the OpenAI API format:

- **Local llama.cpp**: `http://localhost:8080/v1`
- **Together.ai**: `https://api.together.xyz/v1`
- **Chutes**: `https://api.chutes.ai/v1`
- **Nanogpt**: `https://api.nanogpt.co/v1`
- **Custom/local OpenAI-compatible APIs**: Any endpoint URL
- **Official OpenAI API**: `https://api.openai.com/v1` (default)

## Backward Compatibility

All changes maintain full backward compatibility:

- Existing command-line usage continues to work unchanged
- Existing XML configurations continue to work unchanged
- Existing programmatic usage continues to work unchanged
- Default behavior remains unchanged (uses official OpenAI API)

## Configuration Priority

When determining the API endpoint, the following priority is used:

1. Explicit `base_url` parameter (highest priority)
2. `host` parameter with fallback to default host
3. Default OpenAI host: `api.openai.com` (lowest priority)

## Error Handling

- Invalid URLs are handled gracefully with appropriate error messages
- Connection failures provide helpful debugging information
- Missing API keys result in clear error messages
- Invalid base URLs are caught during initialization

## Testing

New comprehensive tests verify:

- Custom base_url parameter functionality
- Trailing slash handling
- Base URL precedence over host parameter
- Backward compatibility with existing configurations
- Error handling for invalid configurations

## Demo and Documentation

- Created demo script: `demo_openai_compatible.rb`
- Created example configuration: `config/example_openai_compatible.xml`
- Updated main README with usage examples
- Created detailed documentation: `docs/openai_compatible_apis.md`

This enhancement significantly expands the framework's flexibility while maintaining full backward compatibility with existing implementations.