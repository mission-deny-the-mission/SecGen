# API Reference

This document provides comprehensive API reference documentation for the Hackerbot framework. This is a placeholder document that will be expanded as the API matures.

## Core APIs

### LLM Client API

#### LLMClientFactory

```ruby
# Create LLM client instances
client = LLMClientFactory.create_client(
  provider: 'ollama',        # 'ollama', 'openai', 'vllm', 'sglang'
  model: 'gemma3:1b',       # Model name
  host: 'localhost',        # Provider host
  port: 11434,              # Provider port
  api_key: nil             # API key (for cloud providers)
)

# Available providers
LLMClientFactory::PROVIDERS.keys
# => ['ollama', 'openai', 'vllm', 'sglang']
```

#### Base LLMClient Interface

```ruby
# All LLM clients implement these methods
class LLMClient
  # Generate non-streaming response
  def generate_response(message, context = '', user_id = nil)
    # Returns: String response
  end
  
  # Generate streaming response with callback
  def generate_streaming_response(message, context = '', user_id = nil, &callback)
    # Yields chunks to callback as they arrive
  end
  
  # Test provider connection
  def test_connection
    # Returns: Boolean (true if connection successful)
  end
  
  # System prompt management
  def update_system_prompt(new_prompt)
  def get_system_prompt
  end
end
```

### RAG/CAG Manager API

#### RAGCAGManager

```ruby
# Initialize with configuration
manager = RAGCAGManager.new(rag_config, cag_config, unified_config)

# Knowledge base operations
manager.initialize_knowledge_base
manager.test_connections

# Context retrieval
context = manager.get_enhanced_context(query, options)
entities = manager.extract_entities(text, entity_types)
related = manager.find_related_entities(entity_name, relationship_type, depth)

# Custom knowledge management
manager.add_custom_knowledge(collection_name, documents, triplets)

# Statistics and monitoring
stats = manager.get_retrieval_stats
manager.cleanup
```

#### Configuration Structure

```ruby
# RAG Configuration
rag_config = {
  vector_db: {
    provider: 'chromadb',    # Vector database provider
    host: 'localhost',
    port: 8000
  },
  embedding_service: {
    provider: 'openai',      # Embedding service provider
    api_key: 'your-key',
    model: 'text-embedding-ada-002'
  },
  rag_settings: {
    max_results: 5,          # Maximum documents to retrieve
    similarity_threshold: 0.7,  # Minimum similarity score
    chunk_size: 1000,       # Text chunk size
    chunk_overlap: 200,     # Overlap between chunks
    enable_caching: true    # Enable response caching
  }
}

# CAG Configuration
cag_config = {
  knowledge_graph: {
    provider: 'in_memory',  # Knowledge graph provider
    host: 'localhost',
    port: 7687
  },
  entity_extractor: {
    provider: 'rule_based', # Entity extraction method
    entity_types: ['ip_address', 'url', 'hash', 'filename']
  },
  cag_settings: {
    max_context_depth: 2,   # Graph traversal depth
    max_context_nodes: 20,  # Maximum nodes in context
    enable_caching: true   # Enable context caching
  }
}

# Unified Configuration
unified_config = {
  enable_rag: true,         # Enable RAG component
  enable_cag: true,         # Enable CAG component
  rag_weight: 0.6,          # Weight for RAG context
  cag_weight: 0.4,          # Weight for CAG context
  max_context_length: 4000, # Maximum context length
  enable_caching: true,     # Enable unified caching
  cache_ttl: 3600,         # Cache time-to-live
  auto_initialization: true # Auto-initialize knowledge base
}
```

### Bot Manager API

#### BotManager

```ruby
# Initialize bot manager
bot_manager = BotManager.new(
  irc_server_ip_address,     # IRC server address
  llm_provider,             # LLM provider name
  ollama_host, ollama_port, ollama_model,     # Ollama settings
  openai_api_key, openai_base_url,           # OpenAI settings
  vllm_host, vllm_port, vllm_model,         # VLLM settings
  sglang_host, sglang_port, sglang_model,    # SGLang settings
  enable_rag_cag,           # Enable knowledge enhancement
  rag_cag_config            # RAG/CAG configuration
)

# Configuration management
bot_manager.load_bot_configurations(config_directory)
bot_manager.create_bot(bot_config)
bot_manager.start_bots

# Context and prompt management
context = bot_manager.get_enhanced_context(bot_name, user_message)
entities = bot_manager.extract_entities_from_message(bot_name, user_message)
prompt = bot_manager.assemble_prompt(system_prompt, context, chat_context, user_message, enhanced_context)

# Chat history management
bot_manager.add_to_chat_history(bot_name, user_message, assistant_response, user_id)
history = bot_manager.get_chat_history(bot_name, user_id)
bot_manager.clear_chat_history(bot_name, user_id)
```

