# Hackerbot RAG System Brownfield Architecture Document

## Introduction

This document captures the CURRENT STATE of the Hackerbot cybersecurity training framework, focusing specifically on its RAG (Retrieval-Augmented Generation) knowledge enhancement system. The previous CAG (Context-Aware Generation) implementation has been removed as it was not functional. This serves as a reference for AI agents working on enhancements and understanding the existing implementation.

### Document Scope

Comprehensive documentation of the RAG system, including technical debt, actual patterns used, and integration dependencies.

### Change Log

| Date   | Version | Description                 | Author    |
| ------ | ------- | --------------------------- | --------- |
| 2025-10-22 | 1.0     | Initial brownfield analysis | Winston (Architect) |
| 2025-10-22 | 1.1     | Removed non-functional CAG system | Winston (Architect) |

## Quick Reference - Key Files and Entry Points

### Critical Files for Understanding the RAG System

- **Main Entry**: `hackerbot.rb` (CLI entry point and configuration)
- **RAG Manager**: `rag_manager.rb` (RAG operations coordinator)
- **RAG Manager**: `rag/rag_manager.rb` (Document retrieval and vector search)

- **Knowledge Source Manager**: `knowledge_bases/knowledge_source_manager.rb` (Multi-source knowledge coordination)
- **LLM Integration**: `providers/llm_client.rb` and factory pattern
- **Configuration**: XML files in `config/` directory
- **Knowledge Sources**: `knowledge_bases/sources/` (man pages, markdown files, MITRE ATT&CK)

## High Level Architecture

### Technical Summary

The Hackerbot framework is a Ruby-based IRC bot system that provides cybersecurity training through AI-powered conversations enhanced with domain-specific knowledge retrieval. It operates both online and offline, making it suitable for air-gapped environments.

### Actual Tech Stack (from Gemfile and dependencies)

| Category  | Technology | Version | Notes                      |
| --------- | ---------- | ------- | -------------------------- |
| Runtime   | Ruby | 2.7+ | Base runtime requirement   |
| Framework | ircinch | ~2.0 | IRC client framework       |
| XML Parsing | nokogiri | ~1.15 | Configuration parsing      |
| HTTP | httparty | ~0.21 | External API calls         |
| JSON | json | ~2.7 | Data serialization         |
| Markdown | kramdown | ~2.4 | Markdown processing        |
| LLM Providers | Multiple | - | Ollama, OpenAI, VLLM, SGLang |
| Vector DB | ChromaDB | - | Document embeddings storage |
| Graph DB | In-memory | - | Knowledge graph operations  |

### Repository Structure Reality Check

- Type: Monolithic Ruby application with modular components
- Package Manager: RubyGems (gem)
- Notable: Heavy use of configuration files, offline-first design, multiple client implementations

## Source Tree and Module Organization

### Project Structure (Actual)

```text
hackerbot/
├── hackerbot.rb                    # Main CLI entry point
├── rag_manager.rb                 # RAG operations coordinator
├── bot_manager.rb                 # Bot instance management
├── rag/                            # Retrieval-Augmented Generation
│   ├── rag_manager.rb            # RAG operations coordinator
│   ├── chromadb_client.rb         # ChromaDB network client
│   ├── chromadb_offline_client.rb # ChromaDB file-based client
│   ├── ollama_embedding_client.rb # Ollama embeddings
│   └── ollama_embedding_offline_client.rb # Offline embeddings
├── cag/                            # Context-Aware Generation
│   ├── cag_manager.rb            # Knowledge graph operations
│   ├── in_memory_graph_client.rb # Graph DB network client
│   └── in_memory_graph_offline_client.rb # File-based graph
├── providers/                      # LLM provider implementations
│   ├── llm_client.rb             # Base LLM interface
│   ├── llm_client_factory.rb     # Provider factory pattern
│   ├── ollama_client.rb          # Ollama provider
│   ├── openai_client.rb          # OpenAI provider
│   └── vllm_client.rb            # VLLM provider
├── knowledge_bases/               # Knowledge management
│   ├── knowledge_source_manager.rb # Multi-source coordinator
│   ├── mitre_attack_knowledge.rb   # MITRE ATT&CK framework data
│   └── sources/                   # Knowledge source implementations
│       ├── man_pages/             # Unix manual pages
│       └── markdown_files/       # Markdown document processing
├── config/                         # XML bot configurations
└── docs/                          # Documentation
```

