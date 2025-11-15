# Hackerbot System Architecture Document

<!-- Powered by BMAD™ Core -->

## Version Information
- **Document Version**: v4.0
- **Architecture Version**: v4.0
- **Creation Date**: 2025-10-17
- **Authors**: Winston (Architect), BMad Orchestrator
- **Status**: Complete
- **Sharded**: true
- **Shard Location**: docs/architecture/

## Table of Contents
1. [Executive Summary](#executive-summary)
2. [Introduction](#introduction)
3. [High-Level Architecture](#high-level-architecture)
4. [Component Architecture](#component-architecture)
5. [Data Flow and Interactions](#data-flow-and-interactions)
6. [Technology Stack](#technology-stack)
7. [Deployment Architecture](#deployment-architecture)
8. [Security Architecture](#security-architecture)
9. [Performance and Scalability](#performance-and-scalability)
10. [Integration Points](#integration-points)
11. [Future Evolution](#future-evolution)

---

## Executive Summary

Hackerbot is a sophisticated Ruby-based IRC bot framework for cybersecurity training that combines traditional attack simulation with modern AI capabilities. The system employs a modular, plugin-based architecture supporting multiple LLM providers (Ollama, OpenAI, VLLM, SGLang), advanced knowledge retrieval systems (RAG with stage-aware context injection), and comprehensive MITRE ATT&CK framework integration.

**Key Architectural Achievements:**
- **Multi-Provider AI Integration**: Seamless switching between LLM providers with unified interface
- **RAG Knowledge System** (Epic 1): Validated and optimized vector-based retrieval system (CAG system removed for maintainability)
- **Full IRC Context Integration** (Epic 2I): Comprehensive message capture and full conversation history in LLM context
- **Stage-Aware Context Injection** (Epic 3): Per-attack explicit knowledge selection with identifier-based lookups
- **VM Context Fetching** (Epic 4): SSH-based runtime state retrieval from student machines (bash history, command outputs, files)
- **Offline-First Design**: Complete operation in air-gapped environments for secure training scenarios
- **Modular Plugin Architecture**: Extensible system for LLM providers, knowledge sources, and bot personalities
- **Nix Development Environment**: Reproducible builds and consistent development across platforms
- **Real-Time Interactive Training**: Progressive attack scenarios with AI-powered guidance and feedback

The architecture addresses the unique challenges of cybersecurity training environments, including network isolation requirements, data privacy concerns, and the need for realistic attack simulations with intelligent tutoring capabilities.

---

## Introduction

### System Overview

Hackerbot operates as an IRC-based training platform where cybersecurity trainees interact with AI-powered bots that simulate attack scenarios, provide guidance, and deliver educational content. The system combines the proven effectiveness of IRC-based chat interfaces with modern AI capabilities to create an immersive learning environment.

### Core Design Principles

1. **Security First**: All components designed for operation in secure, isolated environments
2. **Modularity**: Clear separation of concerns enabling independent component development and testing
3. **Extensibility**: Plugin architecture supporting new LLM providers, knowledge sources, and training scenarios
4. **Offline Capability**: Complete functionality without external dependencies
5. **Real-Time Interaction**: Low-latency responses maintaining conversational flow
6. **Knowledge Integration**: Seamless incorporation of cybersecurity intelligence (MITRE ATT&CK, documentation)

### Target Environments

- **Educational Institutions**: Universities and cybersecurity training centers
- **Corporate Training**: Security awareness and skill development programs
- **Government Agencies**: Law enforcement and military cybersecurity training
- **Individual Learners**: Self-paced cybersecurity skill development
- **Red Team Exercises**: Realistic attack simulation and practice

---

## High-Level Architecture

### Architectural Style

Hackerbot employs a **layered modular architecture** with the following characteristics:

- **Service-Oriented**: Each component provides specialized services through well-defined interfaces
- **Event-Driven**: IRC events trigger bot responses and AI interactions
- **Plugin-Based**: LLM providers and knowledge sources are pluggable components
- **Configuration-Driven**: Behavior controlled through XML configuration files
- **Knowledge-Enhanced**: AI responses enhanced with retrieved cybersecurity knowledge

### System Boundaries

```mermaid
graph TB
    subgraph "User Environment"
        IRC_CLIENTS[IRC Clients<br/>WeeChat, HexChat, etc.]
        CLI_USERS[CLI Users<br/>Terminal Interface]
    end
    
    subgraph "Communication Layer"
        IRC_SERVER[Python IRC Server<br/>Port 6667]
        CLI_INTERFACE[Command Line Interface]
    end
    
    subgraph "Application Layer"
        HACKERBOT[hackerbot.rb<br/>Entry Point]
        BOT_MANAGER[bot_manager.rb<br/>Central Controller]
        PERSONALITY[Personality System<br/>Multi-Bot Support]
    end
    
    subgraph "AI Orchestration Layer"
        LLM_FACTORY[LLM Client Factory]
        RAG_MANAGER[RAG Manager]
        CHAT_HISTORY[Chat History Management]
        CONTEXT_ENHANCEMENT[Context Enhancement]
    end
    
    subgraph "Provider Layer"
        OLLAMA[Ollama Client]
        OPENAI[OpenAI Client]
        VLLM[VLLM Client]
        SGLANG[SGLang Client]
    end
    
    subgraph "Knowledge Layer"
        VECTOR_DB[ChromaDB<br/>Vector Storage]
        KNOWLEDGE_GRAPH[In-Memory<br/>Knowledge Graph]
        MITRE_FRAMEWORK[MITRE ATT&CK<br/>Framework]
        DOCUMENTATION[Project<br/>Documentation]
        MAN_PAGES[Unix/Linux<br/>Man Pages]
    end
    
    subgraph "VM Context Layer"
        VM_CONTEXT_MGR[VM Context Manager<br/>Epic 4]
        SSH_INFRA[SSH Infrastructure]
        STUDENT_VMS[Student VMs]
    end
    
    subgraph "Configuration Layer"
        XML_CONFIG[XML Configuration<br/>System]
        ENV_VARS[Environment<br/>Variables]
        NIX_ENV[Nix Development<br/>Environment]
    end
    
    IRC_CLIENTS --> IRC_SERVER
    CLI_USERS --> CLI_INTERFACE
    IRC_SERVER --> BOT_MANAGER
    CLI_INTERFACE --> HACKERBOT
    HACKERBOT --> BOT_MANAGER
    
    BOT_MANAGER --> PERSONALITY
    BOT_MANAGER --> LLM_FACTORY
    BOT_MANAGER --> RAG_MANAGER
    BOT_MANAGER --> CHAT_HISTORY
    BOT_MANAGER --> CONTEXT_ENHANCEMENT
    BOT_MANAGER --> VM_CONTEXT_MGR
    
    LLM_FACTORY --> OLLAMA
    LLM_FACTORY --> OPENAI
    LLM_FACTORY --> VLLM
    LLM_FACTORY --> SGLANG
    
    RAG_MANAGER --> VECTOR_DB
    VECTOR_DB --> MITRE_FRAMEWORK
    VECTOR_DB --> DOCUMENTATION
    VECTOR_DB --> MAN_PAGES
    
    VM_CONTEXT_MGR --> SSH_INFRA
    SSH_INFRA --> STUDENT_VMS
    
    BOT_MANAGER --> XML_CONFIG
    HACKERBOT --> ENV_VARS
    NIX_ENV --> HACKERBOT
```

### Key Architectural Decisions

1. **IRC-Based Interface**: Chosen for simplicity, universal compatibility, and real-time nature
2. **Ruby Implementation**: Selected for excellent IRC libraries and rapid development capabilities
3. **Plugin Architecture**: Enables flexibility in LLM provider selection and knowledge source integration
4. **RAG Knowledge System**: Validated vector-based retrieval system with identifier-based lookups for precise context control
5. **Offline-First Design**: Essential for security training environments with network restrictions
6. **XML Configuration**: Provides structured validation and complex scenario definitions
7. **Nix Development**: Ensures reproducible environments and dependency management

---

## Component Architecture

### Core Components

#### 1. Entry Point and CLI (hackerbot.rb)
**Purpose**: Command-line interface and application bootstrap
**Responsibilities**:
- Parse command-line arguments and configuration
- Initialize LLM provider settings
- Configure RAG system
- Launch bot instances

**Key Interfaces**:
```ruby
# Main execution flow
hackerbot.rb -> BotManager.new -> start_bots
```

#### 2. Bot Manager (bot_manager.rb)
**Purpose**: Central controller for all bot instances
**Responsibilities**:
- Load and parse XML bot configurations
- Manage multiple bot personalities
- Coordinate LLM client creation
- Handle IRC event routing
- Maintain comprehensive chat history and context

**Key Features**:
- Multi-bot support with different personalities
- Comprehensive IRC message capture (Epic 2I): All channel messages stored with metadata
- Full conversation context assembly: Complete IRC conversation history included in LLM prompts
- Per-user and per-channel message history tracking
- Message type classification (user messages, bot responses, system messages)
- Configurable message type filtering for context inclusion
- Dynamic LLM provider switching
- RAG integration with stage-aware context injection
- Identifier-based knowledge lookups for explicit context selection

#### 3. LLM Provider System
**Purpose**: Abstract interface for multiple AI providers
**Components**:
- `llm_client.rb`: Base interface definition
- `llm_client_factory.rb`: Provider instantiation
- Provider implementations: `ollama_client.rb`, `openai_client.rb`, `vllm_client.rb`, `sglang_client.rb`

**Design Pattern**: Factory Pattern with Strategy Pattern implementation
**Benefits**: Easy addition of new providers, runtime provider switching

#### 4. RAG Manager (rag/rag_manager.rb)
**Purpose**: Knowledge enhancement coordinator (RAG-only system)
**Responsibilities**:
- Coordinate RAG (Retrieval-Augmented Generation) system
- Integrate multiple knowledge sources
- Provide enhanced context for AI responses
- Support explicit knowledge retrieval by identifier

**Architecture**: RAG-only approach for maintainability, with identifier-based lookups for stage-aware context injection
**Note**: CAG system was removed in Epic 1 - decision made to focus on RAG-only approach for better maintainability

#### 5. VM Context Manager (vm_context_manager.rb)
**Purpose**: SSH-based runtime state retrieval from student VMs (Epic 4)
**Responsibilities**:
- Execute SSH commands on student machines and capture output
- Read files from student VMs via SSH
- Retrieve bash history from student machines
- Handle SSH connection failures and timeouts gracefully
- Apply variable substitution in SSH configurations

**Key Features**:
- Reuses existing SSH infrastructure from `get_shell` configuration
- Support for bash history fetching with configurable paths, limits, and users
- Command execution with timeout protection (default 15 seconds)
- File reading for both absolute and relative paths
- Error handling with graceful degradation (continues operation on failures)
- Variable substitution support (`{{chat_ip_address}}` pattern)

**Design Pattern**: Service class with command execution abstraction
**Security**: SSH operations use trusted commands from XML configuration only

#### 6. Knowledge Management System
**Components**:
- **RAG System** (`rag/`): Vector-based document retrieval using ChromaDB
- **Knowledge Sources** (`knowledge_bases/`): MITRE ATT&CK, documentation, man pages
- **Identifier-Based Lookups**: Direct retrieval by ID/name/path for stage-aware context

**Knowledge Sources**:
- MITRE ATT&CK framework integration (lookup by technique ID)
- Project documentation and guides (lookup by file path)
- Unix/Linux manual pages (lookup by command name)
- Custom markdown documents (lookup by file path)

**Features (Epic 3 - Stage-Aware Context Injection)**:
- Per-attack explicit knowledge selection via XML configuration
- Identifier-based lookups for precise knowledge retrieval
- Hybrid mode: explicit items + similarity-based search
- Configurable context formatting with source attribution

#### 6. Configuration System
**Purpose**: XML-based bot and scenario configuration
**Features**:
- Bot personality definitions
- Attack scenario configurations
- LLM provider settings
- RAG system parameters (RAG-only approach)
- Knowledge source specifications

**Enhanced Configuration (Epic 2I, Epic 3, Epic 4)**:
- **Message History**: Configurable history window sizes (`max_history_length`, `max_irc_message_history`)
- **Message Type Filtering**: Control which message types appear in context (`message_type_filter`)
- **Stage-Aware Context** (`context_config`): Per-attack explicit knowledge selection:
  - `<man_pages>`: Specify man pages by command name
  - `<documents>`: Specify documents by file path
  - `<mitre_techniques>`: Specify MITRE techniques by ID
  - Combination modes: explicit-only, similarity-only, hybrid
- **VM Context Fetching** (`vm_context`): Per-attack SSH-based runtime state retrieval:
  - `<bash_history>`: Specify history file path, limit, and user
  - `<commands>`: Execute commands on student VMs and capture output
  - `<files>`: Read files from student VMs
  - Enable/disable flags at bot-level (`vm_context_enabled`) and attack-level

### Component Interactions

```mermaid
sequenceDiagram
    participant User
    participant IRC
    participant BotManager
    participant LLMFactory
    participant RAGManager
    participant VMContextManager
    participant LLMProvider
    participant KnowledgeBase
    participant StudentVM
    
    User->>IRC: Message
    IRC->>BotManager: Route event (capture message)
    BotManager->>BotManager: Get full chat context
    BotManager->>BotManager: Check VM context config
    BotManager->>VMContextManager: Fetch VM context (if configured)
    VMContextManager->>StudentVM: Execute SSH commands
    StudentVM-->>VMContextManager: Return bash history, outputs, files
    VMContextManager-->>BotManager: VM context data
    BotManager->>RAGManager: Get enhanced context
    RAGManager->>KnowledgeBase: Retrieve knowledge (explicit + similarity)
    KnowledgeBase-->>RAGManager: Return context
    RAGManager-->>BotManager: Enhanced context
    BotManager->>BotManager: Assemble prompt (chat + VM + RAG)
    BotManager->>LLMFactory: Create/get LLM client
    LLMFactory-->>BotManager: LLM client instance
    BotManager->>LLMProvider: Generate response
    LLMProvider-->>BotManager: AI response
    BotManager->>IRC: Send response
    BotManager->>BotManager: Store in message history
    IRC->>User: Display response
```

---

## Data Flow and Interactions

### Request Flow Architecture

```mermaid
flowchart TD
    START([User Input]) --> CAPTURE[Capture IRC Message<br/>Epic 2I]
    CAPTURE --> PARSE[Parse IRC Message]
    PARSE --> ROUTE{Route to Bot}
    
    ROUTE --> CHAT_CONTEXT[Get Full Chat Context<br/>Epic 2I: All Messages]
    CHAT_CONTEXT --> ATTACK_STAGE[Get Current Attack Stage]
    
    ATTACK_STAGE --> CHECK_VM_CONTEXT{Attack has<br/>vm_context?}
    CHECK_VM_CONTEXT -->|Yes| FETCH_VM[Fetch VM Context<br/>Epic 4: SSH Operations]
    CHECK_VM_CONTEXT -->|No| CHECK_CONFIG
    
    FETCH_VM --> BASH_HIST[Bash History]
    FETCH_VM --> COMMANDS[Execute Commands]
    FETCH_VM --> FILES[Read Files]
    
    BASH_HIST --> VM_ASSEMBLE[Assemble VM Context]
    COMMANDS --> VM_ASSEMBLE
    FILES --> VM_ASSEMBLE
    
    VM_ASSEMBLE --> CHECK_CONFIG
    CHECK_VM_CONTEXT -->|No| CHECK_CONFIG
    
    ATTACK_STAGE --> CHECK_CONFIG{Attack has<br/>context_config?}
    CHECK_CONFIG -->|Yes| EXPLICIT[Explicit Knowledge Retrieval<br/>Epic 3: Identifier-Based]
    CHECK_CONFIG -->|No| RAG_ONLY[RAG Similarity Search]
    
    EXPLICIT --> MAN_PAGES[Man Pages by Name]
    EXPLICIT --> DOCS[Documents by Path]
    EXPLICIT --> MITRE[MITRE Techniques by ID]
    
    MAN_PAGES --> COMBINE[Combine Knowledge Context]
    DOCS --> COMBINE
    MITRE --> COMBINE
    RAG_ONLY --> COMBINE
    
    COMBINE --> ENHANCE[Format Enhanced Context<br/>with Source Attribution]
    ENHANCE --> PROMPT[Assemble Prompt<br/>Chat + VM + Knowledge]
    PROMPT --> LLM[LLM Provider]
    LLM --> RESPONSE[Generate Response]
    RESPONSE --> STORE[Store in Message History<br/>Epic 2I: Comprehensive]
    STORE --> REPLY[Send IRC Reply]
    REPLY --> END([Complete])
    
    subgraph "Configuration"
        CONFIG[XML Config]
        ENV[Environment]
        CONFIG --> ROUTE
        CONFIG --> EXPLICIT
        CONFIG --> FETCH_VM
        ENV --> LLM
    end
```

### Data Models

#### Bot Configuration Model
```xml
<hackerbot>
  <name>Bot Name</name>
  <llm_provider>ollama</llm_provider>
  <ollama_model>gemma3:1b</ollama_model>
  <rag_cag_enabled>true</rag_cag_enabled>
  <attacks>
    <attack>
      <prompt>Attack scenario description</prompt>
      <get_shell>Command to execute</get_shell>
      <quiz>
        <question>Quiz question</question>
        <answer>Correct answer</answer>
      </quiz>
    </attack>
  </attacks>
  <personalities>
    <personality>
      <name>personality_name</name>
      <system_prompt>Custom prompt</system_prompt>
    </personality>
  </personalities>
</hackerbot>
```

#### Knowledge Enhancement Model
```ruby
# Enhanced context structure (RAG-only, Epic 3: Stage-aware, Epic 4: VM context)
{
  query: "user question",
  rag_context: "retrieved documents",
  explicit_context: {
    man_pages: [{"nmap" => "content..."}],
    documents: [{"attack-guide.md" => "content..."}],
    mitre_techniques: [{"T1003" => "content..."}]
  },
  vm_context: "VM State:\nBash History:\n...\nCommand Outputs:\n...\nFiles:\n...", # Epic 4
  combined_context: "merged enhanced context with source attribution",
  metadata: {
    sources: ["mitre_attack", "documentation", "man_pages"],
    retrieval_method: "explicit_hybrid", # or "explicit_only", "similarity_only"
    chat_context: "full conversation history" # Epic 2I: complete IRC messages
  }
}
```

#### Chat History Model (Epic 2I: Full IRC Context)
```ruby
# Comprehensive message history structure
{
  messages: [
    {
      user: "alice",
      content: "How do I use nmap?",
      timestamp: "2025-01-18T10:00:00Z",
      type: :user_message,
      channel: "#hackerbot"
    },
    {
      user: "bot",
      content: "Here's how to use nmap...",
      timestamp: "2025-01-18T10:00:02Z",
      type: :bot_llm_response,
      channel: "#hackerbot"
    }
  ],
  storage_mode: :per_user, # or :per_channel
  max_length: 20
}
```

---

## Technology Stack

### Core Technologies

| Layer | Technology | Version | Purpose |
|-------|------------|---------|---------|
| **Language** | Ruby | 3.1+ | Primary implementation language |
| **IRC Framework** | ircinch | Latest | IRC protocol handling |
| **XML Processing** | nokogiri | Latest | Configuration parsing |
| **Data Serialization** | nori | Latest | XML to Ruby conversion |
| **HTTP Client** | httparty | Latest | API communication |

### AI and Knowledge Technologies

| Component | Technology | Purpose |
|-----------|------------|---------|
| **LLM Providers** | Ollama, OpenAI, VLLM, SGLang | AI response generation |
| **Vector Database** | ChromaDB | Document similarity search |
| **Knowledge Graph** | In-memory Ruby implementation | Entity relationship mapping |
| **Embeddings** | Ollama nomic-embed-text | Document vectorization |

### Development Environment

| Tool | Technology | Purpose |
|------|------------|---------|
| **Package Manager** | Nix Flakes | Reproducible environments |
| **Build System** | Make | Development automation |
| **IRC Server** | Python custom implementation | Testing environment |
| **Version Control** | Git | Source code management |

### Integration Technologies

| Platform | Integration Method |
|----------|-------------------|
| **MITRE ATT&CK** | Ruby knowledge base integration |
| **Man Pages** | Unix system integration |
| **Documentation** | Markdown file processing |
| **Configuration** | XML schema validation |

---

## Deployment Architecture

### Environment Architecture

```mermaid
graph TB
    subgraph "Development Environment"
        NIX_DEV[Nix Development Environment]
        LOCAL_IRC[Local IRC Server<br/>Port 6667]
        DEV_BOTS[Development Bot Instances]
    end
    
    subgraph "Training Environment"
        AIR_GAPPED[Air-Gapped Network]
        LOCAL_LLM[Local LLM Instances<br/>Ollama]
        OFFLINE_KB[Offline Knowledge Bases]
        TRAINING_BOTS[Training Bot Instances]
    end
    
    subgraph "Production Environment"
        SECURE_NETWORK[Secure Network]
        CLUSTER_LLM[LLM Cluster]
        DISTRIBUTED_KB[Distributed Knowledge]
        PROD_BOTS[Production Bot Instances]
    end
    
    NIX_DEV --> LOCAL_IRC
    LOCAL_IRC --> DEV_BOTS
    
    AIR_GAPPED --> LOCAL_LLM
    LOCAL_LLM --> OFFLINE_KB
    OFFLINE_KB --> TRAINING_BOTS
    
    SECURE_NETWORK --> CLUSTER_LLM
    CLUSTER_LLM --> DISTRIBUTED_KB
    DISTRIBUTED_KB --> PROD_BOTS
```

### Deployment Models

#### 1. Development Deployment
- **Environment**: Local Nix development environment
- **IRC Server**: Python implementation on localhost:6667
- **LLM Providers**: Local Ollama instance
- **Knowledge**: Local ChromaDB and in-memory graphs

#### 2. Training Environment Deployment
- **Network**: Air-gapped or isolated network
- **LLM**: Local Ollama or pre-downloaded models
- **Knowledge**: Pre-populated offline knowledge bases
- **Configuration**: Custom XML scenarios per training exercise

#### 3. Production Deployment
- **Infrastructure**: Containerized or VM-based deployment
- **LLM**: Clustered Ollama or mixed provider setup
- **Knowledge**: Distributed ChromaDB cluster
- **Monitoring**: Logging and metrics collection

### Configuration Management

#### Environment Variables
```bash
# Core Configuration
RUBYOPT="-KU -E utf-8:utf-8"
IRCD_PORT="6667"
IRCD_HOST="localhost"

# LLM Provider Configuration
OLLAMA_HOST="localhost"
OLLAMA_PORT="11434"
OPENAI_API_KEY="your-key"
VLLM_HOST="localhost"
VLLM_PORT="8000"

# RAG Configuration
ENABLE_RAG="true"
OFFLINE_MODE="auto"
```

#### XML Configuration Structure
```xml
<!-- Bot Configuration -->
<hackerbot>
  <name>training_bot</name>
  <llm_provider>ollama</llm_provider>
  <ollama_model>llama2:7b</ollama_model>
  <rag_enabled>true</rag_enabled>
  
  <!-- Message History Configuration (Epic 2I) -->
  <max_history_length>10</max_history_length>
  <max_irc_message_history>20</max_irc_message_history>
  <message_type_filter>
    <type>user_message</type>
    <type>bot_llm_response</type>
    <type>bot_command_response</type>
  </message_type_filter>
  
  <!-- Knowledge Sources -->
  <knowledge_sources>
    <source>
      <type>mitre_attack</type>
      <name>mitre_attack</name>
      <enabled>true</enabled>
      <priority>1</priority>
    </source>
  </knowledge_sources>
  
  <!-- Training Scenarios -->
  <attacks>
    <attack>
      <name>reconnaissance</name>
      <prompt>Perform reconnaissance on target system</prompt>
      <get_shell>nmap -sV {{chat_ip_address}}</get_shell>
      
      <!-- Stage-Aware Context Configuration (Epic 3) -->
      <context_config>
        <man_pages>nmap,netcat</man_pages>
        <documents>attack-guide.md</documents>
        <mitre_techniques>T1595.001,T1046</mitre_techniques>
        <combination_mode>explicit_hybrid</combination_mode>
      </context_config>
      
      <!-- VM Context Fetching Configuration (Epic 4) -->
      <vm_context>
        <bash_history path="~/.bash_history" limit="50" user="student"/>
        <commands>
          <command>ps aux</command>
          <command>netstat -tuln</command>
          <command>whoami</command>
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

---

## Security Architecture

### Threat Model

#### Security Boundaries
```mermaid
graph TB
    subgraph "Trusted Zone"
        HACKERBOT[Hackerbot Application]
        LOCAL_LLM[Local LLM Instances]
        LOCAL_KB[Local Knowledge Bases]
    end
    
    subgraph "Semi-Trusted Zone"
        IRC_NETWORK[IRC Network]
        TRAINING_ENV[Training Environment]
    end
    
    subgraph "Untrusted Zone"
        EXTERNAL_API[External APIs<br/>Optional]
        INTERNET[Internet<br/>Optional]
    end
    
    HACKERBOT -.->|Controlled| IRC_NETWORK
    LOCAL_LLM -.->|No Access| EXTERNAL_API
    LOCAL_KB -.->|No Access| INTERNET
    IRC_NETWORK --> TRAINING_ENV
```

### Security Controls

#### 1. Network Security
- **Air-Gapped Operation**: Complete functionality without internet connectivity
- **Local Services**: All critical services run locally
- **Controlled Connections**: Optional external API connections with explicit configuration
- **IRC Isolation**: Dedicated IRC server for training environments

#### 2. Data Protection
- **Local Storage**: All data stored locally with user-controlled access
- **No Telemetry**: No data transmission to external services by default
- **Configurable Privacy**: User control over data sharing and logging
- **Secure Configuration**: Sensitive configuration through environment variables

#### 3. Application Security
- **Input Validation**: Comprehensive validation of IRC messages and configuration
- **Command Sanitization**: Safe execution of system commands with parameter validation
- **Privilege Separation**: Minimal privileges required for operation
- **Error Handling**: Secure error handling without information disclosure

#### 4. AI Security
- **Prompt Injection Protection**: Input sanitization for AI prompts
- **Context Isolation**: Separation of user contexts and chat histories
- **Provider Abstraction**: Secure integration with multiple AI providers
- **Response Filtering**: Output filtering for malicious content

### Compliance Considerations

#### Data Privacy
- **GDPR Compliance**: No personal data collection without explicit consent
- **Data Minimization**: Only necessary data collected and processed
- **User Control**: Complete user control over data storage and deletion
- **Transparency**: Clear documentation of data usage and storage

#### Educational Compliance
- **Accessibility**: Support for diverse learning needs
- **Content Standards**: Appropriate content for educational environments
- **Assessment Integrity**: Secure quiz and assessment mechanisms
- **Progress Tracking**: Privacy-respecting progress monitoring

---

## Performance and Scalability

### Performance Characteristics

#### Current Performance Metrics
| Metric | Target | Current | Notes |
|--------|--------|---------|-------|
| **Response Time** | <5 seconds | 2-3 seconds | AI generation time |
| **IRC Latency** | <100ms | <50ms | Local IRC server |
| **Knowledge Retrieval** | <2 seconds | 0.5-1 second | RAG processing |
| **Memory Usage** | <4GB | 1-2GB | Typical knowledge base |
| **Concurrent Users** | 50+ | 20+ tested | Per bot instance |

#### Performance Optimization Strategies

##### 1. AI Response Optimization
- **Streaming Responses**: Real-time response streaming for better UX
- **Context Caching**: Cached enhanced contexts for common queries
- **Model Selection**: Optimal model sizing for performance vs quality
- **Parallel Processing**: Efficient knowledge retrieval and context assembly

##### 2. Knowledge System Optimization
- **Vector Index Optimization**: Efficient ChromaDB indexing strategies
- **Identifier-Based Lookup Caching**: Cache frequently accessed knowledge items by identifier
- **Lazy Loading**: On-demand knowledge source loading
- **Compression**: Knowledge base compression for memory efficiency

##### 3. IRC Performance
- **Connection Pooling**: Efficient IRC connection management
- **Message Queuing**: Buffered message handling for high throughput
- **Event Optimization**: Efficient IRC event processing
- **Resource Management**: Memory and connection cleanup

### Scalability Architecture

#### Horizontal Scaling
```mermaid
graph TB
    subgraph "Load Balancer"
        LB[IRC Load Balancer]
    end
    
    subgraph "Bot Cluster"
        BOT1[Bot Instance 1]
        BOT2[Bot Instance 2]
        BOT3[Bot Instance N]
    end
    
    subgraph "AI Cluster"
        LLM1[LLM Instance 1]
        LLM2[LLM Instance 2]
        LLM3[LLM Instance N]
    end
    
    subgraph "Knowledge Cluster"
        KB1[Knowledge Base 1]
        KB2[Knowledge Base 2]
        KB3[Knowledge Base N]
    end
    
    LB --> BOT1
    LB --> BOT2
    LB --> BOT3
    
    BOT1 --> LLM1
    BOT2 --> LLM2
    BOT3 --> LLM3
    
    LLM1 --> KB1
    LLM2 --> KB2
    LLM3 --> KB3
```

#### Scaling Limitations and Solutions

| Limitation | Current Limitation | Scaling Solution |
|------------|-------------------|------------------|
| **Memory Usage** | 4GB per instance | Distributed knowledge graphs |
| **LLM Throughput** | 1 request/second | LLM clustering and load balancing |
| **IRC Connections** | 100 per instance | Connection pooling and distribution |
| **Knowledge Base Size** | 10GB vectors | Sharded vector databases |

### Performance Monitoring

#### Metrics Collection
- **Response Time Metrics**: AI generation, knowledge retrieval, total response time
- **Resource Usage**: CPU, memory, disk usage per component
- **IRC Metrics**: Message throughput, connection counts, error rates
- **Knowledge Metrics**: Retrieval accuracy, cache hit rates, index sizes

#### Monitoring Tools
- **Application Logging**: Structured logging with performance data
- **Health Checks**: Component health monitoring
- **Performance Profiling**: Ruby profiling for optimization
- **Resource Monitoring**: System resource tracking

---

## Integration Points

### External System Integrations

#### 1. LLM Provider Integrations
```mermaid
graph LR
    subgraph "Hackerbot"
        LLM_FACTORY[LLM Factory]
    end
    
    subgraph "LLM Providers"
        OLLAMA[Ollama<br/>Local Models]
        OPENAI[OpenAI<br/>GPT Models]
        VLLM[VLLM<br/>Serving Framework]
        SGLANG[SGLang<br/>Language Models]
    end
    
    LLM_FACTORY --> OLLAMA
    LLM_FACTORY --> OPENAI
    LLM_FACTORY --> VLLM
    LLM_FACTORY --> SGLANG
```

**Integration Patterns:**
- **Common Interface**: Standardized API across all providers
- **Configuration-Driven**: Runtime provider selection
- **Fallback Support**: Automatic provider failover
- **Streaming Support**: Real-time response streaming

#### 2. Knowledge Source Integrations
```mermaid
graph TB
    subgraph "Knowledge Sources"
        MITRE[MITRE ATT&CK<br/>Framework]
        DOCS[Project<br/>Documentation]
        MAN_PAGES[Unix/Linux<br/>Man Pages]
        CUSTOM[Custom<br/>Knowledge]
    end
    
    subgraph "Knowledge Processing"
        RAG[RAG System<br/>Vector Database<br/>+ Identifier Lookups]
    end
    
    MITRE --> RAG
    DOCS --> RAG
    MAN_PAGES --> RAG
    CUSTOM --> RAG
```

#### 3. Development Environment Integrations
- **Nix Integration**: Reproducible development environments
- **Git Integration**: Version control and configuration management
- **Testing Framework**: Automated testing integration
- **Documentation System**: Integrated documentation generation

### API Interfaces

#### Internal APIs
```ruby
# LLM Provider Interface
class LLMClient
  def generate_response(prompt, stream_callback = nil)
  def test_connection
  def update_system_prompt(prompt)
end

# Knowledge Enhancement Interface
class RAGManager
  def get_enhanced_context(query, options = {})
  def get_explicit_context(explicit_items, options = {})
  def add_custom_knowledge(collection, documents)
  def similarity_search(query, limit = 5)
end

# VM Context Interface (Epic 4)
class VMContextManager
  def execute_command(ssh_config, command, variables = {})
  def read_file(ssh_config, file_path, variables = {})
  def read_bash_history(ssh_config, user = nil, limit = nil, variables = {})
end

# Bot Management Interface
class BotManager
  def create_bot(name, config)
  def start_bots
  def get_chat_context(bot_name, user_id)
end
```

#### Configuration APIs
- **XML Configuration**: Structured bot and scenario configuration
- **Environment Variables**: Runtime configuration and secrets
- **Command Line**: Interactive configuration and control

### Extension Points

#### 1. Custom LLM Providers
```ruby
# Provider Implementation Template
class CustomLLMClient < LLMClient
  def initialize(config)
    # Custom initialization
  end
  
  def generate_response(prompt, stream_callback = nil)
    # Custom implementation
  end
end
```

#### 2. Custom Knowledge Sources
```ruby
# Knowledge Source Template
class CustomKnowledgeSource < BaseKnowledgeSource
  def load_knowledge
    # Custom knowledge loading
  end
  
  def to_rag_documents
    # Convert to RAG format
  end
  
  def to_cag_triplets
    # Convert to CAG format
  end
end
```

#### 3. Custom Bot Personalities
```xml
<personality>
  <name>security_expert</name>
  <title>Cybersecurity Expert</title>
  <description>Professional security analyst personality</description>
  <system_prompt>You are a cybersecurity expert...</system_prompt>
  <messages>
    <greeting>Hello! I'm here to help with cybersecurity training.</greeting>
    <help>Available commands: hello, help, next, previous, list, ready</help>
  </messages>
</personality>
```

---

## Future Evolution

### Short-term Roadmap (0-6 months)

#### Completed Enhancements ✅
- **Epic 1 - RAG System Validation**: Comprehensive RAG test suite with ≥80% coverage, performance validation, RAG-only architectural decision
- **Epic 2I - Full IRC Context Integration**: Complete message capture, enhanced chat history structure, full conversation context in LLM prompts
- **Epic 3 - Stage-Aware Context Injection**: Per-attack explicit knowledge selection, identifier-based lookups, configurable context formatting
- **Epic 4 - VM Context Fetching**: SSH-based runtime state retrieval from student machines (bash history, command outputs, files) with per-attack configuration

#### Current Enhancements
- **Performance Optimization**: Ongoing response time improvements
- **Testing Infrastructure**: Expansion of automated test suite coverage
- **Documentation Enhancement**: Complete API documentation and guides
- **Enhanced Personality System**: More sophisticated bot personalities
- **Advanced Scenarios**: Complex multi-step attack scenarios
- **Progress Tracking**: Detailed learning progress analytics
- **Multi-Language Support**: Internationalization framework

#### Platform Expansion
- **Additional LLM Providers**: Support for emerging AI models
- **Enhanced Knowledge Sources**: Integration with more security frameworks
- **Web Interface**: Optional web-based training interface
- **Mobile Support**: Mobile-friendly training access

### Medium-term Roadmap (6-18 months)

#### Architecture Evolution
- **Microservices Transition**: Optional microservices architecture for large deployments
- **Cloud Integration**: Hybrid cloud deployment capabilities
- **Advanced Analytics**: Learning analytics and performance metrics
- **AI Collaboration**: Multi-agent training scenarios

#### Advanced Features
- **Adaptive Learning**: AI-powered personalized learning paths
- **Real-time Collaboration**: Multi-user training scenarios
- **Advanced Assessment**: Automated skill assessment and certification
- **Integration Platform**: Enterprise system integration capabilities

#### Ecosystem Development
- **Plugin Marketplace**: Community-driven plugin ecosystem
- **Training Content Library**: Comprehensive scenario library
- **Professional Services**: Training and consulting services
- **Community Platform**: User community and knowledge sharing

### Long-term Vision (18+ months)

#### Strategic Initiatives
- **AI Leadership**: Become the leading AI-powered cybersecurity training platform
- **Standardization**: Industry standard for immersive security training
- **Global Expansion**: International market expansion and localization
- **Research Partnership**: Academic and industry research collaborations

#### Technology Evolution
- **Advanced AI Integration**: Next-generation AI capabilities
- **Immersive Technologies**: VR/AR training environments
- **Quantum-Ready**: Preparation for quantum computing era
- **Autonomous Training**: Self-improving training systems

#### Market Leadership
- **Enterprise Platform**: Complete enterprise training solution
- **Government Partnerships**: Government and military training contracts
- **Educational Integration**: Integration with academic curricula
- **Certification Authority**: Industry-recognized certification programs

---

## Conclusion

The Hackerbot system architecture represents a sophisticated approach to AI-powered cybersecurity training, combining the proven effectiveness of interactive chat interfaces with advanced AI capabilities and comprehensive knowledge integration. The modular, plugin-based architecture provides flexibility and extensibility while maintaining security and performance.

### Key Architectural Strengths

1. **Modular Design**: Clear separation of concerns enabling independent development and testing
2. **Multi-Provider AI Support**: Flexibility in LLM provider selection and configuration
3. **RAG Knowledge System**: Validated and optimized vector-based knowledge retrieval system
4. **Full Conversation Context**: Comprehensive IRC message capture providing complete conversation history to LLM
5. **Stage-Aware Context Injection**: Precise control over knowledge sources per attack stage
6. **VM Context Awareness**: Runtime state retrieval from student machines providing real-time system context
7. **Offline-First Operation**: Complete functionality in secure, isolated environments
8. **Extensible Plugin Architecture**: Easy addition of new providers, knowledge sources, and features
9. **Security-Focused Design**: Built for the unique requirements of cybersecurity training

### Strategic Position

Hackerbot is well-positioned to become a leading platform in the cybersecurity training market, offering unique capabilities in AI-powered interactive learning with strong security and privacy features. The architecture supports both individual learners and enterprise deployments while maintaining the flexibility to adapt to evolving technologies and requirements.

### Future Success Factors

- **Continued AI Integration**: Staying current with rapidly evolving AI capabilities
- **Community Engagement**: Building a vibrant community of contributors and users
- **Educational Partnerships**: Integration with academic and training institutions
- **Enterprise Features**: Development of enterprise-grade capabilities and support
- **Security Leadership**: Maintaining leadership in security-focused training solutions

The architecture provides a solid foundation for continued growth and evolution, enabling Hackerbot to meet the current and future needs of cybersecurity education and training while maintaining the highest standards of security, privacy, and educational effectiveness.