# Hackerbot Nix Development Environment - Quick Start

This guide will get you up and running with the Hackerbot development environment using Nix.

## Prerequisites

- [Nix](https://nixos.org/download.html) with flakes enabled
- [direnv](https://direnv.net/) (recommended) for automatic environment activation

### Enable Nix Flakes

Add this to your Nix configuration (`~/.config/nix/nix.conf`):
```
experimental-features = nix-command flakes
```

### Install direnv

```bash
# For bash
echo 'eval "$(direnv hook bash)"' >> ~/.bashrc

# For zsh  
echo 'eval "$(direnv hook zsh)"' >> ~/.zshrc

# For fish
echo 'eval (direnv hook fish)' >> ~/.config/fish/config.fish
```

## Quick Start

### 1. Enter Development Environment

```bash
cd opt_hackerbot
direnv allow  # Automatically loads Nix environment
```

Or manually:
```bash
nix develop
```

You should see:
```
🤖 Hackerbot Development Environment
====================================
Ruby: ruby 3.1.7...
Nix: nix (Nix) 2.28.5

Available commands:
  start-irc-server    - Start InspIRCd server
  stop-irc-server     - Stop InspIRCd server
  connect-irc         - Connect with WeeChat
  ruby hackerbot.rb   - Start the bot
  bundle exec ruby    - Run with Bundler
```

### 2. Start IRC Server

```bash
start-irc-server
# or
nix run .#start-irc-server
```

You should see:
```
IRC server started on localhost:6667
```

### 3. Connect to IRC (Terminal 2)

```bash
connect-irc
# or manually:
weechat
```

Once in WeeChat:
```
/server add localhost localhost/6667
/connect localhost
/join #hackerbot
```

### 4. Start Hackerbot (Terminal 3)

```bash
# Basic bot
ruby hackerbot.rb --irc-server localhost --irc-port 6667

# With Ollama (if installed)
ruby hackerbot.rb --irc-server localhost --irc-port 6667 --llm-provider ollama --ollama-model gemma3:1b

# With RAG + CAG enabled
ruby hackerbot.rb --irc-server localhost --irc-port 6667 --enable-rag-cag
```

## Using Make Commands

The project includes a Makefile for convenient commands:

```bash
# Environment setup
make dev           # Enter Nix environment
make setup         # Initial setup
make env           # Check environment

# IRC server
make start-irc     # Start IRC server
make stop-irc      # Stop IRC server
make restart-irc   # Restart IRC server

# Bot commands
make bot           # Start bot with defaults
make bot-ollama    # Start with Ollama
make bot-rag-cag   # Start with RAG + CAG

# Development
make test          # Run tests
make lint          # Ruby linting
make clean         # Clean temporary files

# Quick start (everything)
make dev-setup     # Full development setup
make quick-start   # Quick start setup
```

## Configuration

### IRC Server
- **Config file**: `simple_irc_server.py` (Python implementation)
- **Port**: 6667 (localhost only)
- **Channel**: #hackerbot (auto-created)
- **Admin**: No admin required (simple implementation)

### Bot Configuration
Example configurations in `config/`:
- `config/example_ollama.xml.example` - Ollama setup
- `config/example_rag_cag_bot.xml` - RAG + CAG enabled
- `config/fishing_exercise.xml` - Social engineering scenario

## Common Workflows

### Development Workflow
```bash
# 1. Start environment
make dev

# 2. Start IRC server
make start-irc

# 3. Connect with IRC client (new terminal)
make connect-irc

# 4. Start bot (new terminal)
make bot-rag-cag

# 5. Run tests
make test

# 6. Stop everything
make stop-irc
```

### Testing Bot Changes
```bash
# Start IRC server
make start-irc

# Test with specific config
ruby hackerbot.rb --irc-server localhost --config config/test.xml

# Stop when done
make stop-irc
```

### Using Ollama (Optional)

If you want to use Ollama for local LLM:

```bash
# Install Ollama (outside Nix env)
curl -fsSL https://ollama.ai/install.sh | sh

# Pull a model
ollama pull gemma3:1b

# Start Ollama service
ollama serve

# Use with Hackerbot
ruby hackerbot.rb --irc-server localhost --llm-provider ollama --ollama-model gemma3:1b
```

## Troubleshooting

### IRC Server Issues
```bash
# Check if running
lsof -i :6667

# Check process
ps aux | grep simple_irc_server

# Force stop
make stop-irc
```

### Ruby Gem Issues
```bash
# Reinstall gems
make clean
make setup

# Check gems
gem list | grep -E '(ircinch|nokogiri|nori)'
```

### Environment Issues
```bash
# Reload environment
direnv allow

# Check Nix environment
nix flake check

# Enter clean environment
nix develop --clean
```

### Permission Errors
```bash
# Clean up temporary files
make clean

# Check /tmp permissions
ls -la /tmp/ircd.pid
```

## Next Steps

1. **Read the documentation**: `docs/user_guides/`
2. **Try demo scripts**: `ruby demo_rag_cag.rb`
3. **Explore configurations**: `config/` directory
4. **Run tests**: `make test`
5. **Customize bot**: Edit XML configs in `config/`

## Getting Help

- **Documentation**: `DEVELOPMENT.md`
- **Examples**: `config/` directory
- **Issues**: Check project README
- **Tests**: `test/` directory

## Architecture Overview

```
Hackerbot Framework
├── Core System
│   ├── hackerbot.rb          # Main entry point
│   ├── bot_manager.rb        # Bot management
│   └── rag_cag_manager.rb    # Knowledge enhancement
├── LLM Integration
│   ├── providers/            # LLM providers
│   └── Various Ruby gems
├── Knowledge Systems
│   ├── rag/                  # Retrieval-Augmented Generation
│   ├── cag/                  # Context-Aware Generation
│   └── knowledge_bases/      # Cybersecurity intelligence
└── Development
    ├── flake.nix            # Nix environment
    ├── Gemfile              # Ruby dependencies
    └── Makefile             # Convenience commands
```

Enjoy your Hackerbot development environment! 🤖