### Key Modules and Their Purpose

- **RAG Manager** (`rag_manager.rb`) - Coordinates document retrieval and knowledge enhancement
- **RAG Manager** (`rag/rag_manager.rb`) - Handles document retrieval, vector search, and embedding generation

- **Knowledge Source Manager** (`knowledge_bases/knowledge_source_manager.rb`) - Abstracts multiple knowledge sources (man pages, markdown files, MITRE ATT&CK)
- **LLM Client Factory** (`providers/llm_client_factory.rb`) - Creates appropriate LLM clients based on configuration
- **MITRE Attack Knowledge** (`knowledge_bases/mitre_attack_knowledge.rb`) - Hardcoded cybersecurity knowledge base

## RAG System Implementation Details

### RAG Architecture Pattern

The system uses a **dual-phase RAG architecture**:

1. **Offline Knowledge Preparation**: Documents are pre-processed and embedded into vector storage
2. **Online Retrieval**: Real-time semantic search to find relevant knowledge for user queries

### Core RAG Components

#### Vector Database Implementation
- **Primary**: ChromaDB client (`rag/chromadb_client.rb`)
- **Offline**: File-based ChromaDB client (`rag/chromadb_offline_client.rb`)
- **Storage**: Local file system in `knowledge_bases/offline/vector_db/`
- **Collections**: Named collections for different knowledge bases
- **Persistence**: Embeddings can be cached to disk for faster startup

#### Embedding Services
- **Ollama Embeddings** (`rag/ollama_embedding_client.rb`) - Local embedding generation
- **OpenAI Embeddings** (`rag/openai_embedding_client.rb`) - Cloud-based embeddings
- **Offline Mode** (`rag/ollama_embedding_offline_client.rb`) - Cached embeddings for air-gapped use

#### Document Processing
- **Chunking**: Configurable chunk size (default 1000 chars) with overlap (200 chars)
- **Sources**: Man pages, markdown files, hardcoded cybersecurity knowledge
- **Metadata**: Document source, type, and relevance scores
- **Caching**: Optional query result caching

### RAG Query Flow

```
User Query → RAG Manager → Embedding Service → Vector Database → Document Retrieval → Context Enhancement → LLM Response
```

1. Query is embedded into vector representation
2. Semantic similarity search performed against vector database
3. Top-N relevant documents retrieved (default max 5 results)
4. Documents are formatted and combined with original query
5. Enhanced context is passed to LLM for response generation

## CAG System Implementation Details

### CAG Architecture Pattern

The CAG system implements **knowledge graph-based entity recognition and relationship mapping**:

1. **Entity Extraction**: Identify entities from user queries and retrieved documents
2. **Graph Traversal**: Navigate entity relationships to find related concepts
3. **Context Expansion**: Generate additional context based on graph connections

### Core CAG Components

#### Knowledge Graph Implementation
- **Primary**: In-memory graph client (`cag/in_memory_graph_client.rb`)
- **Offline**: File-based persistent graph (`cag/in_memory_graph_offline_client.rb`)
- **Storage**: JSON-based serialization in `knowledge_bases/offline/`
- **Nodes**: Entities (attack patterns, tools, techniques, mitigations)
- **Edges**: Relationships (uses, mitigates, related-to)

#### Entity Processing
- **Extraction**: Rule-based entity identification from text
- **Normalization**: Standardized entity names and identifiers
- **Relationship Mapping**: Predefined relationships between cybersecurity concepts

### CAG Query Flow

```
User Query → Entity Extraction → Graph Traversal → Related Entities → Context Expansion → Enhanced Response
```

## Integration Points and External Dependencies

### External Services

| Service  | Purpose  | Integration Type | Key Files                      |
| -------- | -------- | ---------------- | ------------------------------ |
| Ollama   | LLM + Embeddings | HTTP API | `providers/ollama_client.rb`, `rag/ollama_embedding_client.rb` |
| OpenAI   | LLM + Embeddings | HTTP API | `providers/openai_client.rb`, `rag/openai_embedding_client.rb` |
| VLLM     | LLM Host | HTTP API | `providers/vllm_client.rb` |
| SGLang   | LLM Host | HTTP API | `providers/sglang_client.rb` |
| ChromaDB | Vector Database | HTTP/File | `rag/chromadb_client.rb`, `rag/chromadb_offline_client.rb` |

