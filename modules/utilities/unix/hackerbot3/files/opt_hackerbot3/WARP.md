# WARP.md

This file provides guidance to WARP (warp.dev) when working with code in this repository.

## Project Overview

Hackerbot is a Ruby-based IRC bot framework for cybersecurity training. It combines traditional attack simulation with modern AI capabilities through multiple LLM providers (Ollama, OpenAI, VLLM, SGLang) and advanced knowledge retrieval systems (RAG + CAG).

## Core Architecture

### System Components

The framework follows a modular architecture with these key layers:

```
Core System
├── hackerbot.rb          # Main entry point with CLI parsing
├── bot_manager.rb        # Bot lifecycle and chat history management  
└── print.rb              # Centralized logging utilities

LLM Integration
├── providers/llm_client.rb           # Base class for all LLM providers
├── providers/llm_client_factory.rb   # Factory pattern for client creation
├── providers/ollama_client.rb        # Ollama local LLM integration
├── providers/openai_client.rb        # OpenAI API integration
├── providers/vllm_client.rb          # VLLM server integration
└── providers/sglang_client.rb        # SGLang server integration

Knowledge Enhancement
├── rag_manager.rb                    # RAG system coordinator
├── knowledge_bases/                  # Knowledge source implementations
│   ├── knowledge_source_manager.rb   # Multi-source coordination
│   ├── mitre_attack_knowledge.rb     # MITRE ATT&CK framework data
│   └── sources/                      # Individual knowledge sources
└── rag/                             # RAG-specific implementations
```

### Key Design Patterns

- **Factory Pattern**: `LLMClientFactory` creates appropriate LLM clients based on provider
- **Strategy Pattern**: Different LLM providers implement the same `LLMClient` interface
- **Manager Pattern**: `BotManager` orchestrates multiple bot instances with shared chat history
- **Modular Knowledge**: Knowledge sources are pluggable through `BaseKnowledgeSource`

## Development Commands

### Environment Setup
```bash
# Enter Nix development environment
nix develop
# or with direnv
direnv allow

# Initialize environment with dependencies
make setup
make dev-setup    # includes IRC server setup
```

### IRC Server Management
```bash
make start-irc    # Start IRC server on localhost:6667
make stop-irc     # Stop IRC server
make status       # Check IRC server status
```

### Bot Operations
```bash
# Basic bot startup
ruby hackerbot.rb --irc-server localhost

# With specific LLM provider
ruby hackerbot.rb --irc-server localhost --llm-provider ollama --ollama-model gemma3:1b

# With knowledge enhancement
ruby hackerbot.rb --irc-server localhost --enable-rag-cag

# Convenience targets
make bot          # Default configuration
make bot-ollama   # With Ollama
make bot-rag-cag  # With RAG + CAG enabled
```

### Testing
```bash
# Run comprehensive test suite
ruby test/run_tests.rb

# Test with different output formats
ruby test/run_tests.rb --verbose
ruby test/run_tests.rb --output documentation
ruby test/run_tests.rb --failures-only

# Run specific test files
ruby test/test_hackerbot.rb
ruby test/test_bot_manager.rb
ruby test/test_llm_client_factory.rb

# Quick verification
ruby test_all.rb
```

### Development Workflow
```bash
# Check Ruby syntax
make lint
ruby -c hackerbot.rb bot_manager.rb

# Clean temporary files
make clean

# Environment verification  
make env
make verify
```

## Configuration System

### Bot Configuration
Bots are configured via XML files in `config/` directory. Key configuration elements:

- **LLM Provider Settings**: Model, host, port, API keys
- **System Prompts**: Base personality and attack-specific prompts
- **RAG Configuration**: Knowledge base settings and source preferences
- **Attack Scenarios**: Progressive training exercises with conditions

### Environment Variables
The system uses these key environment variables:
- `GEM_HOME`/`GEM_PATH`: Ruby gem installation paths
- `RUBYOPT`: Ruby interpreter options
- IRC server settings via command line args

## Knowledge Enhancement System

### RAG (Retrieval-Augmented Generation)
- **Vector Database**: ChromaDB for document embeddings
- **Embedding Service**: Ollama nomic-embed-text model
- **Knowledge Sources**: MITRE ATT&CK, man pages, markdown files
- **Context Retrieval**: Similarity-based document retrieval

### Knowledge Source Architecture
Knowledge sources implement `BaseKnowledgeSource` and provide:
- `load_knowledge`: Initialize and process source data
- `get_rag_documents`: Return documents for vector storage
- `test_connection`: Validate source availability

## Testing Architecture

### Test Structure
- **test/run_tests.rb**: Main test runner with multiple output formats
- **test/test_helper.rb**: Common utilities, mocking, and base classes
- **Individual test files**: Component-specific unit and integration tests

### Mock Strategy
Tests use comprehensive mocking:
- **HTTP requests**: Mock all external API calls
- **File system**: Temporary files for configuration testing
- **Time-based operations**: Controlled time values

### Test Categories
- **Unit tests**: Individual component behavior
- **Integration tests**: Component interaction
- **Error handling**: Network failures, invalid configs
- **Performance**: Multiple bot instances, large histories

## Bot Management Patterns

### Chat History
- **Per-user, per-bot**: Isolated conversation contexts
- **Configurable length**: Default 10 messages with automatic pruning
- **Context assembly**: Combined system prompt + history + current message

### Multi-bot Coordination
- **Shared LLM clients**: Efficient resource utilization
- **Individual configurations**: Bot-specific prompts and settings
- **Dynamic personality switching**: Attack scenario-based system prompts

## Development Guidelines

### Adding LLM Providers
1. Implement `LLMClient` interface in `providers/`
2. Add factory case in `LLMClientFactory`
3. Update command line parsing in `hackerbot.rb`
4. Add comprehensive tests following existing patterns

### Extending Knowledge Sources
1. Inherit from `BaseKnowledgeSource`
2. Implement required methods: `load_knowledge`, `get_rag_documents`, `test_connection`
3. Register in `KnowledgeSourceManager.create_knowledge_source`
4. Add configuration support in bot XML schema

### Bot Configuration Patterns
- Use XML for structured configuration with validation
- Support both global defaults and bot-specific overrides
- Implement graceful fallbacks for missing configurations
- Maintain backward compatibility with existing configs

## Performance Considerations

### Memory Management
- RAG system: ~40% memory reduction in RAG-only mode
- Knowledge caching: Configurable TTL for enhanced contexts
- Chat history pruning: Automatic memory management

### Network Efficiency
- Streaming responses: Line-by-line output for better perceived performance
- Connection pooling: Reuse HTTP connections where possible
- Offline mode: Full functionality without external dependencies

## Security Architecture

### Data Privacy
- Local processing via Ollama eliminates external API dependencies
- User chat histories isolated by bot and user ID
- Configurable knowledge sources prevent data leakage

### API Security
- Secure key management for external providers
- Graceful degradation when services unavailable
- Rate limiting and connection timeout handling