# Post Provision Testing
#
# This file will be copied into each project folder at creation time.
# It will be required from each of the modules/secgen_tests/module_name.rb test scripts
#
# Test classes must: require_relative '../../../../../lib/post_provision_test'

require 'json'
require 'base64'
require 'socket'
require 'timeout'
require 'net/http'
require 'open3'

# Proxmox transport (QEMU Guest Agent). Optional: only used when the project was
# built against Proxmox (a proxmox_test_context.json sits in the project root and
# .vagrant/machines/<system>/proxmox/id exists). Copied into the project lib
# alongside this file at build time.
begin
  require_relative './proxmox_connection'
rescue LoadError
  # Vagrant-only projects don't ship the proxmox client; that's fine.
end

# KubeVirt transport (virtctl). Optional: only used when the project was built with the
# KubeVirt provider (a kubevirt_test_context.json sits in the project root). Copied into
# the project lib alongside this file at build time.
begin
  require_relative './kubevirt_connection'
rescue LoadError
  # Projects built for the other providers don't ship the KubeVirt transport; that's fine.
end

class PostProvisionTest
  attr_accessor :project_path
  attr_accessor :system_ip
  attr_accessor :module_name
  attr_accessor :module_path
  attr_accessor :json_inputs
  attr_accessor :port
  attr_accessor :outputs
  attr_accessor :all_tests_passed

  def initialize
    self.outputs = []
    self.system_ip = get_system_ip
    self.json_inputs = get_json_inputs
    self.port = get_port
    self.all_tests_passed = true
  end

  def run
    test_module
    puts self.outputs
    exit(1) unless all_tests_passed
  end

  def test_module
    # Call super first in overriden methods
    self.outputs << "Running tests for #{self.module_name}"
  end

  #####################
  # Testing Functions #
  #####################

  # Test service is up (tcp)
  def test_service_up
    port_open = if proxmox?
                  guest_port_listening?(self.port)
                elsif kubevirt?
                  # A masquerade guest has no inbound network path from here, so ask the
                  # guest itself (over virtctl) whether it is listening.
                  kubevirt_port_listening?(self.port)
                else
                  is_port_open?(system_ip, self.port)
                end
    if port_open
      self.outputs << "PASSED: Port #{self.port} is open at #{get_system_ip} (#{get_system_name})!"
    else
      self.outputs << "FAILED: Port #{self.port} is closed at #{get_system_ip} (#{get_system_name})!"
      self.all_tests_passed = false
    end
  end

  # example usage for page: /index.html
  def test_html_returned_content(page, match_string, hide_content = false)

    begin
      source = if kubevirt?
                 # No network path into the lab: fetch it through the API server.
                 fetch_page_through_kubevirt_port_forward(page)
               else
                 Net::HTTP.get(get_system_ip, page, self.port)
               end
    rescue SocketError, Errno::ECONNREFUSED
      # do nothing
    end

    if source and source.include? match_string
      match_string = '<redacted>' if hide_content
      self.outputs << "PASSED: Content #{match_string} is contained within #{page} at #{get_system_ip}:#{self.port} (#{get_system_name})!"
    else
      self.outputs << "FAILED: Content #{match_string} is not contained within #{page} at #{get_system_ip}:#{self.port} (#{get_system_name})!"
      self.all_tests_passed = false
    end
  end

  def test_local_command(test_output, local_command, match_string)
    Dir.chdir(get_project_path) do
      output = run_vagrant_ssh(local_command)
      if output[:stdout].include? match_string or output[:stderr].include? match_string
        self.outputs << "PASSED: #{test_output} local command (#{local_command}) matches with output (#{match_string}) on #{get_system_name}!"
      else
        self.outputs << "FAILED: #{test_output} local command (#{local_command}) matches with output (#{match_string}) on #{get_system_name}!"
        self.outputs << output[:stderr]
        self.all_tests_passed = false
      end
    end
  end

  ##################
  # Misc Functions #
  ##################

  def run_vagrant_ssh(args)
    # On Proxmox, run the command in the guest via the QEMU Guest Agent instead
    # of vagrant ssh (no guest network path is needed, and it survives net0 teardown).
    # NOTE: guest commands run as root. For "as the intended user" tests, wrap with
    # `runuser -u <user> -- ...` in the command itself.
    if proxmox?
      node, vmid = proxmox_node_vmid
      result = proxmox_connection.exec_qemu_guest(vmid, node, ['bash', '-lc', args], timeout: 30)
      return {:stdout => result[:stdout], :stderr => result[:stderr], :exit_status => result[:exitcode]}
    end
    if kubevirt?
      # Run the command in the guest over virtctl. The transport reports a non-zero guest
      # status as an exception, so its message (which carries the guest output) is passed
      # back as both streams and the caller's match still sees it.
      begin
        return {:stdout => kubevirt_connection.ssh(kubevirt_vm_name, args, timeout: 60),
                :stderr => '', :exit_status => 0}
      rescue KubeVirt::TransportError => e
        return {:stdout => e.message, :stderr => e.message, :exit_status => 1}
      end
    end
    vagrant_ssh = -> { Open3.capture3("/usr/bin/vagrant ssh #{get_system_name} -c '#{args}'") }
    # tests run under `bundle exec`; Vagrant (with its own embedded Ruby) must not inherit that
    # environment, or it tries to load SecGen's bundle and fails before connecting
    stdout, stderr, status = if defined?(Bundler) && Bundler.respond_to?(:with_unbundled_env)
                               Bundler.with_unbundled_env(&vagrant_ssh)
                             else
                               vagrant_ssh.call
                             end
    {:stdout => stdout, :stderr => stderr, :exit_status => status}
  end

  ############################
  # Proxmox (Guest Agent)    #
  ############################

  # Memoised {url, user} from the project, or nil if this isn't a Proxmox build.
  def proxmox_context
    return @proxmox_context if defined?(@proxmox_context)
    ctx_path = "#{get_project_path}/proxmox_test_context.json"
    @proxmox_context = File.exist?(ctx_path) ? JSON.parse(File.read(ctx_path)) : nil
  end

  def proxmox?
    !proxmox_context.nil? && File.exist?(proxmox_id_path) && defined?(Proxmox::Connection)
  end

  def proxmox_id_path
    "#{get_project_path}/.vagrant/machines/#{get_system_name}/proxmox/id"
  end

  # Returns [node, vmid] for this system from the Vagrant-written id file.
  def proxmox_node_vmid
    File.read(proxmox_id_path).strip.split('/')
  end

  def proxmox_connection
    return @proxmox_connection if @proxmox_connection
    password = ENV['SECGEN_PROXMOX_PASS']
    if password.nil? || password.empty?
      self.outputs << 'FAILED: SECGEN_PROXMOX_PASS is not set; cannot reach the Proxmox API for testing.'
      self.all_tests_passed = false
      exit(1)
    end
    @proxmox_connection = Proxmox::Connection.new(proxmox_context['url'])
    @proxmox_connection.login(username: proxmox_context['user'], password: password)
    @proxmox_connection
  end

  # Is the given TCP port listening inside the guest? (checked locally on the guest)
  def guest_port_listening?(port)
    node, vmid = proxmox_node_vmid
    # ss is present on modern Debian/Kali; fall back to a bash /dev/tcp probe.
    cmd = ['bash', '-lc',
           "ss -ltn 2>/dev/null | grep -q ':#{port} ' && echo LISTENING || " \
           "(exec 3<>/dev/tcp/127.0.0.1/#{port} && echo LISTENING) 2>/dev/null"]
    result = proxmox_connection.exec_qemu_guest(vmid, node, cmd, timeout: 15)
    result[:stdout].include?('LISTENING')
  end

  def get_system_ip
    if proxmox?
      node, vmid = proxmox_node_vmid
      ip = proxmox_connection.qemu_agent_get_ip(vmid)
      if ip.nil?
        puts 'WARNING: Could not determine guest IP via QEMU Guest Agent'
        exit(0)
      end
      return ip
    end
    if kubevirt?
      # The guest's address on the cluster pod network. Phase 1 is masquerade-only, so this
      # address is NOT reachable from here: it labels the guest in test output, and anything
      # that has to touch the guest goes over virtctl. A missing address means the VM is not
      # running, which the tests should report rather than skip.
      ip = kubevirt_connection.vmi_ip(kubevirt_vm_name).to_s
      if ip.empty?
        puts 'WARNING: Could not determine the guest IP from the VirtualMachineInstance'
        return 'unknown'
      end
      return ip
    end
    vagrant_file_path = "#{get_project_path}/Vagrantfile"
    vagrantfile = File.read(vagrant_file_path)
    ip_line = vagrantfile.split("\n").delete_if {|line| !line.include? "# ip_address_for_#{get_system_name}"}[0]
    ip_address = ip_line.split('=')[-1]
    if ip_address == "DHCP"
      puts "WARNING: Cannot test against dynamic IPs" # TODO: fix this so that we grab dynamic IP address (maybe from vagrant?)
      exit(0) # return "OK", if we can't test
    else
      ip_address
    end
  end

  def get_json_inputs
    json_inputs_path = "#{File.expand_path('../', self.module_path)}/secgen_functions/files/json_inputs/*"
    json_inputs_files = Dir.glob(json_inputs_path)
    json_inputs_files.delete_if do |path|
      end_path = path.split('/')[-1]
      !end_path.include?(self.module_name)
    end
    if json_inputs_files.size > 0
      return JSON.parse(Base64.strict_decode64(File.read(json_inputs_files.first)))
    end
    {}
  end

  def get_port
    if get_json_inputs != {} and get_json_inputs['port'] != nil
      get_json_inputs['port'][0].to_i
    else
      -1
    end
  end

  # Pass __FILE__ in from subclasses
  def get_module_path(file_path)
    "#{File.expand_path('..', File.dirname(file_path))}"
  end

  # Note: returns proftpd_testing
  def get_system_name
    get_system_path.match(/.*?([^\/]*)$/i).captures[0]
  end

  # Note: returns /home/thomashaw/git/SecGen/projects/SecGen20190202_010552/puppet/proftpd_testing
  def get_system_path
    "#{File.expand_path('../../', self.module_path)}"
  end

  # Note: returns /home/thomashaw/git/SecGen/projects/SecGen20190202_010552/
  def get_project_path
    "#{File.expand_path('../../../../', self.module_path)}"
  end

  def is_port_open?(ip, port)
    retries = 5
    while retries > 0
      begin
        Timeout::timeout(2) do
          begin
            s = TCPSocket.new(ip, port)
            s.close
            return true
          rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH
            # do nothing
          end
        end
      rescue Timeout::Error
        # ignored
      end
      retries -= 1
    end
    false
  end

  ########################
  # KubeVirt (virtctl)   #
  ########################

  # Memoised {namespace, ssh_key} (and kubeconfig path, if one was given) from the project,
  # or nil if this isn't a KubeVirt build.
  def kubevirt_context
    return @kubevirt_context if defined?(@kubevirt_context)
    ctx_path = "#{get_project_path}/kubevirt_test_context.json"
    @kubevirt_context = File.exist?(ctx_path) ? JSON.parse(File.read(ctx_path)) : nil
  end

  def kubevirt?
    !kubevirt_context.nil? && defined?(KubeVirt)
  end

  # KubeVirt object names must be valid DNS-1123 labels. Mirrors KubeVirtFunctions.vm_name
  # in lib/helpers/kubevirt.rb.
  def kubevirt_vm_name
    name = get_system_name.to_s.downcase.gsub(/[^a-z0-9-]+/, '-')
    name = name.sub(/\A-+/, '').sub(/-+\z/, '')
    name = 'secgen-vm' if name.empty?
    name[0, 63].sub(/-+\z/, '')
  end

  def kubevirt_connection
    return @kubevirt_connection if @kubevirt_connection
    # The ssh key path is recorded in the project: the copy of the transport in the project
    # lib cannot find the SecGen one on its own.
    @kubevirt_connection = KubeVirt.new(kubevirt_context['namespace'],
                                        kubeconfig: kubevirt_context['kubeconfig'],
                                        ssh_key: kubevirt_context['ssh_key'])
  end

  # Is the given TCP port listening inside the guest? Asked over virtctl, so no network
  # path into the lab is needed.
  def kubevirt_port_listening?(port)
    output = kubevirt_connection.ssh(kubevirt_vm_name,
                                     "ss -ltn 2>/dev/null | grep -q ':#{port} ' && echo LISTENING || " \
                                     "(exec 3<>/dev/tcp/127.0.0.1/#{port} && echo LISTENING) 2>/dev/null",
                                     timeout: 30)
    output.include?('LISTENING')
  rescue KubeVirt::TransportError => e
    self.outputs << "WARNING: could not reach #{kubevirt_vm_name} over virtctl: #{e.message}"
    false
  end

  # Fetch a page from a service in the guest through a port-forward over the API server.
  # Returns the body, or nil if it could not be reached.
  def fetch_page_through_kubevirt_port_forward(page)
    body = nil
    kubevirt_connection.with_port_forward(kubevirt_vm_name, self.port) do |local_port|
      body = Net::HTTP.get('127.0.0.1', page, local_port)
    end
    body
  rescue KubeVirt::TransportError => e
    self.outputs << "WARNING: port-forward to #{kubevirt_vm_name}:#{self.port} failed: #{e.message}"
    nil
  end

end
