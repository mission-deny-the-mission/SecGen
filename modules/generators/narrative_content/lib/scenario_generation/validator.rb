require 'nokogiri'
require_relative 'validation_report'

module ScenarioGeneration
  # Runs structural (XSD), repository-convention, and test-coverage checks over a
  # staged ScenarioArtifact + its ModuleArtifacts, producing a ValidationReport.
  # Any failure blocks promotion; failures carry machine-readable repair context.
  class Validator
    VULN_NS = 'http://www.github/cliffe/SecGen/vulnerability'.freeze
    MODULE_PATH_PREFIX = 'modules/vulnerabilities/generated/'.freeze
    NAME_PATTERN = /\A[a-z0-9_]+\z/.freeze

    def initialize(scenario:, modules:, staging_dir:, schema_dir: nil)
      @scenario = scenario
      @modules = Array(modules)
      @staging_dir = staging_dir
      @schema_dir = schema_dir || default_schema_dir
    end

    def validate
      report = ValidationReport.new(artifact_paths: artifact_paths)
      check_scenario_xml_schema(report)
      @modules.each { |mod| check_module_metadata_schema(report, mod) }
      check_required_files_present(report)
      check_unresolved_references(report)
      check_naming_conventions(report)
      check_test_coverage(report)
      check_doc_stub(report)
      report
    end

    private

    def artifact_paths
      paths = [@scenario['staged_scenario_path'], @scenario['doc_stub_path']]
      paths.concat(@modules.map { |mod| mod['staged_module_dir'] })
      paths.compact
    end

    # --- 6.1 structural -----------------------------------------------------

    def check_scenario_xml_schema(report)
      path = @scenario['staged_scenario_path']
      unless path && File.exist?(path)
        return report.add_failure(code: 'missing_required_file', message: 'scenario.xml missing', path: path)
      end

      doc = Nokogiri::XML(File.read(path)) { |config| config.strict }
      errors = scenario_schema.validate(doc)
      if errors.empty?
        report.add_pass('scenario_xml_schema')
      else
        report.add_failure(code: 'invalid_scenario_xml', message: 'scenario.xml failed schema validation',
                           path: path, hint: errors.first.message)
      end
    rescue Nokogiri::XML::SyntaxError => e
      report.add_failure(code: 'malformed_xml', message: 'scenario.xml is not well-formed', path: path, hint: e.message)
    end

    def check_module_metadata_schema(report, mod)
      path = File.join(@staging_dir, mod['metadata_path'])
      unless File.exist?(path)
        return report.add_failure(code: 'missing_required_file', message: "secgen_metadata.xml missing for #{mod['module_name']}", path: path)
      end

      doc = Nokogiri::XML(File.read(path)) { |config| config.strict }
      errors = vulnerability_schema.validate(doc)
      if errors.empty?
        report.add_pass("module_metadata_schema:#{mod['module_name']}")
      else
        report.add_failure(code: 'invalid_module_metadata', message: "secgen_metadata.xml invalid for #{mod['module_name']}",
                           path: path, hint: errors.first.message)
      end
    rescue Nokogiri::XML::SyntaxError => e
      report.add_failure(code: 'malformed_xml', message: "secgen_metadata.xml malformed for #{mod['module_name']}", path: path, hint: e.message)
    end

    def check_required_files_present(report)
      @modules.each do |mod|
        Array(mod['required_files']).each do |relpath|
          abs = File.join(mod['staged_module_dir'], relpath)
          next if File.exist?(abs)

          report.add_failure(code: 'missing_required_file',
                             message: "Required file missing for #{mod['module_name']}: #{relpath}", path: abs)
        end
        report.add_pass("required_files:#{mod['module_name']}") if module_files_present?(mod)
      end
    end

    def module_files_present?(mod)
      Array(mod['required_files']).all? { |relpath| File.exist?(File.join(mod['staged_module_dir'], relpath)) }
    end

    def check_unresolved_references(report)
      module_names = @modules.map { |mod| mod['module_name'] }
      Array(@scenario['module_selectors']).each do |selector|
        name = selector.to_s.split('/').last
        if module_names.include?(name) && @modules.any? { |mod| mod['module_name'] == name && Dir.exist?(mod['staged_module_dir']) }
          report.add_pass("resolved_reference:#{name}")
        else
          report.add_failure(code: 'unresolved_module_reference',
                             message: "Scenario references module that was not generated: #{selector}", hint: name)
        end
      end
    end

    # --- 6.2 repository conventions -----------------------------------------

    def check_naming_conventions(report)
      system_names = Array(@scenario['system_names'])
      bad_systems = system_names.reject { |name| name =~ NAME_PATTERN }
      unless bad_systems.empty?
        report.add_failure(code: 'convention_violation', message: "Invalid system_name(s): #{bad_systems.join(', ')}")
      end

      @modules.each do |mod|
        name = mod['module_name'].to_s
        report.add_failure(code: 'convention_violation', message: "Module name not snake_case: #{name}") unless name =~ NAME_PATTERN

        unless mod['module_path'].to_s.start_with?(MODULE_PATH_PREFIX)
          report.add_failure(code: 'convention_violation',
                             message: "Module path must be under #{MODULE_PATH_PREFIX}: #{mod['module_path']}")
        end

        report.add_failure(code: 'convention_violation', message: "Entry manifest must be #{name}.pp") unless mod['puppet_entry'] == "#{name}.pp"

        check_init_class(report, mod, name)
        check_default_inputs_have_read_facts(report, mod)
      end

      report.add_pass('naming_conventions') if report.passed?
    end

    def check_init_class(report, mod, name)
      init = File.join(mod['staged_module_dir'], 'manifests', 'init.pp')
      return unless File.exist?(init)

      return if File.read(init).include?("class #{name}")

      report.add_failure(code: 'convention_violation', message: "init.pp must declare class #{name}", path: init)
    end

    def check_default_inputs_have_read_facts(report, mod)
      path = File.join(@staging_dir, mod['metadata_path'])
      return unless File.exist?(path)

      doc = Nokogiri::XML(File.read(path))
      ns = { 'v' => VULN_NS }
      read_facts = doc.xpath('//v:read_fact', ns).map(&:text)
      default_into = doc.xpath('//v:default_input', ns).map { |node| node['into'] }
      missing = default_into - read_facts
      return if missing.empty?

      report.add_failure(code: 'default_input_without_read_fact',
                         message: "default_input(s) without read_fact in #{mod['module_name']}: #{missing.join(', ')}", path: path)
    end

    # --- 6.3 test coverage --------------------------------------------------

    def check_test_coverage(report)
      @modules.each do |mod|
        if Array(mod['validation_hooks']).empty?
          report.add_failure(code: 'missing_test_stub', message: "Module has no validation hooks: #{mod['module_name']}")
        end

        stub = File.join(mod['staged_module_dir'], 'secgen_test', "#{mod['module_name']}.rb")
        unless File.exist?(stub)
          report.add_failure(code: 'missing_test_stub', message: "Module test stub missing: #{mod['module_name']}", path: stub)
        end
      end
    end

    def check_doc_stub(report)
      path = @scenario['doc_stub_path']
      if path && File.exist?(path)
        report.add_pass('doc_stub')
      else
        report.add_failure(code: 'missing_doc_stub', message: 'Scenario documentation stub missing', path: path)
      end
    end

    # --- schema loading -----------------------------------------------------

    def scenario_schema
      @scenario_schema ||= load_schema('scenario_schema.xsd')
    end

    def vulnerability_schema
      @vulnerability_schema ||= load_schema('vulnerability_metadata_schema.xsd')
    end

    def load_schema(filename)
      path = File.join(@schema_dir, filename)
      raise ScenarioAssemblyError, "Schema not found: #{path}" unless File.exist?(path)

      Nokogiri::XML::Schema(File.read(path))
    end

    def default_schema_dir
      File.expand_path('../../../../../lib/schemas', __dir__)
    end
  end
end
