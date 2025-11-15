# Hackerbot Development Guide

This guide provides technical documentation for developers who want to extend, modify, or contribute to the Hackerbot framework.

## 🏗️ Architecture Overview

### System Architecture

```
Hackerbot Framework
├── Core Application Layer
│   ├── hackerbot.rb              # Main entry point, CLI handling
│   ├── bot_manager.rb            # Bot lifecycle management
│   └── print.rb                  # Logging and utilities
├── LLM Integration Layer
│   ├── llm_client.rb             # Base LLM interface
│   ├── llm_client_factory.rb     # Provider factory pattern
│   ├── ollama_client.rb          # Ollama implementation
│   ├── openai_client.rb          # OpenAI implementation
│   ├── vllm_client.rb            # VLLM implementation
│   └── sglang_client.rb          # SGLang implementation
├── Knowledge Enhancement Layer
│   ├── rag_cag_manager.rb        # Unified RAG+CAG coordinator
│   ├── rag/                      # Retrieval-Augmented Generation
│   │   ├── rag_manager.rb        # RAG operations
│   │   ├── vector_db_interface.rb
│   │   ├── embedding_service_interface.rb
│   │   ├── chromadb_client.rb    # Vector database implementation
│   │   ├── openai_embedding_client.rb
│   │   └── ollama_embedding_client.rb
│   └── cag/                      # Context-Aware Generation
│       ├── cag_manager.rb        # CAG operations
│       ├── knowledge_graph_interface.rb
│       └── in_memory_graph_client.rb
├── Knowledge Base Layer
│   ├── knowledge_bases/
│   │   └── mitre_attack_knowledge.rb
│   └── config/                   # XML configuration files
└── Testing Layer
    ├── test/                     # Test suite
    └── demo_*.rb                 # Demonstration scripts
```

### Design Patterns

#### Factory Pattern (LLM Client Factory)
```ruby
# Create LLM clients using factory pattern
client = LLMClientFactory.create_client(
  'ollama', 
  model: 'gemma3:1b',
  host: 'localhost',
  port: 11434
)
```

#### Strategy Pattern (Knowledge Sources)
```ruby
# Different knowledge source types implement same interface
class ManPageKnowledgeSource < BaseKnowledgeSource
  def process_content
    # Man page specific processing
  end
end

class MarkdownKnowledgeSource < BaseKnowledgeSource
  def process_content
    # Markdown specific processing
  end
end
```

#### Observer Pattern (Streaming Responses)
```ruby
# Streaming callbacks for real-time responses
client.generate_streaming_response(message) do |chunk|
  # Process each chunk as it arrives
  send_to_irc(chunk)
end
```

## 🔧 Core Components

### BotManager Class

The central controller for bot instances and operations.

#### Key Methods
```ruby
class BotManager
  def initialize(irc_server_ip_address, llm_provider = 'ollama', 
               ollama_host = nil, ollama_port = nil, ollama_model = nil,
               openai_api_key = nil, openai_base_url = nil,
               vllm_host = nil, vllm_port = nil, vllm_model = nil,
               sglang_host = nil, sglang_port = nil, sglang_model = nil,
               enable_rag_cag = false, rag_cag_config = {})
    
  def load_bot_configurations(config_directory)
    # Load and parse XML bot configurations
  end
  
  def create_bot(bot_config)
    # Create IRC bot with LLM integration
  end
  
  def get_enhanced_context(bot_name, user_message)
    # Get RAG + CAG context for bot responses
  end
  
  def assemble_prompt(system_prompt, context, chat_context, user_message, enhanced_context = nil)
    # Assemble complete prompt for LLM
  end
end
```

### LLMClient Base Class

Abstract base class for all LLM provider implementations.

#### Interface Definition
```ruby
class LLMClient
  attr_accessor :model, :host, :port, :system_prompt
  
  def initialize(model: 'default', host: 'localhost', port: 8080, system_prompt: nil)
    # Common initialization
  end
  
  # Abstract methods - must be implemented by subclasses
  def generate_response(message, context = '', user_id = nil)
    raise NotImplementedError
  end
  
  def generate_streaming_response(message, context = '', user_id = nil, &callback)
    raise NotImplementedError
  end
  
  def test_connection
    raise NotImplementedError
  end
  
  # Common utility methods
  def update_system_prompt(new_prompt)
    @system_prompt = new_prompt
  end
  
  def get_system_prompt
    @system_prompt
  end
end
```

