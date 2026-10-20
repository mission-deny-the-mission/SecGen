# Hackerbot Streaming LLM Responses

This document describes the streaming functionality added to Hackerbot for improved LLM responsiveness.

## Overview

The streaming feature allows Hackerbot to receive and display LLM responses from Ollama line-by-line in real-time, rather than waiting for the complete response. This provides a more responsive and interactive experience for users.

## Features

- **Real-time streaming**: Responses appear as they are generated
- **Line-by-line output**: Each complete line is sent immediately
- **Fallback support**: Automatically falls back to non-streaming if streaming fails
- **Configurable**: Can be enabled/disabled per bot or globally
- **Backward compatible**: Existing configurations continue to work

## Configuration

### XML Configuration

Add a `<streaming>` element to your bot configuration:

```xml
<hackerbot>
  <name>MyBot</name>
  <ollama_model>gemma3:1b</ollama_model>
  <streaming>true</streaming>
  <!-- other configuration... -->
</hackerbot>
```

- `true`: Enable streaming (default)
- `false`: Disable streaming

### Command Line Arguments

Use the `--streaming` argument to set the global default:

```bash
# Enable streaming (default)
ruby hackerbot.rb --streaming true

# Disable streaming
ruby hackerbot.rb --streaming false
```

## How It Works

1. **Streaming Request**: When streaming is enabled, the bot sends a request to Ollama with `stream: true`
2. **Line Processing**: As Ollama generates text, the bot processes the response line by line
3. **Immediate Display**: Each complete line is immediately sent to the IRC channel
4. **History Management**: The complete response is still stored in chat history for context

## Technical Details

### OllamaClient Changes

- Added `generate_streaming_response()` method
- Modified `generate_response()` to support streaming via callback
- Added `@streaming` instance variable for configuration

### Message Handling

- Bot checks streaming configuration before processing messages
- Creates callback function to handle streaming responses
- Falls back to non-streaming if streaming fails

### Error Handling

- JSON parsing errors are caught and logged
- Connection failures trigger fallback to non-streaming
- Invalid streaming responses are handled gracefully

## Testing

Use the provided test script to verify streaming functionality:

```bash
ruby test_streaming.rb
```

This script will:
1. Test connection to Ollama
2. Demonstrate streaming vs non-streaming responses
3. Show line-by-line output

## Benefits

- **Improved Responsiveness**: Users see responses immediately
- **Better User Experience**: More interactive and engaging
- **Reduced Perceived Latency**: No waiting for complete responses
- **Maintains Context**: Chat history is preserved for continuity

## Limitations

- Requires Ollama to support streaming (most models do)
- May use slightly more bandwidth due to multiple IRC messages
- Some IRC clients may have rate limiting for rapid messages

## Troubleshooting

### Streaming Not Working

1. Check that Ollama is running and accessible
2. Verify the model supports streaming
3. Check network connectivity
4. Review logs for error messages

### Fallback to Non-Streaming

If streaming fails, the bot automatically falls back to the traditional non-streaming mode. This ensures compatibility and reliability.

### Performance Issues

- Reduce `max_tokens` if responses are too long
- Adjust `temperature` for more focused responses
- Consider network latency between bot and Ollama server 