require 'digest'

module ScenarioGeneration
  # Accumulates harness trace metadata during a generation run (harness/model/
  # isolation, per-phase prompt hashes, validation/repair attempts, final status)
  # into a string-keyed summary embedded in the reproducibility manifest.
  #
  # Prompts are stored as SHA256 hashes (not raw text) so the trace is auditable
  # without persisting provider keys or full prompt bodies.
  class HarnessTrace
    def initialize(adapter:)
      report = adapter.respond_to?(:report) ? adapter.report : {}
      @harness = report['harness']
      @model = report['model']
      @isolation_mode = report['isolation_mode']
      @phases = []
      @prompt_hashes = {}
      @validation_attempts = []
      @repair_attempts = []
    end

    def record_phase(phase:, command: nil, status: nil)
      @phases << { 'phase' => phase.to_s, 'status' => status }
      @prompt_hashes[phase.to_s] = Digest::SHA256.hexdigest(Array(command).last.to_s) if command
      self
    end

    def record_validation(attempt:, report:)
      @validation_attempts << {
        'attempt' => attempt,
        'promotion_ready' => report.respond_to?(:promotion_ready?) ? report.promotion_ready? : nil,
        'failures' => report.respond_to?(:failed) ? report.failed.map { |failure| failure['code'] } : []
      }
      self
    end

    def record_repair(attempt:, report:)
      @repair_attempts << {
        'attempt' => attempt,
        'summary' => report.respond_to?(:summary) ? report.summary : report.to_s
      }
      self
    end

    def finalize(status:)
      {
        'harness' => @harness,
        'model' => @model,
        'isolation_mode' => @isolation_mode,
        'phases' => @phases,
        'prompt_hashes' => @prompt_hashes,
        'validation_attempts' => @validation_attempts,
        'repair_attempts' => @repair_attempts,
        'final_status' => status
      }
    end
  end
end