### RAGCAGManager Class

Coordinates RAG and CAG operations seamlessly.

#### Key Methods
```ruby
class RAGCAGManager
  def initialize(rag_config, cag_config, unified_config)
    # Initialize with configuration
  end
  
  def initialize_knowledge_base
    # Load and process knowledge bases
  end
  
  def get_enhanced_context(query, options = {})
    # Get combined RAG + CAG context
  end
  
  def extract_entities(text, entity_types)
    # Extract cybersecurity entities
  end
  
  def find_related_entities(entity_name, relationship_type, depth)
    # Find related entities in knowledge graph
  end
  
  def add_custom_knowledge(collection_name, documents, triplets)
    # Add custom knowledge sources
  end
end
```

## 📡 API Reference

### LLM Client Factory API

#### create_client(provider, options)
Create LLM client instances.

**Parameters:**
- `provider` (String): LLM provider name ('ollama', 'openai', 'vllm', 'sglang')
- `options` (Hash): Provider-specific configuration

**Returns:** LLMClient instance

**Example:**
```ruby
client = LLMClientFactory.create_client('ollama', {
  model: 'gemma3:1b',
  host: 'localhost',
  port: 11434
})
```

### RAG/CAG Manager API

#### Knowledge Base Operations

```ruby
# Initialize manager with configuration
manager = RAGCAGManager.new(rag_config, cag_config, unified_config)
manager.initialize

# Get enhanced context for a query
context = manager.get_enhanced_context("What is credential dumping?")

# Extract entities from text
entities = manager.extract_entities("Attack from 192.168.1.100 using malware.exe")

# Find related entities
related = manager.find_related_entities("Mimikatz", "USED_BY", 2)

# Add custom knowledge
manager.add_custom_knowledge('custom_collection', documents, triplets)
```

#### Configuration Structure

```ruby
rag_config = {
  vector_db: {
    provider: 'chromadb',
    host: 'localhost',
    port: 8000
  },
  embedding_service: {
    provider: 'openai',
    api_key: 'your-api-key',
    model: 'text-embedding-ada-002'
  },
  rag_settings: {
    max_results: 5,
    similarity_threshold: 0.7,
    chunk_size: 1000,
    chunk_overlap: 200
  }
}

cag_config = {
  knowledge_graph: {
    provider: 'in_memory',
    host: 'localhost',
    port: 7687
  },
  entity_extractor: {
    provider: 'rule_based',
    entity_types: ['ip_address', 'url', 'hash', 'filename']
  },
  cag_settings: {
    max_context_depth: 2,
    max_context_nodes: 20
  }
}

unified_config = {
  enable_rag: true,
  enable_cag: true,
  rag_weight: 0.6,
  cag_weight: 0.4,
  max_context_length: 4000,
  enable_caching: true,
  cache_ttl: 3600
}
```

### Knowledge Source API

#### BaseKnowledgeSource Interface

```ruby
class BaseKnowledgeSource
  def initialize(config)
    # Initialize with configuration
  end
  
  def process_content
    # Process and format content for RAG/CAG
    raise NotImplementedError
  end
  
  def get_rag_documents
    # Return documents for RAG processing
    raise NotImplementedError
  end
  
  def get_cag_triplets
    # Return triplets for CAG processing
    raise NotImplementedError
  end
  
  def test_connection
    # Test connectivity to data source
    raise NotImplementedError
  end
end
```

#### Custom Knowledge Source Implementation

```ruby
class CustomKnowledgeSource < BaseKnowledgeSource
  def process_content
    # Process custom data source
    documents = []
    triplets = []
    
    # Process your custom data
    @config['data_items'].each do |item|
      # Create RAG documents
      documents << {
        id: item['id'],
        content: item['content'],
        metadata: { source: 'custom', type: item['type'] }
      }
      
      # Create CAG triplets
      triplets << {
        subject: item['subject'],
        relationship: item['relationship'],
        object: item['object']
      }
    end
    
    [documents, triplets]
  end
end
```

