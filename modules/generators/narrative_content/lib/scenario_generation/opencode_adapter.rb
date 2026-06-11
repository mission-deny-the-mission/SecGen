require 'json'
require 'fileutils'
require 'shellwords'
require_relative 'harness_adapter'

module ScenarioGeneration
  class OpenCodeAdapter < HarnessAdapter
    DEFAULT_AGENT_PLAN = 'plan'.freeze
    DEFAULT_AGENT_BUILD = 'build'.freeze
    DEFAULT_RETRY_LIMIT = 3
    DEFAULT_CONTAINER_WORKDIR = '/workspace'.freeze

    VALIDATION_PROFILES = {
      'default' => [
        {
          'name' => 'policy file exists',
          'command' => ['test', '-f', File.join(DEFAULT_CONTAINER_WORKDIR, 'opencode.policy.json')]
        },
        {
          'name' => 'normalized intent exists',
          'command' => ['test', '-f', File.join(DEFAULT_CONTAINER_WORKDIR, 'intent.normalized.json')]
        }
      ]
    }.freeze

    attr_reader :opencode_bin, :model, :retry_limit, :trace_dir
    attr_reader :isolation_mode, :container_image, :container_workdir

    def initialize(intent:, staging_dir:, config: {})
      merged = default_config.merge(intent_harness_config(intent)).merge(stringify_keys(config || {}))
      super(intent: intent, staging_dir: staging_dir, config: merged)
      @opencode_bin = @config['opencode_bin']
      @model = @config['model']
      @retry_limit = Integer(@config['retry_limit'])
      raise HarnessError, 'OpenCode retry_limit must be greater than 0' if @retry_limit <= 0

      @trace_dir = @config['trace_dir'] || File.join(staging_dir, 'trace', 'opencode')
      @isolation_mode = @config['isolation_mode']
      @container_image = @config['container_image']
      @container_workdir = @config['container_workdir']
      validate_isolation_config
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

    def phase_command(phase, validation_report: nil)
      case phase.to_sym
      when :plan
        plan_command
      when :generate
        generate_command
      when :validate
        validation_commands
      when :repair
        repair_command(validation_report || {})
      when :report
        report
      else
        raise HarnessError, "Unsupported harness phase: #{phase}"
      end
    end

    def export_command(session_id, sanitize: true)
      command = [@opencode_bin, 'export', session_id.to_s]
      command << '--sanitize' if sanitize
      command
    end

    def validation_commands
      profile = validation_profile
      profile.map { |entry| isolate_command(entry['command']) }
    end

    def vm_validation_command
      command = @config['vm_validation_command']
      return nil unless command
      return command if command.is_a?(Array)

      raise HarnessError, 'vm_validation_command must be an array of command arguments'
    end

    def retries_exhausted?(attempt)
      Integer(attempt) >= @retry_limit
    rescue ArgumentError, TypeError
      raise HarnessError, 'attempt must be an integer'
    end

    def staged_path_allowed?(path)
      root = File.expand_path(@staging_dir)
      candidate = File.expand_path(path.to_s, root)
      candidate == root || candidate.start_with?("#{root}#{File::SEPARATOR}")
    end

    def validate_staged_paths!(paths)
      invalid = Array(paths).reject { |path| staged_path_allowed?(path) }
      raise HarnessError, "Out-of-scope staged paths: #{invalid.join(', ')}" unless invalid.empty?

      true
    end

    def approved_validation_command?(command)
      normalized = Array(command).map(&:to_s)
      validation_profile.any? { |entry| entry['command'].map(&:to_s) == normalized }
    end

    def validate_validation_command!(command)
      raise HarnessError, "Unapproved validation command: #{Array(command).join(' ')}" unless approved_validation_command?(command)

      true
    end

    def report
      super.merge(
        'harness' => 'opencode',
        'opencode_bin' => @opencode_bin,
        'model' => @model,
        'retry_limit' => @retry_limit,
        'trace_dir' => @trace_dir,
        'isolation_mode' => @isolation_mode,
        'container_image' => @container_image,
        'container_workdir' => @container_workdir,
        'validation_profile' => @config['validation_profile'],
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
        'skip_permissions' => false,
        'isolation_mode' => 'docker',
        'container_image' => 'opencode:latest',
        'container_workdir' => DEFAULT_CONTAINER_WORKDIR,
        'container_network' => 'none',
        'validation_profile' => 'default'
      }
    end

    def intent_harness_config(intent)
      return {} unless intent.respond_to?(:harness_options)

      intent.harness_options
    end

    def run_command(agent:, title:, message:)
      command = [container_opencode_bin, 'run', '--dir', harness_workdir, '--agent', agent, '--format', @config['format'], '--title', title]
      command.concat(['--model', @model]) if present?(@model)
      command << '--pure' if @config['pure']
      command << '--print-logs' if @config['print_logs']
      command << '--dangerously-skip-permissions' if @config['skip_permissions']
      command << message
      isolate_command(command)
    end

    def isolate_command(command)
      case @isolation_mode
      when 'host'
        command
      when 'docker'
        docker_command(command)
      else
        raise HarnessError, "Unsupported isolation_mode: #{@isolation_mode.inspect}"
      end
    end

    def docker_command(inner_command)
      [
        'docker', 'run', '--rm',
        '--network', @config['container_network'],
        '--cap-drop', 'ALL',
        '--security-opt', 'no-new-privileges',
        '--mount', "type=bind,source=#{File.expand_path(@staging_dir)},target=#{@container_workdir}",
        '--workdir', @container_workdir,
        '--tmpfs', '/tmp:rw,nosuid,nodev,size=256m',
        @container_image
      ] + inner_command
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
        'container_write_root' => @container_workdir,
        'isolation_mode' => @isolation_mode,
        'container_image' => @container_image,
        'retry_limit' => @retry_limit,
        'validation_profile' => @config['validation_profile'] || 'default',
        'approved_validation_commands' => validation_profile.map { |entry| entry['command'] },
        'vm_validation_enabled' => !vm_validation_command.nil?,
        'forbidden_paths' => ['.git', 'llm_config.json', '*.env', '*.env.*'],
        'required_review' => true
      }
    end

    def normalized_intent
      @intent.respond_to?(:normalized) ? @intent.normalized : @intent
    end

    def validation_profile
      profile_name = @config['validation_profile'] || 'default'
      profile = VALIDATION_PROFILES[profile_name]
      raise HarnessError, "Unknown validation_profile: #{profile_name}" unless profile

      profile
    end

    def validate_isolation_config
      unless %w[docker host].include?(@isolation_mode)
        raise HarnessError, "Unsupported isolation_mode: #{@isolation_mode.inspect}"
      end

      raise HarnessError, 'container_image is required for docker isolation' if @isolation_mode == 'docker' && !present?(@container_image)
      raise HarnessError, 'container_workdir is required for docker isolation' if @isolation_mode == 'docker' && !present?(@container_workdir)
      validation_profile
      vm_validation_command
    end

    def harness_workdir
      @isolation_mode == 'docker' ? @container_workdir : @staging_dir
    end

    def container_opencode_bin
      @isolation_mode == 'docker' ? (@config['container_opencode_bin'] || 'opencode') : @opencode_bin
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
