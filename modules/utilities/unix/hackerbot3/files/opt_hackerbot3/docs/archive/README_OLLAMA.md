# Hackerbot with Ollama Integration

This version of Hackerbot has been updated to use Ollama LLM for natural language responses.

## Key Changes

1. **Replaced ALICE with Ollama**: Removed dependency on `programr` gem and ALICE AIML files
2. **Added OllamaClient class**: Handles communication with Ollama API
3. **Updated message handling**: Now uses Ollama's generate API instead of AIML pattern matching
4. **Per-user chat history**: Each user gets their own conversation context
5. **Configurable models**: Each bot can use different Ollama models
6. **System prompts**: Customizable system prompts per bot
7. **Per-attack system prompts**: Change bot personality and behavior at each exercise stage
8. **Streaming responses**: Real-time line-by-line output for improved responsiveness

## Requirements

- Ruby (tested with 2.7+)
- Ollama installed and running locally (or accessible via network)
- Required gems: `ircinch`, `nokogiri`, `nori`, `net/http`, `json`, `getoptlong`, `thwait`

## Installation

1. Install Ollama from https://ollama.ai/
2. Pull a model: `ollama pull llama2` (or any other model)
3. Start Ollama: `ollama serve`
4. Install Ruby dependencies: `gem install ircinch nokogiri nori`

## Usage

### Basic Usage
```bash
ruby hackerbot.rb
```

### With Custom Ollama Settings
```bash
ruby hackerbot.rb --ollama-host localhost --ollama-port 11434 --ollama-model llama2
```

### Command Line Options
- `--irc-server host`: IRC server address (default: localhost)
- `--ollama-host host`: Ollama server host (default: localhost)
- `--ollama-port port`: Ollama server port (default: 11434)
- `--ollama-model model`: Default Ollama model (default: llama2)
- `--streaming true|false`: Enable/disable streaming responses (default: true)

## Configuration

Bot configurations are defined in XML files in the `config/` directory. Each bot can have its own Ollama settings:

```xml
<hackerbot>
  <name>MyBot</name>
  
  <!-- Ollama configuration (optional - uses command line defaults if not specified) -->
  <ollama_model>llama2</ollama_model>
  <ollama_host>localhost</ollama_host>
  <ollama_port>11434</ollama_port>
  <system_prompt>You are a helpful cybersecurity training assistant.</system_prompt>
  <streaming>true</streaming>
  
  <get_shell>false</get_shell>
  
  <messages>
    <greeting>Hello! I'm an AI assistant powered by Ollama.</greeting>
    <!-- ... other messages ... -->
  </messages>
  
  <attacks>
    <!-- Each attack can have its own system prompt -->
    <attack>
      <prompt>This is a normal attack.</prompt>
      <!-- Uses global system prompt -->
    </attack>
    
    <attack>
      <prompt>This attack has a custom personality.</prompt>
      <system_prompt>You are now a gullible customer service agent who is easily manipulated.</system_prompt>
      <!-- Uses attack-specific system prompt -->
    </attack>
  </attacks>
</hackerbot>
```

## Features

### Per-User Chat History
Each user gets their own conversation context that persists across messages. The bot remembers previous conversations and can reference them in responses.

### Chat History Management
- `clear_history`: Clears your personal chat history
- `show_history`: Shows your current chat history

### Context Awareness
The bot automatically includes current attack context in its responses, making it aware of what the user is working on.

### Per-Attack System Prompts
Each attack stage can have its own system prompt, allowing the bot to change personality and behavior dynamically. This enables:
- **Social engineering exercises**: Bot can role-play as gullible targets
- **AI/LLM security training**: Bot can simulate vulnerable AI assistants
- **Progressive difficulty**: Start with easy targets, progress to harder ones
- **Multi-persona scenarios**: Switch between different roles in a single exercise

### Streaming Responses
The bot can stream responses line-by-line in real-time, providing immediate feedback to users. This can be enabled/disabled per bot or globally via command line arguments.

### Error Handling
- Graceful fallback if Ollama is unavailable
- Connection timeout handling
- Automatic retry logic

## Troubleshooting

### Ollama Connection Issues
1. Ensure Ollama is running: `ollama serve`
2. Check if the model is available: `ollama list`
3. Test connection: `curl http://localhost:11434/api/tags`

### Model Issues
1. Pull the required model: `ollama pull model_name`
2. Check model compatibility
3. Adjust system prompts for better responses

### Performance
- Adjust `max_tokens` in the OllamaClient for shorter/faster responses
- Modify `temperature` for more/less creative responses
- Use smaller models for faster response times

## Migration from AIML

Existing bot configurations will continue to work. You can optionally add Ollama-specific configuration:

```xml
<!-- Add these fields to your existing bot configs -->
<ollama_model>llama2</ollama_model>
<ollama_host>localhost</ollama_host>
<ollama_port>11434</ollama_port>
<system_prompt>Custom system prompt for this bot</system_prompt>
<streaming>true</streaming>
```

## Development

### Adding New Features
- Extend the `OllamaClient` class for additional functionality
- Add new message handlers in the bot configuration
- Implement custom response processing

### Testing
- Use the example configuration in `config/example_ollama.xml`
- Use the fishing exercise example in `config/fishing_exercise.xml.example`
- Test with different Ollama models
- Verify chat history functionality
- Test per-attack system prompt changes

### Per-Attack System Prompts
For detailed information about using per-attack system prompts for social engineering and AI security exercises, see `README_PER_ATTACK_PROMPTS.md`.

## License

This project maintains the same license as the original Hackerbot. 