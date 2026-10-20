# Hackerbot Architecture Overview

This document provides a comprehensive technical overview of the Hackerbot framework's architecture, design decisions, and component interactions.

## 🏗️ High-Level Architecture

### System Design Philosophy

Hackerbot is designed around several key architectural principles:

1. **Modularity**: Each component is loosely coupled and independently testable
2. **Extensibility**: Easy to add new LLM providers, knowledge sources, and entity types
3. **Security**: Offline-first operation with minimal external dependencies
4. **Performance**: Configurable resource usage with caching and optimization
5. **Maintainability**: Clean separation of concerns with well-defined interfaces

### Architectural Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                        Hackerbot Framework                      │
├─────────────────────────────────────────────────────────────────┤
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐  │
│  │   User Layer    │  │  Config Layer   │  │  External Layer │  │
│  │                 │  │                 │  │                 │  │
│  │ • IRC Clients   │  │ • XML Configs   │  │ • Ollama        │  │
│  │ • Web Interface │  │ • Command Line  │  │ • OpenAI        │  │
│  │ • API Clients   │  │ • Environment   │  │ • VLLM          │  │
│  │                 │  │                 │  │ • SGLang        │  │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘  │
│           │                     │                     │         │
│           └─────────────────────┼─────────────────────┘         │
│                                 │                               │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │                    Application Layer                        ││
│  │                                                             ││
│  │  ┌─────────────┐  ┌──────────────┐  ┌─────────────────────┐ ││
│  │  │Bot Manager  │  │ Hackerbot    │  │   RAG/CAG Manager   │ ││
│  │  │             │  │ Main         │  │                     │ ││
│  │  │• Bot Mgmt   │  │• CLI         │  │• Knowledge Coord    │ ││
│  │  │• Config     │  │• Entry Pt    │  │• Context Merging    │ ││
│  │  │• Lifecycle  │  │• Args Parse  │  │• Caching            │ ││
│  │  └─────────────┘  └──────────────┘  └─────────────────────┘ ││
│  └─────────────────────────────────────────────────────────────┘│
│                                 │                               │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │                    Service Layer                            ││
│  │                                                             ││
│  │  ┌─────────────┐  ┌──────────────┐  ┌─────────────────────┐ ││
│  │  │LLM Client   │  │   RAG System │  │   CAG System        │ ││
│  │  │             │  │              │  │                     │ ││
│  │  │• Factory    │  │• Vector DB   │  │• Knowledge Graph    │ ││
│  │  │• Providers  │  │• Embeddings  │  │• Entity Extract     │ ││
│  │  │• Streaming  │  │• Similarity  │  │• Context Analysis   │ ││
│  │  │• History    │  │• Documents   │  │• Relationships      │ ││
│  │  └─────────────┘  └──────────────┘  └─────────────────────┘ ││
│  └─────────────────────────────────────────────────────────────┘│
│                                 │                               │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │                    Data Layer                               ││
│  │                                                             ││
│  │  ┌─────────────┐  ┌──────────────┐  ┌─────────────────────┐ ││
│  │  │ Knowledge   │  │ Configuration│  │   User Data         │ ││
│  │  │  Bases      │  │   Files      │  │                     │ ││
│  │  │             │  │              │  │                     │ ││
│  │  │• MITRE ATT&CK│ │• XML Configs │  │• Chat History       │ ││
│  │  │• Man Pages  │  │• Bot Defs    │  │• User Sessions      | ││
│  │  │• Markdown   │  │• Attack S    │  │• Preferences        | ││
│  │  │• Custom     │  │• Messages    │  │• Progress           | ││
│  │  └─────────────┘  └──────────────┘  └─────────────────────┘ ││
│  └─────────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────────┘
```

## 🎯 Core Components

### 1. Entry Point & CLI (hackerbot.rb)

**Purpose**: Main application entry point and command-line interface

**Responsibilities**:
- Parse command-line arguments
- Initialize application components
- Coordinate startup sequence
- Handle graceful shutdown

**Key Design Decisions**:
- Simple, linear initialization flow
- Clear separation between CLI parsing and application logic
- Graceful error handling with informative messages

```ruby
# Initialization Flow
def main
  # 1. Parse CLI arguments
  options = parse_arguments(ARGV)

  # 2. Initialize components
  bot_manager = BotManager.new(
    options[:irc_server],
    options[:llm_provider],
    # ... other options
  )

  # 3. Load configurations
  bot_manager.load_bot_configurations(options[:config_dir])

  # 4. Start IRC bots
  bot_manager.start_bots

  # 5. Main event loop
  run_event_loop(bot_manager)
