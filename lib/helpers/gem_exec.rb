require 'rubygems'
require 'process_helper'

class GemExec
  @@verbose = false

  def self.verbose=(value)
    @@verbose = value
  end

  def self.verbose
    @@verbose
  end

  # Gems that include executables (vagrant and librarian-puppet) don't always have
  # predictable executable names
  # This resolves the execuable path and starts the command
  # @param [Object] gem_name -- such as 'vagrant', 'puppet', 'librarian-puppet'
  # @param [Object] working_dir -- the location for output
  # @param [Object] argument -- the command to send 'init', 'install'
  def self.exe(gem_name, working_dir, arguments)
    Print.std "Loading #{gem_name} (#{arguments.strip}) in #{working_dir}"

    version = '>= 0'
    begin
      gem_path = ""
      # new versions of vagrant are executed directly
      # this is the most reliable way of checking for vagrant, when multiple versions are isntalled
      if gem_name == 'vagrant' && File.file?("/usr/bin/vagrant")
        gem_path = "/usr/bin/vagrant"
      end
      # test if the program is already installed via package management (for example, vagrant now does this)
      if gem_path.empty?
        gem_path = `which #{gem_name}`.chomp
      end
      # otherwise try getting the location of installed gem
      if gem_path.empty?
        gem_path = Gem.bin_path(gem_name, gem_name, version)
      end
      unless File.file?(gem_path)
        raise 'Gem.bin_path returned a path that does not exist.'
      end
    rescue Exception => e
      unless File.file? gem_path
        Print.err "Executable for #{gem_name} not found: #{e.message}"
        # vagrant can be executed via the gem path, but not installed this way
        unless gem_name == 'vagrant'
          Print.err "Installing #{gem_name} gem by running 'sudo gem install #{gem_name}'..."
          system "sudo gem install #{gem_name}"
          begin
            gem_path = Gem.bin_path(gem_name, gem_name, version)
          rescue Exception => ex
            Print.err "Gem executable for #{gem_name} still not found: #{ex.message}"
          end
        end
      end
    end

    command = "#{gem_path} #{arguments}"

    output_hash = {:output => '', :status => 0, :exception => nil}
    Dir.chdir(working_dir) do
      begin
        # Times out after 30 minutes, (TODO: make this configurable)
        # Vagrant's embedded Ruby must be isolated from the parent process's
        # rbenv/bundler environment. Use fork with ENV cleanup in the child.
        if gem_name == 'vagrant'
          output_hash = run_vagrant_isolated(gem_path, working_dir, arguments)
        else
          output_hash[:output] = ProcessHelper.process(command, {:pty => true, :timeout => (60 * 30),
                                                                                      include_output_in_exception: true})
        end
      rescue Exception => ex
        output_hash[:status] = 1
        output_hash[:exception] = ex
        if ex.class == ProcessHelper::UnexpectedExitStatusError
          output_hash[:output] = ex.to_s.split('Command output: ')[1]
          Print.err 'Non-zero exit status...'
        elsif ex.class == ProcessHelper::TimeoutError
          Print.err 'Timeout: Killing process...'
          sleep(30)
          output_hash[:output] = ex.to_s.split('Command output prior to timeout: ')[1]
        else
          output_hash[:output] = nil
        end
      end
    end
    output_hash
  end

  # Run vagrant in a fully isolated child process.
  # Forks the Ruby process, scrubs bundler/rbenv env vars in the child,
  # then execs vagrant. Output is captured via a pipe.
  # This avoids the PTY.spawn login-shell problem where ~/.zshrc re-inits rbenv.
  def self.run_vagrant_isolated(gem_path, working_dir, arguments)
    output_hash = {:output => '', :status => 0, :exception => nil}

    # Capture the absolute working directory NOW (the parent has already
    # Dir.chdir'd into working_dir, so Dir.pwd gives us the correct path).
    # This avoids the child needing to call Dir.chdir, which conflicts with
    # the parent's Dir.chdir block.
    abs_working_dir = Dir.pwd

    # Create a pipe to capture output from the child
    reader, writer = IO.pipe

    pid = fork do
      # Child process: clean up ENV to remove all bundler/rbenv/ruby vars
      # that would confuse Vagrant's embedded Ruby
      ENV.delete_if { |k, _|
        k.start_with?('BUNDLE_') || k.start_with?('BUNDLER_') ||
        k == 'RUBYOPT' || k == 'RUBYLIB' ||
        k == 'GEM_HOME' || k == 'GEM_PATH' ||
        k.start_with?('RBENV_')
      }
      # Redirect stdout and stderr to the pipe
      $stdout.reopen(writer)
      $stderr.reopen(writer)
      writer.close
      reader.close
      exec(gem_path, *arguments.split(' '))
    end

    # Parent process
    writer.close
    if @@verbose
      # Stream output line-by-line to stdout in real-time
      output = ''
      reader.each_line do |line|
        output << line
        $stdout.print(line)
        $stdout.flush
      end
      reader.close
    else
      output = reader.read
      reader.close
    end
    Process.wait(pid)
    exitstatus = $?.exitstatus

    output_hash[:output] = output
    unless exitstatus == 0
      output_hash[:status] = exitstatus
      output_hash[:exception] = ProcessHelper::UnexpectedExitStatusError.new(
        "Command failed, exit #{exitstatus}. Command output: \"#{output}\""
      )
      Print.err 'Non-zero exit status...'
    end
    output_hash
  rescue Exception => ex
    output_hash[:status] = 1
    output_hash[:exception] = ex
    output_hash[:output] = nil
    output_hash
  end
end
