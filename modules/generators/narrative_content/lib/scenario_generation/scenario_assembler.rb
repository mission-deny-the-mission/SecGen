require 'fileutils'
require_relative 'scenario_artifact'

module ScenarioGeneration
  # Builds a complete, XSD-valid SecGen scenario.xml from a normalized Intent and
  # an Array of ModuleArtifact: scenario metadata, one target system referencing
  # each generated module by module_path regex, deterministic flag values wired
  # through datastores, a private network, a cleanup build, and an optional
  # attacker system for attack_ctf scenarios. Also writes a documentation stub.
  #
  # Output is built as deterministic strings (no absolute staging paths embedded)
  # so regeneration is byte-identical for the section 7 manifest hashes.
  class ScenarioAssembler
    SCENARIO_NAMESPACE = 'http://www.github/cliffe/SecGen/scenario'.freeze

    # intent scenario_type -> scenario <type> vocabulary
    TYPE_MAP = {
      'attack_ctf' => 'attack-ctf',
      'ctf' => 'ctf',
      'lab' => 'lab-sheet',
      'security_audit' => 'security_audit'
    }.freeze

    # intent difficulty -> scenario <difficulty> vocabulary (documented in section 8 docs)
    DIFFICULTY_MAP = {
      'easy' => 'easy',
      'medium' => 'intermediate',
      'hard' => 'intermediate',
      'advanced' => 'intermediate'
    }.freeze

    def initialize(intent:, modules:, staging_dir:, adapter: nil)
      @intent = intent
      @modules = Array(modules)
      @staging_dir = staging_dir
      @adapter = adapter
      @identifiers = intent.identifiers
      @generated_files = []
    end

    def assemble
      xml = to_xml
      scenario_relpath = File.join('scenarios', 'generated', @identifiers['scenario_file'])
      doc_relpath = File.join('docs', "#{@identifiers['scenario_slug']}.md")

      staged_scenario_path = write_staged(scenario_relpath, xml)
      doc_stub_path = write_staged(doc_relpath, build_doc_stub)

      ScenarioArtifact.new(
        'scenario_file' => @identifiers['scenario_file'],
        'staged_scenario_path' => staged_scenario_path,
        'scenario_relpath' => scenario_relpath,
        'xml' => xml,
        'system_names' => system_names,
        'module_selectors' => @modules.map { |mod| mod['selection_regex'] },
        'datastores' => datastore_entries.map { |entry| entry['datastore'] },
        'doc_stub_path' => doc_stub_path,
        'doc_relpath' => doc_relpath
      )
    end

    def to_xml
      lines = []
      lines << '<?xml version="1.0"?>'
      lines << "<scenario xmlns=\"#{SCENARIO_NAMESPACE}\""
      lines << '          xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"'
      lines << "          xsi:schemaLocation=\"#{SCENARIO_NAMESPACE}\">"
      build_metadata(lines)
      build_target_system(lines)
      build_attacker_system(lines) if attacker_required?
      lines << '</scenario>'
      lines.join("\n") + "\n"
    end

    private

    def system_names
      names = [@identifiers['system_name']]
      names << "#{@identifiers['system_name']}_attacker" if attacker_required?
      names
    end

    def attacker_required?
      @intent.normalized['scenario_type'] == 'attack_ctf'
    end

    def build_metadata(lines)
      lines << "  <name>#{escape(@intent['name'])}</name>"
      lines << '  <author>SecGen Scenario Generator (generated)</author>'
      lines << "  <description>#{escape(scenario_description)}</description>"
      lines << "  <type>#{escape(scenario_type)}</type>"
      lines << "  <difficulty>#{escape(scenario_difficulty)}</difficulty>"
      cybok_entries.each do |entry|
        lines << "  <CyBOK KA=\"#{escape(entry['ka'])}\" topic=\"#{escape(entry['topic'])}\">"
        keywords_for(entry).each { |keyword| lines << "    <keyword>#{escape(keyword)}</keyword>" }
        lines << '  </CyBOK>'
      end
    end

    def build_target_system(lines)
      lines << '  <system>'
      lines << "    <system_name>#{@identifiers['system_name']}</system_name>"
      lines << '    <base platform="linux" type="server"/>'

      # Precompute each module's deterministic flag values into named datastores.
      datastore_entries.each do |entry|
        lines << "    <input into_datastore=\"#{escape(entry['datastore'])}\">"
        lines << "      <value>#{escape(entry['value'])}</value>"
        lines << '    </input>'
      end

      # One vulnerability element per generated module, consuming its flag datastores.
      @modules.each { |mod| build_vulnerability(lines, mod) }

      lines << '    <network type="private_network"/>'
      lines << '    <build type="cleanup">'
      lines << '      <input into="root_password">'
      lines << '        <generator type="strong_password_generator"/>'
      lines << '      </input>'
      lines << '    </build>'
      lines << '  </system>'
    end

    def build_vulnerability(lines, mod)
      lines << "    <vulnerability module_path=\"#{escape(mod['selection_regex'])}\">"
      flags_by_target(mod).each do |target, flags|
        lines << "      <input into=\"#{escape(target)}\">"
        flags.each do |flag|
          lines << "        <datastore>#{escape(datastore_name(mod, flag))}</datastore>"
        end
        lines << '      </input>'
      end
      lines << '    </vulnerability>'
    end

    def build_attacker_system(lines)
      lines << '  <system>'
      lines << "    <system_name>#{@identifiers['system_name']}_attacker</system_name>"
      lines << '    <base distro="Kali" type="desktop"/>'
      lines << '    <utility/>'
      lines << '    <network type="private_network"/>'
      lines << '  </system>'
    end

    # Flattened list of { 'datastore' => name, 'value' => flag value, ... } across all modules.
    def datastore_entries
      @datastore_entries ||= @modules.flat_map do |mod|
        Array(mod['flags']).map do |flag|
          {
            'datastore' => datastore_name(mod, flag),
            'value' => flag['value'],
            'target' => flag['target']
          }
        end
      end
    end

    def flags_by_target(mod)
      Array(mod['flags']).group_by { |flag| flag['target'] }
    end

    def datastore_name(mod, flag)
      snake("#{mod['module_name']}_#{flag['name']}")
    end

    def cybok_entries
      Array(@intent.normalized['cybok'])
    end

    def keywords_for(entry)
      keywords = Array(entry['keywords']).map(&:to_s).reject(&:empty?)
      keywords.empty? ? [entry['topic'].to_s] : keywords
    end

    def scenario_type
      TYPE_MAP[@intent.normalized['scenario_type']] || @intent.normalized['scenario_type']
    end

    def scenario_difficulty
      DIFFICULTY_MAP[@intent.normalized['difficulty']] || @intent.normalized['difficulty']
    end

    def scenario_description
      base = @intent['description'].to_s.strip
      summary = "Generated #{@modules.map { |m| m['vulnerability_class'] }.uniq.join(', ')} scenario."
      base.empty? ? summary : base
    end

    def build_doc_stub
      lines = []
      lines << "# #{@intent['name']}"
      lines << ''
      lines << '> Review status: generated — not yet reviewed'
      lines << ''
      lines << '## Purpose'
      lines << ''
      lines << scenario_description
      lines << ''
      lines << '## Learning outcomes'
      lines << ''
      Array(@intent.normalized['learning_outcomes']).each { |outcome| lines << "- #{outcome}" }
      lines << ''
      lines << '## Systems'
      lines << ''
      system_names.each { |name| lines << "- `#{name}`" }
      lines << ''
      lines << '## Vulnerability classes'
      lines << ''
      @modules.map { |mod| mod['vulnerability_class'] }.uniq.each { |vc| lines << "- #{vc}" }
      lines << ''
      lines << '## Validation commands'
      lines << ''
      validation_command_lines.each { |line| lines << "- `#{line}`" }
      lines << ''
      lines.join("\n")
    end

    # Deterministic, relative validation commands sourced from each module's
    # validation hooks (never adapter commands, which embed absolute staging paths).
    def validation_command_lines
      commands = @modules.flat_map do |mod|
        Array(mod['validation_hooks']).map { |hook| Array(hook['command']).join(' ') }
      end
      commands.reject(&:empty?).uniq
    end

    def write_staged(relpath, content)
      abs = File.expand_path(File.join(@staging_dir, relpath))
      ensure_within_staging!(abs)
      begin
        @adapter.validate_staged_paths!([abs]) if @adapter
      rescue HarnessError => e
        raise ScenarioAssemblyError, "Rejected staged write: #{e.message}"
      end
      FileUtils.mkdir_p(File.dirname(abs))
      File.write(abs, content)
      @generated_files << relpath
      abs
    end

    def ensure_within_staging!(abs)
      root = File.expand_path(@staging_dir)
      return if abs == root || abs.start_with?("#{root}#{File::SEPARATOR}")

      raise ScenarioAssemblyError, "Refusing to write outside staging: #{abs}"
    end

    def snake(value)
      value.to_s.strip.downcase.gsub(/[^a-z0-9]+/, '_').gsub(/\A_|_+\z/, '')
    end

    # Characters outside the XML 1.0 Char production produce malformed XML even
    # when entity-escaped, so strip them before escaping.
    XML_INVALID_CHARS = /[^\u0009\u000A\u000D\u0020-\uD7FF\uE000-\uFFFD\u{10000}-\u{10FFFF}]/.freeze

    def escape(value)
      value.to_s
           .gsub(XML_INVALID_CHARS, '')
           .gsub('&', '&amp;')
           .gsub('<', '&lt;')
           .gsub('>', '&gt;')
           .gsub('"', '&quot;')
    end
  end
end
