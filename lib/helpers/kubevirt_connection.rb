require 'base64'
require 'json'
require 'open3'
require 'socket'
require 'timeout'

require_relative './print.rb'

# Transport layer for the KubeVirt provider.
#
# KubeVirt has no maintained Vagrant plugin, so - unlike the Proxmox provider, where
# Vagrant performs the build and SecGen only makes API calls afterwards - this provider
# drives the build itself: each lab VM is a VirtualMachine object applied to the cluster
# with kubectl, and the guest is reached through virtctl (ssh / scp / port-forward) over
# the API server. Three consequences worth knowing:
#
#   * SecGen needs no network path into the lab network; it needs cluster API access.
#   * Credentials never enter the project directory. kubectl and virtctl use the ambient
#     KUBECONFIG (or default context) unless --kubevirt-kubeconfig is given, and only
#     that path is recorded in the project.
#   * No new gems: shelling out to the two CLIs avoids a Ruby Kubernetes client.
#
# Everything the provider needs from the cluster goes through this class, so a future
# API-based implementation can replace it without touching the provider logic.
class KubeVirt
  class TransportError < StandardError; end

  # SecGen's bases are its existing Vagrant boxes, which ship with the published Vagrant
  # "insecure" key in the vagrant user's authorized_keys - hence no key injection step is
  # needed for provisioning. That key is public knowledge by design; it is NOT a secret
  # and confers nothing beyond access to a lab VM.
  DEFAULT_SSH_KEY = File.expand_path('../resources/kubevirt/vagrant_insecure_key', __dir__)

  # Generous default: image uploads and puppet runs are both slow.
  DEFAULT_TIMEOUT = 900

  # The binaries are stored as kubectl_cmd/virtctl_cmd, not kubectl/virtctl: accessors with
  # those names would be overwritten by the kubectl(args)/virtctl(args) methods below.
  attr_accessor :namespace, :kubeconfig, :kubectl_cmd, :virtctl_cmd, :ssh_key, :verbose

  def initialize(namespace, kubeconfig: nil, kubectl: 'kubectl', virtctl: 'virtctl',
                 ssh_key: nil, verbose: false)
    self.namespace = namespace
    self.kubeconfig = kubeconfig
    self.kubectl_cmd = kubectl
    self.virtctl_cmd = virtctl
    self.ssh_key = ssh_key.nil? || ssh_key.empty? ? DEFAULT_SSH_KEY : ssh_key
    self.verbose = verbose
  end

  # Build a transport from the command line options hash.
  def self.from_options(options)
    self.new(options[:kubevirtnamespace],
             kubeconfig: options[:kubevirtkubeconfig],
             kubectl: options[:kubevirtkubectl] || 'kubectl',
             virtctl: options[:kubevirtvirtctl] || 'virtctl',
             ssh_key: options[:kubevirtsshkey],
             verbose: options[:verbose])
  end

  # ---------------------------------------------------------------- process plumbing

  def cli_env
    env = {}
    kubecfg = kubeconfig.to_s
    env['KUBECONFIG'] = kubecfg unless kubecfg.empty?
    env
  end

  # kubectl with the lab namespace applied, unless the caller passes cluster_scoped: true
  # or already names a namespace itself.
  def kubectl_args(args, namespaced = true)
    return args unless namespaced
    ns = namespace.to_s
    return args if ns.empty?
    return args if args.include?('-n') || args.include?('--namespace') ||
                   args.include?('-A') || args.include?('--all-namespaces')
    ['--namespace', ns] + args
  end

  def kubectl(args, namespaced = true, options = {})
    run_cli(kubectl_cmd, kubectl_args(args, namespaced), options)
  end

  def virtctl(args, options = {})
    ns = namespace.to_s
    full_args = ns.empty? ? args : ['--namespace', ns] + args
    run_cli(virtctl_cmd, full_args, options)
  end

  # Run a CLI, returning stdout. Raises TransportError on non-zero exit or timeout.
  # Reads stdout and stderr on separate threads: reading them in sequence deadlocks when
  # a child fills the pipe buffer of the stream we are not currently draining.
  def run_cli(binary, args, options = {})
    timeout = options[:timeout] || DEFAULT_TIMEOUT
    Print.verbose "  $ #{binary} #{args.join(' ')}" if verbose

    stdout = ''
    stderr = ''
    status = nil
    Open3.popen3(cli_env, binary.to_s, *args.map(&:to_s)) do |stdin, out, err, wait|
      begin
        stdin.write(options[:stdin_data].to_s)
      rescue Errno::EPIPE
        # A command that never reads stdin (e.g. most kubectl verbs) may exit first.
      end
      stdin.close rescue nil
      out_reader = Thread.new { out.read.to_s }
      err_reader = Thread.new { err.read.to_s }
      begin
        Timeout.timeout(timeout) do
          stdout = out_reader.value
          stderr = err_reader.value
          status = wait.value
        end
      rescue Timeout::Error
        begin
          Process.kill('KILL', wait.pid)
        rescue StandardError
          nil
        end
        raise TransportError, "#{binary} #{args.join(' ')} timed out after #{timeout}s"
      end
    end

    if status.nil? || !status.success?
      code = status.nil? ? 'unknown' : status.exitstatus
      detail = stderr.strip.empty? ? stdout.strip : stderr.strip
      raise TransportError, "#{binary} #{args.join(' ')} failed (exit #{code}): #{detail}"
    end
    stdout
  end

  # ---------------------------------------------------------------- object operations

  def apply(manifest_yaml, options = {})
    kubectl(['apply', '-f', '-'], true, options.merge(stdin_data: manifest_yaml))
  end

  def delete(kind, name, options = {})
    kubectl(['delete', kind, name, '--ignore-not-found'], true, options)
  end

  def exists?(kind, name)
    kubectl(['get', kind, name, '-o', 'jsonpath={.metadata.name}'], true, timeout: 60).strip == name
  rescue TransportError
    false
  end

  def jsonpath(kind, name, path, default = '')
    out = kubectl(['get', kind, name, '-o', "jsonpath=#{path}"], true, timeout: 60).strip
    out.empty? ? default : out
  rescue TransportError
    default
  end

  def namespace_exists?
    !kubectl(['get', 'namespace', namespace, '-o', 'jsonpath={.metadata.name}'], false,
             timeout: 60).strip.empty?
  rescue TransportError
    false
  end

  def ensure_namespace
    return true if namespace_exists?
    kubectl(['create', 'namespace', namespace], false)
    true
  end

  # ---------------------------------------------------------------- VM lifecycle

  def vmi_phase(vm_name)
    jsonpath('vmi', vm_name, '{.status.phase}')
  end

  def vmi_ready?(vm_name)
    vmi_phase(vm_name) == 'Running'
  end

  # The guest's address on the pod network. It is NOT reachable from outside the cluster, and
  # nothing should depend on it (a pod restart moves it): it identifies the guest for the
  # API-mediated paths (virtctl) and for logging/reporting. A guest's lab-network addresses are
  # the stable ones, and come from the Multus interfaces (see vmi_interfaces).
  def vmi_ip(vm_name)
    jsonpath('vmi', vm_name, '{.status.interfaces[0].ipAddress}')
  end

  def wait_for_vmi_ready(vm_name, timeout: 600, interval: 5)
    wait_until("VM #{vm_name} to be Running", timeout: timeout, interval: interval) do
      vmi_ready?(vm_name)
    end
  end

  def wait_until(description, timeout: 300, interval: 5)
    deadline = Time.now + timeout
    loop do
      return true if yield
      if Time.now > deadline
        raise TransportError, "timed out after #{timeout}s waiting for #{description}"
      end
      sleep interval
    end
  end

  # ---------------------------------------------------------------- cluster facts

  # The cluster's nodes and their internal addresses, in name order (so a choice made from
  # this list is the same on every run).
  def nodes
    data = read_json(kubectl(['get', 'nodes', '-o', 'json'], false, timeout: 60), 'the cluster nodes')
    data.fetch('items', []).map do |node|
      addresses = node.dig('status', 'addresses') || []
      internal = addresses.find { |address| address['type'] == 'InternalIP' } || {}
      { 'name' => node.dig('metadata', 'name').to_s, 'ip' => internal['address'].to_s }
    end.reject { |node| node['name'].empty? || node['ip'].empty? }.sort_by { |node| node['name'] }
  end

  # Each node's pod CIDR (the ranges the lab's own networks must not fall inside).
  def node_pod_cidrs
    data = read_json(kubectl(['get', 'nodes', '-o', 'json'], false, timeout: 60), 'the cluster nodes')
    data.fetch('items', []).flat_map do |node|
      [node.dig('spec', 'podCIDR'), *(node.dig('spec', 'podCIDRs') || [])].compact.map(&:to_s)
    end.reject(&:empty?).uniq
  end

  # The cluster IPs currently handed out by the Service network.
  def service_cluster_ips
    data = read_json(kubectl(['get', 'services', '-A', '-o', 'json'], false, timeout: 60),
                     'the cluster services')
    data.fetch('items', []).flat_map do |service|
      [service.dig('spec', 'clusterIP'), *(service.dig('spec', 'clusterIPs') || [])]
    end.compact.map(&:to_s).reject { |address| address.empty? || address == 'None' }.uniq
  end

  # The node a running VMI is on. The LLM lane has to be addressed at a node OTHER than this
  # one: a masquerade guest cannot complete a service connection that stays on, or returns
  # via, its own node (measured on this cluster).
  def vmi_node_name(vm_name)
    jsonpath('vmi', vm_name, '{.status.nodeName}')
  end

  # The guest's interfaces as the cluster sees them: name ('default', 'net1', ...) and address.
  def vmi_interfaces(vm_name)
    data = read_json(kubectl(['get', 'vmi', vm_name, '-o', 'json'], true, timeout: 60),
                     "#{vm_name}'s interfaces")
    (data.dig('status', 'interfaces') || []).map do |interface|
      { 'name' => interface['name'].to_s, 'ip' => interface['ipAddress'].to_s }
    end
  end

  # The NodePort a Service is exposed on, or nil. A masquerade guest can only reach a service
  # as a NodePort on another node: a ClusterIP is not routable from the guest at all.
  def service_node_port(namespace, name)
    out = kubectl(['get', 'service', name, '--namespace', namespace, '-o',
                   'jsonpath={.spec.ports[0].nodePort}'], false, timeout: 60).strip
    out.empty? ? nil : out
  end

  # The nodes that currently run an endpoint of a Service, so the lab's LLM lane can be pointed
  # at a node that will actually answer (the Service is externalTrafficPolicy Local).
  def endpoint_nodes(namespace, name)
    out = kubectl(['get', 'endpoints', name, '--namespace', namespace, '-o',
                   'jsonpath={.subsets[*].addresses[*].nodeName}'], false, timeout: 60)
    out.to_s.split(/\s+/).reject(&:empty?).uniq
  rescue TransportError
    []
  end

  # Read one credential out of a Secret. Used to hand a lab guest the LiteLLM key; the value is
  # never written into the project directory.
  def secret_value(namespace, name, key)
    encoded = kubectl(['get', 'secret', name, '--namespace', namespace, '-o',
                       "jsonpath={.data.#{key}}"], false, timeout: 60).strip
    encoded.empty? ? nil : Base64.decode64(encoded)
  end

  def read_json(output, description)
    JSON.parse(output.to_s)
  rescue JSON::ParserError => e
    raise TransportError, "cannot read #{description} from the cluster: #{e.message}"
  end

  # Delete a VM and the storage it owns. The golden images live in another namespace and
  # are never touched by this.
  def destroy_vm(vm_name, options = {})
    delete('vm', vm_name, options)
    delete('dv', "#{vm_name}-root", options)
    delete('pvc', "#{vm_name}-root", options)
    delete('secret', "#{vm_name}-cloudinit", options)
  end

  # ---------------------------------------------------------------- guest access

  def ssh_common_args(user, insecure_host_key: true)
    args = ['--username', user]
    args += ['--identity-file', ssh_key] unless ssh_key.to_s.empty?
    if insecure_host_key
      args += ['--local-ssh-opts=-o StrictHostKeyChecking=no',
               '--local-ssh-opts=-o UserKnownHostsFile=/dev/null']
    end
    args
  end

  # Run a command in the guest over the API server.
  def ssh(vm_name, command, user: 'vagrant', timeout: DEFAULT_TIMEOUT)
    virtctl(['ssh'] + ssh_common_args(user) + ['-c', command, "vm/#{vm_name}"], timeout: timeout)
  end

  # Copy a file or directory (source is a local path) into the guest.
  def scp(local_path, vm_name, remote_path = '.', user: 'vagrant', recursive: false,
          timeout: DEFAULT_TIMEOUT)
    args = ['scp']
    args << '--recursive' if recursive
    args += ssh_common_args(user)
    args << local_path.to_s
    args << "#{user}@vm/#{vm_name}:#{remote_path}"
    virtctl(args, timeout: timeout)
  end

  def free_port
    server = TCPServer.new('127.0.0.1', 0)
    port = server.addr[1]
    server.close
    port
  end

  def tcp_open?(host, port, timeout = 2)
    socket = Socket.tcp(host, port, connect_timeout: timeout)
    socket.close
    true
  rescue StandardError
    false
  end

  # Yield a local port tunnelled to a port on the guest, then tear the tunnel down.
  #
  # This is how the post-provision tests reach a service in a lab VM without any network
  # path into the lab: TCP from the SecGen host to 127.0.0.1, carried over the API server.
  # Anything inside the block that talks to 127.0.0.1:<yielded port> reaches the guest.
  def with_port_forward(vm_name, guest_port, wait: 30)
    local_port = free_port
    pid = Process.spawn(cli_env, virtctl.to_s, 'port-forward', "vm/#{vm_name}",
                        "#{local_port}:#{guest_port}", '--namespace', namespace.to_s,
                        out: File::NULL, err: File::NULL)
    begin
      wait_until("port-forward to #{vm_name}:#{guest_port} to come up",
                 timeout: wait, interval: 1) { tcp_open?('127.0.0.1', local_port, 1) }
      yield local_port
    ensure
      terminate(pid)
    end
  end

  def terminate(pid)
    return if pid.nil?
    Process.kill('TERM', pid)
    begin
      Timeout.timeout(10) { Process.wait(pid) }
    rescue Timeout::Error
      Process.kill('KILL', pid) rescue nil
    rescue Errno::ECHILD
      nil
    end
  rescue Errno::ESRCH
    nil
  end
end
