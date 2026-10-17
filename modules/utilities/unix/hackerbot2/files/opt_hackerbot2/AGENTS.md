# Hackerbot Project Guide for AI Agents

## Project Overview

Hackerbot is a Ruby-based IRC bot framework for cybersecurity training exercises. It combines traditional attack simulation with modern AI capabilities through multiple LLM providers (Ollama, OpenAI, VLLM, SGLang) and advanced knowledge retrieval systems (RAG with stage-aware context injection).

**Development Environment**: This project uses a comprehensive Nix development environment that provides reproducible builds, automatic dependency management, and integrated IRC server functionality.

## Core Architecture

### Main Components
- `hackerbot.rb` - Entry point and CLI handler
- `bot_manager.rb` - Central bot instance controller with comprehensive IRC message capture and context management
- `llm_client.rb` - Base LLM interface with provider-specific implementations
- `rag/rag_manager.rb` - RAG (Retrieval-Augmented Generation) coordinator with identifier-based lookups
- `vm_context_manager.rb` - SSH-based VM context fetching from student machines (Epic 4)

### Key Subsystems
1. **LLM Integration**: Multiple provider support with streaming and chat history
2. **RAG System**: Document retrieval and semantic search capabilities with identifier-based lookups
3. **Full IRC Context Integration** (Epic 2I): Comprehensive message capture and full conversation history
4. **Stage-Aware Context Injection** (Epic 3): Per-attack explicit knowledge selection by identifier
5. **VM Context Fetching** (Epic 4): SSH-based runtime state retrieval from student machines (bash history, command outputs, files)
6. **Knowledge Bases**: MITRE ATT&CK, man pages, markdown files (with identifier-based lookups)
7. **Offline Support**: Persistent storage and air-gapped operation

## Development Guidelines

### Project Structure
```
opt_hackerbot/
├── rag/                # Retrieval-Augmented Generation (RAG-only system)
├── knowledge_bases/    # Knowledge sources and processing
├── config/             # XML configuration files
├── docs/               # Documentation
└── test/               # Test suites
```

### Key Files to Know
- `config/example_*.xml` - Configuration examples and templates
- `setup_offline_rag_cag.rb` - Offline mode setup script
- `demo_*.rb` - Interactive demonstration scripts
- `knowledge_bases/mitre_attack_knowledge.rb` - Core threat intelligence
- `flake.nix` - Nix flake configuration for reproducible development environment
- `Makefile` - Development commands and shortcuts
- `simple_irc_server.py` - Custom Python IRC server implementation
- `Gemfile` - Ruby dependencies specification

### Configuration System
Bots are configured through XML files in `config/` with these key elements:
- `<llm_provider>` - Ollama, OpenAI, VLLM, or SGLang
- `<rag_enabled>` - Enable/disable RAG knowledge retrieval
- `<attacks>` - Progressive training scenarios
- `<context_config>` (Epic 3) - Per-attack explicit knowledge selection (man pages, documents, MITRE techniques)
- `<vm_context>` (Epic 4) - Per-attack VM context fetching (bash history, commands, files)
- `<vm_context_enabled>` (Epic 4) - Enable/disable VM context at bot-level or attack-level
- `<message_type_filter>` (Epic 2I) - Control which message types appear in LLM context
- `<max_history_length>` (Epic 2I) - Configure chat history window size
- `<knowledge_sources>` - Custom knowledge base configuration

### Development Tips
1. **LLM Clients**: Implement new providers by extending `llm_client.rb`
2. **Knowledge Sources**: Add new sources by extending `base_knowledge_source.rb`
3. **Configuration**: Use XML files for bot definitions and settings
4. **Testing**: Run tests with `ruby test/test_*.rb`
5. **Offline Mode**: Default operation mode, use `setup_offline_rag_cag.rb` for initial setup
6. **Nix Environment**: Always work within the Nix development environment for consistent dependencies
7. **IRC Server**: Use the built-in Python IRC server on port 6667 for testing

### Best Practices
- Keep LLM client implementations modular and provider-agnostic
- Use the factory pattern for creating LLM instances (`llm_client_factory.rb`)
- Implement proper error handling for external service connections
- Follow the existing naming conventions (snake_case for files and methods)
- Cache expensive operations (embedding generation, knowledge base queries)
- DO NOT commit or push using git WIHTOUT being asked to

### Important Notes
- System defaults to offline operation for security and reliability
- **RAG-only system** (CAG system removed in Epic 1 for maintainability)
- **Full IRC Context** (Epic 2I): All channel messages are captured and included in LLM context
- **Stage-Aware Context** (Epic 3): Attacks can specify explicit knowledge items (man pages by name, documents by path, MITRE techniques by ID)
- **VM Context Fetching** (Epic 4): SSH-based runtime state retrieval from student machines - bash history, command outputs, and file contents included in LLM context
- MITRE ATT&CK framework is included by default in all knowledge bases
- Support for identifier-based lookups: man pages by command name, documents by file path, MITRE techniques by ID
- VM context operations reuse existing SSH infrastructure from `get_shell` configuration

This framework provides flexible, offline-capable cybersecurity training with AI-powered conversations and comprehensive knowledge retrieval.

## Nix Development Environment

### Environment Setup
The project uses Nix flakes for reproducible development environments. The environment includes:
- **Ruby 3.1** with all required gems
- **Python IRC server** (custom implementation)
- **WeeChat** IRC client for testing
- **Development tools** (git, vim, curl, etc.)

### Quick Start
```bash
# Enter development environment
cd opt_hackerbot
nix develop

# Or use direnv for automatic activation
direnv allow

# Start IRC server
make start-irc

# Start Hackerbot
make bot
```

### Available Commands
```bash
# Environment management
make dev          # Enter Nix environment
make setup        # Initial project setup
make verify       # Full environment verification

# IRC server
make start-irc    # Start IRC server (port 6667)
make stop-irc     # Stop IRC server
make restart-irc  # Restart IRC server
make status       # Check server status

# Bot operations
make bot          # Start bot with defaults
make bot-ollama   # Start with Ollama LLM
make bot-rag-cag  # Start with RAG + CAG enabled

# Development
make test         # Run test suite
make install-gems # Install Ruby gems
make clean        # Clean temporary files
```

### Project Structure (Updated)
```
opt_hackerbot/
├── rag/                    # Retrieval-Augmented Generation
├── cag/                    # Context-Aware Generation
├── knowledge_bases/        # Knowledge sources and processing
├── config/                 # XML configuration files
├── docs/                   # Documentation
├── test/                   # Test suites
├── flake.nix              # Nix flake configuration
├── Makefile               # Development commands
├── Gemfile               # Ruby dependencies
├── simple_irc_server.py   # Custom IRC server
├── .gems/                 # Local gem installation directory
└── QUICKSTART.md          # User guide
```

### Development Workflow
1. **Environment Setup**: `nix develop` or `direnv allow`
2. **IRC Server**: `make start-irc` (runs on localhost:6667)
3. **IRC Client**: `make connect-irc` or use any IRC client
4. **Bot Development**: Edit code and test with `make bot`
5. **Testing**: `make test` to run test suite
6. **Gem Management**: Gems installed in local `.gems/` directory

### IRC Server Details
- **Implementation**: Custom Python IRC server (`simple_irc_server.py`)
- **Port**: 6667 (standard IRC port)
- **Channel**: #hackerbot (auto-created)
- **Protocol Support**: Full IRC protocol implementation
- **Features**: NICK, USER, JOIN, PART, PRIVMSG, PING/PONG, WHOIS, LIST, NAMES
- **Configuration**: Environment variables `IRC_HOST` and `IRC_PORT`

### Ruby Gem Management
- **Location**: Local `.gems/` directory (isolated from system gems)
- **Installation**: Automatic via Nix environment or `make install-gems`
- **Key Gems**: ircinch, nokogiri, nori, json, httparty
- **No Bundler Conflicts**: Uses manual gem installation to avoid version issues

### Environment Variables
```bash
RUBYOPT="-KU -E utf-8:utf-8"    # Ruby UTF-8 encoding
IRCD_PORT="6667"                 # IRC server port
IRCD_HOST="localhost"             # IRC server host
GEM_HOME="./.gems"               # Local gem directory
GEM_PATH="./.gems"               # Gem path
IRC_HOST="127.0.0.1"             # IRC server bind address
IRC_PORT="6667"                  # IRC server port
```

### Troubleshooting Common Issues

**IRC Server Problems:**
```bash
# Check if server is running
make status

# Check process
ps aux | grep simple_irc_server

# Restart server
make restart-irc

# Check port usage
sudo lsof -i :6667
```

**Gem Installation Issues:**
```bash
# Clean and reinstall
make clean
make install-gems

# Check environment
make env

# Verify Nix environment
nix flake check
```

**Environment Issues:**
```bash
# Reload environment
direnv allow

# Check Nix
nix --version

# Enter clean environment
nix develop --clean
```

### Key Files for AI Agents

**Configuration Files:**
- `flake.nix` - Complete Nix environment definition
- `Makefile` - All development commands and workflows
- `simple_irc_server.py` - IRC server implementation

**Development Files:**
- `Gemfile` - Ruby dependencies specification
- `.gems/` - Local gem installation directory
- `ircd.conf` - IRC server configuration (auto-generated)

**Documentation:**
- `QUICKSTART.md` - Comprehensive user guide
- `DEVELOPMENT.md` - Detailed development documentation
- `README.md` - Project overview and setup

### Integration Testing
The environment provides integrated testing capabilities:
1. Start IRC server with `make start-irc`
2. Connect with IRC client using `make connect-irc`
3. Start bot with `make bot` or specific variants
4. Test interactions in real-time
5. Use `make test` for automated test suite

### Performance Considerations
- **Local Gems**: Faster loading, no network dependencies
- **Python IRC Server**: Lightweight, minimal resource usage
- **Nix Caching**: Subsequent environment loads are faster
- **Isolated Environment**: No conflicts with system packages

This Nix development environment provides a complete, reproducible setup for Hackerbot development with integrated IRC server capabilities and comprehensive tooling for AI agent development and testing.

<!-- BEGIN: BMAD-AGENTS-OPENCODE -->
# BMAD-METHOD Agents and Tasks (OpenCode)

OpenCode reads AGENTS.md during initialization and uses it as part of its system prompt for the session. This section is auto-generated by BMAD-METHOD for OpenCode.

## How To Use With OpenCode

- Run `opencode` in this project. OpenCode will read `AGENTS.md` and your OpenCode config (opencode.json[c]).
- Reference a role naturally, e.g., "As dev, implement ..." or use commands defined in your BMAD tasks.
- Commit `.bmad-core` and `AGENTS.md` if you want teammates to share the same configuration.
- Refresh this section after BMAD updates: `npx bmad-method install -f -i opencode`.

### Helpful Commands

- List agents: `npx bmad-method list:agents`
- Reinstall BMAD core and regenerate this section: `npx bmad-method install -f -i opencode`
- Validate configuration: `npx bmad-method validate`

Note
- Orchestrators run as mode: primary; other agents as all.
- All agents have tools enabled: write, edit, bash.

## Agents

### Directory

| Title | ID | When To Use |
|---|---|---|
| UX Expert | ux-expert | Use for UI/UX design, wireframes, prototypes, front-end specifications, and user experience optimization |
| Scrum Master | sm | Use for story creation, epic management, retrospectives in party-mode, and agile process guidance |
| Test Architect & Quality Advisor | qa | Use for comprehensive test architecture review, quality gate decisions, and code improvement. Provides thorough analysis including requirements traceability, risk assessment, and test strategy. Advisory only - teams choose their quality bar. |
| Product Owner | po | Use for backlog management, story refinement, acceptance criteria, sprint planning, and prioritization decisions |
| Product Manager | pm | Use for creating PRDs, product strategy, feature prioritization, roadmap planning, and stakeholder communication |
| Full Stack Developer | dev | Use for code implementation, debugging, refactoring, and development best practices |
| BMad Master Orchestrator | bmad-orchestrator | Use for workflow coordination, multi-agent tasks, role switching guidance, and when unsure which specialist to consult |
| BMad Master Task Executor | bmad-master | Use when you need comprehensive expertise across all domains, running 1 off tasks that do not require a persona, or just wanting to use the same agent for many things. |
| Architect | architect | Use for system design, architecture documents, technology selection, API design, and infrastructure planning |
| Business Analyst | analyst | Use for market research, brainstorming, competitive analysis, creating project briefs, initial project discovery, and documenting existing projects (brownfield) |

### UX Expert (id: ux-expert)
Source: [.bmad-core/agents/ux-expert.md](.bmad-core/agents/ux-expert.md)

- When to use: Use for UI/UX design, wireframes, prototypes, front-end specifications, and user experience optimization
- How to activate: Mention "As ux-expert, ..." to get role-aligned behavior
- Full definition: open the source file above (content not embedded)

### Scrum Master (id: sm)
Source: [.bmad-core/agents/sm.md](.bmad-core/agents/sm.md)

- When to use: Use for story creation, epic management, retrospectives in party-mode, and agile process guidance
- How to activate: Mention "As sm, ..." to get role-aligned behavior
- Full definition: open the source file above (content not embedded)

### Test Architect & Quality Advisor (id: qa)
Source: [.bmad-core/agents/qa.md](.bmad-core/agents/qa.md)

