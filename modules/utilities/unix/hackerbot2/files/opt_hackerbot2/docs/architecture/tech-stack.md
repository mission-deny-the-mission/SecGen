# Hackerbot Technology Stack

<!-- Powered by BMAD™ Core -->

## Version Information
- **Document Version**: v4.0
- **Creation Date**: 2025-10-17
- **Author**: Winston (Architect)
- **Status**: Complete

## Overview

This document outlines the complete technology stack used in the Hackerbot project, including core technologies, AI frameworks, development tools, and infrastructure components.

## Core Technology Stack

### Programming Language

#### Ruby 3.1+
- **Purpose**: Primary implementation language
- **Version**: 3.1.x (stable)
- **Rationale**: 
  - Excellent IRC library support (ircinch)
  - Rapid development capabilities
  - Strong text processing and string manipulation
  - Good ecosystem for AI/ML integration
  - Easy deployment and packaging

#### Key Ruby Gems
| Gem | Version | Purpose |
|-----|---------|---------|
| `ircinch` | Latest | IRC protocol implementation |
| `nokogiri` | Latest | XML parsing and manipulation |
| `nori` | Latest | XML to Ruby object conversion |
| `httparty` | Latest | HTTP client for API communication |
| `json` | Latest | JSON serialization/deserialization |
| `timeout` | Latest | Request timeout handling |
| `thwait` | Latest | Thread management |
| `open3` | Latest | External process execution |

### Framework and Libraries

#### IRC Framework
- **ircinch**: Ruby IRC framework
- **Features**:
  - Complete IRC protocol implementation
  - Event-driven architecture
  - SSL/TLS support
  - Multiple server support
  - Plugin system for extensibility

#### XML Processing
- **nokogiri**: XML/HTML parsing library
- **nori**: XML to Ruby object conversion
- **Features**:
  - XPath and CSS selector support
  - Schema validation
  - Namespace handling
  - Performance optimization

## AI and Machine Learning Stack

### LLM Provider Integration

#### Ollama (Primary)
- **Purpose**: Local LLM serving
- **Models Supported**: Llama2, CodeLlama, Mistral, Gemma, etc.
- **Features**:
  - Local model serving
  - RESTful API
  - Model management
  - Streaming responses
  - Offline operation

#### OpenAI (Optional)
- **Purpose**: Cloud-based LLM provider
- **Models**: GPT-3.5-turbo, GPT-4, GPT-4-turbo
- **Features**:
  - High-quality responses
  - Function calling
  - Streaming support
  - Fine-tuning capabilities

#### VLLM (Optional)
- **Purpose**: High-performance LLM serving
- **Features**:
  - PagedAttention optimization
  - High throughput
  - Multiple model support
  - OpenAI-compatible API

#### SGLang (Optional)
- **Purpose**: Structured generation language
- **Features**:
  - Fast inference
  - Structured output
  - Batch processing
  - Memory optimization

### Knowledge Management Systems

#### Vector Database (RAG)
- **ChromaDB**: Open-source vector database
- **Features**:
  - Local deployment
  - Embedding storage and retrieval
  - Similarity search
  - Collection management
  - Metadata filtering

#### Knowledge Graph (CAG)
- **In-Memory Implementation**: Custom Ruby implementation
- **Features**:
  - Entity relationship mapping
  - Graph traversal
  - Context extraction
  - Relationship inference

#### Embedding Models
- **nomic-embed-text**: Text embedding model
- **Provider**: Ollama
- **Features**:
  - Local embedding generation
  - Semantic similarity
  - Dimensionality: 768
  - Multilingual support

## Development Environment

### Package Management and Build System

#### Nix Flakes
- **Purpose**: Reproducible development environment
- **Features**:
  - Declarative environment specification
  - Dependency isolation
  - Cross-platform support
  - Binary caching
  - Rollback capabilities

#### Makefile
- **Purpose**: Development automation
- **Targets**:
  - Environment setup
  - IRC server management
  - Testing automation
  - Documentation generation
  - Deployment helpers

### Development Tools

