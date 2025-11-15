# Hackerbot Source Tree Structure

<!-- Powered by BMAD™ Core -->

## Version Information
- **Document Version**: v4.0
- **Creation Date**: 2025-10-17
- **Author**: Winston (Architect)
- **Status**: Complete

## Overview

This document describes the complete source tree structure of the Hackerbot project, including the purpose and contents of each directory and key files.

## Root Directory Structure

```
opt_hackerbot/
├── .bmad-core/                    # BMad framework configuration
├── .claude/                        # Claude Code integration
├── .gemini/                        # Gemini integration
├── .qwen/                          # Qwen integration
├── .windsurf/                      # Windsurf integration
├── cag/                            # Context-Aware Generation system
├── config/                         # XML configuration files
├── docs/                           # Documentation
├── knowledge_bases/                # Knowledge source management
├── providers/                      # LLM provider implementations
├── rag/                            # Retrieval-Augmented Generation system
├── setup/                          # Setup and initialization scripts
├── test/                           # Test suites
├── .envrc                          # Direnv configuration
├── .gems/                          # Local gem installation
├── .gitignore                      # Git ignore rules
├── .kilocodemodes                  # IDE configuration
├── AGENTS.md                       # BMad agent documentation
├── bot_manager.rb                  # Central bot controller
├── flake.nix                       # Nix flake configuration
├── Gemfile                         # Ruby dependencies
├── hackerbot.rb                    # Main entry point
├── Makefile                        # Development automation
├── print.rb                        # Logging utilities
├── QUICKSTART.md                   # User quick start guide
├── rag_cag_manager.rb              # Knowledge enhancement coordinator
├── README.md                       # Project overview
└── simple_irc_server.py            # Development IRC server
```

## Core Application Files

### Entry Points

#### `hackerbot.rb`
- **Purpose**: Main CLI entry point and application bootstrap
- **Responsibilities**:
  - Command-line argument parsing
  - Environment configuration
  - LLM provider setup
  - Bot manager initialization
- **Key Functions**:
  - Usage information display
  - Argument validation
  - RAG + CAG configuration
  - Bot startup coordination

#### `bot_manager.rb`
- **Purpose**: Central controller for all bot instances
- **Responsibilities**:
  - XML configuration parsing
  - Bot instance management
  - LLM client coordination
  - IRC event handling
  - Chat history management
- **Key Classes**:
  - `BotManager`: Main controller class
  - Bot creation and lifecycle management
  - Personality system coordination

#### `rag_cag_manager.rb`
- **Purpose**: Unified knowledge enhancement coordinator
- **Responsibilities**:
  - RAG system coordination
  - CAG system management
  - Knowledge source integration
  - Context enhancement
- **Key Classes**:
  - `RAGCAGManager`: Unified manager
  - Context combination logic
  - Performance optimization

#### `print.rb`
- **Purpose**: Centralized logging and output utilities
- **Features**:
  - Multiple log levels (Debug, Info, Std, Err)
  - Timestamped logging
  - Structured output
  - Debug file logging

## Directory Structure Details

### `.bmad-core/` - BMad Framework
```
.bmad-core/
├── agent-teams/                    # Agent team configurations
├── agents/                         # BMad agent definitions
├── checklists/                     # Quality checklists
├── data/                           # Reference data and knowledge
├── tasks/                          # Executable task definitions
├── templates/                      # Document templates
├── utils/                          # Utility functions
├── workflows/                      # Workflow definitions
├── core-config.yaml                # Core BMad configuration
├── enhanced-ide-development-workflow.md
├── install-manifest.yaml           # Installation manifest
└── user-guide.md                   # BMad user guide
```

### `cag/` - Context-Aware Generation
```
cag/
├── cag_manager.rb                  # CAG system manager
├── in_memory_graph_client.rb       # In-memory graph implementation
├── in_memory_graph_offline_client.rb # Offline graph client
├── knowledge_graph_interface.rb    # Graph interface definition
└── test_cag_manager.rb             # CAG system tests
```

**Purpose**: Knowledge graph-based context enhancement
**Key Components**:
- Entity extraction and relationship mapping
- Graph traversal and context generation
- In-memory storage for offline operation

### `config/` - Configuration Files
```
config/
├── bot_o.xml                       # Ollama bot configuration
├── example_enhanced_knowledge_bot.xml # Enhanced knowledge bot example
├── example_multi_personality_bot.xml # Multi-personality bot example
├── example_ollama.xml.example      # Ollama configuration template
├── example_openai_compatible.xml.example # OpenAI-compatible template
├── example_rag_cag_bot.xml         # RAG + CAG enabled bot example
├── fishing_exercise.xml            # Social engineering exercise
├── test.xml.example                # Test configuration template
└── teaching_assistant_bot.xml      # Teaching assistant configuration
```

**Purpose**: XML-based bot and scenario configurations
**Configuration Types**:
- LLM provider settings
- Attack scenarios
- Personality definitions
- Knowledge source configuration

### `docs/` - Documentation
```
docs/
├── development/                    # Development documentation
│   ├── api-reference.md            # API documentation
│   ├── architecture.md             # System architecture
│   ├── development-guide.md        # Development setup
│   ├── OFFLINE_INDIVIDUAL_CONTROL_CHANGES.md
│   ├── RAG_CAG_IMPLEMENTATION_SUMMARY.md
│   └── TEST_IMPLEMENTATION_SUMMARY.md
├── stories/                        # User stories and epics
│   ├── epic-1-llm-feature-stabilization.md
│   ├── 1.1.diagnose-cag-loading.story.md
│   ├── 1.2.fix-cag-caching.story.md
│   ├── 1.3.create-rag-tests.story.md
│   ├── 1.4.create-cag-tests.story.md
│   ├── 1.5.performance-comparison.story.md
│   └── 1.6.document-findings.story.md
├── user_guides/                    # User documentation
│   ├── configuration-guide.md      # Configuration guide
│   ├── deployment-guide.md         # Deployment instructions
│   └── user-guide.md               # User manual
├── qa/                             # Quality assurance documentation
├── prd/                            # Product requirements (sharded)
├── architecture/                   # Architecture documentation (sharded)
│   ├── coding-standards.md         # Coding standards
│   ├── tech-stack.md               # Technology stack
│   └── source-tree.md              # Source tree structure
├── bmad-architecture.md            # BMad framework architecture
├── prd.md                          # Product requirements document
├── architecture.md                 # Main architecture document
├── project-analysis.md             # Project analysis
├── CASE_INSENSITIVE_CHANNELS.md    # IRC channel handling
├── MULTI_PERSONALITY_FEATURE.md    # Personality system
├── RESTRUCTURING_SUMMARY.md        # Project restructuring
├── incident_response_procedures.md # Security incident response
└── network_security_best_practices.md # Security guidelines
```

### `knowledge_bases/` - Knowledge Management
```
knowledge_bases/
├── mitre_attack_knowledge.rb       # MITRE ATT&CK integration
├── base_knowledge_source.rb        # Base knowledge source interface
├── knowledge_source_manager.rb     # Knowledge source coordination
├── sources/                        # Knowledge source implementations
│   ├── man_pages/                  # Manual page processing
│   │   └── man_page_processor.rb
│   ├── markdown_files/             # Markdown document processing
│   │   └── markdown_processor.rb
│   └── utils/                      # Knowledge processing utilities
└── test_knowledge_base.rb          # Knowledge base tests
```

**Purpose**: Cybersecurity knowledge integration and management
**Knowledge Sources**:
- MITRE ATT&CK framework
- Unix/Linux manual pages
- Project documentation
- Custom markdown files

### `providers/` - LLM Provider Implementations
```
providers/
├── llm_client.rb                   # Base LLM client interface
├── llm_client_factory.rb           # Provider factory
├── ollama_client.rb                # Ollama provider implementation
├── openai_client.rb                # OpenAI provider implementation
├── sglang_client.rb                # SGLang provider implementation
├── vllm_client.rb                  # VLLM provider implementation
└── test_llm_client_base.rb         # LLM client tests
```

**Purpose**: Multi-provider LLM integration
**Design Pattern**: Factory pattern with pluggable providers
**Features**:
- Unified interface across providers
- Streaming support
- Connection management
- Error handling

### `rag/` - Retrieval-Augmented Generation
```
rag/
├── rag_manager.rb                  # RAG system manager
├── chromadb_client.rb              # ChromaDB integration
├── chromadb_offline_client.rb      # Offline ChromaDB client
├── embedding_service_interface.rb  # Embedding service interface
├── ollama_embedding_client.rb      # Ollama embedding service
├── ollama_embedding_offline_client.rb # Offline embedding service
├── openai_embedding_client.rb      # OpenAI embedding service
├── rag_manager.rb                  # RAG coordination
├── vector_db_interface.rb          # Vector database interface
└── test_rag_manager.rb             # RAG system tests
```

**Purpose**: Vector-based document retrieval and enhancement
**Components**:
- Vector database integration (ChromaDB)
- Embedding service management
- Document similarity search
- Context retrieval

### `setup/` - Setup and Initialization
```
setup/
├── populate_knowledge_bases.rb     # Knowledge base initialization
└── test_knowledge_base.rb          # Knowledge base validation
```

**Purpose**: Project setup and knowledge base population
**Functions**:
- Initial knowledge base setup
- MITRE ATT&CK data loading
- System validation

### `test/` - Test Suites
```
test/
├── cag/                            # CAG system tests
│   ├── test_cag_manager.rb
│   ├── test_in_memory_graph_client.rb
│   └── test_knowledge_graph_interface.rb
├── rag/                            # RAG system tests
│   ├── test_chromadb_client.rb
│   ├── test_embedding_service_interface.rb
│   ├── test_ollama_embedding_client.rb
│   ├── test_rag_manager.rb
│   └── test_vector_db_interface.rb
├── quick_test.rb                   # Quick validation test
├── rag_cag_integration_test.rb     # RAG + CAG integration tests
├── run_rag_cag_tests.rb            # Test runner
├── run_tests.rb                    # Main test runner
├── test_all.rb                     # Complete test suite
├── test_bot_manager.rb             # Bot manager tests
├── test_helper.rb                  # Test utilities
├── test_hackerbot.rb               # Main application tests
├── test_llm_client_base.rb         # LLM client tests
└── README.md                       # Test documentation
```

**Purpose**: Comprehensive testing framework
**Test Types**:
- Unit tests for individual components
- Integration tests for system interactions
- Performance tests for load testing
- Security tests for vulnerability assessment

## Configuration Files

### Development Environment

#### `.envrc`
- **Purpose**: Direnv configuration for automatic environment setup
- **Contents**: Environment variables and PATH configuration

#### `flake.nix`
- **Purpose**: Nix flake for reproducible development environment
- **Contents**: Package definitions, development tools, dependencies

#### `Makefile`
- **Purpose**: Development automation and common tasks
- **Targets**:
  - Environment setup
  - IRC server management
  - Testing automation
  - Documentation generation

#### `Gemfile`
- **Purpose**: Ruby gem dependencies
- **Contents**: Required gems with version constraints

#### `.gitignore`
- **Purpose**: Git ignore patterns
- **Contents**: Files and directories to exclude from version control

### IDE Configuration

#### `.kilocodemodes`
- **Purpose**: IDE-specific configuration
- **Contents**: Editor settings and modes

#### AI Platform Integration
- `.claude/`: Claude Code integration files
- `.gemini/`: Gemini integration files
- `.qwen/`: Qwen integration files
- `.windsurf/`: Windsurf workflow files

## Data and Storage

### Local Storage Structure
```
./knowledge_bases/offline/          # Offline knowledge storage
├── vector_db/                      # ChromaDB storage
├── graph/                          # Knowledge graph storage
└── embeddings/                     # Embedding cache

./cache/                            # Application cache
├── embeddings/                     # Embedding cache
└── responses/                      # Response cache

./logs/                             # Log files
├── debug.log                       # Debug logging
├── error.log                       # Error logging
└── access.log                      # Access logging

./.gems/                            # Local gem installation
└── ruby/                           # Gem files
```

### Configuration Storage
```
./config/                           # Bot configurations
./data/                             # Runtime data
./tmp/                              # Temporary files
```

## Build and Deployment

### Build Artifacts
```
./dist/                             # Distribution files (if created)
./pkg/                              # Package files (if created)
./release/                          # Release artifacts (if created)
```

### Documentation Build
```
./docs/_build/                      # Generated documentation
./docs/_site/                       # Static site (if generated)
```

## Development Workflow

### File Organization Patterns

#### Core Application Logic
- **Location**: Root directory
- **Naming**: snake_case.rb
- **Purpose**: Main application components

#### Subsystem Organization
- **Location**: Dedicated directories (cag/, rag/, providers/)
- **Naming**: Descriptive directory names
- **Purpose**: Modular subsystem organization

#### Configuration Management
- **Location**: config/
- **Format**: XML for configurations, YAML for data
- **Purpose**: Structured configuration management

#### Testing Organization
- **Location**: test/
- **Structure**: Mirror source structure
- **Purpose**: Comprehensive test coverage

#### Documentation Organization
- **Location**: docs/
- **Structure**: Hierarchical by type and audience
- **Purpose**: Complete documentation coverage

### Naming Conventions

#### Files and Directories
- **Ruby Files**: snake_case.rb
- **Configuration Files**: descriptive_name.xml
- **Documentation**: kebab-case.md
- **Test Files**: test_*.rb

#### Classes and Modules
- **Classes**: PascalCase
- **Modules**: PascalCase
- **Methods**: snake_case
- **Constants**: SCREAMING_SNAKE_CASE

## Integration Points

### External Dependencies
- **LLM Providers**: External services (Ollama, OpenAI, etc.)
- **Knowledge Sources**: MITRE ATT&CK, documentation
- **IRC Network**: External IRC servers or local instance

### Internal Interfaces
- **LLM Client Interface**: Standardized provider interface
- **Knowledge Enhancement Interface**: RAG + CAG coordination
- **Configuration Interface**: XML parsing and validation

### Data Flow
- **Input**: IRC messages and CLI commands
- **Processing**: AI enhancement and knowledge retrieval
- **Output**: IRC responses and CLI output

## Maintenance and Evolution

### Code Organization Principles
1. **Separation of Concerns**: Clear boundaries between subsystems
2. **Modularity**: Independent, replaceable components
3. **Consistency**: Uniform naming and structure patterns
4. **Testability**: Comprehensive test coverage
5. **Documentation**: Complete and up-to-date documentation

### Evolution Considerations
- **Scalability**: Structure supports growth and change
- **Maintainability**: Clear organization for long-term maintenance
- **Extensibility**: Plugin architecture for new features
- **Performance**: Optimized file organization for performance

## Conclusion

The Hackerbot source tree is organized to support modular development, comprehensive testing, and clear documentation. The structure reflects the system's architecture with clear separation between core application logic, AI subsystems, knowledge management, and configuration.

This organization enables efficient development, testing, and maintenance while supporting the project's goals of security, reliability, and extensibility.