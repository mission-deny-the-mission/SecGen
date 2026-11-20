#!/usr/bin/env ruby

# Script to update the default knowledge sources configuration in rag_cag_manager.rb

def update_default_knowledge_sources
  Print.info "Updating default knowledge sources configuration..."

  rag_cag_file = 'rag_cag_manager.rb'

  # Read the current file
  content = File.read(rag_cag_file)

  # Find and replace the default_knowledge_sources_config method
  old_method = <<~RUBY
  def default_knowledge_sources_config
    [
      {
        type: 'mitre_attack',
        name: 'mitre_attack',
        enabled: true,
        description: 'MITRE ATT&CK framework knowledge base',
        priority: 1
      }
    ]
  end
  RUBY

  new_method = <<~RUBY
  def default_knowledge_sources_config
    [
      # MITRE ATT&CK Framework
      {
        type: 'mitre_attack',
        name: 'mitre_attack',
        enabled: true,
        description: 'MITRE ATT&CK framework knowledge base',
        priority: 1
      },

      # Common cybersecurity man pages
      {
        type: 'man_pages',
        name: 'cybersecurity_man_pages',
        enabled: true,
        description: 'Common cybersecurity and security tool man pages',
        priority: 2,
        man_pages: [
          # Network security tools
          { name: 'nmap', section: 1, collection_name: 'cybersecurity' },
          { name: 'tcpdump', section: 1, collection_name: 'cybersecurity' },
          { name: 'curl', section: 1, collection_name: 'cybersecurity' },
          { name: 'wget', section: 1, collection_name: 'cybersecurity' },

          # System security tools
          { name: 'sudo', section: 8, collection_name: 'cybersecurity' },
          { name: 'iptables', section: 8, collection_name: 'cybersecurity' },
          { name: 'ssh', section: 1, collection_name: 'cybersecurity' },
          { name: 'openssl', section: 1, collection_name: 'cybersecurity' },

          # Basic system tools
          { name: 'ps', section: 1, collection_name: 'cybersecurity' },
          { name: 'netstat', section: 8, collection_name: 'cybersecurity' },
          { name: 'chmod', section: 1, collection_name: 'cybersecurity' },
          { name: 'chown', section: 1, collection_name: 'cybersecurity' }
        ]
      },

      # Project documentation
      {
        type: 'markdown_files',
        name: 'project_docs',
        enabled: true,
        description: 'Project documentation and guides',
        priority: 3,
        markdown_files: [
          { path: 'README.md', collection_name: 'cybersecurity' },
          { path: 'QUICKSTART.md', collection_name: 'cybersecurity' },
          { path: 'docs/*.md', collection_name: 'cybersecurity' }
        ]
      }
    ]
  end
  RUBY

  if content.include?(old_method)
    content.gsub!(old_method, new_method)
    File.write(rag_cag_file, content)
    Print.info "✅ Updated default knowledge sources configuration"
    Print.info "Now includes MITRE ATT&CK, man pages, and project documentation"
  else
    Print.warn "⚠️  Could not find the default_knowledge_sources_config method to update"
  end
end

# Load the Print module
require_relative './print.rb'

# Run the update
update_default_knowledge_sources
```

Now let me test the knowledge base population script to see if it works:
