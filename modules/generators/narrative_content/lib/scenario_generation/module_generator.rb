require 'digest'
require 'fileutils'
require_relative 'module_artifact'

module ScenarioGeneration
  # Renders a complete, XSD-valid SecGen vulnerability module skeleton into the
  # staging directory from a normalized Intent + one selected TemplateMetadata,
  # and returns a ModuleArtifact describing it.
  #
  # All output is a pure function of (seed, intent identifiers, template content)
  # so regeneration is byte-identical (required by the section 7 manifest hashes).
  # XML is emitted as deterministic strings; Nokogiri is used only to VALIDATE
  # (in tests and the section 6 validator), never to format generated output.
  class ModuleGenerator
    METADATA_NAMESPACE = 'http://www.github/cliffe/SecGen/vulnerability'.freeze

    # intent difficulty (easy/medium/hard/advanced) -> XSD difficultyOptions
    DIFFICULTY_MAP = {
      'easy' => 'low',
      'medium' => 'medium',
      'hard' => 'high',
      'advanced' => 'high'
    }.freeze

    # module_name lets a caller assign a unique on-disk identity when a single
    # scenario generates more than one module (one per vulnerability class);
    # it defaults to the scenario-level identifier for the single-module case.
    def initialize(intent:, template:, staging_dir:, adapter: nil, seed: nil, module_name: nil)
      @intent = intent
      @template = template
      @staging_dir = staging_dir
      @adapter = adapter
      @seed = seed || intent.normalized['seed']
      @identifiers = intent.identifiers
      @module_name = module_name || @identifiers['module_name']
      @module_path = File.join('modules', 'vulnerabilities', 'generated', @module_name)
      @staged_module_dir = File.join(staging_dir, @module_path)
      @generated_files = []
    end

    def generate
      write_metadata_xml
      write_entry_pp
      write_manifests
      write_templates
      write_test_stub

      ModuleArtifact.new(
        'module_name' => @module_name,
        'module_path' => @module_path,
        'staged_module_dir' => @staged_module_dir,
        'metadata_path' => File.join(@module_path, 'secgen_metadata.xml'),
        'puppet_entry' => "#{@module_name}.pp",
        'vulnerability_class' => @template['vulnerability_class'],
        'read_facts' => read_facts,
        'rendered_parameters' => rendered_parameters,
        'flags' => rendered_flags,
        'required_files' => @generated_files.dup.sort,
        'generated_files' => @generated_files.dup.sort,
        'validation_hooks' => Array(@template['tests']['validation_hooks']),
        'selection_regex' => ".*/#{@module_name}"
      )
    end

    # Public: each template parameter resolved deterministically to its value.
    def rendered_parameters
      @rendered_parameters ||= Array(@template['parameters']).each_with_object({}) do |parameter, result|
        result[parameter['name']] = render_parameter(parameter)
      end
    end

    private

    def render_parameter(parameter)
      type = parameter['type'].to_s
      target = parameter['target'].to_s

      case [type, target]
      when %w[flag strings_to_leak], %w[flag file_content]
        flag_value(parameter['name'])
      else
        case type
        when 'flag'
          flag_value(parameter['name'])
        when 'datastore'
          "#{@identifiers['datastore_prefix']}_#{parameter['name']}"
        when 'enum'
          if parameter['name'] == 'difficulty'
            @intent.normalized['difficulty']
          else
            Array(parameter['values']).first || parameter['default']
          end
        else
          parameter['default'] || ''
        end
      end
    end

    # Deterministic flag value, pure function of seed + module + flag name.
    def flag_value(flag_name)
      digest = Digest::SHA256.hexdigest("#{@seed}:#{@module_name}:#{flag_name}")
      "FLAG{#{digest[0, 16]}}"
    end

    def rendered_flags
      flags = Array(@template['flags'])
      flags = [{ 'name' => 'scenario_flag', 'target' => 'strings_to_leak' }] if flags.empty?
      flags.map do |flag|
        {
          'name' => flag['name'],
          'target' => flag['target'] || 'strings_to_leak',
          'value' => flag_value(flag['name'])
        }
      end
    end

    # default_input targets the Puppet code reads; read_facts MUST be a superset
    # of every default_input 'into' or SecGen aborts the build.
    def default_inputs
      inputs = [['port', ['80']]]
      rendered_flags.each do |flag|
        inputs << [flag['target'], [flag['value']]]
      end
      inputs << ['leaked_filenames', ['flag.txt']]
      inputs
    end

    def read_facts
      default_inputs.map(&:first).uniq
    end

    def difficulty
      DIFFICULTY_MAP[@intent.normalized['difficulty']]
    end

    def requires_dependencies
      Array(@template['module']['requires'])
    end

    # --- writers -----------------------------------------------------------

    def write_metadata_xml
      write_staged('secgen_metadata.xml', metadata_xml)
    end

    def write_entry_pp
      write_staged("#{@module_name}.pp", "require #{@module_name}\n")
    end

    def write_manifests
      write_staged('manifests/init.pp', init_pp)
      write_staged('manifests/install.pp', install_pp)
      write_staged('manifests/configure.pp', configure_pp)
    end

    def write_templates
      write_staged('templates/index.php.erb', index_php_erb)
    end

    def write_test_stub
      write_staged("secgen_test/#{@module_name}.rb", test_stub_rb)
    end

    def write_staged(relpath, content)
      abs = File.expand_path(File.join(@staged_module_dir, relpath))
      ensure_within_staging!(abs)
      begin
        @adapter.validate_staged_paths!([abs]) if @adapter
      rescue HarnessError => e
        raise ModuleGenerationError, "Rejected staged write: #{e.message}"
      end
      FileUtils.mkdir_p(File.dirname(abs))
      File.write(abs, content)
      @generated_files << relpath
      abs
    end

    def ensure_within_staging!(abs)
      root = File.expand_path(@staging_dir)
      return if abs == root || abs.start_with?("#{root}#{File::SEPARATOR}")

      raise ModuleGenerationError, "Refusing to write outside staging: #{abs}"
    end

    # --- content builders --------------------------------------------------

    def metadata_xml
      lines = []
      lines << '<?xml version="1.0"?>'
      lines << "<vulnerability xmlns=\"#{METADATA_NAMESPACE}\""
      lines << '               xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"'
      lines << "               xsi:schemaLocation=\"#{METADATA_NAMESPACE}\">"
      lines << "  <name>#{escape(module_display_name)}</name>"
      lines << '  <author>SecGen Scenario Generator</author>'
      lines << '  <module_license>MIT</module_license>'
      lines << "  <description>#{escape(module_description)}</description>"
      lines << '  <type>webapp</type>'
      lines << '  <type>generated</type>'
      lines << '  <privilege>user_rwx</privilege>'
      lines << '  <access>remote</access>'
      lines << '  <platform>linux</platform>'
      lines << "  <difficulty>#{escape(difficulty)}</difficulty>" if difficulty
      read_facts.each { |fact| lines << "  <read_fact>#{escape(fact)}</read_fact>" }
      default_inputs.each do |into, values|
        lines << "  <default_input into=\"#{escape(into)}\">"
        values.each { |value| lines << "    <value>#{escape(value)}</value>" }
        lines << '  </default_input>'
      end
      lines << '  <conflict>'
      lines << '    <type>webapp</type>'
      lines << '  </conflict>'
      requires_dependencies.each do |dependency|
        lines << '  <requires>'
        lines << "    <module_path>.*#{escape(dependency)}.*compatible.*</module_path>"
        lines << '  </requires>'
      end
      cybok_entries.each do |entry|
        lines << "  <CyBOK KA=\"#{escape(entry['ka'])}\" topic=\"#{escape(entry['topic'])}\">"
        keywords_for(entry).each { |keyword| lines << "    <keyword>#{escape(keyword)}</keyword>" }
        lines << '  </CyBOK>'
      end
      lines << '</vulnerability>'
      lines.join("\n") + "\n"
    end

    def module_display_name
      "#{@intent['name']} (#{@template['vulnerability_class']})"
    end

    def module_description
      base = @template['description'].to_s.strip
      summary = "Generated #{@template['vulnerability_class']} vulnerable web application for scenario #{@identifiers['scenario_slug']}."
      base.empty? ? summary : "#{summary} #{base}"
    end

    def cybok_entries
      Array(@intent.normalized['cybok'])
    end

    def keywords_for(entry)
      keywords = Array(entry['keywords']).map(&:to_s).reject(&:empty?)
      keywords.empty? ? [entry['topic'].to_s] : keywords
    end

    def init_pp
      <<~PUPPET
        class #{@module_name} {
          require #{@module_name}::install
          require #{@module_name}::configure
        }
      PUPPET
    end

    def install_pp
      <<~PUPPET
        # Installs the generated vulnerable web application.
        class #{@module_name}::install {
          ensure_packages(['apache2', 'php', 'mysql-server'])

          file { '/var/www/html/#{@module_name}':
            ensure => directory,
          }

          file { '/var/www/html/#{@module_name}/index.php':
            ensure  => file,
            content => template('#{@module_name}/index.php.erb'),
            require => File['/var/www/html/#{@module_name}'],
          }
        }
      PUPPET
    end

    def configure_pp
      flag_target = rendered_flags.first['target']
      <<~PUPPET
        # Reads scenario datastore inputs and leaks the configured flag.
        class #{@module_name}::configure {
          $secgen_parameters = secgen_functions::get_parameters($::base64_inputs_file)
          $strings_to_leak = $secgen_parameters['#{flag_target}']
          $leaked_filenames = $secgen_parameters['leaked_filenames']

          ::secgen_functions::leak_files { '#{@module_name}_flag':
            storage_directory => '/var/www/html/#{@module_name}',
            leaked_filenames  => $leaked_filenames,
            strings_to_leak   => $strings_to_leak,
            leaked_from       => '#{@module_name}',
          }
        }
      PUPPET
    end

    def index_php_erb
      route = rendered_parameters['route_path'] || "/#{@module_name}"
      <<~PHP
        <?php
        // Generated vulnerable web application: #{@template['vulnerability_class']}
        // Scenario: #{@identifiers['scenario_slug']}  Route: #{route}
        // WARNING: intentionally insecure for training; do not deploy to production.
        $conn = mysqli_connect('localhost', 'webapp', 'webapp', 'appdb');
        $id = $_GET['id'];
        // Vulnerable: untrusted input concatenated directly into the SQL query.
        $result = mysqli_query($conn, "SELECT * FROM products WHERE id = $id");
        while ($row = mysqli_fetch_assoc($result)) {
            echo htmlspecialchars($row['name']);
        }
      PHP
    end

    def test_stub_rb
      flag = rendered_flags.first
      <<~RUBY
        # Acceptance test stub for generated module #{@module_name}.
        # Vulnerability class: #{@template['vulnerability_class']}
        # Exploit expectation: #{@template['tests']['exploit_expectation']}
        #
        # Expected flag: leaked via datastore key '#{flag['target']}' as a file under
        # /var/www/html/#{@module_name} (see manifests/configure.pp leak_files).
        # Flag value is seed-derived and recorded in the generation manifest.
        require 'minitest/autorun'

        class #{test_class_name} < Minitest::Test
          def test_exploit_entry_point_is_documented
            skip 'Integration test: run against a provisioned target VM.'
          end
        end
      RUBY
    end

    def test_class_name
      "Test#{@module_name.split('_').map(&:capitalize).join}"
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