### Knowledge Source API

#### BaseKnowledgeSource

```ruby
# Base interface for all knowledge sources
class BaseKnowledgeSource
  def initialize(config)
    # Initialize with configuration hash
  end
  
  # Process content and return RAG documents and CAG triplets
  def process_content
    # Returns: [Array<Hash>, Array<Hash>] - [documents, triplets]
    raise NotImplementedError
  end
  
  # Test connection to data source
  def test_connection
    # Returns: Boolean
    raise NotImplementedError
  end
  
  # Get source metadata
  def get_metadata
    # Returns: Hash with source information
  end
end
```

#### Custom Knowledge Source Implementation

```ruby
class CustomKnowledgeSource < BaseKnowledgeSource
  def process_content
    documents = []
    triplets = []
    
    # Process your custom data source
    @config['data_items'].each do |item|
      # Create RAG document
      documents << {
        id: item['id'],
        content: item['content'],
        metadata: {
          source: @config['name'],
          type: item['type'],
          created_at: Time.now
        }
      }
      
      # Create CAG triplet
      if item['relationship']
        triplets << {
          subject: item['subject'],
          relationship: item['relationship'],
          object: item['object'],
          confidence: item['confidence'] || 1.0
        }
      end
    end
    
    [documents, triplets]
  end
  
  def test_connection
    # Test connectivity to your data source
    # Return true if successful, false otherwise
    true
  end
end
```

## Configuration API

### XML Configuration Schema

```xml
<!-- Basic bot configuration -->
<hackerbot>
  <!-- Core identity -->
  <name>BotName</name>
  <llm_provider>ollama</llm_provider>
  
  <!-- LLM-specific settings -->
  <ollama_model>gemma3:1b</ollama_model>
  <ollama_host>localhost</ollama_host>
  <ollama_port>11434</ollama_port>
  
  <!-- Personality and behavior -->
  <system_prompt>You are a helpful assistant.</system_prompt>
  <streaming>true</streaming>
  <max_tokens>2000</max_tokens>
  <temperature>0.7</temperature>
  
  <!-- Knowledge enhancement -->
  <rag_cag_enabled>true</rag_cag_enabled>
  <rag_enabled>true</rag_enabled>
  <cag_enabled>true</cag_enabled>
  <entity_extraction_enabled>true</entity_extraction_enabled>
  <entity_types>ip_address, url, hash, filename, port, email</entity_types>
  
  <!-- Knowledge sources -->
  <knowledge_sources>
    <source>
      <type>mitre_attack</type>
      <name>mitre_attack</name>
      <enabled>true</enabled>
      <priority>1</priority>
    </source>
  </knowledge_sources>
  
  <!-- Training scenarios -->
  <attacks>
    <attack>
      <prompt>Scenario description</prompt>
      <system_prompt>Scenario-specific personality</system_prompt>
      <post_command>echo "scenario_completed"</post_command>
      <condition>
        <output_matches>success_pattern</output_matches>
        <message>Completion message</message>
        <trigger_next_attack>true</trigger_next_attack>
      </condition>
    </attack>
  </attacks>
  
  <!-- Bot messages -->
  <messages>
    <greeting>Hello! I'm your AI assistant.</greeting>
    <goodbye>Goodbye!</goodbye>
    <help>Available commands: help, next, clear_history, show_history</help>
  </messages>
</hackerbot>
```

## Command Line API

### hackerbot.rb

```bash
# Basic usage
ruby hackerbot.rb [OPTIONS]

# LLM Provider Options
--llm-provider PROVIDER      # ollama, openai, vllm, sglang
--ollama-host HOST           # Ollama server host
--ollama-port PORT           # Ollama server port
--ollama-model MODEL         # Ollama model name
--openai-api-key KEY         # OpenAI API key
--openai-base-url URL        # OpenAI API base URL (default: https://api.openai.com/v1)
--openai-model MODEL         # OpenAI model name
--vllm-host HOST             # VLLM server host
--vllm-port PORT             # VLLM server port
--vllm-model MODEL           # VLLM model name
--sglang-host HOST           # SGLang server host
--sglang-port PORT           # SGLang server port
--sglang-model MODEL         # SGLang model name

# Knowledge Enhancement Options
--enable-rag-cag             # Enable RAG + CAG (default: true)
--rag-only                   # Enable only RAG system
--cag-only                   # Enable only CAG system
--offline                    # Force offline mode
--online                     # Force online mode

# Response Options
--streaming true|false       # Enable/disable streaming responses

# Basic Options
--irc-server HOST            # IRC server address
--irc-port PORT              # IRC server port
--config FILE                # XML configuration file
--help                       # Show help message
--version                    # Show version information
```

