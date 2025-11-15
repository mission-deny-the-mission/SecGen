<?xml version="1.0" encoding="UTF-8"?>
<hackerbot>
  <!-- Basic Information -->
  <name>MyBot</name>
  <llm_provider>ollama</llm_provider>
  
  <!-- LLM Configuration -->
  <ollama_model>gemma3:1b</ollama_model>
  <system_prompt>You are a helpful assistant.</system_prompt>
  
  <!-- Knowledge Enhancement -->
  <rag_cag_enabled>true</rag_cag_enabled>
  
  <!-- Training Scenarios -->
  <attacks>
    <!-- Attack scenarios go here -->
  </attacks>
  
  <!-- Bot Messages -->
  <messages>
    <greeting>Hello!</greeting>
    <goodbye>Goodbye!</goodbye>
  </messages>
</hackerbot>
```

## LLM Provider Configuration

### Ollama Configuration

```xml
<hackerbot>
  <name>OllamaBot</name>
  <llm_provider>ollama</llm_provider>
  
  <!-- Ollama-specific settings -->
  <ollama_model>gemma3:1b</ollama_model>
  <ollama_host>localhost</ollama_host>
  <ollama_port>11434</ollama_port>
  
  <!-- Response settings -->
  <streaming>true</streaming>
  <max_tokens>2000</max_tokens>
  <temperature>0.7</temperature>
  
  <system_prompt>You are a cybersecurity training assistant with expertise in network security and ethical hacking.</system_prompt>
</hackerbot>
```

**Available Ollama Models:**
- `gemma3:1b` - Fast, suitable for basic interactions
- `llama2` - Balanced performance and capability
- `mistral` - Good for technical content
- `codellama` - Excellent for code-related queries

### OpenAI Configuration

```xml
<hackerbot>
  <name>OpenAIBot</name>
  <llm_provider>openai</llm_provider>
  
  <!-- OpenAI-specific settings -->
  <openai_model>gpt-3.5-turbo</openai_model>
  <openai_api_key>your-api-key-here</openai_api_key>
  <!-- Optional: Custom OpenAI-compatible API base URL -->
  <!-- <openai_base_url>http://localhost:8080/v1</openai_base_url> -->
  
  <!-- Response settings -->
  <streaming>true</streaming>
  <max_tokens>2000</max_tokens>
  <temperature>0.7</temperature>
  
  <system_prompt>You are an expert cybersecurity instructor specializing in penetration testing and defense strategies.</system_prompt>
</hackerbot>
```

**Available OpenAI Models:**
- `gpt-3.5-turbo` - Fast and cost-effective
- `gpt-4` - Higher quality, more expensive
- `gpt-4-turbo` - Latest GPT-4 model

### VLLM Configuration

```xml
<hackerbot>
  <name>VLLMBot</name>
  <llm_provider>vllm</llm_provider>
  
  <!-- VLLM-specific settings -->
  <vllm_model>llama2</vllm_model>
  <vllm_host>localhost</vllm_host>
  <vllm_port>8000</vllm_port>
  
  <!-- Response settings -->
  <streaming>true</streaming>
  <max_tokens>2000</max_tokens>
  <temperature>0.7</temperature>
  
  <system_prompt>You are a high-performance cybersecurity training bot optimized for rapid response and comprehensive explanations.</system_prompt>
</hackerbot>
```

### SGLang Configuration

```xml
<hackerbot>
  <name>SGLangBot</name>
  <llm_provider>sglang</llm_provider>
  
  <!-- SGLang-specific settings -->
  <sglang_model>llama2</sglang_model>
  <sglang_host>localhost</sglang_host>
  <sglang_port>30000</sglang_port>
  
  <!-- Response settings -->
  <streaming>true</streaming>
  <max_tokens>2000</max_tokens>
  <temperature>0.7</temperature>
  
  <system_prompt>You are a structured language generation expert specializing in cybersecurity documentation and technical explanations.</system_prompt>
