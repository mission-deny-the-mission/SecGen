# Hackerbot - AI-Powered Cybersecurity Training Framework

[![Ruby](https://img.shields.io/badge/Ruby-2.7%2B-red.svg)](https://www.ruby-lang.org/)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Documentation](https://img.shields.io/badge/Documentation-Yes-green.svg)](docs/)

Hackerbot is a Ruby-based IRC bot framework designed for cybersecurity training exercises. It combines traditional attack simulation with modern AI capabilities through multiple LLM providers (Ollama, OpenAI, VLLM, SGLang) and advanced knowledge retrieval systems (RAG with stage-aware context injection).

## 🎯 Overview

Hackerbot provides an interactive platform for cybersecurity education by:
- **Simulating Attack Scenarios**: Progressive training exercises with multiple stages
- **AI-Powered Conversations**: Natural language interactions with LLM-powered bots
- **Knowledge-Enhanced Responses**: Built-in cybersecurity intelligence and documentation
- **Flexible Deployment**: Support for both online and offline operation modes
- **Multi-Provider Support**: Integration with various LLM providers and knowledge sources

## 🚀 Quick Start

### Prerequisites

#### Option 1: Nix Development Environment (Recommended)
- **[Nix](https://nixos.org/download.html)** with flakes enabled
- **[direnv](https://direnv.net/)** (optional, for automatic environment activation)

The project uses a comprehensive Nix development environment that provides reproducible builds, automatic dependency management, and integrated IRC server functionality.

#### Option 2: Manual Installation
- **Ruby 3.1+** - Programming language runtime
- **Ollama** (recommended) - Local LLM provider
- **IRC Server** - For bot communication (can be local)

### Installation

#### Using Nix (Recommended)

1. **Enable Nix Flakes** (if not already enabled)
   ```bash
   mkdir -p ~/.config/nix
   echo 'experimental-features = nix-command flakes' >> ~/.config/nix/nix.conf
   ```

2. **Enter Development Environment**
   ```bash
   cd opt_hackerbot
   nix develop
   # OR use direnv for automatic activation
   direnv allow
   ```

3. **Start IRC Server**
   ```bash
   make start-irc
   # Server runs on localhost:6667
   ```

4. **Start Hackerbot**
   ```bash
   make bot                    # Basic bot
   make bot-ollama            # With Ollama LLM
   make bot-rag-cag          # With RAG enabled
   ```

#### Manual Installation

1. **Clone and Setup**
   ```bash
   git clone <repository-url>
   cd opt_hackerbot
   ```

2. **Install Ollama** (if using local LLM)
   ```bash
   # Install Ollama
   curl -fsSL https://ollama.ai/install.sh | sh
   
   # Start Ollama service
   ollama serve
   
   # Pull a model (recommended: gemma3:1b for speed)
   ollama pull gemma3:1b
   ```

3. **Install Ruby Dependencies**
   ```bash
   gem install ircinch nokogiri nori json httparty
   ```

### Basic Usage

```bash
# Start with default settings
ruby hackerbot.rb

# Start with custom Ollama settings
ruby hackerbot.rb --ollama-host localhost --ollama-port 11434 --ollama-model gemma3:1b

# Enable RAG knowledge enhancement
ruby hackerbot.rb --enable-rag-cag

# Force offline mode for air-gapped environments
ruby hackerbot.rb --offline

# Using Make commands (Nix environment)
make bot              # Start bot with defaults
make bot-ollama       # Start with Ollama
make bot-rag-cag      # Start with RAG enabled
make start-irc        # Start IRC server
make test             # Run test suite
```

## 📚 Documentation

### User Documentation
- **[User Guide](docs/user_guides/user-guide.md)** - Comprehensive user manual
- **[Configuration Guide](docs/user_guides/configuration-guide.md)** - XML configuration reference
- **[Deployment Guide](docs/user_guides/deployment-guide.md)** - Installation and setup instructions

### Developer Documentation
- **[Architecture Overview](docs/development/architecture.md)** - System design and components
- **[Development Guide](docs/development/development-guide.md)** - Contributing and extending
- **[API Reference](docs/development/api-reference.md)** - Technical API documentation
- **[Contributing Guide](docs/development/contributing.md)** - How to contribute

### Knowledge Base
- **[Incident Response Procedures](docs/incident_response_procedures.md)** - Security incident handling
- **[Network Security Best Practices](docs/network_security_best_practices.md)** - Network security guidelines
- **[Threat Intelligence](docs/threat_intelligence/apt_groups.md)** - APT group information

### Quick Reference
- **[Changelog](CHANGELOG.md)** - Version history and changes
- **[Project Guide for AI Agents](AGENTS.md)** - AI agent development guide with BMAD configuration
- **[Nix Quick Start](QUICKSTART.md)** - Comprehensive Nix environment guide
- **[Development Guide](DEVELOPMENT.md)** - Detailed development documentation

### Epic Documentation
- **[Epic 2I: Full IRC Context Integration](docs/stories/epic-2i-full-irc-context-integration.md)** - Complete conversation history capture
- **[Epic 3: Stage-Aware Context Injection](docs/stories/epic-3-stage-aware-context-injection.md)** - Per-attack explicit knowledge selection
- **[Epic 4: VM Context Fetching](docs/stories/epic-4-vm-context-fetching.md)** - SSH-based runtime state retrieval

## 🏗️ Architecture

### Core Components

```
Hackerbot Framework
├── Core System
│   ├── hackerbot.rb          # Main entry point and CLI
│   ├── bot_manager.rb        # Bot instance management with full IRC context
│   ├── vm_context_manager.rb # SSH-based VM context fetching (Epic 4)
│   └── print.rb              # Logging and output utilities
├── LLM Integration
│   ├── providers/
│   │   ├── llm_client.rb         # Base LLM interface
│   │   ├── llm_client_factory.rb # LLM client factory
│   │   ├── ollama_client.rb      # Ollama provider
│   │   ├── openai_client.rb      # OpenAI provider
│   │   ├── vllm_client.rb        # VLLM provider
│   │   └── sglang_client.rb      # SGLang provider
├── Knowledge Enhancement
│   ├── rag/rag_manager.rb    # RAG coordinator (RAG-only system)
│   ├── rag/                  # Retrieval-Augmented Generation
│   └── knowledge_bases/      # Knowledge sources (MITRE, man pages, markdown)
└── Development
    ├── flake.nix             # Nix flake configuration
    ├── Makefile              # Development commands
    ├── simple_irc_server.py  # Built-in IRC server
    └── config/               # XML bot configurations
```

### Key Features

#### 🤖 AI Integration
- **Multiple LLM Providers**: Ollama, OpenAI, VLLM, SGLang
- **Streaming Responses**: Real-time line-by-line output
- **Full IRC Context Integration** (Epic 2I): Complete conversation history with all channel messages
- **Per-User Chat History**: Contextual conversations with configurable history windows
- **Dynamic Personalities**: Per-attack system prompts for social engineering training

#### 🧠 Knowledge Enhancement
- **RAG System**: Document retrieval and semantic search with identifier-based lookups
- **Stage-Aware Context Injection** (Epic 3): Per-attack explicit knowledge selection
  - Select specific man pages by command name (e.g., "nmap", "netcat")
  - Select specific documents by file path
  - Select specific MITRE ATT&CK techniques by ID (e.g., "T1003", "T1059.001")
- **Built-in Knowledge**: MITRE ATT&CK framework, man pages, markdown files
- **VM Context Fetching** (Epic 4): SSH-based runtime state retrieval from student machines
  - Bash history retrieval
  - Command output capture (configurable commands)
  - File content reading
  - Runtime state awareness for contextual responses

#### 🔒 Security & Deployment
- **Offline Operation**: Air-gapped deployment capability (default operation mode)
- **RAG-Only System**: Simplified architecture (CAG removed for maintainability)
- **Resource Efficiency**: Configurable for various deployment environments
- **Secure by Default**: Minimal external dependencies

## ⚙️ Configuration

Bot configurations are defined in XML files in the `config/` directory. The configuration system supports progressive training exercises with stage-aware context injection and VM context fetching.

### Basic Configuration

```xml
<hackerbot>
  <name>CybersecurityBot</name>
  <llm_provider>ollama</llm_provider>
  <ollama_model>gemma3:1b</ollama_model>
  <system_prompt>You are a helpful cybersecurity training assistant.</system_prompt>
  <rag_enabled>true</rag_enabled>
  
  <!-- Full IRC Context (Epic 2I) -->
  <max_history_length>10</max_history_length>
  <max_irc_message_history>20</max_irc_message_history>
  <message_type_filter>
    <type>user_message</type>
    <type>bot_llm_response</type>
    <type>bot_command_response</type>
  </message_type_filter>
  
  <attacks>
    <attack>
      <prompt>Try to extract sensitive information from the target.</prompt>
      <system_prompt>You are a gullible customer service agent.</system_prompt>
      
      <!-- Stage-Aware Context (Epic 3) -->
      <context_config>
        <man_pages>nmap,netcat</man_pages>
        <documents>attack-guide.md</documents>
        <mitre_techniques>T1003,T1059.001</mitre_techniques>
      </context_config>
      
      <!-- VM Context Fetching (Epic 4) -->
      <vm_context>
        <bash_history path="~/.bash_history" limit="50"/>
        <commands>
          <command>ps aux</command>
          <command>netstat -tuln</command>
        </commands>
        <files>
          <file path="/etc/passwd"/>
          <file path="./config.txt"/>
        </files>
      </vm_context>
    </attack>
  </attacks>
</hackerbot>
```

### Configuration Features

- **LLM Provider Settings**: Configure Ollama, OpenAI, VLLM, or SGLang
- **Full IRC Context** (Epic 2I): Control message history windows and filtering
- **Stage-Aware Context** (Epic 3): Per-attack explicit knowledge selection
- **VM Context Fetching** (Epic 4): Per-attack VM state retrieval configuration
- **RAG Settings**: Enable/disable RAG and configure knowledge sources

See [Configuration Guide](docs/user_guides/configuration-guide.md) for detailed options and examples.

## 💡 Usage Examples

### Basic Bot Interaction
```bash
# Start the bot
ruby hackerbot.rb --irc-server localhost

# Connect via IRC client
/server localhost 6667
/join #hackerbot
```

### Advanced Configuration
```bash
# Bot with RAG + CAG and custom knowledge
ruby hackerbot.rb \
  --config config/cybersecurity_bot.xml \
  --enable-rag-cag \
  --offline

# Bot with specific LLM provider
ruby hackerbot.rb \
  --llm-provider openai \
  --openai-api-key your-api-key \
  --openai-model gpt-3.5-turbo

# Bot with OpenAI-compatible API (local llama.cpp, Together.ai, etc.)
ruby hackerbot.rb \
  --llm-provider openai \
  --openai-api-key your-api-key \
  --openai-model llama-2-7b-chat \
  --openai-base-url http://localhost:8080/v1

# Bot with Together.ai (OpenAI-compatible)
ruby hackerbot.rb \
  --llm-provider openai \
  --openai-api-key your-together-api-key \
  --openai-model meta-llama/Llama-2-13b-chat-hf \
  --openai-base-url https://api.together.xyz/v1
```

### Advanced Features

#### Full IRC Context Integration (Epic 2I)
- **Complete Conversation History**: All IRC channel messages captured
- **Multi-User Support**: Track conversations with multiple users
- **Message Type Filtering**: Control which message types appear in LLM context
- **Configurable History Windows**: Separate limits for traditional and IRC message history

#### Stage-Aware Context Injection (Epic 3)
- **Explicit Knowledge Selection**: Per-attack specification of exact knowledge items
- **Identifier-Based Lookups**: Direct retrieval by name/path/ID (bypasses similarity search)
- **Flexible Combination Modes**: Mix explicit items with query-based similarity search
- **Clear Source Attribution**: Context includes clear identification of knowledge sources

#### VM Context Fetching (Epic 4)
- **SSH-Based Runtime State Retrieval**: Fetch context from student machines
- **Bash History**: Retrieve command history from student VMs
- **Command Execution**: Execute configurable commands on student machines
- **File Reading**: Read specific files from student VMs via SSH
- **Runtime Awareness**: Bot responses adapt to actual student machine state

### Social Engineering Training
Configure bots with dynamic personalities for realistic scenarios:
- **Customer Service Agents**: Practice extracting sensitive information
- **IT Administrators**: Learn privilege escalation techniques
- **Security Personnel**: Test defensive awareness and procedures

## 🛠️ Development

### Nix Development Environment

This project uses a comprehensive Nix development environment that provides reproducible builds, automatic dependency management, and integrated IRC server functionality.

#### Environment Features
- **Ruby 3.1** with all required gems (ircinch, nokogiri, nori, json, httparty)
- **Python IRC Server** (custom implementation) - runs on localhost:6667
- **WeeChat** IRC client for testing
- **Development Tools** (git, vim, curl, etc.)
- **Local Gem Installation** - gems installed in `.gems/` directory (isolated from system)

#### Available Make Commands

```bash
# Environment Management
make dev          # Enter Nix environment
make setup        # Initial project setup
make verify       # Full environment verification
make env          # Check environment status

# IRC Server
make start-irc    # Start IRC server (port 6667)
make stop-irc     # Stop IRC server
make restart-irc  # Restart IRC server
make status       # Check server status

# Bot Operations
make bot          # Start bot with defaults
make bot-ollama   # Start with Ollama LLM
make bot-rag-cag  # Start with RAG enabled

# Development
make test         # Run test suite
make install-gems # Install Ruby gems
make clean        # Clean temporary files
make connect-irc  # Connect with WeeChat IRC client
```

#### Development Workflow

1. **Enter Environment**: `nix develop` or `direnv allow`
2. **Start IRC Server**: `make start-irc` (runs on localhost:6667)
3. **Connect IRC Client**: `make connect-irc` (new terminal) or any IRC client
4. **Start Bot**: `make bot` (new terminal) or specific variants
5. **Run Tests**: `make test` to run test suite

#### IRC Server Details
- **Implementation**: Custom Python IRC server (`simple_irc_server.py`)
- **Port**: 6667 (standard IRC port)
- **Channel**: #hackerbot (auto-created)
- **Protocol Support**: Full IRC protocol (NICK, USER, JOIN, PART, PRIVMSG, PING/PONG, WHOIS, LIST, NAMES)

### Running Tests
```bash
# Run comprehensive test suite
make test
# OR
ruby test_all.rb

# Run quick verification
ruby test/quick_test.rb

# Run specific test file
ruby test/test_llm_client_factory.rb
ruby test/test_vm_context_manager.rb
ruby test/test_full_conversation_context.rb
```

### BMAD Method Integration

This project uses **[BMAD-METHOD](https://github.com/bmad-method)** for structured AI agent coordination and workflow management. BMAD (Build, Measure, Analyze, Deploy) provides:

#### Agent System
- **Role-based AI Agents**: Pre-configured specialist agents for different tasks
  - Product Manager (pm) - PRDs, product strategy, roadmap planning
  - Product Owner (po) - Backlog management, story refinement
  - Full Stack Developer (dev) - Code implementation, debugging
  - Test Architect (qa) - Quality assurance, test architecture
  - Architect - System design, technology selection
  - Scrum Master (sm) - Story creation, epic management
  - And more...
- **Agent Activation**: Reference agents naturally (e.g., "As dev, implement...")
- **Task Execution**: Reusable task briefs for common workflows

#### How It Works

The BMAD configuration lives in `.bmad-core/`:
- **Agents**: Defined in `.bmad-core/agents/` (persona, commands, dependencies)
- **Tasks**: Reusable workflows in `.bmad-core/tasks/`
- **Templates**: Document templates in `.bmad-core/templates/`

#### Using BMAD with OpenCode

When using OpenCode, reference agents in your prompts:
- "As pm, create a PRD for the VM context feature"
- "As dev, implement the SSH command execution"
- "As qa, review the test coverage for Epic 4"

The `AGENTS.md` file is auto-generated by BMAD and contains the complete agent directory and task listings.

See [AGENTS.md](AGENTS.md) for the full agent directory and available tasks.



## 📊 Performance & Requirements

### System Requirements
- **Memory**: 2GB+ (4GB+ recommended for RAG with knowledge bases)
- **Storage**: 1GB+ (more for knowledge bases and embeddings)
- **Network**: Optional (offline mode supported, default operation mode)
- **CPU**: Modern multi-core processor recommended

### Performance Optimization
- **RAG-Only System**: Simplified architecture with focused knowledge retrieval
- **Offline Mode**: Eliminates network latency (default operation mode)
- **Streaming**: Real-time line-by-line output improves perceived responsiveness
- **Configurable History Windows**: Control memory usage with message history limits
- **Efficient Context Assembly**: Smart truncation and context length management

## 🔒 Security Considerations

### Data Privacy
- **Local Processing**: Ollama provides on-device AI processing
- **Offline Operation**: No external API calls required
- **Configurable Data Sources**: Control knowledge base content
- **Air-Gapped Support**: Full functionality without internet

### API Security
- **Key Management**: Secure storage for external API keys
- **Rate Limiting**: Configurable request limits
- **Fallback Behavior**: Graceful degradation when services unavailable
- **Access Control**: User-specific chat history isolation

## 🤝 Community & Support

### Getting Help
- **Documentation**: Start with the [User Guide](docs/user_guides/user-guide.md)
- **Issues**: Report bugs and request features
- **Discussions**: Join community conversations
- **Examples**: Review configuration files in `config/`



## 📈 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- **MITRE ATT&CK Framework**: For comprehensive cybersecurity knowledge
- **Ruby Community**: For excellent tools and libraries
- **AI/LLM Providers**: Ollama, OpenAI, VLLM, SGLang teams
- **Contributors**: All developers who have helped improve this project

---

**Built with ❤️ for cybersecurity education and training**

For the most up-to-date information, visit our [documentation](docs/) or [changelog](CHANGELOG.md).