## 🧪 Testing Framework

### Test Structure

```
test/
├── test_helper.rb              # Common test utilities
├── run_tests.rb                # Test runner
├── quick_test.rb               # Quick verification
├── test_llm_client_factory.rb  # LLM factory tests
├── test_llm_client_base.rb     # Base class tests
├── test_openai_client.rb       # OpenAI client tests
├── test_vllm_client.rb         # VLLM client tests
├── test_bot_manager.rb         # Bot manager tests
└── test_hackerbot.rb           # Main application tests
```

### Writing Tests

#### Test Helper Utilities

```ruby
require_relative 'test_helper'

class TestMyComponent < LLMClientTest
  def setup
    super
    # Setup code
  end
  
  def test_my_functionality
    # Test code
    result = my_component.my_method()
    
    assert_equal expected, result
    assert_includes result, 'expected_content'
  end
end
```

#### Mocking HTTP Responses

```ruby
def test_openai_client_success
  # Mock successful HTTP response
  mock_response = HTTPMock.mock_success_response({
    'choices' => [{
      'message' => { 'content' => 'Test response' }
    }]
  })
  
  HTTPMock.stub(:post_request, mock_response) do
    client = OpenAIClient.new(api_key: 'test-key')
    response = client.generate_response('Hello')
    
    assert_equal 'Test response', response
  end
end
```

### Running Tests

```bash
# Run all tests
ruby test/run_tests.rb

# Run with verbose output
ruby test/run_tests.rb --verbose

# Run specific test file
ruby test/test_llm_client_factory.rb

# Quick verification
ruby test/quick_test.rb
```

## 🔌 Extending Hackerbot

### Adding New LLM Providers

#### 1. Create Provider Client

```ruby
class NewProviderClient < LLMClient
  def generate_response(message, context = '', user_id = nil)
    # Implement provider-specific API call
    response = make_api_call(message, context)
    extract_content_from_response(response)
  end
  
  def generate_streaming_response(message, context = '', user_id = nil, &callback)
    # Implement streaming if supported
    stream_api_call(message, context) do |chunk|
      callback.call(process_chunk(chunk))
    end
  end
  
  def test_connection
    # Test provider connectivity
    make_test_call()
  end
  
  private
  
  def make_api_call(message, context)
    # Provider-specific API implementation
  end
end
```

#### 2. Register with Factory

```ruby
class LLMClientFactory
  PROVIDERS = {
    'ollama' => OllamaClient,
    'openai' => OpenAIClient,
    'vllm' => VLLMClient,
    'sglang' => SGLangClient,
    'newprovider' => NewProviderClient  # Add new provider
  }
end
```

### Adding New Knowledge Sources

#### 1. Implement Knowledge Source

```ruby
class CustomKnowledgeSource < BaseKnowledgeSource
  def process_content
    documents = []
    triplets = []
    
    # Process your custom data source
    data_items = fetch_data_from_source()
    
    data_items.each do |item|
      # Create RAG documents
      documents << {
        id: generate_id(item),
        content: item['content'],
        metadata: {
          source: @config['name'],
          type: item['type'],
          created_at: Time.now
        }
      }
      
      # Create CAG triplets
      if item['relationships']
        item['relationships'].each do |rel|
          triplets << {
            subject: rel['subject'],
            relationship: rel['relationship'],
            object: rel['object']
          }
        end
      end
    end
    
    [documents, triplets]
  end
  
  private
  
  def fetch_data_from_source
    # Custom data fetching logic
    # API calls, database queries, file reading, etc.
  end
end
```

#### 2. Register Knowledge Source Type

```ruby
class KnowledgeSourceManager
  SOURCE_TYPES = {
    'mitre_attack' => MitreAttackKnowledgeSource,
    'man_pages' => ManPageKnowledgeSource,
    'markdown_files' => MarkdownKnowledgeSource,
    'custom' => CustomKnowledgeSource  # Add new type
  }
end
```

### Adding New Entity Types

#### 1. Extend Entity Extractor

