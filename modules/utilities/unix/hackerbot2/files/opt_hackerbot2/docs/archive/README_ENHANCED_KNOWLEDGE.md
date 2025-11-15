# Enhanced Knowledge Sources for RAG/CAG System

## Overview

This document explains the enhanced knowledge sources functionality that extends the RAG (Retrieval-Augmented Generation) and CAG (Context-Aware Generation) system to support man pages and markdown files. This enhancement allows Hackerbot agents to provide comprehensive, context-aware responses based on Unix/Linux command documentation and custom markdown documentation.

## Features

### Man Pages Integration
- **Direct man page access**: Reference Unix/Linux commands by name in XML configuration
- **Automatic content extraction**: Clean and format man page content for RAG processing
- **Knowledge graph integration**: Extract command relationships, file references, and option descriptions
- **Section-aware handling**: Support for all standard man page sections (1-8)
- **Caching**: Intelligent caching system for improved performance

### Markdown Files Integration
- **File-based documentation**: Include custom markdown documentation by path
- **Metadata extraction**: Extract YAML frontmatter, headers, tags, and document structure
- **Directory support**: Automatically load all markdown files from specified directories
- **Content analysis**: Extract code blocks, links, and technical concepts
- **Flexible tagging**: Support for custom tags and automated content categorization

### Enhanced XML Configuration
- **Knowledge sources section**: Define multiple knowledge sources in bot configuration
- **Per-source configuration**: Fine-tune each knowledge source independently
- **Collection management**: Organize documents into logical collections
- **Priority system**: Control knowledge source precedence and weighting

## Configuration

### XML Structure

The enhanced knowledge sources are configured through a new `<knowledge_sources>` section in the bot XML configuration:

```xml
<hackerbot>
  <name>EnhancedKnowledgeBot</name>
  <!-- ... existing configuration ... -->
  
  <!-- Knowledge Sources Configuration -->
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
          <path>docs/security_guide.md</path>
          <collection_name>security_guidelines</collection_name>
          <tags>
            <tag>security</tag>
            <tag>best-practices</tag>
          </tags>
        </markdown_file>
        <directory>
          <path>docs/threat_intelligence/</path>
          <pattern>*.md</pattern>
          <collection_name>threat_intel</collection_name>
        </directory>
      </markdown_files>
    </source>
  </knowledge_sources>
  
  <!-- ... rest of configuration ... -->
</hackerbot>
```

### Configuration Elements

#### Source Configuration
- **type**: `mitre_attack`, `man_pages`, or `markdown_files`
- **name**: Unique identifier for the knowledge source
- **enabled**: Boolean flag to enable/disable the source
- **description**: Human-readable description of the source
- **priority**: Numeric priority (lower numbers = higher priority)

#### Man Pages Configuration
- **man_page**: Individual man page configuration
  - **name**: Man page name (required)
  - **section**: Man section number (1-8, optional)
  - **collection_name**: Logical collection name (optional)

#### Markdown Files Configuration
- **markdown_file**: Individual markdown file configuration
  - **path**: File path to markdown document (required)
  - **collection_name**: Logical collection name (optional)
  - **tags**: Custom tags for categorization (optional)
- **directory**: Directory-based configuration
  - **path**: Directory path containing markdown files
  - **pattern**: File pattern (default: `*.md`)
  - **collection_name**: Logical collection name

## Usage Examples

### Basic Man Pages Configuration

```xml
<knowledge_sources>
  <source>
    <type>man_pages</type>
    <name>essential_tools</name>
    <enabled>true</enabled>
    <man_pages>
      <man_page>
        <name>ssh</name>
        <section>1</section>
        <collection_name>remote_access</collection_name>
      </man_page>
      <man_page>
        <name>scp</name>
        <section>1</section>
        <collection_name>remote_access</collection_name>
      </man_page>
    </man_pages>
  </source>
</knowledge_sources>
```

### Markdown Files with Tags

```xml
<knowledge_sources>
  <source>
    <type>markdown_files</type>
    <name>documentation</name>
    <enabled>true</enabled>
    <markdown_files>
      <markdown_file>
        <path>docs/incident_response.md</path>
        <collection_name>procedures</collection_name>
        <tags>
          <tag>incident-response</tag>
          <tag>procedures</tag>
          <tag>forensics</tag>
        </tags>
      </markdown_file>
    </markdown_files>
  </source>
</knowledge_sources>
```

### Directory-Based Loading

```xml
<knowledge_sources>
  <source>
    <type>markdown_files</type>
    <name>knowledge_base</name>
    <enabled>true</enabled>
    <markdown_files>
      <directory>
        <path>docs/cybersecurity/</path>
        <pattern>*.md</pattern>
        <collection_name>cybersecurity_docs</collection_name>
      </directory>
    </markdown_files>
  </source>
</knowledge_sources>
```

## Implementation Details

### Architecture

The enhanced knowledge system consists of several components:

1. **Knowledge Source Manager**: Coordinates multiple knowledge sources
2. **Base Knowledge Source**: Abstract interface for all knowledge sources
3. **Man Page Processor**: Handles man page extraction and processing
4. **Markdown Processor**: Handles markdown file parsing and analysis
5. **Source-specific Knowledge Classes**: ManPageKnowledgeSource and MarkdownKnowledgeSource

### Processing Pipeline

