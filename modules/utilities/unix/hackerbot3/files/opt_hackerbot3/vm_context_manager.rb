require 'open3'
require 'timeout'
require_relative './print.rb'

# VMContextManager - Handles SSH-based operations for fetching context from student VMs
#
# This class provides methods to execute commands, read files, and retrieve bash history
# from remote machines via SSH. It follows the same SSH execution patterns as bot_manager.rb
# and provides graceful error handling for connection failures and timeouts.
#
# Example:
#   manager = VMContextManager.new
#   ssh_config = { 'get_shell' => 'sshpass -p password ssh user@host' }
#   output = manager.execute_command(ssh_config, 'ls -la')
#
# Author: Hackerbot Team
# Version: 1.0
class VMContextManager
  # Constants
  DEFAULT_TIMEOUT = 30
  DEFAULT_COMMAND_TIMEOUT = 15
  DEFAULT_HISTORY_PATH = '~/.bash_history'
  
  # Initialize VM context manager with optional configuration
  #
  # @param options [Hash] Configuration options
  # @option options [Integer] :default_timeout Default timeout for operations (default: 30)
  # @option options [Integer] :command_timeout Timeout for command execution (default: 15)
  def initialize(options = {})
    @default_timeout = options.fetch(:default_timeout, DEFAULT_TIMEOUT)
    @command_timeout = options.fetch(:command_timeout, DEFAULT_COMMAND_TIMEOUT)
  end
  
  # Execute a command via SSH and capture output
  #
  # @param ssh_config [Hash] SSH configuration hash with 'get_shell' key
  # @param command [String] Command to execute on remote machine
  # @param variables [Hash] Optional variables for substitution (e.g., { chat_ip_address: '192.168.1.1' })
  # @return [String, nil] Command output string or nil on error
  #
  # @example
  #   ssh_config = { 'get_shell' => 'sshpass -p password ssh user@{{chat_ip_address}}' }
  #   output = manager.execute_command(ssh_config, 'ls -la', { chat_ip_address: '192.168.1.1' })
  def execute_command(ssh_config, command, variables = {})
    return nil if ssh_config.nil? || ssh_config.empty? || command.nil? || command.empty?
    
    shell_cmd = extract_shell_command(ssh_config, variables)
    return nil unless shell_cmd
    
    # Add semicolon to ensure command runs via bash
    shell_cmd_with_semicolon = shell_cmd + ';'
    
    Print.debug("Executing SSH command: #{shell_cmd_with_semicolon}")
    
    execute_remote_command(shell_cmd_with_semicolon, command)
  rescue => e
    Print.err("Error executing SSH command: #{e.message}")
    nil
  end
  
  # Read a file from remote machine via SSH
  #
  # @param ssh_config [Hash] SSH configuration hash with 'get_shell' key
  # @param file_path [String] Path to file on remote machine (absolute or relative)
  # @param variables [Hash] Optional variables for substitution
  # @return [String, nil] File content string or nil on error
  #
  # @example
  #   content = manager.read_file(ssh_config, '/etc/passwd')
  #   content = manager.read_file(ssh_config, './config.txt')
  def read_file(ssh_config, file_path, variables = {})
    return nil if ssh_config.nil? || ssh_config.empty? || file_path.nil? || file_path.empty?
    
    # Use cat to read file (works for both absolute and relative paths)
    command = "cat #{file_path}"
    execute_command(ssh_config, command, variables)
  end
  
  # Read bash history from remote machine
  #
  # @param ssh_config [Hash] SSH configuration hash with 'get_shell' key
  # @param user [String, nil] Optional username (defaults to current user or detected user)
  # @param limit [Integer, nil] Optional limit on number of history lines to return
  # @param variables [Hash] Optional variables for substitution
  # @return [String, nil] Bash history string or nil on error
  #
  # @example
  #   history = manager.read_bash_history(ssh_config)
  #   history = manager.read_bash_history(ssh_config, user: 'student', limit: 50)
  def read_bash_history(ssh_config, user = nil, limit = nil, variables = {})
    return nil if ssh_config.nil? || ssh_config.empty?
    
    # Determine history file path
    history_path = determine_history_path(user)
    
    # Build command to read history
    command = if limit && limit > 0
      # Use tail to get last N lines
      "tail -n #{limit} #{history_path} 2>/dev/null || echo ''"
    else
      # Read entire history file
      "cat #{history_path} 2>/dev/null || echo ''"
    end
    
    output = execute_command(ssh_config, command, variables)
    
    # Always return empty string for bash history (graceful degradation)
    # If command failed or returned error, return empty string
    if output.nil? || output.empty?
      ''
    elsif is_error_output?(output)
      ''
    else
      output
    end
  end
  
  private
  
  # Extract shell command from SSH config and apply variable substitution
  #
  # @param ssh_config [Hash] SSH configuration hash
  # @param variables [Hash] Variables for substitution
  # @return [String, nil] Shell command string or nil if not found
  def extract_shell_command(ssh_config, variables = {})
    shell_cmd = ssh_config['get_shell'] || ssh_config[:get_shell]
    return nil unless shell_cmd
    
    # Convert to string and clone to avoid modifying original
    shell_cmd = shell_cmd.to_s.clone
    
    # Apply variable substitution
    substitute_variables(shell_cmd, variables)
    
    shell_cmd
  end
  
  # Substitute variables in command string
  #
  # @param command [String] Command string that may contain variables
  # @param variables [Hash] Variables hash with keys as symbols or strings
  # @return [String] Command string with variables substituted
  def substitute_variables(command, variables = {})
    # Support {{chat_ip_address}} pattern (used in bot_manager.rb)
    if variables[:chat_ip_address] || variables['chat_ip_address']
      ip_address = variables[:chat_ip_address] || variables['chat_ip_address']
      command.gsub!(/{{chat_ip_address}}/, ip_address.to_s)
    end
    
    # Support other variable patterns if needed
    variables.each do |key, value|
      var_name = key.to_s
      var_pattern = /\{\{#{Regexp.escape(var_name)}\}\}/
      command.gsub!(var_pattern, value.to_s) if var_pattern
    end
    
    command
  end
  
  # Execute a remote command via SSH and capture output
  #
  # @param shell_cmd [String] Complete SSH shell command
  # @param remote_command [String] Command to execute on remote machine
  # @return [String, nil] Output string or nil on error
  def execute_remote_command(shell_cmd, remote_command)
    output = nil
    exit_status = nil
    
    Open3.popen2e(shell_cmd) do |stdin, stdout_err, wait_thr|
      begin
        Timeout.timeout(@command_timeout) do
          # Send command to remote shell
          stdin.puts "#{remote_command}\n"
          stdin.flush
          
          # Capture output using non-blocking read pattern (from bot_manager.rb)
          output = capture_output(stdout_err, @command_timeout)
          
          # Close stdin to signal end of input
          stdin.close
          
          # Wait for any remaining output
          begin
            Timeout.timeout(5) do
              remaining_output = stdout_err.read
              output += remaining_output if remaining_output
            end
          rescue Timeout::Error
            # Process may still be running, kill it
            wait_thr.kill if wait_thr.alive?
            
            # Try to read any remaining output
            begin
              while ch = stdout_err.read_nonblock(1)
                output << ch
              end
            rescue
              # No more data available
            end
          end
          
          # Get exit status
          begin
            exit_status = wait_thr.value.exitstatus
          rescue => e
            Print.debug("Could not get exit status: #{e.message}")
          end
        end
      rescue Timeout::Error
        Print.err("SSH command execution timed out after #{@command_timeout} seconds")
        wait_thr.kill if wait_thr.alive?
        return nil
      rescue => e
        Print.err("Error during SSH execution: #{e.message}")
        wait_thr.kill if wait_thr.alive? rescue nil
        return nil
      end
    end
    
    # If we got output, check if it's an error message
    if output
      output = output.strip
      
      # Check for common error patterns
      if is_error_output?(output)
        return nil
      end
      
      # Check exit status if available
      if exit_status && exit_status != 0
        return nil
      end
    end
    
    output
  end
  
  # Capture output from stdout/stderr stream using non-blocking reads
  #
  # @param stdout_err [IO] Combined stdout/stderr stream
  # @param timeout [Integer] Timeout for reading
  # @return [String] Captured output string
  def capture_output(stdout_err, timeout)
    output = ''
    start_time = Time.now
    
    # Read output in chunks with timeout
    begin
      while (Time.now - start_time) < timeout
        # Try to read available data
        begin
          # Non-blocking read of available data
          chunk = stdout_err.read_nonblock(4096)
          output << chunk if chunk
        rescue IO::WaitReadable
          # No data available yet, wait a bit
          sleep(0.1)
        rescue EOFError
          # End of stream
          break
        rescue => e
          # Other errors (including when no data is available)
          break
        end
      end
    rescue => e
      # Ignore errors during read - we've captured what we could
      Print.debug("Output capture completed with: #{e.class}")
    end
    
    output
  end
  
  # Determine bash history file path for a user
  #
  # @param user [String, nil] Username or nil for current user
  # @return [String] History file path
  def determine_history_path(user)
    if user
      "~#{user}/.bash_history"
    else
      DEFAULT_HISTORY_PATH
    end
  end
  
  # Check if output string represents an error message
  #
  # @param output [String] Output string to check
  # @return [Boolean] True if output appears to be an error message
  def is_error_output?(output)
    return true if output.nil? || output.empty?
    
    # Common error message patterns
    error_patterns = [
      /command not found/i,
      /Could not resolve hostname/i,
      /Connection refused/i,
      /Permission denied/i,
      /No such file or directory/i,
      /Pseudo-terminal will not be allocated/i,
      /^sh: line \d+: .*: command not found/,
      /^ssh:/
    ]
    
    error_patterns.any? { |pattern| output.match?(pattern) }
  end
end