</hackerbot>
```

## Knowledge Enhancement Configuration

### RAG + CAG Configuration

```xml
<hackerbot>
  <name>KnowledgeEnhancedBot</name>
  <rag_cag_enabled>true</rag_cag_enabled>
  
  <!-- Individual system control -->
  <rag_enabled>true</rag_enabled>
  <cag_enabled>true</cag_enabled>
  
  <!-- Entity extraction -->
  <entity_extraction_enabled>true</entity_extraction_enabled>
  <entity_types>ip_address, url, hash, filename, port, email, domain</entity_types>
  
  <!-- RAG + CAG detailed configuration -->
  <rag_cag_config>
    <!-- RAG settings -->
    <rag>
      <max_rag_results>7</max_rag_results>
      <include_rag_context>true</include_rag_context>
      <collection_name>cybersecurity_knowledge</collection_name>
      <similarity_threshold>0.7</similarity_threshold>
      <chunk_size>1000</chunk_size>
      <chunk_overlap>200</chunk_overlap>
    </rag>
    
    <!-- CAG settings -->
    <cag>
      <max_cag_depth>3</max_cag_depth>
      <max_cag_nodes>25</max_cag_nodes>
      <include_cag_context>true</include_cag_context>
      <entity_types>ip_address, url, hash, filename, port, email</entity_types>
    </cag>
  </rag_cag_config>
</hackerbot>
```

### Knowledge Sources Configuration

```xml
<hackerbot>
  <name>ComprehensiveKnowledgeBot</name>
  <rag_cag_enabled>true</rag_cag_enabled>
  
  <knowledge_sources>
    <!-- MITRE ATT&CK Framework (always included by default) -->
    <source>
      <type>mitre_attack</type>
      <name>mitre_attack</name>
      <enabled>true</enabled>
      <description>MITRE ATT&CK framework knowledge base</description>
      <priority>1</priority>
    </source>
    
    <!-- Man Pages Knowledge Source -->
    <source>
      <type>man_pages</type>
      <name>security_tools</name>
      <enabled>true</enabled>
      <description>Unix/Linux security tools man pages</description>
      <priority>2</priority>
      <man_pages>
        <man_page>
          <name>nmap</name>
          <section>1</section>
          <collection_name>network_scanning_tools</collection_name>
        </man_page>
        <man_page>
          <name>iptables</name>
          <section>8</section>
          <collection_name>firewall_tools</collection_name>
        </man_page>
        <man_page>
          <name>ssh</name>
          <section>1</section>
          <collection_name>remote_access_tools</collection_name>
        </man_page>
        <man_page>
          <name>wireshark</name>
          <section>1</section>
          <collection_name>network_analysis_tools</collection_name>
        </man_page>
        <man_page>
          <name>metasploit</name>
          <section>1</section>
          <collection_name>penetration_testing_tools</collection_name>
        </man_page>
      </man_pages>
    </source>
    
    <!-- Markdown Files Knowledge Source -->
    <source>
      <type>markdown_files</type>
      <name>cybersecurity_docs</name>
      <enabled>true</enabled>
      <description>Custom cybersecurity documentation</description>
      <priority>3</priority>
      <markdown_files>
        <markdown_file>
          <path>docs/incident_response_procedures.md</path>
          <collection_name>procedures</collection_name>
          <tags>
            <tag>incident-response</tag>
            <tag>procedures</tag>
            <tag>forensics</tag>
          </tags>
        </markdown_file>
        <markdown_file>
          <path>docs/network_security_best_practices.md</path>
          <collection_name>best_practices</collection_name>
          <tags>
            <tag>security</tag>
            <tag>best-practices</tag>
            <tag>network</tag>
          </tags>
        </markdown_file>
        <!-- Directory-based loading -->
        <directory>
          <path>docs/threat_intelligence/</path>
          <pattern>*.md</pattern>
          <collection_name>threat_intel</collection_name>
        </directory>
      </markdown_files>
    </source>
  </knowledge_sources>