### Internal Integration Points

- **Bot Manager ↔ RAG Manager**: Bot instances request knowledge enhancement
- **Knowledge Source Manager → RAG**: Provides pre-processed knowledge
- **LLM Client Factory → Bot Instances**: Provider abstraction and connection management

### Knowledge Dependencies

#### MITRE ATT&CK Framework
- **Source**: Hardcoded in `knowledge_bases/mitre_attack_knowledge.rb`
- **Content**: Attack patterns, techniques, tactics, tools, mitigations
- **Structure**: JSON-like Ruby data structures with hierarchical relationships
- **Usage**: Primary knowledge source for cybersecurity training scenarios

#### Unix Manual Pages
- **Source**: System man pages via `knowledge_bases/sources/man_pages/`
- **Processing**: Text extraction and chunking
- **Purpose**: Command-line tool knowledge for cybersecurity scenarios
- **Integration**: Converted to RAG documents with tool metadata

#### Markdown Documentation
- **Source**: Custom markdown files in `knowledge_bases/sources/markdown_files/`
- **Processing**: Kramdown parsing for structured content extraction
- **Purpose**: Additional knowledge sources and training materials
- **Integration**: Supports embedded metadata and categorization

## Development and Deployment

### Local Development Setup

```bash
# Install Ruby dependencies
bundle install

# Start Ollama (local LLM provider)
ollama serve
ollama pull gemma3:1b

# Run with RAG enabled
ruby hackerbot.rb --enable-rag-cag --ollama-model gemma3:1b

# Force offline mode (air-gapped)
ruby hackerbot.rb --offline --enable-rag-cag
```

### Configuration Reality

**Critical Configuration Files**:
- `config/` - XML-based bot configurations
- Knowledge bases configured per-bot in XML
- RAG settings controlled via command-line flags

**Configuration Gotchas**:
- Knowledge base initialization is automatic by default
- Offline mode requires pre-populated knowledge files

- Vector embeddings are cached locally for performance

### Build and Deployment Process

- **Build**: No compilation step (Ruby interpreted)
- **Deployment**: Direct file deployment or gem packaging
- **Dependencies**: RubyGems, system manual pages (for knowledge extraction)
- **Environments**: Development, staging, production (via config files)

## Technical Debt and Known Issues

### Critical Technical Debt

1. **Hardcoded Knowledge Base** (`knowledge_bases/mitre_attack_knowledge.rb`)
   - MITRE ATT&CK data is embedded in Ruby code
   - Cannot be updated without code changes
   - Should be externalized to JSON/XML files

2. **Multiple Client Implementations**
   - Separate network and offline clients for each service
   - Duplicated functionality across `*_client.rb` and `*_offline_client.rb`
   - Should use adapter pattern with shared interface

3. **Inconsistent Error Handling**
   - Some methods return boolean, others raise exceptions
   - Mixed logging approaches across components
   - No standardized error recovery mechanisms

4. **Configuration Scattered Across Multiple Systems**
   - XML config for bots, Ruby hashes for internal services
   - No unified configuration management
   - Command-line flags override embedded settings

### Performance Bottlenecks

1. **Embedding Generation**
   - No batch processing for large document sets
   - Synchronous embedding generation blocks operations
   - Missing embedding caching strategies

2. **Knowledge Graph Traversal**
   - In-memory graph can grow large with complex knowledge bases
   - No query optimization or indexing
   - Recursive traversal without depth limits in some cases

3. **File I/O Operations**
   - Synchronous file operations for offline storage
   - No background processing for knowledge updates
   - Potential race conditions in concurrent access

### Workarounds and Gotchas

- **Knowledge Initialization**: Must wait for full knowledge base loading before bot responses
- **Memory Usage**: RAG + large knowledge bases require 2GB+ RAM
- **Offline Mode**: Requires pre-generated embeddings and graph files
- **Service Dependencies**: External LLM services have rate limits and latency
- **IRC Integration**: Limited concurrency due to single-threaded IRC client

## Testing Reality

### Current Test Coverage