## Error Handling API

### Common Exceptions

```ruby
# LLM-related errors
class LLMConnectionError < StandardError; end
class LLMResponseError < StandardError; end
class UnknownProviderError < StandardError; end

# Configuration errors
class ConfigurationError < StandardError; end
class MissingConfigurationError < StandardError; end

# Knowledge system errors
class KnowledgeBaseError < StandardError; end
class EntityExtractionError < StandardError; end

# Bot management errors
class BotCreationError < StandardError; end
class IRCConnectionError < StandardError; end
```

### Error Handling Patterns

```ruby
begin
  # Create LLM client
  client = LLMClientFactory.create_client('ollama', {
    model: 'gemma3:1b',
    host: 'localhost',
    port: 11434
  })
  
  # Test connection
  unless client.test_connection
    raise LLMConnectionError, "Unable to connect to LLM provider"
  end
  
  # Generate response
  response = client.generate_response("Hello", context)
  
rescue LLMConnectionError => e
  log_error("LLM connection failed", e)
  fallback_response = "I'm currently experiencing technical difficulties. Please try again later."
rescue ConfigurationError => e
  log_error("Configuration error", e)
  fallback_response = "There's a configuration issue. Please check the bot settings."
rescue => e
  log_error("Unexpected error", e)
  fallback_response = "An unexpected error occurred. Please contact support."
end
```

## Utility APIs

### Print Utilities

```ruby
# Colorized output methods
Print.debug("Debug message")
Print.info("Info message")
Print.success("Success message")
Print.warning("Warning message")
Print.error("Error message")

# Color methods
Print.red("Red text")
Print.green("Green text")
Print.blue("Blue text")
Print.yellow("Yellow text")
Print.magenta("Magenta text")
Print.cyan("Cyan text")
Print.white("White text")
```

### Configuration Validation

```ruby
# Validate bot configuration
def validate_bot_config(config)
  errors = []
  
  # Required fields
  errors << "Name is required" unless config['name']
  errors << "LLM provider is required" unless config['llm_provider']
  
  # Provider-specific validation
  case config['llm_provider']
  when 'ollama'
    errors << "Ollama model is required" unless config['ollama_model']
  when 'openai'
    errors << "OpenAI API key is required" unless config['openai_api_key']
  end
  
  errors.empty? ? true : errors
end
```

## Extension Points

### Adding New LLM Providers

```ruby
# 1. Implement the LLMClient interface
class CustomProviderClient < LLMClient
  def generate_response(message, context = '', user_id = nil)
    # Provider-specific implementation
  end
  
  def generate_streaming_response(message, context = '', user_id = nil, &callback)
    # Streaming implementation
  end
  
  def test_connection
    # Connection test
  end
end

# 2. Register with factory
LLMClientFactory::PROVIDERS['custom'] = CustomProviderClient
```

### Adding New Knowledge Sources

```ruby
# 1. Implement BaseKnowledgeSource
class CustomKnowledgeSource < BaseKnowledgeSource
  def process_content
    # Process your data source
  end
  
  def test_connection
    # Test connectivity
  end
end

# 2. Add to knowledge source manager
KnowledgeSourceManager.register_source_type('custom', CustomKnowledgeSource)
```

## Version Information

### API Versioning

The Hackerbot API follows semantic versioning:

- **Major version**: Breaking changes to API interfaces
- **Minor version**: New features added without breaking existing functionality
- **Patch version**: Bug fixes and minor improvements

### Current Version: 2.0.0

This version includes:
- Complete LLM provider abstraction
- RAG/CAG knowledge enhancement system
- Modular architecture for extensibility
- Comprehensive configuration system

---

*Note: This API reference is a work in progress. Additional methods, classes, and detailed parameter documentation will be added as the framework evolves. For the most up-to-date information, please refer to the source code and inline documentation.*