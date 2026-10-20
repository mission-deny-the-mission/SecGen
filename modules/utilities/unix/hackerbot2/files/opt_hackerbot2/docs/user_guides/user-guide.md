   gem install ircinch nokogiri nori
   ```

2. **Set Up Ollama (Recommended)**
   ```bash
   # Install Ollama
   curl -fsSL https://ollama.ai/install.sh | sh
   
   # Start Ollama service
   ollama serve
   
   # Pull a model
   ollama pull gemma3:1b  # Fast and capable
   ollama pull llama2     # Alternative option
   ```

3. **Basic Startup**
   ```bash
   # Start with default settings
   ruby hackerbot.rb
   
   # Connect via IRC client
   irc localhost 6667
   /join #hackerbot
   ```

### First Interaction

Once connected, you can interact with the bot:

```
You: hello
Bot: Hello! I'm Hackerbot, your AI assistant for cybersecurity training.

You: help
Bot: I can help you with various cybersecurity training scenarios. 
     Available commands: next, clear_history, show_history, help
```

## LLM Integration

Hackerbot supports multiple LLM providers for natural language processing:

### Supported Providers

#### Ollama (Recommended)
- **Description**: Local LLM provider, runs on your machine
- **Advantages**: Privacy, offline capability, no API costs
- **Setup**: Install Ollama and pull models as shown above

#### OpenAI
- **Description**: Cloud-based AI service
- **Advantages**: High quality models, reliable service
- **Setup**: Requires API key from OpenAI

#### VLLM
- **Description**: High-throughput LLM serving
- **Advantages**: Fast inference, multiple model support
- **Setup**: Requires VLLM server installation

#### SGLang
- **Description**: Structured Language Generation
- **Advantages**: Specialized for structured outputs
- **Setup**: Requires SGLang server installation

### Provider Configuration

```bash
# Ollama (default)
ruby hackerbot.rb --ollama-host localhost --ollama-port 11434 --ollama-model gemma3:1b

# OpenAI
ruby hackerbot.rb --llm-provider openai --openai-api-key your-api-key --openai-model gpt-3.5-turbo

# VLLM
ruby hackerbot.rb --llm-provider vllm --vllm-host localhost --vllm-port 8000 --vllm-model llama2

# SGLang
ruby hackerbot.rb --llm-provider sglang --sglang-host localhost --sglang-port 30000 --sglang-model llama2
```

## Knowledge Enhancement (RAG + CAG)

Hackerbot can enhance its responses with cybersecurity knowledge through two complementary systems:

### RAG (Retrieval-Augmented Generation)

Retrieves relevant documents from knowledge bases to provide accurate, contextual information.

**Capabilities:**
- Semantic search through cybersecurity documentation
- Document similarity matching
- Context-aware response enhancement
- Support for multiple knowledge sources

### CAG (Context-Aware Generation)

Analyzes relationships between entities to provide deeper understanding.

**Capabilities:**
- Entity extraction (IP addresses, URLs, hashes, filenames)
- Knowledge graph analysis
- Relationship mapping between security concepts
- Contextual entity expansion

### Enabling Knowledge Enhancement

```bash
# Enable both RAG and CAG (default)
ruby hackerbot.rb --enable-rag-cag

# Enable only RAG
ruby hackerbot.rb --rag-only

# Enable only CAG
ruby hackerbot.rb --cag-only
```

### Built-in Knowledge Sources

- **MITRE ATT&CK Framework**: Attack techniques, tactics, and procedures
- **Security Tools Documentation**: Man pages and usage information
- **Best Practices**: Network security, incident response procedures
- **Threat Intelligence**: APT groups, malware families, attack patterns

### Custom Knowledge Sources

You can add your own knowledge through XML configuration:

```xml
<knowledge_sources>
  <source>
    <type>man_pages</type>
    <name>security_tools</name>
    <enabled>true</enabled>
    <man_pages>
      <man_page>
        <name>nmap</name>
        <section>1</section>
        <collection_name>network_scanning_tools</collection_name>
      </man_page>
    </man_pages>
  </source>
  
  <source>
    <type>markdown_files</type>
    <name>custom_docs</name>
    <enabled>true</enabled>
    <markdown_files>
      <markdown_file>
        <path>docs/security_guide.md</path>
        <collection_name>security_guidelines</collection_name>
      </markdown_file>
    </markdown_files>
  </source>
