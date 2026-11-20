#!/usr/bin/env ruby

require_relative './knowledge_bases/utils/man_page_processor.rb'
require_relative './print.rb'

# Script to check man page content lengths and identify problematic documents
class ManPageChecker
  def initialize
    @processor = ManPageProcessor.new
  end

  def check_man_pages
    Print.info "=== Checking Man Page Content Lengths ==="

    # Check the same man pages that the bot loads
    man_pages_to_check = [
      { name: 'nmap', section: 1 },
      { name: 'tcpdump', section: 1 },
      { name: 'curl', section: 1 },
      { name: 'wget', section: 1 },
      { name: 'sudo', section: 8 },
      { name: 'iptables', section: 8 },
      { name: 'ssh', section: 1 },
      { name: 'openssl', section: 1 },
      { name: 'ps', section: 1 },
      { name: 'netstat', section: 8 },
      { name: 'chmod', section: 1 },
      { name: 'chown', section: 1 }
    ]

    max_allowed = 8192
    max_safe = 7000

    problematic_pages = []
    safe_pages = []

    man_pages_to_check.each do |man_config|
      name = man_config[:name]
      section = man_config[:section]

      begin
        # Get the formatted document as it would be created
        doc = @processor.to_rag_document(name, section)

        if doc
          content_length = doc[:content].length

          Print.info "#{name} (#{section}): #{content_length} characters"

          if content_length > max_allowed
            Print.err "❌ EXCEEDS LIMIT by #{content_length - max_allowed} chars"
            problematic_pages << { name: name, section: section, length: content_length }
          elsif content_length > max_safe
            Print.warn "⚠️  Close to limit (#{content_length} chars)"
            problematic_pages << { name: name, section: section, length: content_length }
          else
            Print.info "✅ Safe length"
            safe_pages << { name: name, section: section, length: content_length }
          end
        else
          Print.warn "⚠️  Could not get document for #{name}"
        end
      rescue => e
        Print.err "❌ Error checking #{name}: #{e.message}"
        problematic_pages << { name: name, section: section, error: e.message }
      end
    end

    Print.info "\n=== Summary ==="
    Print.info "Safe pages: #{safe_pages.length}"
    Print.info "Problematic pages: #{problematic_pages.length}"

    if problematic_pages.any?
      Print.warn "\nProblematic pages:"
      problematic_pages.each do |page|
        if page[:error]
          Print.warn "  #{page[:name]}: Error - #{page[:error]}"
        else
          Print.warn "  #{page[:name]}: #{page[:length]} chars"
        end
      end

      Print.warn "\nRecommended max_content_length for chunking:"
      max_length = problematic_pages.map { |p| p[:length] || 0 }.max
      recommended = [max_length - 2000, 4000].max
      Print.info "  Recommended: #{recommended} characters"
    end

    return problematic_pages.empty?
  end
end

# Run the check
if __FILE__ == $0
  checker = ManPageChecker.new
  success = checker.check_man_pages

  if success
    Print.info "\n🎉 All man pages are within safe limits!"
  else
    Print.info "\n⚠️  Some man pages need chunking adjustments."
  end
end
```