end
```

### 2. Bot Manager (bot_manager.rb)

**Purpose**: Central coordinator for bot lifecycle and operations

**Responsibilities**:
- Manage multiple bot instances
- Load and parse XML configurations
- Coordinate LLM client creation
- Handle chat history management
- Assemble prompts for LLM processing
- Fetch VM context from student machines (Epic 4)

**Key Design Patterns**:
- **Manager Pattern**: Centralized control over bot lifecycle
- **Factory Pattern**: Delegates LLM client creation to LLMClientFactory
- **Strategy Pattern**: Different prompt assembly strategies based on configuration

```ruby
class BotManager
  # Core Management Methods
  def initialize(irc_server, llm_provider, *options)
    @bots = {}
    @llm_clients = {}
    @chat_histories = {}
    # Initialize components
  end

  def load_bot_configurations(config_dir)
    # Load XML configurations and create bot instances
  end

  def create_bot(config)
    # Create IRC bot with LLM integration
  end

  def assemble_prompt(system_prompt, context, chat_context, user_message, enhanced_context)
    # Combine all context elements into final prompt (includes VM context)
  end
  
  def fetch_vm_context(bot_name, attack_index, variables = {})
    # Fetch VM context from student machines via SSH (Epic 4)
  end
end
```

### 3. LLM Client System

#### Base LLM Client (llm_client.rb)

**Purpose**: Abstract interface for all LLM provider implementations

**Key Design Principles**:
- **Template Method Pattern**: Defines algorithm structure, delegates implementation details
- **Strategy Pattern**: Different providers implement same interface
- **Dependency Injection**: Configuration injected at construction

```ruby
class LLMClient
  # Abstract interface - all providers must implement
  def generate_response(message, context = '', user_id = nil)
    raise NotImplementedError
  end

  def generate_streaming_response(message, context = '', user_id = nil, &callback)
    raise NotImplementedError
  end

  def test_connection
    raise NotImplementedError
  end

  # Common functionality for all providers
  def update_system_prompt(new_prompt)
    @system_prompt = new_prompt
  end
end
```

#### LLM Client Factory (llm_client_factory.rb)

**Purpose**: Create appropriate LLM client instances based on provider type

**Design Pattern**: Factory Method with Registry

```ruby
class LLMClientFactory
  PROVIDERS = {
    'ollama' => OllamaClient,
    'openai' => OpenAIClient,
    'vllm' => VLLMClient,
    'sglang' => SGLangClient
  }

  def self.create_client(provider, options = {})
    provider_class = PROVIDERS[provider.downcase]
    raise UnknownProviderError, "Unknown LLM provider: #{provider}" unless provider_class

    provider_class.new(options)
  end
end
```

### 4. VM Context Manager (vm_context_manager.rb)

**Purpose**: SSH-based runtime state retrieval from student VMs (Epic 4)

**Design Principles**:
- **Service Class Pattern**: Stateless service providing SSH operations
- **Graceful Degradation**: Continues operation if VM context fetching fails
- **Security First**: Only executes trusted commands from XML configuration

**Key Methods**:
```ruby
class VMContextManager
  def initialize(options = {})
    @default_timeout = options.fetch(:default_timeout, 30)
    @command_timeout = options.fetch(:command_timeout, 15)
  end
  
  # Execute command on remote VM via SSH
  def execute_command(ssh_config, command, variables = {})
    # Uses Open3.popen2e for SSH command execution
    # Applies variable substitution (e.g., {{chat_ip_address}})
    # Handles timeouts and connection errors gracefully
  end
  
  # Read file from remote VM via SSH
  def read_file(ssh_config, file_path, variables = {})
    # Uses execute_command with 'cat' to read file contents
    # Supports both absolute and relative paths
  end
  
  # Retrieve bash history from remote VM
  def read_bash_history(ssh_config, user = nil, limit = nil, variables = {})
    # Reads .bash_history or .zsh_history
    # Supports user-specific paths and line limits
    # Returns empty string on error (graceful degradation)
  end