</hackerbot>
```

## Training Scenarios Configuration

### Social Engineering Training Bot

```xml
<?xml version="1.0" encoding="UTF-8"?>
<hackerbot>
  <name>SocialEngineeringTrainingBot</name>
  <llm_provider>ollama</llm_provider>
  <ollama_model>gemma3:1b</ollama_model>
  <system_prompt>You are a cybersecurity training assistant specializing in social engineering awareness and defense.</system_prompt>
  <rag_cag_enabled>true</rag_cag_enabled>
  
  <attacks>
    <!-- Stage 1: Educational Introduction -->
    <attack>
      <prompt>Learn about social engineering techniques and how to recognize them.</prompt>
      <system_prompt>You are a cybersecurity expert providing an educational introduction to social engineering. Explain common techniques, psychological principles, and warning signs that students should be aware of. Be informative and helpful.</system_prompt>
      <post_command>echo "Social engineering education completed"</post_command>
      <condition>
        <output_matches>Social engineering education completed</output_matches>
        <message>Excellent! You've learned the fundamentals of social engineering. Now let's practice identifying these techniques in realistic scenarios. Type 'next' to continue to the practical exercise.</message>
        <trigger_next_attack>true</trigger_next_attack>
      </condition>
    </attack>
    
    <!-- Stage 2: Customer Service Scenario -->
    <attack>
      <prompt>Practice social engineering against a bank customer service agent. Try to get them to reveal customer information or reset a password without proper verification.</prompt>
      <system_prompt>You are a customer service agent at MetroBank. You are helpful and want to assist customers, but you're somewhat gullible and eager to please. You have access to customer account information and password reset capabilities. You sometimes skip verification procedures if the customer seems legitimate or in a hurry. You're proud of your customer satisfaction scores and want to maintain them.</system_prompt>
      <post_command>echo "Customer service scenario completed"</post_command>
      <condition>
        <output_matches>Customer service scenario completed</output_matches>
        <message>Well done! You've practiced social engineering against a customer service target. Notice how trust, urgency, and authority can be used to bypass security procedures. Type 'next' to continue to the next scenario.</message>
        <trigger_next_attack>true</trigger_next_attack>
      </condition>
    </attack>
    
    <!-- Stage 3: IT Administrator Scenario -->
    <attack>
      <prompt>Attempt to gain system access by manipulating an IT administrator. Create a convincing scenario that requires immediate administrative action.</prompt>
      <system_prompt>You are an IT administrator at TechCorp. You're responsible for system maintenance and user support. You're security-conscious but can be overwhelmed during busy periods. You respond well to authority and emergency situations. You have administrative access to company systems and want to help resolve issues quickly.</system_prompt>
      <post_command>echo>IT administrator scenario completed</post_command>
      <condition>
        <output_matches>IT administrator scenario completed</output_matches>
        <message>Great work! You've practiced against an IT administrator target. This scenario demonstrates how technical authority and urgency can be effective social engineering tools. Type 'next' for the final challenge.</message>
        <trigger_next_attack>true</trigger_next_attack>
      </condition>
    </attack>
    
    <!-- Stage 4: Executive Assistant Scenario -->
    <attack>
      <prompt>Try to obtain sensitive executive information by manipulating the CEO's assistant. This is the most challenging scenario.</prompt>
      <system_prompt>You are the executive assistant to the CEO of a major corporation. You're professional, loyal, and protective of your boss. You're accustomed to handling sensitive information and dealing with important people. You're trained in security protocols but can be influenced by perceived authority, urgency, or threats to your company/CEO. You want to be helpful but also need to maintain confidentiality.</system_prompt>
      <post_command>echo>Executive assistant scenario completed</post_command>
      <condition>
        <output_matches>Executive assistant scenario completed</output_matches>
        <message>Outstanding! You've completed all social engineering scenarios. You've experienced how different personality types and professional roles respond to social engineering techniques. flag{social_engineering_mastery_achieved}</message>
        <trigger_next_attack>false</trigger_next_attack>
      </condition>
    </attack>
  </attacks>
  
  <messages>
    <greeting>Welcome to Social Engineering Training! I'll help you understand and practice identifying social engineering techniques through realistic scenarios. Type 'help' for available commands.</greeting>
    <goodbye>Great job completing the social engineering training! Remember these techniques for both offense and defense.</goodbye>
    <help>Available commands: next (advance to next scenario), current (show current scenario), reset (restart current scenario), clear_history, show_history, help</help>
    <unknown>I'm here to help you learn about social engineering. Try asking about the current scenario or use the commands listed above.</unknown>
  </messages>