- **Unit Tests**: Comprehensive test suite in `test/` directory
- **Integration Tests**: Limited, mainly for LLM client connectivity
- **RAG Tests**: Basic functionality verification
- **Performance Tests**: No automated performance regression testing

### Running Tests

```bash
# Run comprehensive test suite
ruby test_all.rb

# Run specific RAG tests
ruby test_rag_cag.rb

# Test knowledge base population
ruby test_knowledge_population.rb
```

### Known Testing Limitations

- Mock-heavy tests for external services
- No end-to-end testing with real LLM providers
- Limited testing of offline functionality
- No load testing for concurrent bot instances

## System Performance Characteristics

### Resource Requirements

- **Memory**: 1GB minimum, 2GB+ recommended for RAG
- **Storage**: 500MB base + 100MB per knowledge base
- **Network**: Optional (offline mode eliminates network dependency)
- **CPU**: Moderate during embedding generation, low during operation

### Performance Optimizations

- **Streaming Responses**: Real-time line-by-line output
- **RAG Optimization**: Configurable result limits and similarity thresholds
- **Embedding Caching**: Persistent cache reduces startup time
- **Offline Mode**: Eliminates network latency for air-gapped deployment

### Scaling Considerations

- **Single Process**: Currently designed for single-machine deployment
- **Knowledge Base Limits**: Memory-bound for large document sets
- **Concurrent Users**: Limited by IRC client and single-threaded design
- **Horizontal Scaling**: Not implemented (would require Redis/database coordination)

## Security Considerations

### Data Privacy Controls

- **Local Processing**: Ollama provides on-device AI processing
- **Offline Operation**: Complete air-gapped deployment capability
- **Knowledge Base Control**: Administrators control all knowledge sources
- **Chat History**: Isolated per user, stored in memory only

### API Security

- **Key Management**: API keys stored in environment variables or config files
- **Rate Limiting**: Basic rate limiting for external API calls
- **Fallback Behavior**: Graceful degradation when external services unavailable
- **Input Validation**: Limited validation on user inputs and knowledge source content

## Operational Considerations

### Monitoring and Observability

- **Logging**: Comprehensive logging via `print.rb` utility
- **Debug Mode**: Verbose logging for troubleshooting
- **Health Checks**: Basic connectivity checks for external services
- **Performance Metrics**: Basic timing and usage statistics

### Maintenance Requirements

- **Knowledge Base Updates**: Manual updates for MITRE ATT&CK data
- **Dependency Updates**: Regular RubyGems updates
- **Configuration Management**: XML configuration file maintenance
- **Cache Management**: Periodic cache clearing for stale data

### Disaster Recovery

- **Backup Strategy**: File-based backup for knowledge bases and configurations
- **Failover**: Manual failover between online/offline modes
- **Data Loss Prevention**: Persistent storage for embeddings and knowledge graphs
- **Recovery Time**: Full system recovery possible from file backups

## Appendix - Useful Commands and Scripts

### Frequently Used Commands

```bash
# Start with different LLM providers
ruby hackerbot.rb --ollama-host localhost --ollama-port 11434
ruby hackerbot.rb --llm-provider openai --openai-api-key $KEY
ruby hackerbot.rb --llm-provider vllm --openai-base-url http://localhost:8080/v1

# RAG configuration
ruby hackerbot.rb --enable-rag-cag
ruby hackerbot.rb --enable-rag-cag
ruby hackerbot.rb --enable-rag-cag --offline

# Knowledge management
ruby update_default_knowledge_sources.rb
ruby test_knowledge_population.rb
```

### Configuration Examples

```xml
<!-- config/cybersecurity_bot.xml -->
<hackerbot>
  <name>CyberTrainerBot</name>
  <llm_provider>ollama</llm_provider>
  <ollama_model>gemma3:1b</ollama_model>
  <rag_cag_enabled>true</rag_cag_enabled>
  <system_prompt>You are a cybersecurity training assistant.</system_prompt>
</hackerbot>
```

### Debugging and Troubleshooting

- **Logs**: Check console output for detailed operation logs
- **Debug Mode**: Set `DEBUG=1` environment variable for verbose logging
- **Common Issues**:
  - ChromaDB connection failures: Check network connectivity
  - Embedding generation errors: Verify Ollama service status
  - Knowledge loading failures: Check file permissions and disk space
  - Memory issues: Reduce knowledge base size or disable RAG components