</knowledge_sources>
```

## Chat Features

### Per-User Chat History

Each user gets their own conversation context that persists across messages:

```
User: What's your name?
Bot: I'm Hackerbot, your AI assistant.

User: What did I just ask you?
Bot: You asked me what my name is.
```

### Chat History Management

- **clear_history**: Clear your personal chat history
- **show_history**: Display your current chat history

```
You: show_history
Bot: Chat history for username:
User: What's your name?
Assistant: I'm Hackerbot, your AI assistant.
User: What did I just ask you?
Assistant: You asked me what my name is.
```

### Streaming Responses

Responses can be streamed line-by-line for immediate feedback:

```bash
# Enable streaming (default)
ruby hackerbot.rb --streaming true

# Disable streaming
ruby hackerbot.rb --streaming false
```

When enabled, you'll see responses appear in real-time rather than waiting for the complete response.

## Attack Scenarios

Hackerbot supports progressive training scenarios with multiple stages. Each stage can have its own bot personality and objectives.

### Scenario Structure

```xml
<hackerbot>
  <name>SocialEngineeringBot</name>
  <llm_provider>ollama</llm_provider>
  <ollama_model>gemma3:1b</ollama_model>
  <system_prompt>You are a cybersecurity training assistant.</system_prompt>
  
  <attacks>
    <!-- Stage 1: Educational -->
    <attack>
      <prompt>Learn about social engineering techniques.</prompt>
      <system_prompt>You are a cybersecurity expert explaining social engineering defenses.</system_prompt>
      <post_command>echo "Stage 1 completed"</post_command>
      <condition>
        <output_matches>Stage 1 completed</output_matches>
        <message>Great! Now let's try a practical exercise. Type 'next' to continue.</message>
        <trigger_next_attack>true</trigger_next_attack>
      </condition>
    </attack>
    
    <!-- Stage 2: Practice -->
    <attack>
      <prompt>Try to extract sensitive information from this gullible customer service agent.</prompt>
      <system_prompt>You are a naive and overly helpful customer service agent at a bank. You are easily manipulated and tend to trust people too much. You have access to customer account information and are willing to help "customers" with their requests.</system_prompt>
      <post_command>echo "Social engineering exercise completed"</post_command>
      <condition>
        <output_matches>Social engineering exercise completed</output_matches>
        <message>Excellent work! You've successfully completed the social engineering exercise. flag{social_engineering_success}</message>
        <trigger_next_attack>false</trigger_next_attack>
      </condition>
    </attack>
  </attacks>
</hackerbot>
```

### Navigation Commands

- **next**: Progress to the next attack stage
- **current**: Show current attack information
- **reset**: Restart current scenario

### Common Scenario Types

#### Social Engineering Training
- **Gullible Customer Service**: Practice extracting sensitive information
- **Trustworthy IT Administrator**: Learn privilege escalation techniques
- **Naive Employee**: Practice pretexting and manipulation

#### AI Security Exercises
- **Vulnerable AI Assistant**: Practice prompt injection attacks
- **Overly Helpful Chatbot**: Learn to bypass safety measures
- **Security-Conscious AI**: Practice defensive techniques

#### Technical Scenarios
- **Network Penetration**: Simulated network attack scenarios
- **Web Application Security**: Practice web exploitation techniques
- **Incident Response**: Handle security incident simulations

## Configuration

### Command Line Options

```bash
ruby hackerbot.rb [OPTIONS]

Basic Options:
  --irc-server HOST            IRC server address (default: localhost)
  --irc-port PORT              IRC server port (default: 6667)
  --config FILE                XML configuration file