</hackerbot>
```

### Network Security Training Bot

```xml
<?xml version="1.0" encoding="UTF-8"?>
<hackerbot>
  <name>NetworkSecurityBot</name>
  <llm_provider>ollama</llm_provider>
  <ollama_model>gemma3:1b</ollama_model>
  <system_prompt>You are a network security expert providing training on network defense, monitoring, and attack detection.</system_prompt>
  <rag_cag_enabled>true</rag_cag_enabled>
  
  <!-- Enhanced with network security knowledge -->
  <knowledge_sources>
    <source>
      <type>man_pages</type>
      <name>network_tools</name>
      <enabled>true</enabled>
      <man_pages>
        <man_page>
          <name>nmap</name>
          <section>1</section>
          <collection_name>scanning_tools</collection_name>
        </man_page>
        <man_page>
          <name>tcpdump</name>
          <section>1</section>
          <collection_name>analysis_tools</collection_name>
        </man_page>
        <man_page>
          <name>iptables</name>
          <section>8</section>
          <collection_name>firewall_tools</collection_name>
        </man_page>
      </man_pages>
    </source>
    <source>
      <type>markdown_files</type>
      <name>security_docs</name>
      <enabled>true</enabled>
      <markdown_files>
        <markdown_file>
          <path>docs/network_security_best_practices.md</path>
          <collection_name>best_practices</collection_name>
        </markdown_file>
      </markdown_files>
    </source>
  </knowledge_sources>
  
  <attacks>
    <attack>
      <prompt>Learn about network scanning techniques and defensive countermeasures.</prompt>
      <system_prompt>You are a network security instructor teaching about network scanning techniques, tools, and defensive strategies. Cover port scanning, service detection, vulnerability scanning, and how to detect and prevent scanning activities.</system_prompt>
      <post_command>echo "Network scanning training completed"</post_command>
      <condition>
        <output_matches>Network scanning training completed</output_matches>
        <message>Excellent! You've learned about network scanning fundamentals. Type 'next' to continue to practical defense scenarios.</message>
        <trigger_next_attack>true</trigger_next_attack>
      </condition>
    </attack>
    
    <attack>
      <prompt>Analyze network traffic logs and identify potential security incidents.</prompt>
      <system_prompt>You are a security operations center (SOC) analyst. You're reviewing network logs and traffic patterns. Provide students with log excerpts and traffic data, asking them to identify suspicious activities, potential breaches, or attack patterns. Guide them through the analysis process.</system_prompt>
      <post_command>echo>Log analysis exercise completed</post_command>
      <condition>
        <output_matches>Log analysis exercise completed</output_matches>
        <message>Well done! You've practiced network traffic analysis. Type 'next' to continue to firewall configuration.</message>
        <trigger_next_attack>true</trigger_next_attack>
      </condition>
    </attack>
    
    <attack>
      <prompt>Configure firewall rules to defend against network attacks.</prompt>
      <system_prompt>You are a network security engineer specializing in firewall configuration. Students will need to configure firewall rules to block specific attack patterns while allowing legitimate traffic. Provide scenarios and ask for rule recommendations, explaining the reasoning behind each rule.</system_prompt>
      <post_command>echo>Firewall configuration completed</post_command>
      <condition>
        <output_matches>Firewall configuration completed</output_matches>
        <message>Perfect! You've completed the network security training module. You now understand scanning techniques, traffic analysis, and firewall configuration. flag{network_security_certified}</message>
        <trigger_next_attack>false</trigger_next_attack>
      </condition>
    </attack>
  </attacks>
</hackerbot>
```

### AI Security Training Bot

```xml
<?xml version="1.0" encoding="UTF-8"?>
<hackerbot>
  <name>AISecurityBot</name>
  <llm_provider>ollama</llm_provider>
  <ollama_model>gemma3:1b</ollama_model>
  <system_prompt>You are an AI security expert teaching about prompt injection, AI vulnerabilities, and defensive measures.</system_prompt>
  <rag_cag_enabled>true</rag_cag_enabled>
  
  <attacks>
    <attack>
      <prompt>Learn about AI security vulnerabilities and prompt injection techniques.</prompt>
      <system_prompt>You are an AI security researcher explaining the fundamentals of AI system vulnerabilities, prompt injection, data poisoning, and model extraction attacks. Provide comprehensive coverage of these emerging security concerns.</system_prompt>
      <post_command>echo>AI security fundamentals completed</post_command>
      <condition>
        <output_matches>AI security fundamentals completed</output_matches>
       
