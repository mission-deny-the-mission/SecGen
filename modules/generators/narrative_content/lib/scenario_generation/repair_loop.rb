module ScenarioGeneration
  # Orchestrates the bounded validate-repair loop via a harness adapter:
  # while the artifacts are not promotion-ready and retries remain, feeds the
  # validation repair_context into adapter.repair_command, runs it via an
  # injectable command_runner, and re-validates. Stops on pass or retry
  # exhaustion. NEVER promotes on exhaustion.
  #
  # command_runner is a callable taking a command array; it is injected so tests
  # (and the deterministic path) never execute real docker/OpenCode.
  class RepairLoop
    def initialize(adapter:, validator:, command_runner: nil)
      @adapter = adapter
      @validator = validator
      @command_runner = command_runner || ->(_command) { { 'status' => 'noop' } }
    end

    def run(max_attempts: nil)
      limit = max_attempts || @adapter.retry_limit
      report = @validator.validate
      return outcome('passed', 0, report, []) if report.promotion_ready?

      repair_commands = []
      attempt = 0
      while attempt < limit
        command = @adapter.repair_command(report.repair_context)
        repair_commands << command
        @command_runner.call(command)

        report = @validator.validate
        break if report.promotion_ready?

        attempt += 1
        break if @adapter.retries_exhausted?(attempt)
      end

      status = report.promotion_ready? ? 'passed' : 'retry_exhausted'
      outcome(status, repair_commands.length, report, repair_commands)
    end

    private

    def outcome(status, attempts, report, commands)
      {
        'status' => status,
        'attempts' => attempts,
        'final_report' => report.to_h,
        'repair_commands' => commands,
        'promoted' => report.promotion_ready?
      }
    end
  end
end