#### Version Control
- **Git**: Source code management
- **Features**:
  - Distributed version control
  - Branching and merging
  - Tagging and releases
  - Hook support

#### Text Editors and IDEs
- **VS Code**: Primary development environment
- **Cursor**: AI-enhanced IDE
- **Vim/Neovim**: Terminal-based editing
- **Features**:
  - Ruby language support
  - Debugging integration
  - Git integration
  - Extension ecosystem

#### IRC Client for Testing
- **WeeChat**: Terminal-based IRC client
- **HexChat**: GUI IRC client
- **Custom Python Server**: Development IRC server

## Infrastructure and Deployment

### Operating System Support

#### Primary Platforms
- **Linux**: Ubuntu 20.04+, Debian 11+, CentOS 8+
- **macOS**: 11.0+ (Big Sur and later)
- **Windows**: Windows 10/11 with WSL2

#### Container Support
- **Docker**: Application containerization
- **Podman**: Docker alternative
- **Features**:
  - Consistent deployment
  - Resource isolation
  - Portability
  - Microservices support

### Server Infrastructure

#### IRC Server
- **Custom Python Implementation**: Development and testing
- **InspIRCd**: Production IRC server (optional)
- **Features**:
  - Standard IRC protocol
  - SSL/TLS support
  - Channel management
  - User authentication
  - Logging and monitoring

#### LLM Serving Infrastructure
- **Ollama**: Local model serving
- **GPU Support**: CUDA, ROCm for acceleration
- **Model Storage**: Local file system
- **Memory Management**: RAM optimization

### Database and Storage

#### Vector Database Storage
- **ChromaDB Storage**: Local file system
- **Location**: `./knowledge_bases/offline/vector_db`
- **Format**: Persistent storage with compression
- **Backup**: File system backup strategies

#### Knowledge Graph Storage
- **In-Memory**: Runtime storage
- **Persistence**: Optional file-based persistence
- **Format**: Serialized Ruby objects
- **Location**: `./knowledge_bases/offline/graph`

#### Configuration Storage
- **XML Files**: Human-readable configuration
- **Location**: `./config/` directory
- **Validation**: Schema validation
- **Backup**: Version control integration

## Testing and Quality Assurance

### Testing Framework

#### Minitest
- **Purpose**: Ruby testing framework
- **Features**:
  - Lightweight and fast
  - Mock and stub support
  - Benchmarking
  - Spec-style assertions

#### Test Types
- **Unit Tests**: Component-level testing
- **Integration Tests**: System integration testing
- **Performance Tests**: Load and stress testing
- **Security Tests**: Vulnerability assessment

### Code Quality Tools

#### RuboCop
- **Purpose**: Ruby code style checker
- **Features**:
  - Style guide enforcement
  - Code complexity analysis
  - Security vulnerability detection
  - Auto-correction capabilities

#### Reek
- **Purpose**: Code smell detector
- **Features**:
  - Design pattern analysis
  - Complexity metrics
  - Duplication detection
  - Method length analysis

## Monitoring and Observability

### Logging System

#### Custom Logging (print.rb)
- **Levels**: Debug, Info, Std, Err
- **Output**: Console and file logging
- **Features**:
  - Timestamped entries
  - Level-based filtering
  - Structured logging
  - Performance metrics

#### Debug Logging
- **Location**: `.ai/debug-log.md`
- **Purpose**: Development debugging
- **Features**:
  - Detailed execution traces
  - Error context
  - Performance profiling
  - AI interaction logging

### Performance Monitoring

#### Metrics Collection
- **Response Times**: AI generation latency
- **Memory Usage**: Component memory consumption
- **IRC Metrics**: Message throughput, connection counts
- **Knowledge Metrics**: Retrieval accuracy, cache hit rates

#### Health Checks
- **Component Health**: LLM provider connectivity
- **Knowledge Base**: Vector database status
- **IRC Server**: Connection and channel status
- **System Resources**: CPU, memory, disk usage

## Security Technologies

### Encryption and Security

