require 'nokogiri'
require 'redcarpet'
require 'erb'

# Generates an HTML lab sheet from narrative content, scenario metadata, flags, and CyBOK coverage.
# Used by ProjectFilesCreator to write instructions.html for narrative-enabled scenarios.
class LabSheetGenerator

  # @param [Object] systems list of resolved System objects
  # @param [String] scenario file path to the scenario XML
  # @param [Hash] datastore the $datastore global
  def initialize(systems, scenario, datastore)
    @systems = systems
    @scenario = scenario
    @datastore = datastore
  end

  # Render the full HTML lab sheet
  # @return [String] complete HTML document
  def render
    markdown_body = build_markdown_body
    redcarpet = Redcarpet::Markdown.new(
      Redcarpet::Render::HTML.new(prettify: true, hard_wrap: true, with_toc_data: true),
      footnotes: true, fenced_code_blocks: true, no_intra_emphasis: true,
      autolink: true, highlight: true, lax_spacing: true, tables: true
    )
    body_html = redcarpet.render(markdown_body).force_encoding('UTF-8')

    redcarpet_toc = Redcarpet::Markdown.new(Redcarpet::Render::HTML_TOC.new)
    toc_html = redcarpet_toc.render(markdown_body).force_encoding('UTF-8')

    render_template(toc_html, body_html)
  end

  private

  # Assemble the full markdown body with all sections
  # @return [String] markdown content
  def build_markdown_body
    parts = []

    # 1. Scenario metadata header
    parts << build_header

    # 2. VM access information
    parts << build_vm_access unless vm_info.empty?

    # 3. Narrative introduction (the LLM-generated scenario briefing)
    if @datastore.key?('narrative_introduction') && !@datastore['narrative_introduction'].empty?
      parts << "\n## Scenario Briefing\n\n"
      parts << @datastore['narrative_introduction'].first
    end

    # 4. Your Objectives (derived from scenario description and flags)
    parts << build_objectives

    # 5. Hints (collapsible, from flag_hints.xml data via system modules)
    hints = build_hints
    parts << hints unless hints.empty?

    # 6. CyBOK Knowledge Areas
    cybok = build_cybok
    parts << cybok unless cybok.empty?

    # 7. Flag submission reminder
    parts << build_flag_submission

    parts.join("\n\n")
  end

  # Parse scenario XML for metadata
  # @return [Hash] scenario metadata
  def scenario_metadata
    return @metadata if @metadata
    @metadata = {}
    begin
      doc = Nokogiri::XML(File.read(@scenario))
      doc.remove_namespaces!
      @metadata['name'] = doc.xpath('/scenario/name').first&.content || 'Security Lab'
      @metadata['description'] = doc.xpath('/scenario/description').first&.content || ''
      @metadata['difficulty'] = doc.xpath('/scenario/difficulty').first&.content || ''
      @metadata['author'] = doc.xpath('/scenario/author').map(&:content)
      @metadata['types'] = doc.xpath('/scenario/type').map(&:content)
    rescue => e
      Print.warn "Could not parse scenario metadata for lab sheet: #{e.message}"
    end
    @metadata
  end

  def build_header
    meta = scenario_metadata
    lines = []
    lines << "# #{meta['name']}\n"
    if meta['difficulty'] && !meta['difficulty'].empty?
      lines << "**Difficulty:** #{meta['difficulty'].capitalize}  "
    end
    unless meta['author'].empty?
      lines << "**Author:** #{meta['author'].join(', ')}  "
    end
    if meta['description'] && !meta['description'].empty?
      lines << "\n#{meta['description']}"
    end
    lines.join("\n")
  end

  def build_vm_access
    lines = ["## Accessing the Lab\n"]
    vm_info.each do |vm|
      lines << "\n### #{vm[:name].gsub('_', ' ').capitalize}\n"
      lines << '<div class="system-info">'
      lines << '<table>'
      lines << "<tr><td>IP Address</td><td><code>#{vm[:ip]}</code></td></tr>"
      if vm[:username]
        lines << "<tr><td>Username</td><td><code>#{vm[:username]}</code></td></tr>"
      end
      if vm[:password]
        lines << "<tr><td>Password</td><td><code>#{vm[:password]}</code></td></tr>"
      end
      lines << '</table>'
      lines << '</div>'
    end
    lines.join("\n")
  end

  # Collect VM access info from systems and datastore
  # @return [Array<Hash>] vm info hashes
  def vm_info
    return @vm_info if @vm_info
    @vm_info = []

    ip_data = @datastore['IP_addresses']

    @systems.each_with_index do |system, idx|
      info = { name: system.name }

      # Get IP from datastore or network modules
      system.module_selections.each do |mod|
        if mod.module_type == 'network'
          ip = mod.received_inputs['IP_address']&.first
          if ip
            info[:ip] = ip
            break
          end
        end
      end

      # Get account credentials from parameterised_accounts modules
      system.module_selections.each do |mod|
        if mod.module_path_name&.include?('parameterised_accounts')
          accounts_input = mod.received_inputs['accounts']
          if accounts_input && accounts_input.first
            begin
              account = JSON.parse(accounts_input.first)
              # Use the first non-root, non-super account (the student account)
              student_account = account.is_a?(Array) ? account.first : account
              if student_account
                info[:username] = student_account['username']
                info[:password] = student_account['password']
              end
            rescue JSON::ParserError
              # If it's not JSON, try as a simple value
            end
          end
          break
        end
      end

      @vm_info << info if info[:ip]
    end

    @vm_info
  end

  def build_objectives
    lines = ["## Your Objectives\n"]
    lines << "Your goal is to find and capture flags hidden within the target system(s). "
    lines << "Flags are in the format `flag{SOMETHING}`.\n\n"
    lines << "Use the scenario briefing above to guide your investigation. "
    lines << "Explore the systems, identify vulnerabilities, and extract the flags.\n"

    # Count total flags from systems
    flag_count = 0
    @systems.each do |system|
      system.module_selections.each do |mod|
        mod.output.each do |out|
          flag_count += 1 if out.match?(/\Aflag{.*\z/)
        end
      end
    end
    lines << "There #{flag_count == 1 ? 'is' : 'are'} **#{flag_count} flag#{'s' if flag_count != 1}** to find." if flag_count > 0

    lines.join("\n")
  end

  def build_hints
    lines = ["## Hints\n"]
    hint_count = 0

    @systems.each do |system|
      system.module_selections.each do |mod|
        mod.output.each do |out|
          next unless out.match?(/\Aflag{.*\z/)

          # Walk the module chain to find hints for this flag
          hints_for_flag = collect_hints_for(mod, system.module_selections)
          next if hints_for_flag.empty?

          lines << "\n### Hints for Challenge\n"
          hints_for_flag.each do |hint|
            hint_count += 1
            css_class = hint[:type] == 'big_hint' ? 'hint-big' : ''
            lines << "<details class=\"hint-box #{css_class}\"><summary>Hint (#{hint[:type].gsub('_', ' ').capitalize})</summary>\n\n#{hint[:text]}\n\n</details>"
          end
        end
      end
    end

    hint_count > 0 ? lines.join("\n") : ''
  end

  # Recursively collect hints from the module chain (mirrors XmlMarkerGenerator logic)
  def collect_hints_for(target_mod, all_modules, collected = [], visited = [])
    return collected if visited.include?(target_mod.unique_id)
    visited << target_mod.unique_id

    # Find modules that write to this module
    all_modules.each do |mod|
      if mod.write_to_module_with_id == target_mod.unique_id
        collect_hints_for(mod, all_modules, collected, visited)

        # Generate hints based on module type
        case mod.module_type
        when 'vulnerability'
          if mod.attributes['access']&.first == 'remote'
            collected << { text: 'A vulnerability that can be accessed/exploited remotely. Perhaps try scanning the system/network?', type: 'normal' }
          elsif mod.attributes['access']&.first == 'local'
            collected << { text: 'A vulnerability that can only be accessed/exploited with local access. You need to first find a way in...', type: 'normal' }
          end
          type = mod.attributes['type']&.first
          if type && !%w[system misc ctf local ctf_challenge].include?(type)
            collected << { text: "The system is vulnerable in terms of its #{type}", type: 'big_hint' }
          end
          if mod.attributes['name']&.first
            collected << { text: "The system is vulnerable to #{mod.attributes['name'].first}", type: 'big_hint' }
          end
        when 'service'
          if mod.attributes['type']&.first
            collected << { text: "The flag is hosted using #{mod.attributes['type'].first}", type: 'normal' }
          end
        when 'encoder'
          collected << { text: 'The flag is encoded/hidden somewhere', type: 'normal' }
        end

        # Custom hints from module attributes
        if mod.attributes['hint']
          mod.attributes['hint'].each do |hint|
            collected << { text: hint.tr("\n", ' ').gsub(/\s+/, ' '), type: 'big_hint' }
          end
        end
      end
    end

    collected
  end

  def build_cybok
    return '' if $cybok_coverage.empty?

    lines = ["## CyBOK Knowledge Areas\n"]
    lines << "This exercise covers the following CyBOK (Cyber Security Body of Knowledge) areas:\n"

    seen = []
    $cybok_coverage.each do |cybok_node|
      ka = cybok_node.attr('KA')
      topic = cybok_node.attr('topic')
      key = "#{ka}:#{topic}"
      next if seen.include?(key)
      seen << key

      keywords = cybok_node.xpath('.//keyword').map(&:content)
      lines << "\n**#{ka}** - #{topic}\n"
      keywords.each do |kw|
        lines << "<span class=\"cybok-tag\">#{kw}</span>"
      end
      lines << "\n"
    end

    lines.join("\n")
  end

  def build_flag_submission
    lines = ["## Submitting Flags\n"]
    lines << "> **Remember:** Flags are in the format `flag{SOMETHING}`"
    lines << "> "
    lines << "> Search for text matching this pattern within files, logs, and output on the target systems."
    lines << "> Submit each flag you discover for points."
    lines.join("\n")
  end

  # Render the ERB template with the generated HTML
  # @param [String] toc_html table of contents HTML
  # @param [String] body_html main body HTML
  # @return [String] complete HTML document
  def render_template(toc_html, body_html)
    template_path = File.join(File.dirname(__FILE__), '..', 'templates', 'labsheet.html.erb')
    template = ERB.new(File.read(template_path), trim_mode: '<>-')

    # Set instance variables for the template
    @title = scenario_metadata['name']
    @toc_html = toc_html
    @body_html = body_html

    template.result(binding)
  end
end