end
```

**Integration with BotManager**:
- BotManager calls `fetch_vm_context()` when attack has `<vm_context>` config
- VM context assembled into structured format and included in LLM prompt
- Reuses existing SSH infrastructure from `get_shell` configuration

### 5. Knowledge Enhancement System

#### RAG Manager (rag/rag_manager.rb)

**Purpose**: Knowledge enhancement coordinator (RAG-only system)

**Design Principles**:
- **Facade Pattern**: Simplifies complex subsystem interactions
- **Strategy Pattern**: Configurable RAG weighting and combination
- **Observer Pattern**: Cache invalidation and knowledge base updates

```ruby
class RAGManager
  def initialize(rag_config)
    @rag_config = rag_config
    # Initialize vector DB, embedding service, etc.
  end

  def get_enhanced_context(query, options = {})
    # 1. Get RAG context via similarity search
    rag_context = get_relevant_documents(query) if @config[:enable_rag]
    
    # 2. Get explicit context via identifier-based lookups (Epic 3)
    explicit_context = get_explicit_context(options[:explicit_items]) if options[:explicit_items]
    
    # 3. Combine contexts with configured weights
    merge_contexts(rag_context, explicit_context)
  end
end
```

#### RAG System Architecture

```
┌─────────────────────────────────────────────────----────────────┐
│                        RAG System                               │
├──────────────────────────────────────────────----───────────────┤
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐  │
│  │   RAG Manager   │  │ Vector DB       │  │ Embedding       │  │
│  │                 │  │ Interface       │  │ Service         │  │
│  │                 │  │                 │  │ Interface       │  │
│  │ • Document Mgmt │  │ • Storage       │  │ • Text -> Vec   │  │
│  │ • Similarity    │  │ • Search        │  │ • Batch Proc    │  │
│  │ • Caching       │  │ • Collections   │  │ • Models        │  │
│  │ • Integration   │  │ • Metadata      │  │ • API Mgmt      │  │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘  │
└──────────────────────────────────────────────────────----───────┘
```

#### CAG System Architecture

```
┌────────----─────────────────────────────────────────────────────┐
│                        CAG System                               │
├───────────----──────────────────────────────────────────────────┤
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐  │
│  │   CAG Manager   │  │ Knowledge Graph │  │ Entity          │  │
│  │                 │  │ Interface       │  │ Extractor       │  │
│  │                 │  │                 │  │ Interface       │  │
│  │ • Context Mgmt  │  │ • Nodes/Edges   │  │ • Pattern Match │  │
│  │ • Graph Traversal│ │ • Relationships │  │ • Type Recogn   │  │
│  │ • Entity Link   │  │ • Properties    │  │ • Confidence    │  │
│  │ • Integration   │  │ • Traversal     │  │ • Context       │  │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘  │
└──────────────────────────────────────────────----───────────────┘
```

### 5. Knowledge Base System

#### Knowledge Source Architecture

```
┌─────────────────────────────────────────────────────────----────┐
│                   Knowledge Sources                             │
├────────────────────────────────────────────────────────────----─┤
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐  │
│  │  Base Knowledge │  │  MITRE ATT&CK   │  │   Man Pages     │  │
│  │    Source       │  │   Knowledge     │  │   Source        │  │
│  │                 │  │    Source       │  │                 │  │
│  │ • Abstract      │  │ • Techniques    │  │ • Command Docs  │  │
│  │ • Interface     │  │ • Tactics       │  │ • Sections      │  │
│  │ • Processing    │  │ • Procedures    │  │ • Parsing       │  │
│  │ • Validation    │  │ • Mitigations   │  │ • Caching       │  │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘  │
│                                                                 │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐  │
│  │  Markdown Files │  │  Custom         │  │  Web APIs       │  │
│  │    Source       │  │  Knowledge      │  │   Source        │  │
│  │                 │  │    Source       │  │                 │  │
│  │ • File Reading  │  │ • Plugin Arch   │  │ • HTTP Client   │  │
│  │ • Metadata      │  │ • Config Driven │  │ • Auth          │  │
│  │ • Structuring   │  │ • Extensible    │  │ • Rate Limit    │  │
│  │ • Headers       │  │ • Data Types    │  │ • Error Handling│  │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘  │
└─────────────────────────────────────────────────────────────----┘
```

### 6. Configuration System

#### XML Configuration Architecture

```xml
<hackerbot>
  <!-- Core Identity -->
  <name>BotName</name>
  <llm_provider>ollama</llm_provider>

  <!-- LLM Configuration -->
  <ollama_model>gemma3:1b</ollama_model>
  <system_prompt>Bot personality</system_prompt>

  <!-- Knowledge Enhancement -->
  <rag_cag_enabled>true</rag_cag_enabled>
  <rag_enabled>true</rag_enabled>
  <cag_enabled>true</cag_enabled>

  <!-- Knowledge Sources -->
  <knowledge_sources>
    <source>
      <type>mitre_attack</type>
      <name>mitre</name>
      <enabled>true</enabled>
    </source>
  </knowledge_sources>

  <!-- Training Scenarios -->
  <attacks>
    <attack>
      <prompt>Scenario description</prompt>
      <system_prompt>Scenario personality</system_prompt>
      <condition>
        <output_matches>success_pattern</output_matches>
        <message>Completion message</message>
      </condition>
      
      <!-- VM Context Configuration (Epic 4) -->
      <vm_context>
        <bash_history path="~/.bash_history" limit="50" user="student"/>
        <commands>
          <command>ps aux</command>
          <command>netstat -tuln</command>
        </commands>
        <files>
          <file path="/etc/passwd"/>
        </files>
      </vm_context>
    </attack>
  </attacks>
</hackerbot>
```

## 🔄 Data Flow and Processing

### 1. Message Processing Pipeline

```
User Input → Validation → Context Assembly → LLM Processing → Response Delivery
     ↓              ↓              ↓              ↓              ↓
  IRC Message → Security Check → Knowledge Enhancement → API Call → IRC Response
```

#### Detailed Flow:

1. **Input Reception**
   - IRC message received
   - User identification
   - Input validation and sanitization

2. **Context Assembly**
   - Chat history retrieval (per-user)
   - Current attack context
   - RAG/CAG knowledge enhancement
   - System prompt integration

3. **LLM Processing**
   - Prompt construction
   - API call to LLM provider
   - Response streaming (if enabled)
   - Error handling and retries

4. **Response Delivery**
   - Response formatting
   - IRC message delivery
   - Chat history update
   - Logging and metrics

### 2. Knowledge Enhancement Flow

```
Query → Entity Extraction → Parallel Processing → Context Merging → Final Context
   ↓         ↓               ↓               ↓              ↓
Input → Find Entities → RAG + Explicit → Weighted Combine → Enhanced Output
```

#### RAG Processing:
- Query vectorization
- Similarity search in vector database
- Document retrieval and ranking
- Context formatting

#### Explicit Context Processing (Epic 3):
- Identifier-based lookups (man pages by name, docs by path, MITRE by ID)
- Direct knowledge source queries
- No similarity calculation needed

### 3. VM Context Fetching Flow (Epic 4)

```
Attack Stage → Check VM Config → SSH Operations → Assemble Context → LLM Prompt
    ↓              ↓                ↓                  ↓              ↓
Current Attack → vm_context? → Bash/Commands/Files → Structured → Enhanced
```

#### VM Context Processing:
- Check if attack has `<vm_context>` configuration
- Execute SSH commands via VMContextManager
- Fetch bash history, command outputs, and file contents
- Assemble structured VM state string
- Include in enhanced context for LLM prompt

### 3. Configuration Loading Flow

```
XML Config → Parsing → Validation → Component Creation → System Initialization
    ↓          ↓          ↓              ↓              ↓
File Read → DOM Build → Schema Check → Factory Methods → Ready State
```

## 🎨 Design Patterns Used

### 1. Factory Pattern
- **LLM Client Factory**: Creates appropriate LLM provider instances
- **Knowledge Source Factory**: Instantiates different knowledge source types
- **Bot Factory**: Creates configured bot instances

### 2. Strategy Pattern
- **LLM Providers**: Different implementations of same interface
- **Knowledge Sources**: Different processing strategies
- **Prompt Assembly**: Different assembly strategies based on configuration

### 3. Observer Pattern
- **Streaming Responses**: Callback-based chunk processing
- **Cache Invalidation**: Knowledge base updates
- **Configuration Changes**: Dynamic system updates

###
