require 'json'
require 'fileutils'
require 'shellwords'
require_relative 'harness_adapter'

module ScenarioGeneration
  class OpenCodeAdapter < HarnessAdapter
    DEFAULT_AGENT_PLAN = 'plan'.freeze
    DEFAULT_AGENT_BUILD = 'build'.freeze
    DEFAULT_RETRY_LIMIT = 3

    attr_reader :opencode_bin, :model, :retry_limit, :trace_dir

    def initialize(intent:, staging_dir:, config: {})
      merged = default_config.merge(intent_harness_config(intent)).merge(stringify_keys(config || {}))
      super(intent: intent, staging_dir: staging_dir, config: merged)
      @opencode_bin = @config['opencode_bin']
      @model = @config['model']
      @retry_limit = Integer(@config['retry_limit'])
      @trace_dir = @config['trace_dir'] || File.join(staging_dir, 'trace', 'opencode')
    rescue ArgumentError, TypeError
      raise HarnessError, 'OpenCode retry_limit must be an integer'
    end

    def prepare_workspace
      FileUtils.mkdir_p(@staging_dir)
      FileUtils.mkdir_p(@trace_dir)
      write_json(File.join(@staging_dir, 'intent.normalized.json'), normalized_intent)
      write_json(File.join(@staging_dir, 'opencode.policy.json'), policy)
      true
    end

    def plan_command
      run_command(
        agent: @config['plan_agent'],
        title: title('plan'),
        message: plan_prompt
      )
    end

    def generate_command
      run_command(
        agent: @config['build_agent'],
        title: title('generate'),
        message: generate_prompt
      )
    end

    def repair_command(validation_report)
      run_command(
        agent: @config['build_agent'],
        title: title('repair'),
        message: repair_prompt(validation_report)
      )
    end

    def export_command(session_id, sanitize: true)
      command = [@opencode_bin, 'export', session_id.to_s]
      command << '--sanitize' if sanitize
      command
    end

    def report
      super.merge(
        'harness' => 'opencode',
        'opencode_bin' => @opencode_bin,
        'model' => @model,
        'retry_limit' => @retry_limit,
        'trace_dir' => @trace_dir,
        'plan_agent' => @config['plan_agent'],
        'build_agent' => @config['build_agent']
      )
    end

    private

    def default_config
      {
        'harness' => 'opencode',
        'opencode_bin' => 'opencode',
        'plan_agent' => DEFAULT_AGENT_PLAN,
        'build_agent' => DEFAULT_AGENT_BUILD,
        'retry_limit' => DEFAULT_RETRY_LIMIT,
        'format' => 'json',
        'pure' => true,
        'print_logs' => false,
        'skip_permissions' => false
      }
    end

    def intent_harness_config(intent)
      return {} unless intent.respond_to?(:harness_options)

      intent.harness_options
    end

    def run_command(agent:, title:, message:)
      command = [@opencode_bin, 'run', '--dir', @staging_dir, '--agent', agent, '--format', @config['format'], '--title', title]
      command.concat(['--model', @model]) if present?(@model)
      command << '--pure' if @config['pure']
      command << '--print-logs' if @config['print_logs']
      command << '--dangerously-skip-permissions' if @config['skip_permissions']
      command << message
      command
    end

    def plan_prompt
      <<~PROMPT
        You are planning a SecGen insecure software scenario generation run.
        Read intent.normalized.json and opencode.policy.json in this staging directory.
        Produce a concise implementation plan only. Do not edit files in this phase.
      PROMPT
    end

    def generate_prompt
      <<~PROMPT
        Generate the staged SecGen insecure software scenario artifacts described by intent.normalized.json.
        Obey opencode.policy.json. Write only inside this staging directory.
        Include module/scenario/test/documentation artifacts needed for later validation.
      PROMPT
    end

    def repair_prompt(validation_report)
      report_json = JSON.pretty_generate(validation_report || {})
      <<~PROMPT
        Repair the staged SecGen scenario artifacts using this validation report:

        #{report_json}

        Obey opencode.policy.json. Modify only files inside this staging directory.
      PROMPT
    end

    def policy
      {
        'allowed_write_root' => @staging_dir,
        'retry_limit' => @retry_limit,
        'validation_profile' => @config['validation_profile'] || 'default',
        'forbidden_paths' => ['.git', 'llm_config.json', '*.env', '*.env.*'],
        'required_review' => true
      }
    end

    def normalized_intent
      @intent.respond_to?(:normalized) ? @intent.normalized : @intent
    end

    def title(phase)
      slug = if @intent.respond_to?(:identifiers)
               @intent.identifiers['scenario_slug']
             else
               'scenario-generation'
             end
      "secgen #{phase} #{slug}"
    end

    def write_json(path, data)
      File.write(path, JSON.pretty_generate(data))
    end

    def present?(value)
      !value.nil? && !value.to_s.strip.empty?
    end
  end
end