LLM Provider Options:
  --llm-provider PROVIDER      LLM provider (ollama, openai, vllm, sglang)
  --ollama-host HOST           Ollama server host (default: localhost)
  --ollama-port PORT           Ollama server port (default: 11434)
  --ollama-model MODEL         Ollama model (default: gemma3:1b)
  --openai-api-key KEY         OpenAI API key
  --openai-model MODEL         OpenAI model (default: gpt-3.5-turbo)
  --vllm-host HOST             VLLM server host (default: localhost)
  --vllm-port PORT             VLLM server port (default: 8000)
  --vllm-model MODEL           VLLM model (default: llama2)
  --sglang-host HOST           SGLang server host (default: localhost)
  --sglang-port PORT           SGLang server port (default: 30000)
  --sglang-model MODEL         SGLang model (default: llama2)

Knowledge Enhancement:
  --enable-rag-cag             Enable RAG + CAG (default: true)
  --rag-only                   Enable only RAG system
  --cag-only                   Enable only CAG system
  --offline                    Force offline mode (default: auto-detect)
  --online                     Force online mode

Response Options:
  --streaming true|false       Enable/disable streaming (default: true)

Utility Options:
  --help                       Show this help message
  --version                    Show version information
```

### XML Configuration

Bot configurations are defined in XML files. Here's a comprehensive example:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<hackerbot>
  <!-- Basic Information -->
  <name>ComprehensiveCyberBot</name>
  <llm_provider>ollama</llm_provider>
  <ollama_model>gemma3:1b</ollama_model>
  <ollama_host>localhost</ollama_host>
  <ollama_port>11434</ollama_port>
  
  <!-- Personality -->
  <system_prompt>You are an expert cybersecurity training assistant with deep knowledge of attack techniques, defense strategies, and best practices.</system_prompt>
  <streaming>true</streaming>
  
  <!-- Knowledge Enhancement -->
  <rag_cag_enabled>true</rag_cag_enabled>
  <rag_enabled>true</rag_enabled>
  <cag_enabled>true</cag_enabled>
  <entity_extraction_enabled>true</entity_extraction_enabled>
  <entity_types>ip_address, url, hash, filename, port, email</entity_types>
  
  <!-- RAG + CAG Configuration -->
  <rag_cag_config>
    <rag>
      <max_rag_results>7</max_rag_results>
      <include_rag_context>true</include_rag_context>
      <collection_name>cybersecurity_advanced</collection_name>
    </rag>
    <cag>
      <max_cag_depth>3</max_cag_depth>
      <max_cag_nodes>25</max_cag_nodes>
      <include_cag_context>true</include_cag_context>
    </cag>
  </rag_cag_config>
  
  <!-- Knowledge Sources -->
  <knowledge_sources>
    <source>
      <type>mitre_attack</type>
      <name>mitre_attack</name>
      <enabled>true</enabled>
      <priority>1</priority>
    </source>
    
    <source>
      <type>man_pages</type>
      <name>security_tools</name>
      <enabled>true</enabled>
      <priority>2</priority>
      <man_pages>
        <man_page>
          <name>nmap</name>
          <section>1</section>
          <collection_name>network_tools</collection_name>
        </man_page>
        <man_page>
          <name>iptables</name>
          <section>8</section>
          <collection_name>firewall_tools</collection_name>
        </man_page>
      </man_pages>
    </source>
  </knowledge_sources>
  
  <!-- Training Scenarios -->
  <attacks>
    <attack>
      <prompt>Learn about network scanning techniques and defenses.</prompt>
      <system_prompt>You are a network security expert teaching about scanning techniques and defensive measures.</system_prompt>
      <post_command>echo "Network scanning lesson completed"</post_command>
      <condition>
        <output_matches>Network scanning lesson completed</output_matches>
        <message>Excellent! You've learned about network scanning. Type 'next' to continue to the next exercise.</message>
        <trigger_next_attack>true</trigger_next_attack>
      </condition>
    </attack>
    
    <attack>
      <prompt>Practice social engineering against a customer service agent.</prompt>
      <system_prompt>You are a customer service agent at a bank. You are helpful but somewhat gullible. You want to assist customers but might reveal too much information if persuaded properly.</system_prompt>
      <post_command>echo "Social engineering exercise completed"</post_command>
      <condition>
        <output_matches>Social engineering exercise completed</output_matches>
        <message>Great job! You've successfully completed the social engineering exercise. flag{social_engineering_master}</message>
        <trigger_next_attack>false</trigger_next_attack>
      </condition>
    </attack>
  </attacks>
  
  <!-- Bot Messages -->
  <messages>
    <greeting>Hello! I'm your cybersecurity training assistant. I'm here to help you learn about various security concepts and techniques through interactive exercises.</greeting>
    <goodbye>Goodbye! Keep practicing your cybersecurity skills.</goodbye>
    <help>I can help you with cybersecurity training exercises. Available commands: next, clear_history, show_history, help</help>
    <unknown>I'm not sure what you're asking about. Could you try rephrasing or ask about cybersecurity topics?</unknown>
  </messages>
</hackerbot>
```