- When to use: Use for comprehensive test architecture review, quality gate decisions, and code improvement. Provides thorough analysis including requirements traceability, risk assessment, and test strategy. Advisory only - teams choose their quality bar.
- How to activate: Mention "As qa, ..." to get role-aligned behavior
- Full definition: open the source file above (content not embedded)

### Product Owner (id: po)
Source: [.bmad-core/agents/po.md](.bmad-core/agents/po.md)

- When to use: Use for backlog management, story refinement, acceptance criteria, sprint planning, and prioritization decisions
- How to activate: Mention "As po, ..." to get role-aligned behavior
- Full definition: open the source file above (content not embedded)

### Product Manager (id: pm)
Source: [.bmad-core/agents/pm.md](.bmad-core/agents/pm.md)

- When to use: Use for creating PRDs, product strategy, feature prioritization, roadmap planning, and stakeholder communication
- How to activate: Mention "As pm, ..." to get role-aligned behavior
- Full definition: open the source file above (content not embedded)

### Full Stack Developer (id: dev)
Source: [.bmad-core/agents/dev.md](.bmad-core/agents/dev.md)

- When to use: Use for code implementation, debugging, refactoring, and development best practices
- How to activate: Mention "As dev, ..." to get role-aligned behavior
- Full definition: open the source file above (content not embedded)

### BMad Master Orchestrator (id: bmad-orchestrator)
Source: [.bmad-core/agents/bmad-orchestrator.md](.bmad-core/agents/bmad-orchestrator.md)

- When to use: Use for workflow coordination, multi-agent tasks, role switching guidance, and when unsure which specialist to consult
- How to activate: Mention "As bmad-orchestrator, ..." to get role-aligned behavior
- Full definition: open the source file above (content not embedded)

### BMad Master Task Executor (id: bmad-master)
Source: [.bmad-core/agents/bmad-master.md](.bmad-core/agents/bmad-master.md)

- When to use: Use when you need comprehensive expertise across all domains, running 1 off tasks that do not require a persona, or just wanting to use the same agent for many things.
- How to activate: Mention "As bmad-master, ..." to get role-aligned behavior
- Full definition: open the source file above (content not embedded)

### Architect (id: architect)
Source: [.bmad-core/agents/architect.md](.bmad-core/agents/architect.md)

- When to use: Use for system design, architecture documents, technology selection, API design, and infrastructure planning
- How to activate: Mention "As architect, ..." to get role-aligned behavior
- Full definition: open the source file above (content not embedded)

### Business Analyst (id: analyst)
Source: [.bmad-core/agents/analyst.md](.bmad-core/agents/analyst.md)

- When to use: Use for market research, brainstorming, competitive analysis, creating project briefs, initial project discovery, and documenting existing projects (brownfield)
- How to activate: Mention "As analyst, ..." to get role-aligned behavior
- Full definition: open the source file above (content not embedded)

## Tasks

These are reusable task briefs; use the paths to open them as needed.

### Task: validate-next-story
Source: [.bmad-core/tasks/validate-next-story.md](.bmad-core/tasks/validate-next-story.md)
- How to use: Reference the task in your prompt or execute via your configured commands.
- Full brief: open the source file above (content not embedded)

### Task: trace-requirements
Source: [.bmad-core/tasks/trace-requirements.md](.bmad-core/tasks/trace-requirements.md)
- How to use: Reference the task in your prompt or execute via your configured commands.
- Full brief: open the source file above (content not embedded)

### Task: test-design
Source: [.bmad-core/tasks/test-design.md](.bmad-core/tasks/test-design.md)
- How to use: Reference the task in your prompt or execute via your configured commands.
- Full brief: open the source file above (content not embedded)

### Task: shard-doc
Source: [.bmad-core/tasks/shard-doc.md](.bmad-core/tasks/shard-doc.md)
- How to use: Reference the task in your prompt or execute via your configured commands.
- Full brief: open the source file above (content not embedded)

### Task: risk-profile
Source: [.bmad-core/tasks/risk-profile.md](.bmad-core/tasks/risk-profile.md)
- How to use: Reference the task in your prompt or execute via your configured commands.
- Full brief: open the source file above (content not embedded)

### Task: review-story
Source: [.bmad-core/tasks/review-story.md](.bmad-core/tasks/review-story.md)
- How to use: Reference the task in your prompt or execute via your configured commands.
- Full brief: open the source file above (content not embedded)

