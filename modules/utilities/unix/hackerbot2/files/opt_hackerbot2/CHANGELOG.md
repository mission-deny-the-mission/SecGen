# Changelog

## [2.0.0] - 2024-01-XX

### Added
- **Ollama LLM Integration**: Complete replacement of AIML with modern LLM capabilities
- **OllamaClient Class**: New HTTP client for communicating with Ollama API
- **Per-User Chat History**: Each user gets their own conversation context
- **Configurable Models**: Support for different Ollama models per bot
- **System Prompts**: Customizable system prompts for each bot
- **Chat History Management**: Commands to clear and view chat history
- **Context Awareness**: Bot includes current attack context in responses
- **Error Handling**: Robust error handling for network and API issues

### Changed
- **Message Processing**: Now uses Ollama's generate API instead of AIML pattern matching
- **Configuration**: Added Ollama-specific configuration options
- **Response Quality**: Significantly improved natural language understanding
- **Performance**: Faster response times with modern LLM models

### Removed
- **AIML Dependencies**: Removed `programr` gem dependency
- **ALICE Integration**: Removed ALICE AIML chatbot
- **AIML Files**: Removed all AIML configuration files
- **Legacy Code**: Cleaned up AIML-related code paths

### Technical Details
- **API Integration**: Uses Ollama's REST API for model inference
- **Timeout Handling**: Configurable timeouts for API calls
- **Fallback Behavior**: Graceful degradation when Ollama is unavailable
- **Memory Management**: Efficient chat history storage with size limits

### Configuration Changes
- **New XML fields**:
  - `<ollama_model>`: Specify the Ollama model to use
  - `<ollama_host>`: Ollama server hostname
  - `<ollama_port>`: Ollama server port

### Command Line Options
- `--ollama-host`: Set Ollama server host (default: localhost)
- `--ollama-port`: Set Ollama server port (default: 11434)
- `--ollama-model`: Set default Ollama model (default: llama2)

### Files Added
- `config/example_ollama.xml`: Example configuration with Ollama settings
- `README_OLLAMA.md`: Comprehensive documentation
- `test_ollama.rb`: Integration test script
- `setup_ollama.sh`: Automated setup script
- `CHANGELOG.md`: This changelog

### Files Modified
- `hackerbot.rb`: Complete rewrite of chatbot integration
  - Removed `require 'programr'`
  - Added `require 'net/http'` and `require 'json'`
  - Added `OllamaClient` class
  - Updated bot initialization logic
  - Modified message handling to use Ollama API
  - Added command line argument parsing for Ollama settings

### Backward Compatibility
- Existing bot configurations continue to work
- AIML files are no longer used but don't cause errors
- All existing IRC bot functionality preserved
- Attack system unchanged

### Requirements
- **New**: Ollama server running locally or remotely
- **New**: Compatible LLM model installed in Ollama
- **Removed**: `programr` gem dependency
- **Removed**: AIML file dependencies

### Migration Notes
1. Install Ollama: `curl -fsSL https://ollama.ai/install.sh | sh`
2. Pull a model: `ollama pull llama2`
3. Start Ollama: `ollama serve`
4. Optionally add Ollama configuration to existing XML files
5. Run with: `ruby hackerbot.rb`

### Performance Impact
- **Positive**: More natural and contextual responses
- **Positive**: Support for modern language models
- **Consideration**: First response may be slower due to model loading
- **Consideration**: Network latency for remote Ollama instances 