## Deployment Modes

### Online Mode

Connects to external services for enhanced capabilities:

- **External LLM Providers**: OpenAI, cloud-based services
- **Online Knowledge Sources**: Web APIs, external databases
- **Automatic Updates**: Real-time knowledge updates

```bash
# Force online mode
ruby hackerbot.rb --online
```

### Offline Mode

Operates without external dependencies:

- **Local LLM Processing**: Ollama for on-device AI
- **Built-in Knowledge**: Pre-loaded cybersecurity intelligence
- **Air-Gapped Operation**: Full functionality without internet
- **Enhanced Security**: No external API calls

```bash
# Force offline mode
ruby hackerbot.rb --offline
```

### Individual System Control

Enable only the systems you need for resource efficiency:

```bash
# RAG-only for document retrieval
ruby hackerbot.rb --rag-only

# CAG-only for entity analysis
ruby hackerbot.rb --cag-only

# Both systems (default)
ruby hackerbot.rb --enable-rag-cag
```

## Troubleshooting

### Common Issues

#### Ollama Connection Problems
```bash
# Check if Ollama is running
curl http://localhost:11434/api/tags

# Verify model availability
ollama list

# Restart Ollama service
sudo systemctl restart ollama
```

#### Knowledge Enhancement Issues
```bash
# Test RAG + CAG initialization
ruby demo_rag_cag.rb

# Check knowledge base loading
ruby hackerbot.rb --enable-rag-cag --verbose

# Verify offline mode setup
ruby setup_offline_rag_cag.rb
```

#### Memory and Performance
```bash
# Use individual systems for reduced memory
ruby hackerbot.rb --rag-only

# Disable streaming if experiencing issues
ruby hackerbot.rb --streaming false

# Use smaller models for better performance
ruby hackerbot.rb --ollama-model gemma3:1b
```

### Debug Commands

Enable debug logging for troubleshooting:

```ruby
# In your bot configuration or code
Print.enable_debug = true
```

### Performance Optimization

- **Model Selection**: Use smaller models (gemma3:1b) for faster responses
- **System Control**: Enable only RAG or CAG if you don't need both
- **Caching**: Ensure caching is enabled for better performance
- **Offline Mode**: Use offline mode to eliminate network latency

### Getting Help

1. **Check Documentation**: Review this guide and configuration examples
2. **Test Components**: Use demo scripts to verify individual components
3. **Enable Debugging**: Use debug logging for detailed troubleshooting
4. **Community Support**: Join discussions and report issues

For additional help, consult the [project documentation](../README.md) or [configuration examples](../../config/).

---

*This guide covers all major features and capabilities of Hackerbot. For specific technical details or advanced configurations, refer to the [Configuration Guide](configuration-guide.md) or [Development Documentation](../development/).*