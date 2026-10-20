require 'base64'
require 'digest'
require 'erb'
require 'fileutils'
require 'ipaddr'
require 'json'
require 'securerandom'
require 'socket'
require 'tmpdir'

require_relative 'constants.rb'
require_relative './print.rb'
require_relative 'network'
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
# NETWORKING: every guest has a masquerade interface on the cluster pod network, which is how
# SecGen reaches it (the API server) and the only way it gets a default route. Each scenario
# <network> additionally becomes a Multus interface on the lab's own L2 segment, on the address
# SecGen assigned that interface. Two backends (--kubevirt-lab-network):
#   ovn     a Kube-OVN logical switch per scenario network, spanning every node (Geneve), each in
#           a Vpc of its own so labs never see each other; addresses pinned per interface. The
#           default when the cluster has Kube-OVN.
#   bridge  a node-local Linux bridge per VLAN with whereabouts-pinned NADs: a lab's VMs only
#           reach each other while they are co-located (--kubevirt-placement compact).
# See "Networking" in README-KubeVirt.md.
#
# What a lab VM may reach (egress, other namespaces) is the cluster's policy, not SecGen's: every
# lab VM's launcher pod carries the labels secgen.io/lab-vm=true and secgen.io/lab=<namespace>
# for a NetworkPolicy to select. Services a lab uses (an LLM gateway, say) are deployed once,
# outside SecGen; scenarios are handed their address as ordinary module inputs.
class KubeVirtFunctions

  # Raised when the lab cannot be built. secgen.rb turns it into a user-facing error.
  class BuildError < StandardError; end

  # No default: unless --kubevirt-storage-class names one, the clones use the cluster's
  # default StorageClass.
  DEFAULT_STORAGE_CLASS = nil
  DEFAULT_GOLDEN_NAMESPACE = 'secgen-bases'
  DEFAULT_CPUS = '2'

  # Module types that are provisioned with puppet: everything except the base (the golden
  # image provides it) and network modules (the interfaces are the cluster's job).
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
  NAD_TEMPLATE = "#{ROOT_DIR}/lib/templates/kubevirt_nad.yaml.erb"
  OVN_TEMPLATE = "#{ROOT_DIR}/lib/templates/kubevirt_ovn.yaml.erb"

  # The lab's network plan (non-secret: names, subnets and addresses) and the rendered
  # NetworkAttachmentDefinitions, both kept in the project next to the VM manifests.
  LAB_NETWORKS_FILE = 'kubevirt/lab-networks.json'
  LAB_NAD_MANIFEST = 'kubevirt/lab-networks.yaml'

  # Label carried by every lab VMI, hence by its virt-launcher pod: the placement constraints
  # match it, and a cluster's NetworkPolicy can select lab VMs by it.
  LAB_VM_LABEL = 'secgen.io/lab-vm'
  LAB_VM_LABEL_VALUE = 'true'
  LAB_ID_LABEL = 'secgen.io/lab'

  # Placement of a lab's VMs. 'spread' (the default) lets a lab bigger than any one node's
  # free memory still build; 'compact' keeps a lab on one node, which is what a lab needs when
  # its VMs have to reach each other on their Multus networks. Anything else is a node name.
  DEFAULT_PLACEMENT = 'spread'
  PLACEMENT_SPREAD = 'spread'
  PLACEMENT_COMPACT = 'compact'

  # Lab network backends (see NETWORKING above). 'auto' picks ovn when the cluster serves the
  # kubeovn.io API, else bridge.
  LAB_NETWORK_BACKENDS = %w(auto ovn bridge).freeze
  LAB_NETWORK_OVN = 'ovn'
  LAB_NETWORK_BRIDGE = 'bridge'
  # Labels on the cluster-scoped Kube-OVN objects (Vpc, Subnet) a lab owns, so destroy can find
  # them.
  LAB_NETWORK_OWNER_LABEL = 'secgen.io/owner'
  LAB_NETWORK_OWNER_PROVIDER = 'secgen-provider'
  LAB_NETWORK_NAMESPACE_LABEL = 'secgen.io/lab-namespace'
  # A lab's Kube-OVN Subnets refuse deletion while a port is still in use: the VMs' launcher
  # pods take a little while to go after the VMs are deleted.
  OVN_DELETE_TIMEOUT = 180

  # Masquerade guests are given their default route on 10.0.2.0/24 (measured: the guest's
  # masquerade interface is 10.0.2.2/24, gateway 10.0.2.1). A lab network inside that range
  # would collide with the guest's own routing, so it counts as a cluster range.
  MASQUERADE_SUBNET = '10.0.2.0/24'.freeze
  DEFAULT_SUBNET_MASK = '255.255.255.0'
  # The scenario's ranges are `10.<n>.0.0/24` by default, which lands inside the cluster's pod
  # or service CIDR often enough to check for. Where the cluster's own ranges are not known
  # exactly, they are widened to a /16: a lab subnet slipped inside one of the cluster's /24s
  # would otherwise hand out addresses that belong to the cluster.
  CLUSTER_RANGE_WIDENING = 16


  # Values handed to the ERB templates: explicit readers (rather than a generic hash) so a
  # template cannot silently depend on something that is not set.
  class TemplateContext
    attr_accessor :vm_name, :system_name, :hostname, :memory, :cpus, :namespace
    attr_accessor :storage_class, :golden_namespace, :golden_image, :disk_size
    attr_accessor :dns_nameservers, :dns_policy
    attr_accessor :modules, :puppet_root, :puppet_system_dir
    # Lab networking and placement (kubevirt_vm.yaml.erb) and the lab's own networks
    # (kubevirt_nad.yaml.erb / kubevirt_ovn.yaml.erb).
    attr_accessor :lab_interfaces, :placement, :lab_id, :lab_network_backend
    attr_accessor :nad_networks

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
  # (a link-local address on some distributions), which the guest equally cannot reach -- both verified on
  # the cluster. So the provider always sets dnsPolicy None plus an explicit nameserver,
  # defaulting to a public resolver, and never depends on the cluster's DNS.
  def self.dns_nameservers(options)
    configured = options[:kubevirtdns].to_s.split(/[,\s]+/).reject { |nameserver| nameserver.empty? }
    configured.empty? ? DEFAULT_DNS_NAMESERVERS.dup : configured
  end

  # 'spread' (default), 'compact', or a node name (see PLACEMENT_*). Validated by secgen.rb
  # only in that it must be a non-empty string: a node name cannot be checked until the build
  # can read the cluster.
  def self.placement(options)
    value = options[:kubevirtplacement].to_s
    value.empty? ? DEFAULT_PLACEMENT : value
  end

  # 'ovn' or 'bridge'. 'auto' (the default) asks the cluster whether it serves the kubeovn.io
  # API (API discovery, which every authenticated client may read, so a restricted
  # service account can answer it too). Resolved once and remembered in the options.
  def self.lab_network_backend(options, transport = nil)
    value = options[:kubevirtlabnetwork].to_s
    value = 'auto' if value.empty?
    return value unless value == 'auto'

    transport ||= self.transport(options)
    options[:kubevirtlabnetwork] = transport.api_group_served?('kubeovn.io') ? LAB_NETWORK_OVN : LAB_NETWORK_BRIDGE
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
  #   kubevirt/lab-networks.yaml  the lab's NetworkAttachmentDefinitions (when the scenario has
  #                               networks), applied before any VM
  #   kubevirt/lab-networks.json  the lab network plan: which NAD each interface uses, and the
  #                               address it is pinned to (no secrets: addresses are in the
  #                               scenario anyway)
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

    # The scenario's networks become the lab's own L2 segments, before anything is generated:
    # the NADs have to exist before a VM that references them, and the interfaces are part of
    # the VM manifest.
    lab_network_backend(options, transport)
    plan = lab_network_plan(systems, options)
    write_lab_networks(out_dir, plan, options)

    systems.each_with_index do |system, index|
      vm = vm_name(system.name)
      begin
        golden_image = golden_image_for(system)
        disk_size = clone_size(golden_image, options, transport)
      rescue BuildError => e
        Print.err e.message
        exit 1
      end

      interfaces = plan['systems'][system.name] || []

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
        'placement' => placement(options),
        'lab_interfaces' => interfaces,
        'order' => index,
        'created' => Time.now.to_s
      }

      context = template_context(system, vm, golden_image, disk_size,
                                 module_inputs(system, out_dir), interfaces, options)
      write_file(render(VM_TEMPLATE, context), "#{kubevirt_dir}/#{vm}.yaml")
      write_file(render(PROVISION_TEMPLATE, context), "#{kubevirt_dir}/#{vm}-provision.sh")
      write_file(JSON.pretty_generate(meta), "#{kubevirt_dir}/#{vm}.json")

      Print.std "Creating KubeVirt VM manifest: #{kubevirt_dir}/#{vm}.yaml"
      Print.info " #{vm}: #{golden_image} cloned into the namespace, #{meta['cpus']} cpu(s), " \
                 "#{meta['memory']}Mi, disk #{disk_size}#{lab_interface_summary(interfaces)}"
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

  def self.template_context(system, vm, golden_image, disk_size, modules, interfaces, options)
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
    # One bridge interface per scenario network, plus the placement that decides whether they
    # will reach each other (a Multus L2 segment exists on one node).
    context.lab_interfaces = interfaces
    context.placement = placement(options)
    context.lab_id = options[:kubevirtnamespace].to_s
    context.lab_network_backend = lab_network_backend(options)
    context
  end

  # ------------------------------------------------------------------ lab networks

  # The lab's network plan: the NetworkAttachmentDefinitions to create, and the interfaces each
  # system's VM attaches.
  #
  # SecGen's model maps onto KubeVirt like this:
  #
  #   a scenario <network>     -> one interface on the VM (net1, net2, ... after the masquerade
  #                              NIC), on the bridge of its VLAN
  #   the VLAN                 -> the L2 segment: every system given the same vlan shares one
  #                              bridge, and so can reach the others on that segment
  #   the interface's address  -> a NAD with its whereabouts pool pinned to exactly that address
  #
  # The address has to be pinned rather than left to the IPAM: SecGen assigns it when the
  # scenario is built and gives it to other modules as <network_ip>, so a guest that ends up on
  # a different address leaves the lab configured to talk to nothing. (A NAD is per address
  # because KubeVirt drops a per-interface address request: see the NAD template.)
  def self.lab_network_plan(systems, options)
    namespace = options[:kubevirtnamespace].to_s
    network_map = options[:network_map] || {}
    base_vlan = options[:proxmoxvlan].to_s.empty? ? 0 : options[:proxmoxvlan].to_i

    vlans = {}       # vlan => { 'range' => cidr, 'systems' => [name] }
    want = {}        # vlan => [[system_name, address, comment]]
    interfaces = {}  # system name => [interface]

    systems.each do |system|
      list = []
      system.network_module_selections.each do |mod|
        # Only private_network elements are scenario-defined L2 segments. public_network is a DHCP
        # interface on the hypervisor's bridged network, which a lab VM has no equivalent of
        # (warn_network_module_limits says so); its masquerade interface fills that role.
        next unless (mod.attributes['type'] || []).first.to_s == 'private_network'

        vlan = NetworkFunctions.compute_vlan(mod, base_vlan)
        entry = network_map[vlan]
        address = entry && entry[:ips] ? entry[:ips][mod.unique_id] : nil
        if entry.nil? || address.to_s.empty?
          Print.warn "KubeVirt: #{system.name}'s network module #{mod.module_path} has no address " \
                     'in the scenario network map: no interface is created for it.'
          next
        end

        mask = (mod.received_inputs['subnet_mask'] || []).first.to_s
        mask = DEFAULT_SUBNET_MASK if mask.empty?
        range = "#{entry[:subnet]}/#{prefix_length(mask)}"
        vlans[vlan] ||= { 'range' => range, 'systems' => [] }
        vlans[vlan]['systems'] << system.name
        (want[vlan] ||= []) << [system.name, address, mod.received_inputs.include?('IP_address')]
        list << { 'vlan' => vlan, 'address' => address }
      end
      interfaces[system.name] = list
    end

    if lab_network_backend(options) == LAB_NETWORK_OVN
      return ovn_lab_network_plan(namespace, vlans, want, interfaces, options)
    end

    # One NAD per interface address, all of a VLAN's addresses on that VLAN's bridge.
    nad_networks = []
    vlans.keys.sort.each do |vlan|
      bridge = bridge_name(namespace, vlan)
      range = vlans[vlan]['range']
      want.fetch(vlan, []).each do |system_name, address, fixed|
        nad_networks << {
          'name' => network_nad_name(vlan, address),
          'bridge' => bridge,
          'range' => range,
          'range_start' => address,
          'range_end' => address,
          'vlan' => vlan,
          'system' => system_name,
          'comment' => "VLAN #{vlan} (#{range}) for '#{system_name}': pinned to #{address}" \
                       "#{fixed ? ' (fixed in the scenario)' : ' (assigned by the scenario, pinned so the ' \
                       'guest gets the address the scenario was built with)'}. Shares bridge " \
                       "#{bridge} with the VLAN's other interfaces."
        }
      end
    end

    # The VM's interfaces: net1, net2, ... in scenario order, after the masquerade NIC.
    attached = interfaces.each_with_object({}) do |(system_name, list), out|
      out[system_name] = list.each_with_index.map do |interface, index|
        nad = network_nad_name(interface['vlan'], interface['address'])
        { 'name' => "net#{index + 1}",
          'nad' => nad,
          'nad_namespace' => namespace,
          'address' => interface['address'],
          'vlan' => interface['vlan'],
          'comment' => "VLAN #{interface['vlan']} lab network, address #{interface['address']} " \
                       "(NAD #{nad})" }
      end
    end

    { 'namespace' => namespace, 'backend' => LAB_NETWORK_BRIDGE, 'networks' => nad_networks,
      'systems' => attached }
  end

  # The Kube-OVN form of the plan: one Vpc + Subnet + NAD per VLAN (not per address), and each
  # interface carries its address for the ip_address annotation on the VM template.
  def self.ovn_lab_network_plan(namespace, vlans, want, interfaces, options)
    nad_networks = vlans.keys.sort.map do |vlan|
      range = vlans[vlan]['range']
      used = want.fetch(vlan, []).map { |_system, address, _fixed| address }
      names = ovn_names(namespace, vlan)
      network = names.merge(
        'range' => range,
        'gateway' => ovn_gateway(range, used),
        'vlan' => vlan,
        'systems' => vlans[vlan]['systems'].uniq,
        'addresses' => used,
        'comment' => "VLAN #{vlan} (#{range}): #{vlans[vlan]['systems'].uniq.join(', ')} " \
                     "(#{used.join(', ')}). Kube-OVN logical switch #{names['subnet']} in Vpc " \
                     "#{names['vpc']}, spanning every node."
      )
      network
    end

    attached = interfaces.each_with_object({}) do |(system_name, list), out|
      out[system_name] = list.each_with_index.map do |interface, index|
        names = ovn_names(namespace, interface['vlan'])
        { 'name' => "net#{index + 1}",
          'nad' => names['name'],
          'nad_namespace' => namespace,
          'provider' => names['provider'],
          'address' => interface['address'],
          'vlan' => interface['vlan'],
          'comment' => "VLAN #{interface['vlan']} lab network, address #{interface['address']} " \
                       "(Kube-OVN NAD #{names['name']}, pinned with the ip_address annotation)" }
      end
    end

    { 'namespace' => namespace, 'backend' => LAB_NETWORK_OVN, 'networks' => nad_networks,
      'systems' => attached }
  end

  # Names for a lab network on the Kube-OVN backend. The Vpc and Subnet are cluster-scoped, so
  # they carry a hash of the namespace (the full name can be too long for some labels) plus the
  # VLAN; the NAD is namespaced and named after the VLAN only. The provider string ties all three together: <nad>.<namespace>.ovn.
  def self.ovn_names(namespace, vlan)
    tag = "lab-#{Digest::SHA1.hexdigest(namespace.to_s)[0, 8]}-#{vlan}"
    nad = "secgen-net-#{vlan}"
    # Kube-OVN refuses a Subnet named like its Vpc ("cannot have the same name").
    { 'vpc' => tag, 'subnet' => "#{tag}-net", 'name' => nad, 'provider' => "#{nad}.#{namespace}.ovn" }
  end

  # A Kube-OVN Subnet needs a gateway address. Nothing routes through it (the Vpc has no other
  # subnet, and the guests get no default route on a lab network), so it only has to be an
  # address no lab system uses: the highest host address that is free.
  def self.ovn_gateway(range, used)
    net = IPAddr.new(range)
    first = net.to_range.first.to_i
    last = net.to_range.last.to_i
    candidate = last - 1
    candidate -= 1 while used.include?(IPAddr.new(candidate, Socket::AF_INET).to_s) && candidate > first + 1
    IPAddr.new(candidate, Socket::AF_INET).to_s
  end

  # Write the lab's NAD manifest and its plan into the project. Both are plain objects: the
  # addresses they carry are already in the generated scenario.
  def self.write_lab_networks(out_dir, plan, options)
    networks = plan['networks'] || []
    if networks.empty?
      Print.info 'KubeVirt: the scenario has no lab networks (only the pod network per guest)'
    else
      context = TemplateContext.new
      context.namespace = plan['namespace']
      context.nad_networks = networks
      if plan['backend'] == LAB_NETWORK_OVN
        write_file(render(OVN_TEMPLATE, context), "#{out_dir}/#{LAB_NAD_MANIFEST}")
        Print.std "Creating KubeVirt lab networks (Kube-OVN, cross-node): " \
                  "#{out_dir}/#{LAB_NAD_MANIFEST} (#{networks.size} network(s))"
        networks.each do |network|
          Print.info " #{network['name']}: VLAN #{network['vlan']} #{network['range']} for " \
                     "#{network['addresses'].join(', ')}"
        end
      else
        write_file(render(NAD_TEMPLATE, context), "#{out_dir}/#{LAB_NAD_MANIFEST}")
        Print.std "Creating KubeVirt lab networks: #{out_dir}/#{LAB_NAD_MANIFEST} " \
                  "(#{networks.size} attachment definition(s))"
        networks.each do |network|
          Print.info " #{network['name']}: VLAN #{network['vlan']} #{network['range']} pinned to " \
                     "#{network['range_start']} on #{network['bridge']}"
        end
      end
    end
    write_file(JSON.pretty_generate(plan), "#{out_dir}/#{LAB_NETWORKS_FILE}")
    placement_limits(plan, options) if networks.any?
    true
  end

  def self.lab_interface_summary(interfaces)
    return '' if interfaces.empty?

    " + #{interfaces.size} lab network interface(s): " \
      "#{interfaces.map { |interface| "#{interface['name']}=#{interface['address']}" }.join(', ')}"
  end

  # A Linux bridge name is limited to 15 characters (IFNAMSIZ), and the bridge lives on the
  # node: it must not collide with another lab's bridge there, so the namespace goes into the
  # name as a hash. Two labs on one node therefore never share an L2 segment.
  def self.bridge_name(namespace, vlan)
    "br-#{Digest::SHA1.hexdigest(namespace.to_s)[0, 5]}-#{vlan}"[0, 15]
  end

  def self.network_nad_name(vlan, address)
    "secgen-net-#{vlan}-ip-#{address.tr('.', '-')}"
  end

  # 255.255.255.0 -> 24. A scenario's subnet_mask says how wide the lab segment is; fall back to
  # a /24 (SecGen's own default) if it is missing or unreadable.
  def self.prefix_length(mask)
    bits = IPAddr.new(mask).to_i.to_s(2).count('1')
    bits.zero? ? 24 : bits
  rescue StandardError
    24
  end

  # What the lab's own networks must not overlap: the cluster's pod and service networks, the
  # nodes themselves, and KubeVirt's masquerade subnet. SecGen assigns a random `10.<n>.0.0/24`
  # when a scenario does not fix a range, which lands inside the pod or service CIDR often
  # enough to be worth checking -- a bridge handing out addresses that belong to the cluster
  # would break the node it runs on, not just the lab.
  def self.cluster_ranges(transport)
    ranges = [{ 'cidr' => MASQUERADE_SUBNET, 'why' => "KubeVirt's masquerade subnet" }]

    transport.node_pod_cidrs.each do |cidr|
      ranges << { 'cidr' => widen(cidr), 'why' => "the cluster's pod network (#{cidr} is a node's pod CIDR)" }
    end
    transport.service_cluster_ips.each do |address|
      ranges << { 'cidr' => widen("#{address}/32"),
                  'why' => "the cluster's Service network (a ClusterIP is #{address})" }
    end
    transport.nodes.each do |node|
      ranges << { 'cidr' => widen("#{node['ip']}/32"), 'why' => "node #{node['name']} (#{node['ip']})" }
    end

    ranges.uniq { |range| range['cidr'] }
  rescue KubeVirt::TransportError => e
    raise BuildError, "cannot read the cluster's own address ranges to check the lab networks " \
      "against them: #{e.message}"
  end

  # Widen a known address or small CIDR to the block the cluster reserved around it. The
  # cluster does not publish its pod/service CIDRs in a way this provider can read (they live in
  # the control plane's own configuration), so they are inferred: per-node pod CIDRs are /24s out of one
  # pool, and ClusterIPs are spread over the service CIDR's /16s.
  def self.widen(cidr)
    address = IPAddr.new(cidr)
    prefix = address.prefix
    return "#{address}/#{prefix}" if prefix <= CLUSTER_RANGE_WIDENING

    IPAddr.new("#{address.to_i & mask_for(CLUSTER_RANGE_WIDENING)}/#{CLUSTER_RANGE_WIDENING}").to_s
  rescue StandardError
    cidr.to_s
  end

  def self.mask_for(prefix)
    ((1 << prefix) - 1) << (32 - prefix)
  end

  # Refuse to build a lab whose networks overlap the cluster's own addressing, naming both sides
  # of the clash. This runs before anything is applied, so a rejected lab leaves nothing behind.
  def self.check_lab_subnets(transport, networks)
    conflicts = []
    cluster_ranges(transport).each do |range|
      cluster = IPAddr.new(range['cidr'])
      networks.each do |network|
        lab = IPAddr.new(network['range'])
        next unless cluster.include?(lab) || lab.include?(cluster)

        conflicts << [network, range]
      end
    end
    return true if conflicts.empty?

    Print.err 'The lab networks overlap the cluster\'s own address space:'
    conflicts.each do |network, range|
      Print.err "  #{network['name']}: #{network['range']} overlaps #{range['cidr']} (#{range['why']})"
    end
    Print.err 'A bridge handing out the cluster\'s addresses breaks the node it runs on.'
    Print.err 'Give the scenario network an explicit non-overlapping range (a <network> element'
    Print.err 'with an <input into="range"> value), or remap the scenario\'s ranges with'
    Print.err '--network-ranges. See "Networking" in README-KubeVirt.md.'
    raise BuildError, 'lab networks overlap the cluster\'s own address space'
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
    # The lab's networks come first: a VM referencing a NetworkAttachmentDefinition that does not
    # exist yet never gets its networking set up, and the subnet check has to run before anything
    # is applied so a rejected lab leaves nothing behind.
    ensure_lab_networks(transport, project_dir, options)

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
        # This address is on the cluster pod network and is not reachable from outside the
        # cluster. Use virtctl to get into the guest. The lab network addresses below are the
        # ones the scenario was built with.
        Print.info " #{vm}: #{phase}#{ip.empty? ? '' : " at #{ip} (pod network, not routable here)"}" \
                   " - golden image #{meta['golden_image']}"
        lab = transport.vmi_interfaces(vm).reject { |interface| interface['name'] == 'default' }
        if lab.empty? && !(meta['lab_interfaces'] || []).empty?
          # The VMI is up but has no secondary interface: the lab network did not come up, which
          # is what a missing NetworkAttachmentDefinition looks like.
          Print.warn " #{vm}: its lab networks are missing (expected " \
                     "#{(meta['lab_interfaces'] || []).map { |interface| interface['address'] }.join(', ')})"
        elsif !lab.empty?
          Print.info " #{vm}: lab network(s) #{lab.map { |interface| "#{interface['name']}=#{interface['ip']}" }.join(', ')}"
        end
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
  #
  # The lab's own networks go with it, but only when the whole lab is being
  # destroyed: --system leaves the other VMs running, and they still need their networks.
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

    if options[:system].to_s.empty?
      plan = lab_network_plan_from_project(project_dir)
      (plan['networks'] || []).each do |network|
        transport.delete('network-attachment-definition', network['name'])
      end
      if plan['backend'] == LAB_NETWORK_OVN
        removed = delete_ovn_networks(transport, plan)
        Print.info "KubeVirt: deleted #{removed} Kube-OVN lab network(s)"
      elsif !(plan['networks'] || []).empty?
        Print.info "KubeVirt: deleted #{plan['networks'].size} lab network(s)"
        Print.info 'KubeVirt: whereabouts keeps its address records in kube-system/ippools; an empty'
        Print.info ' pool left behind is harmless and is reused by the next lab on that subnet.'
      end
    end
    true
  end

  def self.set_run_strategy(transport, vm, strategy)
    transport.kubectl(['patch', 'vm', vm, '--type', 'merge',
                       '-p', "{\"spec\":{\"runStrategy\":\"#{strategy}\"}}"])
  end

  # ------------------------------------------------------------------ lab networking

  # The lab's network plan, as it was written into the project when that was generated. A project
  # with no networks (or one generated before the provider had networks) has no file: the lab
  # then just has its guests on the pod network.
  def self.lab_network_plan_from_project(project_dir)
    path = "#{project_dir}/#{LAB_NETWORKS_FILE}"
    return { 'networks' => [], 'systems' => {} } unless File.exist?(path)

    JSON.parse(File.read(path))
  rescue JSON::ParserError => e
    raise BuildError, "cannot read #{path}: #{e.message}"
  end

  # Create the lab's NetworkAttachmentDefinitions. They have to exist before the VMs that
  # reference them: Multus fails a pod whose NAD is missing, so the VM would not come up.
  def self.ensure_lab_networks(transport, project_dir, options)
    plan = lab_network_plan_from_project(project_dir)
    networks = plan['networks'] || []
    if networks.empty?
      Print.info 'KubeVirt: the lab has no networks of its own (pod network only)'
      return plan
    end

    check_lab_subnets(transport, networks)
    check_ovn_networks(transport, plan) if plan['backend'] == LAB_NETWORK_OVN

    manifest = "#{project_dir}/#{LAB_NAD_MANIFEST}"
    unless File.exist?(manifest)
      raise BuildError, "missing generated lab network manifest #{manifest}"
    end
    # apply, not create: rebuilding a lab reuses the same NADs, so the interfaces keep the
    # addresses the scenario was built with.
    begin
      transport.apply(File.read(manifest))
    rescue KubeVirt::TransportError => e
      raise BuildError, "failed to create the lab's networks from #{manifest}: #{e.message}"
    end
    wait_ovn_networks(transport, plan) if plan['backend'] == LAB_NETWORK_OVN
    Print.info "KubeVirt: #{networks.size} lab network(s) ready " \
               "(#{networks.map { |network| network['name'] }.join(', ')})"
    plan
  end

  # Before applying a Kube-OVN lab's networks: a Subnet of the same name that already exists must
  # belong to this lab (Vpc and Subnet are cluster-scoped, so another lab's would be clobbered).
  def self.check_ovn_networks(transport, plan)
    (plan['networks'] || []).each do |network|
      next if transport.cluster_jsonpath('subnets.kubeovn.io', network['subnet'], '{.metadata.name}').empty?

      owner = transport.cluster_jsonpath('subnets.kubeovn.io', network['subnet'],
                                         "{.metadata.labels.secgen\\.io/lab-namespace}")
      next if owner == plan['namespace']

      raise BuildError, "Kube-OVN subnet #{network['subnet']} already exists and belongs to " \
        "'#{owner}', not this lab."
    end
  end

  # Kube-OVN validates a Subnet asynchronously and only then creates its logical switch; a VM
  # created before that has its address request resolved against the default subnet and never
  # starts (AddressOutOfRange). Wait for Ready, and surface Kube-OVN's own reason if it refuses.
  def self.wait_ovn_networks(transport, plan)
    (plan['networks'] || []).each do |network|
      reason = ''
      transport.wait_until("lab network #{network['subnet']} to be ready", timeout: 120, interval: 3) do
        status = transport.cluster_jsonpath('subnets.kubeovn.io', network['subnet'],
                                            '{.status.conditions[?(@.type=="Ready")].status}')
        reason = transport.cluster_jsonpath('subnets.kubeovn.io', network['subnet'],
                                            '{.status.conditions[?(@.type=="Error")].message}')
        status == 'True'
      end
    rescue KubeVirt::TransportError => e
      raise BuildError, "Kube-OVN did not bring up lab network #{network['subnet']}" \
                        "#{reason.empty? ? '' : " (#{reason})"}: #{e.message}"
    end
  end

  # Remove the Kube-OVN objects a lab created. A Subnet with ports
  # still in use is held by Kube-OVN's finalizer and goes by itself once the last launcher pod
  # has; the Vpc is deleted after its Subnet is gone.
  def self.delete_ovn_networks(transport, plan)
    owned = plan['networks'] || []
    owned.each do |network|
      transport.delete_cluster('subnets.kubeovn.io', network['subnet'])
    end
    owned.each do |network|
      transport.wait_until("lab network #{network['subnet']} to be released",
                           timeout: OVN_DELETE_TIMEOUT, interval: 5) do
        transport.cluster_jsonpath('subnets.kubeovn.io', network['subnet'], '{.metadata.name}').empty?
      end
      transport.delete_cluster('vpcs.kubeovn.io', network['vpc'])
    end
    owned.size
  rescue KubeVirt::TransportError => e
    Print.warn "KubeVirt: lab network cleanup incomplete (#{e.message}); Kube-OVN removes a Subnet " \
               'once its last port is gone -- re-run kubevirt-destroy to finish.'
    0
  end

  # What spreading a lab costs, said out loud. A lab's Multus network is a bridge on one node, so
  # its VMs only reach each other on it while they land on the same node -- and the default
  # placement spreads a lab because one node rarely has room for all of it. Which of the two
  # matters more is the user's call, so the tradeoff is stated rather than chosen silently.
  def self.placement_limits(plan, options)
    return unless placement(options) == PLACEMENT_SPREAD
    # Kube-OVN lab networks span the nodes: spreading a lab costs nothing.
    return if plan['backend'] == LAB_NETWORK_OVN

    shared = {}
    (plan['networks'] || []).each do |network|
      (shared[network['vlan']] ||= []) << network['system']
    end
    shared.each do |vlan, systems|
      systems = systems.compact.uniq
      next if systems.size < 2

      Print.warn "KubeVirt: VLAN #{vlan} connects #{systems.sort.join(', ')}, and the default " \
                 "placement spreads a lab over the cluster's nodes."
      Print.warn ' A lab network is a bridge on one node, so those VMs only reach each other on it'
      Print.warn ' while they are on the same node. Pass --kubevirt-placement compact (or a node'
      Print.warn ' name) when the scenario needs them to. See "Networking" in README-KubeVirt.md.'
    end
  end

  # ------------------------------------------------------------------ helpers

  # The per-VM metadata written while the project was generated, in scenario order.
  def self.vm_metadata(project_dir)
    # kubevirt/ also holds lab-networks.json, so a file is VM metadata only if it names a VM;
    # globbing *.json alone made the network plan a nameless third "VM" (found on the first
    # real kubevirt-build run).
    Dir.glob("#{project_dir}/kubevirt/*.json").map do |path|
      begin
        JSON.parse(File.read(path))
      rescue JSON::ParserError => e
        raise BuildError, "cannot read #{path}: #{e.message}"
      end
    end.select { |meta| meta.is_a?(Hash) && !meta['vm_name'].to_s.empty? }
      .sort_by { |meta| [meta['order'].to_i, meta['vm_name'].to_s] }
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

  # Scenario network settings this mapping cannot honour, said out loud rather than silently
  # dropped: a lab whose network is not what its scenario describes is worse than a warning. The
  # mapping itself (VLANs to bridges, addresses pinned) is done by lab_network_plan; what is left
  # over is the parts of a scenario network that have no equivalent on a cluster.
  def self.warn_network_module_limits(systems, options)
    systems.each do |system|
      system.network_module_selections.each do |mod|
        type = (mod.attributes['type'] || []).first.to_s
        if type != 'private_network'
          Print.warn "KubeVirt: #{system.name} has a #{type} interface (#{mod.module_path})."
          Print.warn ' A KubeVirt lab has no bridged host network: the guest keeps its masquerade'
          Print.warn ' interface on the cluster pod network for that role, and no extra interface is'
          Print.warn ' created. Scenario <network> elements of type private_network do get their own'
          Print.warn ' interface. See "Networking" in README-KubeVirt.md.'
          next
        end

        %w(default_gateway dns_nameservers routes).each do |input|
          values = (mod.received_inputs[input] || []).reject { |value| value.to_s.empty? }
          next if values.empty?

          vlan = NetworkFunctions.compute_vlan(mod, options[:proxmoxvlan].to_s.empty? ? 0 : options[:proxmoxvlan].to_i)
          Print.warn "KubeVirt: #{system.name}'s VLAN #{vlan} network sets #{input}: " \
                     "#{values.join(', ')}"
          Print.warn ' A lab network is a plain L2 segment with no router, and a guest has one'
          Print.warn ' resolver (--kubevirt-dns) rather than one per interface, so a gateway, nameserver'
          Print.warn ' or route on a scenario network is NOT applied: the guest keeps the masquerade'
          Print.warn ' interface as its default route. Put a router VM on the network if the lab needs'
          Print.warn ' one. See "Networking" in README-KubeVirt.md.'
        end
      end
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
