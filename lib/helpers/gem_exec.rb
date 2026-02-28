require 'rubygems'
require 'process_helper'
require_relative 'constants'

class GemExec

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
      if gem_name == 'vagrant' && File.file?("/opt/vagrant/bin/vagrant")
        gem_path = "/opt/vagrant/bin/vagrant"
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

    output_hash = {:output => '', :status => 0, :exception => nil}
    Dir.chdir(working_dir) do
      begin
        # For vagrant, don't use BUNDLE_GEMFILE - just run it directly
        # programr is now installed globally
        if gem_name == 'vagrant'
          full_cmd = "#{gem_path} #{arguments}"
        else
          full_cmd = "#{gem_path} #{arguments}"
        end
        # Times out after 30 minutes, (TODO: make this configurable)
        output_hash[:output] = ProcessHelper.process(full_cmd, {:pty => true, :timeout => (60 * 30),
                                                                                  include_output_in_exception: true})
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
end
