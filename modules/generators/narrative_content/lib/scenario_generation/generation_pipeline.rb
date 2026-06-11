require 'time'
require_relative 'harness_adapter'
require_relative 'template_catalog'
require_relative 'template_selector'
require_relative 'module_generator'
require_relative 'scenario_assembler'
require_relative 'validator'
require_relative 'repair_loop'
require_relative 'harness_trace'
require_relative 'manifest'

module ScenarioGeneration
  # Facade composing sections 3.3-7 into one deterministic run: load the catalog,
  # select templates (fail-fast before any write), prepare the harness workspace,
  # generate one module per requested vulnerability class, assemble the scenario
  # and docs, validate, run the bounded repair loop, then build and write the
  # reproducibility manifest. Nothing is promoted; the result reports readiness.
  #
  # No real docker/OpenCode process is executed: the harness phases are recorded
  # as command arrays and the repair loop uses an injectable command_runner.
  class GenerationPipeline
    def initialize(intent:, staging_dir:, catalog: nil, adapter: nil, command_runner: nil, now: nil)
      @intent = intent
      @staging_dir = staging_dir
      @catalog = catalog
      @adapter = adapter
      @command_runner = command_runner
      @now = now
    end

    def run
      catalog = @catalog || TemplateCatalog.load
      selector = TemplateSelector.new(intent: @intent, catalog: catalog)
      selection = selector.select # raises TemplateSelectionError before any artifact is written

      adapter = @adapter || HarnessAdapter.for(intent: @intent, staging_dir: @staging_dir)
      adapter.prepare_workspace

      trace = HarnessTrace.new(adapter: adapter)
      trace.record_phase(phase: 'plan', command: adapter.plan_command, status: 'planned')
      trace.record_phase(phase: 'generate', command: adapter.generate_command, status: 'generated')

      modules = build_modules(selection, adapter)
      scenario = ScenarioAssembler.new(intent: @intent, modules: modules, staging_dir: @staging_dir, adapter: adapter).assemble

      validator = Validator.new(scenario: scenario, modules: modules, staging_dir: @staging_dir)
      repair = RepairLoop.new(adapter: adapter, validator: validator, command_runner: @command_runner).run

      report = validator.validate
      # Reflect any repair iterations in the trace so the manifest's
      # retry.attempts / harness_trace.repair_attempts are accurate (0 on the
      # deterministic happy path, since no repair is needed).
      Array(repair['repair_commands']).each_with_index do |command, index|
        trace.record_phase(phase: "repair_#{index + 1}", command: command, status: 'repaired')
        trace.record_repair(attempt: index, report: report)
      end
      trace.record_validation(attempt: 0, report: report)
      final_trace = trace.finalize(status: report.promotion_ready? ? 'passed' : 'failed')

      manifest = Manifest.build(
        intent: @intent, selection: selector.selection_summary, modules: modules, scenario: scenario,
        adapter: adapter, validation_report: report, staging_dir: @staging_dir,
        harness_trace: final_trace, now: @now || Time.now
      )
      manifest.write(File.join(@staging_dir, 'manifest.json'))

      {
        'selection' => selector.selection_summary,
        'modules' => modules,
        'scenario' => scenario,
        'validation' => report,
        'manifest' => manifest,
        'repair' => repair,
        'promotion_ready' => report.promotion_ready?
      }
    end

    # Re-run the same deterministic pipeline into a fresh directory and compare
    # the recomputed output hashes against a prior manifest (task 7.2 / 9.3).
    def regenerate(into:, manifest:)
      result = self.class.new(
        intent: @intent, staging_dir: into, catalog: @catalog, command_runner: @command_runner, now: @now
      ).run
      fresh = result['manifest'].output_hashes
      { 'output_hashes' => fresh, 'matches' => fresh == manifest.output_hashes }
    end

    private

    def build_modules(selection, adapter)
      multiple = selection.length > 1
      base_name = @intent.identifiers['module_name']
      names = selection.map do |entry|
        multiple ? snake("#{base_name}_#{entry['vulnerability_class']}") : base_name
      end
      if names.uniq.length != names.length
        raise ModuleGenerationError, "Generated module names are not unique: #{names.join(', ')}"
      end

      selection.each_with_index.map do |entry, index|
        ModuleGenerator.new(
          intent: @intent, template: entry['template'], staging_dir: @staging_dir,
          adapter: adapter, module_name: names[index]
        ).generate
      end
    end

    def snake(value)
      value.to_s.strip.downcase.gsub(/[^a-z0-9]+/, '_').gsub(/\A_|_+\z/, '')
    end
  end
end