```ruby
class CustomEntityExtractor < EntityExtractor
  def extract_entities(text, entity_types)
    entities = super(text, entity_types)
    
    if entity_types.include?('custom_type')
      entities.concat(extract_custom_entities(text))
    end
    
    entities
  end
  
  private
  
  def extract_custom_entities(text)
    # Custom entity extraction logic
    text.scan(/custom-pattern/).map do |match|
      {
        type: 'custom_type',
        value: match,
        confidence: 0.9,
        context: get_context(text, match)
      }
    end
  end
end
```

#### 2. Update Configuration

```xml
<entity_types>ip_address, url, hash, filename, port, email, custom_type</entity_types>
```

## 🚀 Performance Optimization

### Memory Management

#### Selective System Loading

```ruby
# Load only needed systems
rag_only_config = unified_config.merge(enable_cag: false)
cag_only_config = unified_config.merge(enable_rag: false)

# Use smaller models for better performance
lightweight_client = LLMClientFactory.create_client('ollama', {
  model: 'gemma3:1b',  # Smaller, faster model
  max_tokens: 1000    # Limit response length
})
```

#### Caching Strategies

```ruby
# Enable caching with appropriate TTL
cache_config = unified_config.merge({
  enable_caching: true,
  cache_ttl: 3600,    # 1 hour cache
  max_cache_size: 1000 # Maximum cache entries
})

# Implement custom caching
class CustomCache
  def get(key)
    @cache[key] if @cache[key] && !expired?(@cache[key])
  end
  
  def set(key, value, ttl = 3600)
    @cache[key] = {
      value: value,
      expires_at: Time.now + ttl
    }
  end
end
```

### Connection Pooling

```ruby
class ConnectionPool
  def initialize(size = 5, &block)
    @pool = Array.new(size, &block)
    @available = @pool.dup
  end
  
  def with_connection
    connection = @available.pop
    yield connection
  ensure
    @available.push(connection) if connection
  end
end

# Usage with HTTP clients
pool = ConnectionPool.new(5) { HTTPClient.new }

pool.with_connection do |client|
  response = client.get(url)
  # Process response
end
```

## 🔒 Security Considerations

### API Key Management

```ruby
class SecureConfig
  def initialize
    @api_keys = load_secure_keys()
  end
  
  def get_key(provider)
    @api_keys[provider] || ENV["#{provider.upcase}_API_KEY"]
  end
  
  private
  
  def load_secure_keys
    # Load from secure storage (environment variables, key management service)
    # Never hardcode API keys
    {}
  end
end
```

### Input Validation

```ruby
class InputValidator
  def self.validate_user_input(input)
    # Remove potentially dangerous content
    sanitized = input.gsub(/<script[^>]*>.*?<\/script>/i, '')
                   .gsub(/javascript:/i, '')
    
    # Validate length
    raise InputTooLongError if sanitized.length > 10000
    
    sanitized
  end
  
  def self.validate_entity_type(type)
    allowed_types = ['ip_address', 'url', 'hash', 'filename', 'port', 'email']
    raise InvalidEntityTypeError unless allowed_types.include?(type)
  end
end
```

### Data Privacy

```ruby
class PrivacyManager
  def self.anonymize_data(data)
    # Remove or anonymize sensitive information
    data.gsub(/\b\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\b/, '[IP_ADDRESS]')
       .gsub(/\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b/, '[EMAIL]')
       .gsub(/\b[0-9a-fA-F]{32,}\b/, '[HASH]')
  end
  
  def self.should_log_content?(content)
    # Check for sensitive content that shouldn't be logged
    !contains_sensitive_patterns?(content)
  end
end
```

## 🐛 Debugging and Troubleshooting

### Debug Logging

```ruby
class DebugLogger
  def self.enable_debug=(enabled)
    @debug_enabled = enabled
  end
  
  def self.debug(message, context = {})
    return unless @debug_enabled
    
    debug_message = "[DEBUG] #{Time.now}: #{message}"
    debug_message += " | Context: #{context.inspect}" unless context.empty?
    
    puts debug_message
    log_to_file(debug_message) if @log_to_file
  end
  
  def self.trace_method_call(obj, method_name)
    original_method = obj.method(method