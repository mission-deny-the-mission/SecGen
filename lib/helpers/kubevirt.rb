require 'base64'
require 'digest'
require 'erb'
require 'fileutils'
require 'ipaddr'
require 'json'
require 'securerandom'
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
# <network> additionally becomes a Multus bridge interface on the lab's own L2 segment, with a
# NetworkAttachmentDefinition pinned to the address SecGen assigned that interface. That is the
# one thing to know about this mapping: a Multus L2 segment exists on a single node, so a lab's
# VMs only reach each other on it while they are co-located (--kubevirt-placement).
# See "Networking" in README-KubeVirt.md.
#
# The lab can also be given an egress tier (--kubevirt-egress): the whole point of a lab VM on a
# shared cluster is that it does not have the cluster's own network reach, so 'litellm' opens
# only the LiteLLM lane and 'none' opens nothing. Applying that tier is the last step of a
# build, because provisioning needs open egress.
class KubeVirtFunctions

  # Raised when the lab cannot be built. secgen.rb turns it into a user-facing error.
  class BuildError < StandardError; end

  DEFAULT_STORAGE_CLASS = 'ceph-block'
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
  EGRESS_CNP_TEMPLATE = "#{ROOT_DIR}/lib/templates/kubevirt_egress_cnp.yaml.erb"

  # The lab's network plan (non-secret: names, subnets and addresses) and the rendered
  # NetworkAttachmentDefinitions, both kept in the project next to the VM manifests.
  LAB_NETWORKS_FILE = 'kubevirt/lab-networks.json'
  LAB_NAD_MANIFEST = 'kubevirt/lab-networks.yaml'

  # Label carried by every lab VMI, hence by its virt-launcher pod: the egress tier's
  # CiliumNetworkPolicy selects on it, and the placement constraints match it.
  LAB_VM_LABEL = 'secgen.io/lab-vm'
  LAB_VM_LABEL_VALUE = 'true'
  LAB_ID_LABEL = 'secgen.io/lab'

  # Placement of a lab's VMs. 'spread' (the default) lets a lab bigger than any one node's
  # free memory still build; 'compact' keeps a lab on one node, which is what a lab needs when
  # its VMs have to reach each other on their Multus networks. Anything else is a node name.
  DEFAULT_PLACEMENT = 'spread'
  PLACEMENT_SPREAD = 'spread'
  PLACEMENT_COMPACT = 'compact'

  # Egress tiers. 'internet' applies no policy at all (the cluster's default reach), 'litellm'
  # allows only the LiteLLM lane, 'none' allows nothing.
  EGRESS_TIERS = %w(internet litellm none).freeze
  DEFAULT_EGRESS = 'internet'
  EGRESS_CNP_NAME = 'secgen-lab-egress'

  # LiteLLM as it is deployed beside the labs: the Service's NodePort is the only address a
  # masquerade guest can complete a connection to, and the master key is read out of the
  # Secret at build time. Neither is ever written into the project: the key goes to the guest
  # only, and the endpoint the guest is given is a hosts entry, so the guest needs no DNS.
  DEFAULT_LITELLM_SERVICE = 'litellm/litellm'
  DEFAULT_LITELLM_SECRET = 'litellm/master-key:litellm-master-key'
  LLM_HOSTNAME = 'litellm.lab'
  LLM_MODELS = %w(spark-active glm-5.3-flash).freeze
  GUEST_LLM_ENV_PATH = '/etc/profile.d/secgen-llm.sh'
  GUEST_HOSTS_PATH = '/etc/hosts'
  # Where a generated script (which may carry the key) lands in the guest before it is run.
  GUEST_LLM_SCRIPT_PATH = '/tmp/secgen-llm-access.sh'
  # How long to wait for the egress policy to take effect in the datapath: measured at about a
  # minute, so the check retries rather than testing once straight after the apply.
  LLM_LANE_TIMEOUT = 300

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
    # Lab networking and placement (kubevirt_vm.yaml.erb), the lab's own networks
    # (kubevirt_nad.yaml.erb) and the egress tier (kubevirt_egress_cnp.yaml.erb).
    attr_accessor :lab_interfaces, :placement, :lab_id
    attr_accessor :nad_networks
    attr_accessor :egress_tier, :egress_port, :egress_dns_servers

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

  # Which egress tier the lab gets. secgen.rb rejects anything outside EGRESS_TIERS, so this
  # only has to fill in the default.
  def self.egress_tier(options)
    value = options[:kubevirtegress].to_s
    EGRESS_TIERS.include?(value) ? value : DEFAULT_EGRESS
  end

  # 'spread' (default), 'compact', or a node name (see PLACEMENT_*). Validated by secgen.rb
  # only in that it must be a non-empty string: a node name cannot be checked until the build
  # can read the cluster.
  def self.placement(options)
    value = options[:kubevirtplacement].to_s
    value.empty? ? DEFAULT_PLACEMENT : value
  end

  # Is this lab handed the LiteLLM lane? It comes with the 'litellm' tier, and --kubevirt-llm
  # adds it to a lab whose tier is open. A 'none' lab has no egress at all, so there is nothing
  # to hand it.
  def self.inject_llm?(options)
    tier = egress_tier(options)
    return false if tier == 'none'

    tier == 'litellm' || options[:kubevirtllm]
  end

  # The LiteLLM Service as <namespace, name>. A NodePort is the only way a masquerade guest can
  # reach a service (a ClusterIP is not routable from the guest), so the provider reads the
  # NodePort from the Service rather than being told it.
  def self.litellm_service(options)
    value = options[:kubevirtlitellmservice].to_s
    value = DEFAULT_LITELLM_SERVICE if value.empty?
    namespace, _, name = value.partition('/')
    if namespace.empty? || name.empty?
      raise BuildError, "--kubevirt-litellm-service wants <namespace>/<service>, got '#{value}'"
    end
    [namespace, name]
  end

  # The Secret holding the LiteLLM master key, as <namespace, name, key>. Read at build time and
  # handed to the guest only; it is never written into the project.
  def self.litellm_secret(options)
    value = options[:kubevirtlitellmsecret].to_s
    value = DEFAULT_LITELLM_SECRET if value.empty?
    reference, separator, key = value.rpartition(':')
    namespace, _, name = reference.partition('/')
    if separator.empty? || namespace.empty? || name.empty? || key.empty?
      raise BuildError, "--kubevirt-litellm-secret wants <namespace>/<name>:<key>, got '#{value}'"
    end
    [namespace, name, key]
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

    { 'namespace' => namespace, 'networks' => nad_networks, 'systems' => attached }
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
      write_file(render(NAD_TEMPLATE, context), "#{out_dir}/#{LAB_NAD_MANIFEST}")
      Print.std "Creating KubeVirt lab networks: #{out_dir}/#{LAB_NAD_MANIFEST} " \
                "(#{networks.size} attachment definition(s))"
      networks.each do |network|
        Print.info " #{network['name']}: VLAN #{network['vlan']} #{network['range']} pinned to " \
                   "#{network['range_start']} on #{network['bridge']}"
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
  # cluster does not publish its pod/service CIDRs in a way this provider can read (Talos puts
  # them in the machine config), so they are inferred: per-node pod CIDRs are /24s out of one
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

    # Only now, with every guest provisioned: provisioning needs open egress (apt, downloads),
    # so a lab locked down before its modules ran would fail to build.
    apply_egress_policy(transport, options)
    # Last: the lab's LLM lane, given to each guest and then actually exercised from inside it,
    # because the egress policy takes about a minute to reach the datapath.
    inject_llm_lane(transport, vms, options) if inject_llm?(options)

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
  # The lab's own networks and its egress policy go with it, but only when the whole lab is being
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
      transport.delete('ciliumnetworkpolicy', EGRESS_CNP_NAME)
      unless (plan['networks'] || []).empty?
        Print.info "KubeVirt: deleted #{plan['networks'].size} lab network(s) and the egress policy"
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
    Print.info "KubeVirt: #{networks.size} lab network(s) ready " \
               "(#{networks.map { |network| network['name'] }.join(', ')})"
    plan
  end

  # ------------------------------------------------------------------ egress tier

  # Give the lab its egress tier. 'internet' is the cluster's default reach, so it means no
  # policy at all; the other tiers are one CiliumNetworkPolicy selecting every lab VM in the
  # namespace. Runs after provisioning: the build itself needs open egress.
  def self.apply_egress_policy(transport, options)
    tier = egress_tier(options)
    if tier == 'internet'
      # A policy from an earlier build with a tighter tier would otherwise still be in force, so
      # the lab would look like it has the default reach while the old allow-list applied.
      if transport.exists?('ciliumnetworkpolicy', EGRESS_CNP_NAME)
        transport.delete('ciliumnetworkpolicy', EGRESS_CNP_NAME)
        Print.info "KubeVirt: egress tier 'internet': removed the lab's old egress policy"
      else
        Print.info "KubeVirt: egress tier 'internet' (no policy: the lab has the cluster's default reach)"
      end
      return true
    end

    port = nil
    if tier == 'litellm'
      namespace, service_name = litellm_service(options)
      port = transport.service_node_port(namespace, service_name)
      if port.to_s.empty?
        raise BuildError, "the LiteLLM service #{namespace}/#{service_name} has no nodePort, so no " \
          'guest can reach it: a masquerade guest cannot reach a ClusterIP. See "The LLM lane" in ' \
          'README-KubeVirt.md.'
      end
    end

    context = TemplateContext.new
    context.namespace = transport.namespace.to_s
    context.egress_tier = tier
    context.egress_port = port.to_s
    # Only IPv4 resolvers can be in the policy: a masquerade guest has no usable IPv6 outside the
    # pod, and a toCIDR rule cannot mix the families.
    context.egress_dns_servers = dns_nameservers(options).select { |server| ipv4?(server) }

    begin
      transport.apply(render(EGRESS_CNP_TEMPLATE, context))
    rescue KubeVirt::TransportError => e
      raise BuildError, "failed to apply the '#{tier}' egress tier: #{e.message}"
    end

    if tier == 'litellm'
      Print.info "KubeVirt: egress tier 'litellm': the lab may reach node port #{port}/TCP and its " \
                 'resolver, and nothing else (the rest of the cluster, the registry mirror and the ' \
                 'internet are denied)'
      Print.info 'KubeVirt: the policy takes about a minute to take effect, so the LLM lane is ' \
                 'checked from inside each guest below'
    else
      Print.info "KubeVirt: egress tier 'none': the lab has no egress at all"
    end
    true
  end

  def self.ipv4?(address)
    IPAddr.new(address).ipv4?
  rescue StandardError
    false
  end

  # ------------------------------------------------------------------ the LLM lane

  # Hand every guest the lab's LLM endpoint. The key is read out of the cluster here, at build
  # time, and written into the guest only: it never reaches the project directory, and it is not
  # put on a command line (the process table, which --verbose also prints).
  def self.inject_llm_lane(transport, vms, options)
    namespace, service_name = litellm_service(options)
    secret_namespace, secret_name, secret_key = litellm_secret(options)

    port = transport.service_node_port(namespace, service_name).to_s
    if port.empty?
      raise BuildError, "the LiteLLM service #{namespace}/#{service_name} has no nodePort: the lab " \
        'LLM lane is addressed as a NodePort because a masquerade guest cannot reach a ClusterIP. ' \
        'See "The LLM lane" in README-KubeVirt.md.'
    end

    key = transport.secret_value(secret_namespace, secret_name, secret_key)
    if key.to_s.empty?
      raise BuildError, "secret #{secret_namespace}/#{secret_name} has no '#{secret_key}': pass " \
        '--kubevirt-litellm-secret <namespace>/<name>:<key>. See "The LLM lane" in README-KubeVirt.md.'
    end

    serving_nodes = transport.endpoint_nodes(namespace, service_name)
    if serving_nodes.empty?
      Print.warn "KubeVirt: the LiteLLM service #{namespace}/#{service_name} reports no endpoints: " \
                 'the lane will not answer until it has a ready replica'
    end

    vms.each do |meta|
      vm = meta['vm_name']
      node_ip = llm_node_ip(transport, transport.vmi_node_name(vm), serving_nodes)
      push_and_run(transport, vm, llm_access_script(node_ip, port, key), GUEST_LLM_SCRIPT_PATH)
      Print.info "KubeVirt: #{vm} has the LiteLLM lane at http://#{LLM_HOSTNAME}:#{port}/v1 " \
                 "(via #{node_ip}; a guest cannot use its own node), models: #{LLM_MODELS.join(', ')}"
    end

    verify_llm_lane(transport, vms)
    true
  end

  # Which node's NodePort a guest should use. Never its own node: a masquerade guest cannot
  # complete a service connection that stays on, or returns via, its own node (measured -- its own
  # node's NodePort times out while another node's answers). Preferably a node that runs a LiteLLM
  # replica, because the Service is externalTrafficPolicy Local and a node without one answers
  # nothing.
  def self.llm_node_ip(transport, vm_node, serving_nodes)
    nodes = transport.nodes
    serving = nodes.select { |node| serving_nodes.include?(node['name']) && node['name'] != vm_node }
    chosen = serving.first || nodes.find { |node| node['name'] != vm_node }
    if chosen.nil?
      raise BuildError, "no cluster node other than '#{vm_node}' to serve the lab's LLM lane"
    end
    chosen['ip']
  end

  # The script that hands a guest the lane: a hosts entry (so the guest needs no DNS to use the
  # endpoint) and a login-shell snippet with the endpoint and the key. The key is base64-encoded
  # in the script so that no character in it can break the quoting around it. (Every '$' below is
  # escaped for Ruby's own string interpolation, so what the guest receives is a shell variable.)
  def self.llm_access_script(node_ip, port, key)
    base64_key = Base64.strict_encode64(key)
    <<~SCRIPT
      #!/bin/bash
      # Generated by SecGen: this guest's access to the lab's LiteLLM lane. Removed after it runs.
      # Runs as the vagrant user, which has passwordless sudo.
      set -e
      HOSTS=#{GUEST_HOSTS_PATH}
      ENV_FILE=#{GUEST_LLM_ENV_PATH}

      # The guest cannot use the cluster's DNS (see "Guest DNS" in README-KubeVirt.md), so the
      # endpoint is given as an address: litellm.lab -> the node whose NodePort serves the lane.
      # Replace rather than append, so re-running this does not pile up entries.
      sudo sed -i '/[[:space:]]litellm\\.lab\\([[:space:]]\\|\$\\)/d' "\$HOSTS"
      printf '%s\\t%s\\n' '#{node_ip}' '#{LLM_HOSTNAME}' | sudo tee -a "\$HOSTS" >/dev/null

      # Decoded from base64 so no character in the key can break the quoting here.
      KEY="\$(printf '%s' '#{base64_key}' | base64 -d)"
      TMP_ENV=/tmp/secgen-llm-env.sh
      cat > "\$TMP_ENV" <<EOF
      # SecGen: the lab's LiteLLM lane (models: #{LLM_MODELS.join(', ')}).
      export OPENAI_API_BASE="http://#{LLM_HOSTNAME}:#{port}/v1"
      export OPENAI_BASE_URL="http://#{LLM_HOSTNAME}:#{port}/v1"
      export OPENAI_API_KEY="\$KEY"
      export LITELLM_MASTER_KEY="\$KEY"
      EOF
      sudo install -m 0644 "\$TMP_ENV" "\$ENV_FILE"
      rm -f "\$TMP_ENV"
      echo "SecGen: LLM lane -> http://#{LLM_HOSTNAME}:#{port}/v1"
    SCRIPT
  end

  # Check the lane from inside each guest, retrying: the policy took about a minute to reach the
  # datapath in testing, and until it does, traffic still flows. A failure is reported, not raised:
  # the lab itself is built, and what to look at is more useful than a stack of retries. (The
  # post-provision tests already fail a lab whose services do not answer.)
  def self.verify_llm_lane(transport, vms)
    vms.each do |meta|
      vm = meta['vm_name']
      state = :up
      begin
        transport.wait_until("the LLM lane to work in #{vm}", timeout: LLM_LANE_TIMEOUT, interval: 15) do
          llm_lane_state(transport, vm) == :up
        end
      rescue KubeVirt::TransportError
        state = llm_lane_state(transport, vm)
      end

      case state
      when :up
        Print.info "KubeVirt: #{vm} reached the LiteLLM lane from inside the guest"
      when :untestable
        Print.warn "KubeVirt: cannot check the LLM lane in #{vm}: the guest has no curl"
      else
        Print.warn "KubeVirt: #{vm} did not reach the LiteLLM lane within #{LLM_LANE_TIMEOUT}s"
        Print.warn " The guest has the endpoint and the key (#{GUEST_LLM_ENV_PATH}); check it by hand with:"
        Print.warn "   virtctl -n #{transport.namespace} ssh --username vagrant vm/#{vm} -- \\"
        Print.warn "     '. #{GUEST_LLM_ENV_PATH}; curl -sS \"\$OPENAI_API_BASE/models\" " \
                   '-H "Authorization: Bearer $OPENAI_API_KEY"\''
        Print.warn ' An egress policy that has not reached the datapath, a node with no LiteLLM'
        Print.warn ' replica, or another policy of your own can all cause this.'
      end
    end
    true
  end

  # Probe the lane from inside the guest. 42 is "the guest has no curl", which is not a broken
  # lane, so the two are told apart rather than reported as one.
  def self.llm_lane_state(transport, vm)
    transport.ssh(vm, llm_probe, timeout: 60)
    :up
  rescue KubeVirt::TransportError => e
    e.message.include?('exit 42') ? :untestable : :down
  end

  def self.llm_probe
    "command -v curl >/dev/null || exit 42; . #{GUEST_LLM_ENV_PATH}; " \
      'curl -s -o /dev/null -w "%{http_code}" -m 10 ' \
      '-H "Authorization: Bearer $OPENAI_API_KEY" "$OPENAI_API_BASE/models" | grep -q 200'
  end

  # Push a generated script into the guest and run it, then remove it. The script can carry a
  # credential, so it goes to a scratch file (mode 0600) and is copied in rather than put on a
  # command line: the process table is world-readable on the SecGen host, and --verbose prints
  # command lines.
  def self.push_and_run(transport, vm, script, guest_path)
    file = File.join(Dir.tmpdir, "secgen-kubevirt-#{SecureRandom.hex(6)}.sh")
    begin
      File.open(file, File::WRONLY | File::CREAT | File::TRUNC, 0600) { |handle| handle.write(script) }
      transport.scp(file, vm, guest_path, timeout: SCP_TIMEOUT)
    ensure
      File.delete(file) if File.exist?(file)
    end
    transport.ssh(vm, "bash #{guest_path} && rm -f #{guest_path}", timeout: 300)
  end

  # What spreading a lab costs, said out loud. A lab's Multus network is a bridge on one node, so
  # its VMs only reach each other on it while they land on the same node -- and the default
  # placement spreads a lab because one node rarely has room for all of it. Which of the two
  # matters more is the user's call, so the tradeoff is stated rather than chosen silently.
  def self.placement_limits(plan, options)
    return unless placement(options) == PLACEMENT_SPREAD

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
