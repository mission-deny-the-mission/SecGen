require 'base64'
require 'erb'
require 'fileutils'
require 'json'
require 'securerandom'
require 'tmpdir'

require_relative 'constants.rb'
require_relative './print.rb'
require_relative 'kubevirt_connection'

# The KubeVirt provider.
#
# KubeVirt has no maintained Vagrant plugin, so - unlike the Proxmox provider, where Vagrant
# performs the build and SecGen only makes API calls afterwards - this provider drives the
# build itself: for each system it applies a VirtualMachine object that clones the base's
# golden image into the lab namespace, waits for the guest, and then provisions it by
# pushing the project's puppet tree and running a generated script over virtctl.
#
# All the cluster plumbing lives in the KubeVirt transport (lib/helpers/kubevirt_connection.rb);
# this class holds the provider logic.
#
# PHASE 1 SCOPE: networking is pod/masquerade only. Guests get an address on the cluster pod
# network and are reached through the API server (virtctl ssh/scp/port-forward). Scenario
# modules that expect a static IP on an isolated L2 network or VLAN (SecGen's compute_vlan
# model) are NOT supported yet: that needs Multus (phase 2). warn_unsupported_network_modules
# says so loudly, rather than building a lab whose network configuration is silently wrong.
class KubeVirtFunctions

  # Raised when the lab cannot be built. secgen.rb turns it into a user-facing error.
  class BuildError < StandardError; end

  DEFAULT_STORAGE_CLASS = 'ceph-block'
  DEFAULT_GOLDEN_NAMESPACE = 'secgen-bases'
  DEFAULT_CPUS = '2'

  # Module types that are provisioned with puppet: everything except the base (the golden
  # image provides it) and network modules (unsupported in phase 1).
  PROVISIONABLE_MODULE_TYPES = %w(vulnerability service utility build).freeze

  # Where the provisioning script expects things inside the guest.
  GUEST_ASSET_DIR = '/tmp/secgen'
  GUEST_TARBALL_PATH = '/tmp/secgen-assets.tar.gz'
  GUEST_SCRIPT_PATH = '/tmp/secgen-provision.sh'

  # Resolver handed to lab guests. A masquerade guest can reach neither the cluster's DNS
  # nor (with dnsPolicy Default) the node's resolver -- both verified on the cluster -- so
  # guests are always given an explicit nameserver. Override with --kubevirt-dns, e.g. to
  # point labs at the lab's own resolver rather than a public one.
  DEFAULT_DNS_NAMESERVERS = ['1.1.1.1'].freeze

  VMI_READY_TIMEOUT = 900
  # The VMI reports Running well before sshd accepts connections (measured ~68s on the
  # bookworm base), so the guest is polled before provisioning.
  SSH_READY_TIMEOUT = 900
  SCP_TIMEOUT = 900
  # Provisioning runs every puppet module in the scenario; give it a generous ceiling.
  PROVISION_TIMEOUT = 3600

  # A CDI cross-namespace clone is rejected with this wording when the lab namespace's
  # service accounts cannot read the golden image's namespace.
  CLONE_PERMISSION_ERROR = 'insufficient permissions in clone source namespace'

  VM_TEMPLATE = "#{ROOT_DIR}/lib/templates/kubevirt_vm.yaml.erb"
  PROVISION_TEMPLATE = "#{ROOT_DIR}/lib/templates/kubevirt_provision.sh.erb"
  NAMESPACE_QUOTA_TEMPLATE = "#{ROOT_DIR}/lib/templates/kubevirt_namespace_quota.yaml.erb"
  CLONE_RBAC_TEMPLATE = "#{ROOT_DIR}/lib/templates/kubevirt_clone_rbac.yaml.erb"

  # Values handed to the ERB templates: explicit readers (rather than a generic hash) so a
  # template cannot silently depend on something that is not set.
  class TemplateContext
    attr_accessor :vm_name, :system_name, :hostname, :memory, :cpus, :namespace
    attr_accessor :storage_class, :golden_namespace, :golden_image, :disk_size
    attr_accessor :dns_nameservers, :dns_policy
    attr_accessor :modules, :puppet_root, :puppet_system_dir

    def get_binding
      binding
    end
  end

  # @param [Hash] options -- command-line opts
  # @return [Boolean] is this secgen process using the KubeVirt provider?
  #   The lab namespace is what selects the provider (there are no credentials to give
  #   SecGen: kubectl and virtctl use the ambient kubeconfig).
  def self.provider_kubevirt?(options)
    !options[:kubevirtnamespace].to_s.empty?
  end

  def self.transport(options)
    KubeVirt.from_options(options)
  end

  def self.storage_class(options)
    value = options[:kubevirtstorageclass].to_s
    value.empty? ? DEFAULT_STORAGE_CLASS : value
  end

  def self.golden_namespace(options)
    value = options[:kubevirtgoldennamespace].to_s
    value.empty? ? DEFAULT_GOLDEN_NAMESPACE : value
  end

  def self.cpus(options)
    value = options[:kubevirtcpus].to_s
    value.empty? ? DEFAULT_CPUS : value
  end

  # Resolvers handed to the guest. A masquerade guest cannot reach the cluster's DNS, and
  # `dnsPolicy: Default` does not help: it merely substitutes the node's resolver
  # (169.254.116.108 on Talos), which the guest equally cannot reach -- both verified on
  # the cluster. So the provider always sets dnsPolicy None plus an explicit nameserver,
  # defaulting to a public resolver, and never depends on the cluster's DNS.
  def self.dns_nameservers(options)
    configured = options[:kubevirtdns].to_s.split(/[,\s]+/).reject { |nameserver| nameserver.empty? }
    configured.empty? ? DEFAULT_DNS_NAMESERVERS.dup : configured
  end

  # KubeVirt object names must be valid DNS-1123 labels, so system names have to be
  # normalised (they may contain underscores or capitals). The same rule is applied by
  # PostProvisionTest#kubevirt_vm_name in lib/objects/post_provision_test.rb.
  def self.vm_name(system_name)
    name = system_name.to_s.downcase.gsub(/[^a-z0-9-]+/, '-')
    name = name.sub(/\A-+/, '').sub(/-+\z/, '')
    name = 'secgen-vm' if name.empty?
    name = name[0, 63]
    name.sub(/-+\z/, '')
  end

  # ------------------------------------------------------------------ project generation

  # Generate everything the KubeVirt provider needs into the project directory:
  #
  #   kubevirt/<vm>.yaml          the VirtualMachine manifest (clones the golden image)
  #   kubevirt/<vm>-provision.sh  the in-guest provisioning script
  #   kubevirt/<vm>.json          the metadata the build/status/destroy paths read
  #   kubevirt_test_context.json  namespace and paths for the post-provision tests
  #   lib/kubevirt_connection.rb  the transport those tests use over virtctl
  #
  # The clone size has to be read from the cluster (a clone may not be smaller than its
  # source), so generating a KubeVirt project needs cluster API access unless
  # --kubevirt-image-size is given.
  def self.write_project_assets(systems, out_dir, options)
    transport = self.transport(options)
    kubevirt_dir = "#{out_dir}/kubevirt"
    FileUtils.mkdir_p(kubevirt_dir) unless File.exist?(kubevirt_dir)

    # Object names are derived from system names, so two systems whose names differ only in
    # characters that are not valid in a Kubernetes name would collide.
    names = systems.map { |system| vm_name(system.name) }
    duplicates = names.select { |name| names.count(name) > 1 }.uniq
    unless duplicates.empty?
      Print.err "These systems resolve to the same Kubernetes object name: " \
                "#{duplicates.join(', ')} (from #{systems.map(&:name).join(', ')})"
      Print.err 'Rename the systems in the scenario: KubeVirt object names may only contain' \
                ' lowercase letters, digits and "-".'
      exit 1
    end

    systems.each_with_index do |system, index|
      vm = vm_name(system.name)
      begin
        golden_image = golden_image_for(system)
        disk_size = clone_size(golden_image, options, transport)
      rescue BuildError => e
        Print.err e.message
        exit 1
      end

      meta = {
        'vm_name' => vm,
        'system_name' => system.name,
        'hostname' => system.get_hostname,
        'golden_image' => golden_image,
        'golden_namespace' => golden_namespace(options),
        'disk_size' => disk_size,
        'cpus' => cpus(options),
        'memory' => system.memory.to_s,
        'namespace' => options[:kubevirtnamespace].to_s,
        'order' => index,
        'created' => Time.now.to_s
      }

      context = template_context(system, vm, golden_image, disk_size,
                                 module_inputs(system, out_dir), options)
      write_file(render(VM_TEMPLATE, context), "#{kubevirt_dir}/#{vm}.yaml")
      write_file(render(PROVISION_TEMPLATE, context), "#{kubevirt_dir}/#{vm}-provision.sh")
      write_file(JSON.pretty_generate(meta), "#{kubevirt_dir}/#{vm}.json")

      Print.std "Creating KubeVirt VM manifest: #{kubevirt_dir}/#{vm}.yaml"
      Print.info " #{vm}: #{golden_image} cloned into the namespace, #{meta['cpus']} cpu(s), " \
                 "#{meta['memory']}Mi, disk #{disk_size}"
    end

    # Neither of these holds a credential: kubectl and virtctl use the ambient kubeconfig
    # (or the one given by --kubevirt-kubeconfig, whose path is recorded below).
    FileUtils.mkdir_p("#{out_dir}/lib")
    FileUtils.cp("#{ROOT_DIR}/lib/helpers/kubevirt_connection.rb", "#{out_dir}/lib/kubevirt_connection.rb")
    FileUtils.cp("#{ROOT_DIR}/lib/helpers/print.rb", "#{out_dir}/lib/print.rb")

    # The test context records paths, never secrets: the guest key is the one the build used.
    ssh_key = options[:kubevirtsshkey].to_s
    ssh_key = KubeVirt::DEFAULT_SSH_KEY if ssh_key.empty?
    context_json = { 'namespace' => options[:kubevirtnamespace].to_s,
                     'ssh_key' => ssh_key }
    kubeconfig = options[:kubevirtkubeconfig].to_s
    context_json['kubeconfig'] = kubeconfig unless kubeconfig.empty?
    write_file(JSON.pretty_generate(context_json), "#{out_dir}/kubevirt_test_context.json")
    Print.std 'Wrote KubeVirt test context (namespace and paths only, no credentials)'

    true
  end

  # The golden image a system clones from, declared by its base module as
  # <kubevirt_image>secgen-base-...</kubevirt_image>.
  def self.golden_image_for(system)
    base_module = system.module_selections.find { |mod| mod.module_type == 'base' }
    if base_module.nil?
      raise BuildError, "system '#{system.name}' has no base module: cannot resolve a KubeVirt image"
    end
    image = (base_module.attributes['kubevirt_image'] || []).first.to_s
    if image.empty?
      raise BuildError, "base #{base_module.module_path} is not available on KubeVirt: add " \
        '<kubevirt_image>secgen-base-name</kubevirt_image> to its secgen_metadata.xml ' \
        "(see 'Preparing golden images' in README-KubeVirt.md)"
    end
    image
  end

  # The size of the DataVolume that clones the golden image. A clone may not be smaller
  # than its source, so the golden PVC's own size is read from the cluster;
  # --kubevirt-image-size overrides it (which is also how a project can be generated
  # without cluster access).
  def self.clone_size(golden_image, options, transport)
    override = options[:kubevirtimagesize].to_s
    return override unless override.empty?

    namespace = golden_namespace(options)
    begin
      size = transport.kubectl(['get', 'pvc', golden_image, '--namespace', namespace,
                                '-o', 'jsonpath={.spec.resources.requests.storage}']).strip
      return size unless size.empty?
      raise BuildError, "golden image #{namespace}/#{golden_image} exists but reports no size"
    rescue KubeVirt::TransportError => e
      raise BuildError, "cannot read the golden image #{namespace}/#{golden_image}: #{e.message}\n" \
        "The provider reads the golden PVC's size from the cluster because a clone may not be " \
        "smaller than its source.\nPrepare the golden image and run where kubectl can reach the " \
        "cluster, or pass --kubevirt-image-size <size, e.g. 34Gi> (at least the source size)."
    end
  end

  # The puppet modules to apply in the guest, in scenario order, each with the base64
  # inputs file it needs. Mirrors the puppet provisioning blocks of Vagrantfile.erb: the
  # JSON inputs are written into the system's secgen_functions module and passed to puppet
  # as the facter variable base64_inputs_file.
  def self.module_inputs(system, out_dir)
    system.module_selections.select do |mod|
      PROVISIONABLE_MODULE_TYPES.include?(mod.module_type)
    end.map do |mod|
      inputs_file = nil
      unless mod.received_inputs.empty?
        base64_inputs = Base64.strict_encode64(JSON.generate(mod.received_inputs))
        inputs_file = "#{mod.module_path_end}_#{SecureRandom.hex(15)}"
        dir = "#{out_dir}/puppet/#{system.name}/modules/secgen_functions/files/json_inputs"
        FileUtils.mkdir_p(dir) unless File.exist?(dir)
        Print.verbose "Writing #{mod.module_path_name} input to: #{dir}/#{inputs_file}"
        write_file(base64_inputs, "#{dir}/#{inputs_file}")
      end
      { 'path' => mod.module_path,
        'path_end' => mod.module_path_end,
        'inputs_file' => inputs_file }
    end
  end

  def self.template_context(system, vm, golden_image, disk_size, modules, options)
    context = TemplateContext.new
    context.vm_name = vm
    context.system_name = system.name
    context.hostname = system.get_hostname
    context.memory = system.memory.to_s
    context.cpus = cpus(options)
    context.namespace = options[:kubevirtnamespace].to_s
    context.storage_class = storage_class(options)
    context.golden_namespace = golden_namespace(options)
    context.golden_image = golden_image
    context.disk_size = disk_size
    context.dns_nameservers = dns_nameservers(options)
    # dnsPolicy None always: the guest can reach neither the cluster DNS nor (with
    # "Default") the node's resolver, so an explicit nameserver is mandatory. See
    # self.dns_nameservers.
    context.dns_policy = 'None'
    context.modules = modules
    context.puppet_root = GUEST_ASSET_DIR
    context.puppet_system_dir = "#{GUEST_ASSET_DIR}/puppet/#{system.name}"
    context
  end

  # ------------------------------------------------------------------ build

  # Apply the generated VM manifests, wait for each guest and provision it.
  # Used by 'run', 'build-vms' and the 'kubevirt-build' subcommand.
  def self.build(project_dir, options)
    vms = vm_metadata(project_dir)
    if vms.empty?
      raise BuildError, "no generated KubeVirt VMs found in #{project_dir}/kubevirt: " \
        'generate the project first (secgen.rb ... build-project), see README-KubeVirt.md'
    end
    vms = select_vms(vms, options)

    transport = self.transport(options)
    Print.info "KubeVirt: using namespace '#{transport.namespace}'"
    ensure_lab_namespace(transport, options)

    Print.info "KubeVirt: creating #{vms.size} VM(s)"
    vms.each do |meta|
      vm = meta['vm_name']
      manifest = "#{project_dir}/kubevirt/#{vm}.yaml"
      unless File.exist?(manifest)
        raise BuildError, "missing generated manifest #{manifest}"
      end
      Print.std " Creating VM #{vm} (cloning #{meta['golden_image']}, disk #{meta['disk_size']})"
      apply_manifest(transport, manifest, options)
    end

    vms.each do |meta|
      vm = meta['vm_name']
      Print.std " Waiting for #{vm} to boot"
      transport.wait_for_vmi_ready(vm, timeout: VMI_READY_TIMEOUT)
      wait_for_ssh(transport, vm)
      provision(transport, project_dir, meta)
    end

    Print.info 'KubeVirt: all VM(s) are built and provisioned'
    true
  end

  # Provision one guest: push the project's puppet tree as a single tarball, extract it and
  # run the generated script. virtctl scp accepts exactly one source per invocation, hence
  # the tarball.
  def self.provision(transport, project_dir, meta)
    vm = meta['vm_name']
    system_name = meta['system_name']
    script = "#{project_dir}/kubevirt/#{vm}-provision.sh"
    unless File.exist?(script)
      raise BuildError, "missing generated provisioning script #{script}"
    end

    Print.info "KubeVirt: provisioning #{vm} (#{system_name})"
    tarball = create_asset_tarball(project_dir, system_name)
    begin
      transport.scp(tarball, vm, GUEST_TARBALL_PATH, timeout: SCP_TIMEOUT)
      transport.ssh(vm, "rm -rf #{GUEST_ASSET_DIR} && mkdir -p #{GUEST_ASSET_DIR} && " \
                        "tar xzf #{GUEST_TARBALL_PATH} -C #{GUEST_ASSET_DIR}", timeout: 300)
      transport.scp(script, vm, GUEST_SCRIPT_PATH, timeout: SCP_TIMEOUT)
      output = transport.ssh(vm, "bash #{GUEST_SCRIPT_PATH}", timeout: PROVISION_TIMEOUT)
      Print.verbose output
      Print.info "KubeVirt: #{vm} provisioned"
    rescue KubeVirt::TransportError => e
      raise BuildError, "provisioning #{vm} failed: #{e.message}\n" \
        "The guest log is in the command output above; see 'Troubleshooting a lab VM' in README-KubeVirt.md."
    ensure
      File.delete(tarball) if tarball && File.exist?(tarball)
    end
  end

  # One tarball holding the system's puppet modules plus the shared environments directory,
  # so extracting it in the guest reproduces the layout the Vagrant puppet provisioner would
  # have used (modulepath and environmentpath, as in Vagrantfile.erb).
  def self.create_asset_tarball(project_dir, system_name)
    sources = []
    puppet_dir = "puppet/#{system_name}"
    sources << puppet_dir if File.directory?("#{project_dir}/#{puppet_dir}")
    sources << 'environments' if File.directory?("#{project_dir}/environments")
    if sources.empty?
      raise BuildError, "no puppet tree for '#{system_name}' in #{project_dir} " \
        "(expected #{puppet_dir})"
    end

    tarball = File.join(Dir.tmpdir,
                        "secgen-kubevirt-#{vm_name(system_name)}-#{SecureRandom.hex(6)}.tar.gz")
    unless system('tar', 'czf', tarball, '-C', project_dir, *sources)
      raise BuildError, "failed to archive #{sources.join(', ')} from #{project_dir}"
    end
    tarball
  end

  # ------------------------------------------------------------------ lifecycle

  # Print the phase and pod-network address of each generated VM.
  def self.status(project_dir, options)
    vms = vm_metadata(project_dir)
    if vms.empty?
      raise BuildError, "no generated KubeVirt VMs found in #{project_dir}/kubevirt"
    end
    vms = select_vms(vms, options)
    transport = self.transport(options)
    Print.std "KubeVirt lab in namespace '#{transport.namespace}':"
    vms.each do |meta|
      vm = meta['vm_name']
      phase = transport.vmi_phase(vm).to_s
      if phase.empty?
        if transport.exists?('vm', vm)
          Print.warn " #{vm}: not running (the VM exists but has no VirtualMachineInstance: " \
                     'halted, or still starting)'
        else
          Print.err " #{vm}: no VirtualMachine object in this namespace"
        end
      else
        ip = transport.vmi_ip(vm).to_s
        # Phase 1 is masquerade-only: this address is on the cluster pod network and is
        # not reachable from outside the cluster. Use virtctl to get into the guest.
        Print.info " #{vm}: #{phase}#{ip.empty? ? '' : " at #{ip} (pod network, not routable here)"}" \
                   " - golden image #{meta['golden_image']}"
      end
    end
    true
  end

  # Power the VMs off: 'Halted' stops the VM being re-created by its controller, which
  # runStrategy Always would do. The disks are left in place.
  def self.halt(project_dir, options)
    vms = vm_metadata(project_dir)
    if vms.empty?
      raise BuildError, "no generated KubeVirt VMs found in #{project_dir}/kubevirt"
    end
    vms = select_vms(vms, options)
    transport = self.transport(options)
    vms.each do |meta|
      vm = meta['vm_name']
      Print.std " Halting #{vm} (runStrategy Halted)"
      set_run_strategy(transport, vm, 'Halted')
      begin
        transport.wait_until("#{vm} to stop", timeout: 180, interval: 5) do
          transport.vmi_phase(vm).to_s.empty?
        end
      rescue KubeVirt::TransportError => e
        Print.warn " #{vm} is still reported as running: #{e.message}"
        Print.warn " (virtctl stop vm/#{vm} stops it immediately)"
      end
    end
    true
  end

  # Restart the VMs: the equivalent of the halt/up cycle the post-provision tests do under
  # Vagrant. Dropping the VirtualMachineInstance makes the controller create a fresh one.
  def self.restart(project_dir, options)
    vms = vm_metadata(project_dir)
    if vms.empty?
      raise BuildError, "no generated KubeVirt VMs found in #{project_dir}/kubevirt"
    end
    vms = select_vms(vms, options)
    transport = self.transport(options)
    vms.each do |meta|
      vm = meta['vm_name']
      Print.std " Restarting #{vm}"
      set_run_strategy(transport, vm, 'Always')
      transport.kubectl(['delete', 'vmi', vm, '--ignore-not-found'])
    end
    vms.each do |meta|
      vm = meta['vm_name']
      transport.wait_for_vmi_ready(vm, timeout: VMI_READY_TIMEOUT)
      wait_for_ssh(transport, vm)
    end
    true
  end

  # Delete the lab VMs and the storage they own. The golden images live in another
  # namespace and are never touched.
  def self.destroy(project_dir, options)
    vms = vm_metadata(project_dir)
    if vms.empty?
      raise BuildError, "no generated KubeVirt VMs found in #{project_dir}/kubevirt"
    end
    vms = select_vms(vms, options)
    transport = self.transport(options)
    vms.each do |meta|
      vm = meta['vm_name']
      Print.std " Deleting VM #{vm}, its DataVolume and root disk (PVC #{vm}-root)"
      transport.destroy_vm(vm)
    end
    Print.info "KubeVirt: deleted #{vms.size} VM(s); golden images were not modified"
    true
  end

  def self.set_run_strategy(transport, vm, strategy)
    transport.kubectl(['patch', 'vm', vm, '--type', 'merge',
                       '-p', "{\"spec\":{\"runStrategy\":\"#{strategy}\"}}"])
  end

  # ------------------------------------------------------------------ helpers

  # The per-VM metadata written while the project was generated, in scenario order.
  def self.vm_metadata(project_dir)
    Dir.glob("#{project_dir}/kubevirt/*.json").map do |path|
      begin
        JSON.parse(File.read(path))
      rescue JSON::ParserError => e
        raise BuildError, "cannot read #{path}: #{e.message}"
      end
    end.sort_by { |meta| [meta['order'].to_i, meta['vm_name'].to_s] }
  end

  # Honour --system, which restricts a command to one system of the scenario (as it does for
  # the Vagrant commands).
  def self.select_vms(vms, options)
    system_name = options[:system].to_s
    return vms if system_name.empty?
    selected = vms.select { |meta| meta['system_name'].to_s == system_name }
    if selected.empty?
      raise BuildError, "no generated VM for system '#{system_name}' in this project (it has: " \
        "#{vms.map { |meta| meta['system_name'] }.join(', ')})"
    end
    Print.info "KubeVirt: only acting on system '#{system_name}' (--system)"
    selected
  end

  # Create the lab namespace when asked, with the quota and the clone access it needs.
  def self.ensure_lab_namespace(transport, options)
    namespace = transport.namespace.to_s
    if transport.namespace_exists?
      Print.info "KubeVirt: namespace '#{namespace}' already exists"
      return true
    end
    unless options[:kubevirtcreatenamespace]
      raise BuildError, "namespace '#{namespace}' does not exist. Create it and give it clone " \
        "access to the golden images (see 'Cluster RBAC' in README-KubeVirt.md), or pass " \
        '--kubevirt-create-namespace to have SecGen create it.'
    end

    Print.info "KubeVirt: creating namespace '#{namespace}'"
    transport.ensure_namespace

    context = TemplateContext.new
    context.namespace = namespace
    transport.apply(render(NAMESPACE_QUOTA_TEMPLATE, context))

    golden = golden_namespace(options)
    context = TemplateContext.new
    context.namespace = namespace
    context.golden_namespace = golden
    clone_rbac = render(CLONE_RBAC_TEMPLATE, context)
    # The Role and RoleBinding belong to the golden-image namespace, which is not the
    # provider's namespace, so it is named explicitly here.
    transport.kubectl(['apply', '--namespace', golden, '-f', '-'], false,
                      stdin_data: clone_rbac)
    Print.info "KubeVirt: granted namespace '#{namespace}' clone access in '#{golden}'"
    true
  end

  # kubectl/CDI failures worth explaining rather than just reporting.
  def self.apply_manifest(transport, manifest_path, options)
    transport.apply(File.read(manifest_path))
  rescue KubeVirt::TransportError => e
    if e.message.include?(CLONE_PERMISSION_ERROR)
      golden = golden_namespace(options)
      Print.err 'The cluster refused the cross-namespace clone.'
      Print.err "The lab namespace's service accounts need 'create' on datavolumes/source in " \
                "'#{golden}'."
      Print.err 'Grant it as described in "Cluster RBAC" in README-KubeVirt.md, or create the ' \
                'namespace with --kubevirt-create-namespace, which does it for you.'
    end
    raise BuildError, "failed to create the VM from #{manifest_path}: #{e.message}"
  end

  def self.wait_for_ssh(transport, vm)
    transport.wait_until("ssh to #{vm} to become available",
                         timeout: SSH_READY_TIMEOUT, interval: 10) { ssh_ready?(transport, vm) }
  rescue KubeVirt::TransportError => e
    raise BuildError, "#{e.message}\n(is virtctl installed and on PATH? see README-KubeVirt.md)"
  end

  def self.ssh_ready?(transport, vm)
    transport.ssh(vm, 'true', timeout: 60)
    true
  rescue StandardError
    false
  end

  # Warn (loudly) about scenario network modules, which phase 1 cannot honour.
  def self.warn_unsupported_network_modules(systems)
    systems.each do |system|
      network_modules = system.module_selections.select { |mod| mod.module_type == 'network' }
      next if network_modules.empty?
      Print.warn "KubeVirt provider: '#{system.name}' includes network module(s): " \
                 "#{network_modules.map(&:module_path).join(', ')}"
      Print.warn ' The KubeVirt provider (phase 1) only supports pod/masquerade networking: the'
      Print.warn ' static IPs, VLANs and isolated L2 segments the scenario describes are NOT applied.'
      Print.warn ' Guests reach each other over the cluster pod network; where a module expects an'
      Print.warn ' isolated network, that isolation does not exist. See "Networking (phase 1:'
      Print.warn ' masquerade only)" in README-KubeVirt.md.'
    end
  end

  def self.render(template_path, context)
    ERB.new(File.read(template_path), trim_mode: '<>-').result(context.get_binding)
  end

  def self.write_file(contents, path)
    File.open(path, 'w+') do |file|
      file.write(contents)
    end
  end

end