#### SSL/TLS
- **IRC Connections**: Encrypted IRC communication
- **API Calls**: HTTPS for external API communication
- **Certificate Management**: Self-signed and CA certificates

#### Input Validation
- **Sanitization**: Input cleaning and validation
- **Command Injection Prevention**: Safe command execution
- **XSS Prevention**: Output encoding and filtering

### Access Control

#### Authentication
- **IRC Authentication**: NickServ integration
- **API Keys**: Secure API key management
- **Environment Variables**: Sensitive configuration

#### Authorization
- **Role-Based Access**: User permission management
- **Command Restrictions**: Limited command set
- **Resource Limits**: Usage quotas and throttling

## Documentation and Communication

### Documentation Tools

#### Markdown
- **Primary Format**: Markdown for all documentation
- **Features**:
  - Version control friendly
  - Easy editing and collaboration
  - Multiple output formats
  - Code highlighting

#### Mermaid Diagrams
- **Architecture Diagrams**: System visualization
- **Flow Charts**: Process documentation
- **Sequence Diagrams**: Interaction documentation

### Communication Platforms

#### IRC
- **Primary Protocol**: IRC for user interaction
- **Channels**: Training and discussion channels
- **Features**: Real-time communication, logging

#### Git
- **Version Control**: Source code management
- **Collaboration**: Code review and discussion
- **Issues**: Bug tracking and feature requests

## Integration and APIs

### Internal APIs

#### LLM Provider Interface
```ruby
# Standardized interface for all LLM providers
class LLMClient
  def generate_response(prompt, stream_callback = nil)
  def test_connection
  def update_system_prompt(prompt)
  def get_model_info
end
```

#### Knowledge Enhancement Interface
```ruby
# Unified knowledge enhancement interface
class RAGCAGManager
  def get_enhanced_context(query, options = {})
  def add_custom_knowledge(collection, documents)
  def extract_entities(query, entity_types)
  def test_connections
end
```

### External Integrations

#### MITRE ATT&CK Framework
- **Integration**: Ruby knowledge base
- **Format**: Structured data objects
- **Updates**: Manual or automated updates

#### System Integration
- **Shell Commands**: Secure command execution
- **File System**: Knowledge base management
- **Network**: IRC and HTTP communication

## Performance and Optimization

### Caching Strategies

#### Response Caching
- **Memory Cache**: Frequently accessed responses
- **Disk Cache**: Persistent response storage
- **TTL Management**: Time-based cache expiration

#### Knowledge Caching
- **Vector Cache**: Embedding result caching
- **Graph Cache**: Knowledge graph traversal caching
- **Document Cache**: Processed document caching

### Optimization Techniques

#### Memory Management
- **Garbage Collection**: Ruby GC tuning
- **Object Pooling**: Reusable object instances
- **Memory Profiling**: Memory usage analysis

#### Concurrency
- **Thread Management**: Efficient thread usage
- **Async Operations**: Non-blocking I/O
- **Connection Pooling**: Resource reuse

## Future Technology Considerations

### Emerging Technologies

#### Advanced AI Models
- **Multimodal Models**: Vision and text integration
- **Larger Context Windows**: Extended conversation history
- **Fine-tuning**: Custom model training

#### Distributed Systems
- **Microservices**: Service-oriented architecture
- **Message Queues**: Asynchronous communication
- **Load Balancing**: High availability deployment

### Technology Evolution

#### Language Updates
- **Ruby 3.2+**: Latest Ruby features and performance
- **Alternative Languages**: Go, Rust for performance-critical components

#### Database Evolution
- **Vector Database Advances**: Improved vector storage
- **Graph Databases**: Neo4j or similar for CAG
- **Distributed Storage**: Scalable knowledge storage

## Conclusion

The Hackerbot technology stack is designed for security, reliability, and extensibility. The combination of Ruby's rapid development capabilities, modern AI frameworks, and robust infrastructure components provides a solid foundation for cybersecurity training applications.

The stack emphasizes offline operation, security, and flexibility while maintaining high performance and user experience. Regular evaluation and updates to the technology stack ensure the project remains current with evolving technologies and security requirements.