### Task: qa-gate
Source: [.bmad-core/tasks/qa-gate.md](.bmad-core/tasks/qa-gate.md)
- How to use: Reference the task in your prompt or execute via your configured commands.
- Full brief: open the source file above (content not embedded)

### Task: nfr-assess
Source: [.bmad-core/tasks/nfr-assess.md](.bmad-core/tasks/nfr-assess.md)
- How to use: Reference the task in your prompt or execute via your configured commands.
- Full brief: open the source file above (content not embedded)

### Task: kb-mode-interaction
Source: [.bmad-core/tasks/kb-mode-interaction.md](.bmad-core/tasks/kb-mode-interaction.md)
- How to use: Reference the task in your prompt or execute via your configured commands.
- Full brief: open the source file above (content not embedded)

### Task: index-docs
Source: [.bmad-core/tasks/index-docs.md](.bmad-core/tasks/index-docs.md)
- How to use: Reference the task in your prompt or execute via your configured commands.
- Full brief: open the source file above (content not embedded)

### Task: generate-ai-frontend-prompt
Source: [.bmad-core/tasks/generate-ai-frontend-prompt.md](.bmad-core/tasks/generate-ai-frontend-prompt.md)
- How to use: Reference the task in your prompt or execute via your configured commands.
- Full brief: open the source file above (content not embedded)

### Task: facilitate-brainstorming-session
Source: [.bmad-core/tasks/facilitate-brainstorming-session.md](.bmad-core/tasks/facilitate-brainstorming-session.md)
- How to use: Reference the task in your prompt or execute via your configured commands.
- Full brief: open the source file above (content not embedded)

### Task: execute-checklist
Source: [.bmad-core/tasks/execute-checklist.md](.bmad-core/tasks/execute-checklist.md)
- How to use: Reference the task in your prompt or execute via your configured commands.
- Full brief: open the source file above (content not embedded)

### Task: document-project
Source: [.bmad-core/tasks/document-project.md](.bmad-core/tasks/document-project.md)
- How to use: Reference the task in your prompt or execute via your configured commands.
- Full brief: open the source file above (content not embedded)

### Task: create-next-story
Source: [.bmad-core/tasks/create-next-story.md](.bmad-core/tasks/create-next-story.md)
- How to use: Reference the task in your prompt or execute via your configured commands.
- Full brief: open the source file above (content not embedded)

### Task: create-doc
Source: [.bmad-core/tasks/create-doc.md](.bmad-core/tasks/create-doc.md)
- How to use: Reference the task in your prompt or execute via your configured commands.
- Full brief: open the source file above (content not embedded)

### Task: create-deep-research-prompt
Source: [.bmad-core/tasks/create-deep-research-prompt.md](.bmad-core/tasks/create-deep-research-prompt.md)
- How to use: Reference the task in your prompt or execute via your configured commands.
- Full brief: open the source file above (content not embedded)

### Task: create-brownfield-story
Source: [.bmad-core/tasks/create-brownfield-story.md](.bmad-core/tasks/create-brownfield-story.md)
- How to use: Reference the task in your prompt or execute via your configured commands.
- Full brief: open the source file above (content not embedded)

### Task: correct-course
Source: [.bmad-core/tasks/correct-course.md](.bmad-core/tasks/correct-course.md)
- How to use: Reference the task in your prompt or execute via your configured commands.
- Full brief: open the source file above (content not embedded)

### Task: brownfield-create-story
Source: [.bmad-core/tasks/brownfield-create-story.md](.bmad-core/tasks/brownfield-create-story.md)
- How to use: Reference the task in your prompt or execute via your configured commands.
- Full brief: open the source file above (content not embedded)

### Task: brownfield-create-epic
Source: [.bmad-core/tasks/brownfield-create-epic.md](.bmad-core/tasks/brownfield-create-epic.md)
- How to use: Reference the task in your prompt or execute via your configured commands.
- Full brief: open the source file above (content not embedded)

### Task: apply-qa-fixes
Source: [.bmad-core/tasks/apply-qa-fixes.md](.bmad-core/tasks/apply-qa-fixes.md)
- How to use: Reference the task in your prompt or execute via your configured commands.
- Full brief: open the source file above (content not embedded)

### Task: advanced-elicitation
Source: [.bmad-core/tasks/advanced-elicitation.md](.bmad-core/tasks/advanced-elicitation.md)
- How to use: Reference the task in your prompt or execute via your configured commands.
- Full brief: open the source file above (content not embedded)

<!-- END: BMAD-AGENTS-OPENCODE -->
