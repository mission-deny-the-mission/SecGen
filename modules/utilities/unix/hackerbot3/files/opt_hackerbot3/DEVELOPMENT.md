# Development Guide

## Nix Development Environment Setup

This project uses Nix to provide a reproducible development environment with all necessary dependencies including Ruby, IRC server, and development tools.

### Prerequisites

- [Nix](https://nixos.org/download.html) with flakes enabled
- [direnv](https://direnv.net/) (recommended) for automatic environment activation

### Quick Start

1. **Enable Nix flakes** (if not already enabled):
   ```bash
   mkdir -p ~/.config/nix
   echo 'experimental-features = nix-command flakes' >> ~/.config/nix/nix.conf
   ```

2. **Install direnv** and hook it into your shell:
   ```bash
   # For bash
   echo 'eval "$(direnv hook bash)"' >> ~/.bashrc
   
   # For zsh
   echo 'eval "$(direnv hook zsh)"' >> ~/.zshrc
   
   # For fish
   echo 'eval (direnv hook fish)' >> ~/.config/fish/config.fish
   ```

3. **Enter the development environment**:
   ```bash
   cd opt_hackerbot
   direnv allow  # This will automatically load the Nix environment
   ```

   Or manually activate:
   ```bash
   nix develop
   ```

### Environment Features

The development environment includes:

- **Ruby 3.1** with required gems (ircinch, nokogiri, nori, json, httparty)
- **InspIRCd** - Professional IRC server software
- **WeeChat** - Terminal-based IRC client for testing
- **Development tools** - git, vim, tree, htop, curl, wget

### IRC Server Management

The environment provides convenient aliases for IRC server management:

```bash
# Start the IRC server
start-irc-server

# Stop the IRC server  
stop-irc-server

# Connect with IRC client
connect-irc
```

The IRC server runs on `localhost:6667` by default and creates a `#hackerbot` channel.

### Workflow

1. **Start the IRC server**:
   ```bash
   start-irc-server
   ```

2. **Connect with an IRC client** (in a new terminal):
   ```bash
   connect-irc
   # Once in WeeChat:
   # /server add localhost localhost/6667
   # /connect localhost  
   # /join #hackerbot
   ```

3. **Start the Hackerbot** (in another terminal):
   ```bash
   # Basic usage
   ruby hackerbot.rb --irc-server localhost
   
   # With Ollama (if installed)
   ruby hackerbot.rb --irc-server localhost --llm-provider ollama --ollama-model gemma3:1b
   
   # With RAG + CAG enabled
   ruby hackerbot.rb --irc-server localhost --enable-rag-cag
   ```

### Project Structure

```
opt_hackerbot/
├── hackerbot.rb           # Main entry point
├── bot_manager.rb         # Bot instance management
├── rag_cag_manager.rb     # Knowledge enhancement system
├── config/                # XML configuration files
├── knowledge_bases/       # Cybersecurity intelligence
├── rag/                   # Retrieval-Augmented Generation
├── cag/                   # Context-Aware Generation
├── providers/             # LLM provider implementations
├── test/                  # Test suites
├── docs/                  # Documentation
├── Gemfile               # Ruby dependencies
├── shell.nix             # Nix shell environment
├── flake.nix             # Nix flake configuration
├── ircd.conf             # IRC server configuration
└── .envrc                # direnv configuration
```

### Development Commands

```bash
# Run tests
ruby test_all.rb

# Check Ruby code style
rubocop

# Install new gems
bundle install

# Update dependencies
bundle update

# Build the project package
nix build

# Run specific demo
ruby demo_rag_cag.rb
```

### Configuration

The IRC server configuration is stored in `ircd.conf`. You can modify settings like:

- Server name and description
- Port number (default: 6667)
- Channel settings
- Operator accounts

Bot configurations are XML files in the `config/` directory. Examples include:

- `config/example_ollama.xml.example` - Ollama LLM configuration
- `config/example_rag_cag_bot.xml` - RAG + CAG enabled bot
- `config/fishing_exercise.xml` - Social engineering training scenario

### Troubleshooting

**IRC server won't start:**
- Check if port 6667 is already in use: `lsof -i :6667`
- Verify configuration: `inspircd --config ircd.conf --debug`
- Check logs in `/tmp/ircd.log`

**Ruby gems not found:**
- Ensure you're in the Nix environment: `nix develop`
- Reinstall gems: `bundle install --deployment`

**Bot won't connect to IRC:**
- Verify IRC server is running: `start-irc-server`
- Check connection settings: `--irc-server localhost --irc-port 6667`

**Permission errors:**
- Ensure `/tmp` is writable
- Check file permissions: `ls -la /tmp/ircd.pid`

### Advanced Usage

**Using different Ruby versions:**
Modify `shell.nix` or `flake.nix` to use `ruby_3_0`, `ruby_3_2`, etc.

**Custom IRC client:**
Instead of WeeChat, you can use any IRC client like:
- `irssi` - Terminal client
- `hexchat` - GUI client
- Web clients like The Lounge

**Production deployment:**
The flake includes a production package that can be installed:
```bash
nix profile install .#hackerbot
```

This installs the bot with wrapper scripts for easy system-wide use.

### Contributing

1. Make changes to the code
2. Run tests: `ruby test_all.rb`
3. Check style: `rubocop`
4. Update documentation if needed
5. Test the IRC server and bot integration
6. Commit changes with descriptive messages

The Nix environment ensures all contributors have the same dependencies and toolchain, eliminating "works on my machine" issues.