1. **Configuration Loading**: Parse XML configuration and initialize knowledge sources
2. **Content Extraction**: Extract raw content from man pages and markdown files
3. **Content Processing**: Clean, format, and analyze content
4. **Knowledge Generation**: Create RAG documents and CAG triplets
5. **Integration**: Load processed knowledge into RAG/CAG systems
6. **Query Processing**: Retrieve relevant knowledge during bot interactions

### Caching System

- **Man Pages**: Cache raw man page output for 24 hours
- **Markdown Files**: Cache processed content with file modification tracking
- **Vector Embeddings**: Cache generated embeddings to avoid recomputation
- **Knowledge Graph**: Cache entity relationships and graph structures

## Best Practices

### Man Pages Selection
- Choose frequently used security-relevant commands
- Include tools for network analysis, system administration, and security monitoring
- Consider section numbers (1 for user commands, 8 for administration)
- Test man page availability on target systems

### Markdown File Organization
- Use clear, descriptive file names
- Include YAML frontmatter for metadata
- Structure content with proper headers and formatting
- Include code examples and command references
- Use consistent tagging conventions

### Configuration Management
- Start with a small set of essential knowledge sources
- Organize related content into logical collections
- Use appropriate priorities for knowledge source ordering
- Test configuration changes before deployment
- Monitor performance and adjust caching parameters as needed

## Troubleshooting

### Common Issues

**Man pages not found**
- Verify man page names and sections are correct
- Ensure man command is available on the system
- Check that man pages are installed for the specified commands

**Markdown files not loading**
- Verify file paths are correct and files exist
- Check file permissions and accessibility
- Ensure markdown files have proper extensions (.md, .markdown)

**Performance issues**
- Increase caching time for frequently accessed content
- Reduce the number of knowledge sources or documents
- Optimize vector database and embedding service configuration
- Monitor memory usage and system resources

**Memory constraints**
- Use smaller collections for large document sets
- Implement periodic cleanup of cached content
- Consider using offline mode for reduced memory footprint
- Monitor and adjust chunk sizes for document processing

### Debugging

Enable debug logging to troubleshoot knowledge source issues:

```ruby
# In the bot manager or main application
Print.debug_level = :verbose
```

Check the cache directories for processed content:
- `cache/man_pages/`: Cached man page content
- `cache/markdown/`: Cached markdown file content

## Integration with Existing Systems

### RAG System Integration
The enhanced knowledge sources integrate seamlessly with the existing RAG system:
- Documents are processed into standardized RAG format
- Vector embeddings are generated using configured embedding services
- Retrieval works across all configured knowledge sources
- Relevance scoring considers source priority and content quality

### CAG System Integration
Knowledge sources contribute to the context-aware generation system:
- Entities are extracted from man pages and markdown content
- Relationships are built between commands, files, and concepts
- Graph traversal considers multiple knowledge source types
- Context includes both traditional MITRE knowledge and new sources

### Bot Configuration
Enhanced knowledge sources work with existing bot configurations:
- Compatible with all existing bot features and settings
- Works with individual bot RAG/CAG configurations
- Supports both online and offline operation modes
- Integrates with existing caching and performance optimization

## Examples and Templates

### Security-Focused Bot Configuration

See `config/example_enhanced_knowledge_bot.xml` for a complete example of a security-focused bot with man pages and markdown files integration.

### Sample Knowledge Sources

The `docs/` directory contains example markdown files:
- `network_security_best_practices.md`: Network security guidelines
- `incident_response_procedures.md`: Incident response playbooks
- `threat_intelligence/apt_groups.md`: Threat intelligence information

## Future Enhancements

Planned improvements to the knowledge sources system:

1. **Additional Knowledge Sources**
   - Web scraping and online documentation
   - Database integration (SQL, NoSQL)
   - API-based knowledge sources
   - Real-time threat intelligence feeds

2. **Advanced Processing**
   - Multi-language support
   - Image and diagram analysis
   - Video and multimedia content
   - Interactive code examples

3. **Performance Optimizations**
   - Parallel processing of knowledge sources
   - Incremental updates and delta loading
   - Advanced caching strategies
   - Resource usage optimization

4. **Enhanced Features**
   - Automatic knowledge source discovery
   - Intelligent content categorization
   - Cross-source relationship mapping
   - Interactive knowledge exploration tools

## Support and Community

For help with enhanced knowledge sources:

1. **Documentation**: Check this README and inline code documentation
2. **Examples**: Review the provided configuration examples and demo files
3. **Testing**: Use the demo script to test functionality
4. **Issues**: Report bugs and request features through the project issue tracker
5. **Community**: Join discussions about knowledge management and AI integration

## Contributing

Contributions to the enhanced knowledge sources system are welcome:

1. **Bug Reports**: Submit detailed bug reports with reproduction steps
2. **Feature Requests**: Propose new knowledge source types or capabilities
3. **Documentation**: Improve documentation and examples
4. **Code Contributions**: Submit pull requests for enhancements
5. **Testing**: Help test and validate new features

---

*This enhanced knowledge sources system significantly expands the capabilities of Hackerbot agents, enabling them to provide more comprehensive, accurate, and context-aware responses based on a wide variety of knowledge sources. The system is designed to be extensible, allowing for future integration of additional knowledge source types and advanced processing capabilities.*