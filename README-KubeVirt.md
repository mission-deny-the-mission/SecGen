# Running SecGen labs on KubeVirt

KubeVirt runs SecGen's lab VMs as Kubernetes objects. There is no maintained Vagrant plugin
for it, so this provider does not use Vagrant at all: SecGen applies one `VirtualMachine`
per system to the cluster itself, waits for the guest, and then provisions it by pushing the
project's puppet tree and running a generated script over `virtctl`.

That has two consequences worth knowing before you start:

- SecGen needs **cluster API access** (a kubeconfig for `kubectl` and `virtctl`), not a
  network path into the lab. Credentials are never written into the project.
- Generating a project already needs cluster access, because a clone may not be smaller than
  the golden image it clones, so the provider reads the golden PVC's size (unless you pass
  `--kubevirt-image-size`).

**Networking:** every guest always has a `masquerade` interface on the cluster pod network,
which is how SecGen reaches it and the only interface with a default route. On top of that,
every `<network>` in a scenario becomes a Multus interface on the lab's own L2 segment,
carrying the address SecGen assigned it (fixed or auto-assigned), pinned in the cluster rather
than left to the CNI. That segment is a Kube-OVN logical switch spanning every node when the
cluster runs Kube-OVN, or a node-local Linux bridge otherwise. See [Networking](#networking).

What a lab may reach beyond its own networks is the cluster's business, not SecGen's: see
[Egress and shared services](#egress-and-shared-services).

## Requirements

This section is what SecGen needs from you; [README-KubeVirt-Cluster.md](README-KubeVirt-Cluster.md)
is what the cluster needs, and one way to set it up.

- A Kubernetes cluster running KubeVirt, with CDI (its `DataVolume` API clones the golden
  images).
- `kubectl` and `virtctl` on `PATH` on the machine running SecGen, with a kubeconfig
  (`--kubevirt-kubeconfig` chooses one; otherwise the ambient `KUBECONFIG`/default context is
  used).
- A storage class for the lab disks that can clone the golden images (the cluster's default
  StorageClass unless `--kubevirt-storage-class` names one).
- A namespace holding the golden base images (default `secgen-bases`, set with
  `--kubevirt-golden-namespace`).
- For scenarios with networks: [Multus](https://github.com/k8snetworkplumbingwg/multus-cni), and
  either [Kube-OVN](https://kubeovn.github.io/docs/) (as a secondary network; lab networks span
  nodes) or the bridge CNI with [whereabouts](https://github.com/k8snetworkplumbingwg/whereabouts)
  IPAM (lab networks are node-local). Scenarios without networks need neither.
- Nothing else: this is all `kubectl`/`virtctl`, so no new Ruby gems are needed.

## Preparing golden images

A "golden image" is a PVC containing a bootable SecGen base, in its own namespace. Every lab
VM's root disk is a clone of it, so it is never modified - keep it running-free and do not
boot it.

Images are named `secgen-base-<base-slug>`, and each base module declares the one it uses:

```xml
<kubevirt_image>secgen-base-bookworm-desktop-kde</kubevirt_image>
```

in `modules/bases/<base>/secgen_metadata.xml` (the KubeVirt equivalent of `esxi_url` /
`vagrant_box`). A base without the element is not usable on KubeVirt, and SecGen stops with a
message naming the base.

The image has to satisfy the same things a [Vagrant base box](README-Creating-Bases.md) does,
because the guest is provisioned over ssh exactly as Vagrant would provision it:

- puppet (7) installed, with the modules' legacy facts available (`$operatingsystem`,
  `$osfamily`, ...)
- the `vagrant` user with Vagrant's published insecure key in `authorized_keys` (both the
  ed25519 and RSA halves), password `vagrant`, and passwordless sudo
- distro apt sources up to date (modules install packages without running `apt-get update`)

To create one, upload the base's disk image as a PVC (ordinary CDI usage):

```bash
# from a Vagrant box: the .box is a tar containing the provider's disk (e.g. box.vmdk)
mkdir /tmp/base && tar xf bookworm-base-1.1.0-virtualbox.box -C /tmp/base
# convert to a raw/qcow2 image for the node's storage if needed (qemu-img), then:
virtctl image-upload dv secgen-base-bookworm-desktop-kde \
  --namespace secgen-bases \
  --size=34Gi \
  --image-path=/tmp/base/bookworm-base-disk.img
```

`--size` must be at least the image's virtual disk size; the uploaded PVC's
`spec.resources.requests.storage` is what SecGen reads when it sizes each clone.

Two things about these images that the provider works around:

- **cloud-init is inert in them.** The published bases have already consumed their cloud-init
  instance state, so the `userData` in the VM manifest does not run. The generated
  provisioning script sets the hostname itself (`hostnamectl` + `/etc/hosts`).
- **they must not hold anything worth protecting.** Lab VMs are reachable by anyone who can
  read the repository's published Vagrant insecure key (see
  `lib/resources/kubevirt/README.md`).

## Cluster RBAC

A clone is *cross-namespace*: the lab lives in one namespace (`secgen-lab` by default) and
the golden image in another (`secgen-bases`). CDI authorises the clone as the `DataVolume`'s
creator, so the **lab** namespace's service accounts need `create` on `datavolumes/source`
in the **golden** namespace. Without that, creating a VM fails with:

```
User system:serviceaccount:secgen-lab:default has insufficient permissions
in clone source namespace secgen-bases
```

SecGen recognises that error and prints what to do. The objects to create are the Role and
RoleBinding rendered by `lib/templates/kubevirt_clone_rbac.yaml.erb`; create them once per lab
namespace (or let `--kubevirt-create-namespace` do it, below).

`--kubevirt-create-namespace` does it for you when the lab namespace does not exist yet:
SecGen creates the namespace, a `ResourceQuota` (storage/count only, so it cannot make
virt-launcher pods unschedulable), and the Role/RoleBinding above. That needs permission to
create roles and rolebindings in the golden namespace, which a GitOps-managed cluster may not
grant you - in that case create the namespace, quota and binding yourself.

## Options

```
--kubevirt-namespace [namespace]   run the lab in this namespace (this is what selects the
                                   KubeVirt provider; without it the other providers apply)
--kubevirt-kubeconfig [path]       kubeconfig to use instead of the ambient one
--kubevirt-storage-class [name]    storage class for the cloned root disks (cluster default)
--kubevirt-golden-namespace [ns]   namespace holding the golden images (secgen-bases)
--kubevirt-cpus [number]           virtual CPUs per VM (2)
--kubevirt-ssh-key [path]          private key for the guest's vagrant user (the published
                                   Vagrant insecure key in lib/resources/kubevirt)
--kubevirt-dns [nameserver]        nameserver(s) to hand the guest, comma separated (see
                                   Guest DNS below; default 1.1.1.1, dnsPolicy None)
--kubevirt-create-namespace        create the namespace, quota and clone access if missing
--kubevirt-halt                    halt the VMs after provisioning (runStrategy Halted)
--kubevirt-image-size [size]       size for the cloned root disk, e.g. 34Gi; needs no cluster
                                   access, but must be at least the golden image's size
--kubevirt-placement [placement]   spread (default), compact, or a node name
--kubevirt-lab-network [backend]   ovn, bridge, or auto (default: ovn if the cluster serves
                                   the kubeovn.io API, otherwise bridge)
```

No lab gets an interface on a scenario network without Multus, and SecGen says so if the
lab's networks cannot be created.

## Commands

The provider is selected by `--kubevirt-namespace`, so it has to be given to the subcommands
as well as to the build:

```bash
# build a project and a lab in one step
ruby secgen.rb --scenario scenarios/examples/remotely_exploitable_user_vulnerability.xml \
  --kubevirt-namespace secgen-lab --kubevirt-create-namespace run

# generate the project only (needs the cluster: it sizes the clones; add
# --kubevirt-image-size to do it without cluster access)
ruby secgen.rb -s scenarios/examples/remotely_exploitable_user_vulnerability.xml \
  --project projects/kv1 --kubevirt-namespace secgen-lab build-project

# build, provision and test an already generated project
ruby secgen.rb --project projects/kv1 --kubevirt-namespace secgen-lab kubevirt-build

# what is running, where it is on the pod network and on its lab networks
ruby secgen.rb --project projects/kv1 --kubevirt-namespace secgen-lab kubevirt-status

# delete the lab VMs and their root disks, and its networks
# (golden images are never touched)
ruby secgen.rb --project projects/kv1 --kubevirt-namespace secgen-lab kubevirt-destroy
```

`run`, `build-vms` and `kubevirt-build` all end with the same post-provision tests as the
other providers, but the guests are reached over `virtctl` instead of a network path or the
QEMU Guest Agent, and the pre-test reboot restarts the VMs through the API. The order in a
build is: create the lab's networks (and wait for them to be ready), create and boot the VMs,
provision them, test them.

`--system <name>` restricts these commands to one system of the scenario (the same option
that limits the Vagrant commands); `--retries` retries the whole lab rather than individual
VMs.

## Networking

Every guest has a `masquerade` interface on the pod network, plus one Multus interface
for each `<network>` element in its system definition:

- `masquerade` (always, named `default`) is how SecGen reaches the guest (`virtctl ssh`/`scp`,
  and ports through the API server) and the only interface with a default route, so a lab
  network cannot cut a guest off from its node;
- **nothing outside the cluster can reach a guest on that interface**, and a pod restart moves a
  guest to a new pod-network address, so nothing should depend on it;
- each scenario network is its own L2 segment (`net1`, `net2`, ... in the order the `<network>`
  elements appear) carrying the address SecGen assigned that interface.

Guests reach each other on the pod network (subject to the cluster's NetworkPolicy) and on
their lab networks - across nodes with the `ovn` backend, on one node with `bridge`.
README-Networking.md describes the scenario model itself; this section is what the provider does
with it.

### Two backends

`--kubevirt-lab-network` chooses how a scenario network is built:

| backend | a scenario VLAN becomes | VMs reach each other on it | address pinned by |
|---|---|---|---|
| `ovn` | a Kube-OVN `Vpc` + `Subnet` (an OVN logical switch) | on any node (Geneve tunnels) | `<provider>.kubernetes.io/ip_address` pod annotation |
| `bridge` | a Linux bridge on each node | only on the same node | whereabouts IPAM pinned to one address |

`auto` (the default) picks `ovn` when the cluster serves the `kubeovn.io` API. Both are attached
through Multus, so Kube-OVN runs as a secondary network beside whatever the primary CNI is.

**`ovn`:** every network gets a `Vpc` of its own. A `Vpc` is an OVN logical router, and Kube-OVN
only checks CIDR overlap inside one `Vpc`, so two labs (or two networks of one lab) can use the
same subnet at the same time without seeing each other - verified with two labs on the same /24
using the same address: 0% loss inside each, 100% between them. Nothing routes a lab `Vpc` to the
cluster or to another `Vpc`. KubeVirt's DHCP hands the guest its address and the subnet's MTU
(Kube-OVN's default 1400) and no default route. `Vpc` and `Subnet` are cluster-scoped, so their
names carry the lab namespace, they are labelled with it, and SecGen refuses to touch one that
belongs to another lab. SecGen waits for each `Subnet` to be ready before creating VMs, because
Kube-OVN validates a `Subnet` asynchronously and a VM on a rejected one never starts.

The `bridge` backend is described in the next two sections; it is what the provider falls back to
on a cluster without Kube-OVN.

### Addresses are pinned, not left to the CNI (`bridge`)

SecGen gives every interface its own address (a fixed `IP_address`, or auto-assigned from the
network's range starting at `.2`) and hands that address to other modules as `<network_ip>`, so
the lab is only correct if the guest actually ends up on it. Each interface therefore gets its
own NetworkAttachmentDefinition, with whereabouts IPAM pinned to that one address:

```
ipam:
  type: whereabouts
  range: 10.55.0.0/24
  range_start: 10.55.0.3      # == range_end: the address SecGen chose for this interface
  range_end: 10.55.0.3
```

Asking for the address on the VMI does not work: KubeVirt builds the Multus annotation for the
virt-launcher pod itself and **drops** an address a user asks for (verified: the request was
discarded and whereabouts allocated the first free address instead), and the VMI schema has no
address field for a Multus network. Pinning it in the IPAM does work, and several pinned
NetworkAttachmentDefinitions can share one range with each still getting exactly its own address
(verified: two on the same /24 pinned to `.5` and `.6`, both honoured in the guest, and the same
address again after a rebuild). The address arrives with the subnet's prefix - a guest pinned to
`.7` reported `enp2s0 172.30.95.7/24`.

Two labs using the same subnet at the same time share one whereabouts pool and the same pinned
addresses, and the second lab's interfaces will not come up. SecGen randomises each network's
range per build, so this only bites a scenario that fixes its own `range`; give concurrent labs
different ranges (`--network-ranges`) if you have one.

Interfaces on one VLAN share a bridge, named from the lab namespace and the VLAN tag, so two
labs on one node never share a segment even if they compute the same VLAN tag.

### A `bridge` lab network is on one node

The bridge CNI attaches the interface to a Linux bridge inside the node's network namespace, so a
lab network reaches VMs **on the same node only**: two guests on one node sharing a
NetworkAttachmentDefinition reached each other with no packet loss; two on different nodes
sharing one lost 100% of packets both ways.

With `bridge`, the provider still defaults to spreading a lab over the cluster's nodes
(`--kubevirt-placement spread`; `topologySpreadConstraints` with
`whenUnsatisfiable: ScheduleAnyway`, so a node with no room is skipped rather than making the
whole lab unschedulable), because a lab whose VMs do not all fit on one node has to be spread to
build at all. The cost is exactly that connectivity: **in a spread lab, VMs only reach each other
on their lab networks while they happen to land on the same node.** When a scenario needs its VMs
to talk over a lab network, build the lab with:

```bash
--kubevirt-placement compact      # the whole lab on one node (required podAffinity)
--kubevirt-placement node-1       # or one named node (nodeSelector)
```

`compact` uses *required* affinity, so a lab that does not fit fails to schedule instead of
coming up with its VMs unable to reach each other. SecGen also warns at generation time when a
scenario puts two or more systems on one VLAN, the backend is `bridge` and the placement is
`spread`. None of this applies to `ovn`, where `spread` is safe.

### What a scenario network cannot do

An interface on a lab network gets an address and nothing else. These parts of a scenario's
network definition are **not** applied (SecGen names each one it sees when generating the
project):

- `default_gateway` on a scenario network: there is no router on the segment unless a lab VM is
  one, and a guest's default route stays on `masquerade`;
- `dns_nameservers` per network: a guest has one resolver (`--kubevirt-dns`), handed to it as a
  whole-VM setting rather than one per interface;
- `routes` on a scenario network;
- `public_network` (DHCP on the host's bridged network): there is no such network to attach to.
  The `masquerade` interface fills that role - it is the pod-network interface and does have a
  default route - but its address belongs to the cluster, not to the lab's LAN.

A guest can still *be* that router: give a VM two interfaces on the networks it joins (as
`scenarios/examples/network_examples/networks_vlans.xml` does) and let its modules configure
forwarding.

### Where the lab's networks live

Generating a project writes two files into it:

- `kubevirt/lab-networks.yaml` - the lab's networks (`Vpc`/`Subnet`/NetworkAttachmentDefinition per
  VLAN for `ovn`; one NetworkAttachmentDefinition per interface for `bridge`), applied before any
  VM is created;
- `kubevirt/lab-networks.json` - the mapping the rest of the build uses (which system gets which
  interface, on which bridge, at which address).

`kubevirt-destroy` deletes the lab's networks along with the VMs, unless `--system` limits it to
one system - the other VMs are still running and still need their networks. A Kube-OVN `Subnet`
finishes deleting once its last VM port is gone. With `bridge`, empty whereabouts pools are left
behind in `kube-system/ippools`; they are harmless and are reused by the next lab on that subnet.

## Egress and shared services

SecGen does not decide what a lab may reach beyond its own networks, and it does not deploy or
configure services that labs share. Both belong to whoever runs the cluster, and are set up once,
not per lab:

- **Egress.** Every lab VM's virt-launcher pod carries the labels `secgen.io/lab-vm: "true"` and
  `secgen.io/lab: <lab namespace>`, so a cluster's own NetworkPolicy (or its CNI's equivalent) can
  select lab VMs - per namespace, or across all labs. Provisioning needs whatever the modules
  download (package mirrors, the internet), but a finished lab usually should not have it, so
  each VM also carries `secgen.io/phase`: `provisioning` from creation until its guest has been
  provisioned, then `ready` (the KubeVirt counterpart of the Proxmox provider's temporary
  provisioning NIC). A policy that selects `secgen.io/phase notin (provisioning)` isolates
  finished labs and leaves builds alone; the post-provision tests run after a restart, so they
  already see the finished lab's egress. `ready` is set on the VM template and, when the account
  may patch pods, on the running pod too; otherwise it takes effect at the VM's next boot. Traffic on a Kube-OVN or bridge lab network does not pass through the
  primary CNI's policy at all; isolation there comes from each lab having its own segments.
- **Shared services** (an LLM gateway for chatbot scenarios, a package mirror, ...) are deployed
  once, outside SecGen. A scenario that needs one is handed its address through the ordinary
  module inputs, the same as on any other provider.

A masquerade guest cannot reach a ClusterIP Service directly (the address is not routed from
inside the guest), so a service meant for labs should be published on an address the guests can
route to - a LoadBalancer or NodePort address on the node network, for example.

## Guest DNS

KubeVirt hands a masquerade guest the *pod's* `resolv.conf` over DHCP, and whichever way that is
configured, the guest cannot use it:

- with the default policy it is the cluster's DNS (CoreDNS ClusterIP) - `No route to host`;
- with `dnsPolicy: Default` it is the *node's* resolver, which on some distributions is a
  link-local address the guest cannot reach either.

Every puppet module that installs a package then fails, so SecGen always sets `dnsPolicy: None`
together with an explicit `dnsConfig.nameservers`, defaulting to a public resolver: the guest is
handed exactly that nameserver, and resolution and package installation then work (verified end
to end on a booted VM). To point labs at the lab's own resolver instead:

```bash
--kubevirt-namespace secgen-lab --kubevirt-dns 192.0.2.53,192.0.2.54
```

The provisioning script also writes the same resolver into the guest's `/etc/resolv.conf` (after
setting the hostname, so the hostname resolves while it does it), so provisioning does not depend
on the DHCP handoff alone.

## Troubleshooting a lab VM

```bash
# what exists for the lab
kubectl get vm,vmi,dv,pvc -n secgen-lab
virtctl -n secgen-lab ssh --username vagrant \
  --identity-file lib/resources/kubevirt/vagrant_insecure_key vm/<vm> -- 'sudo puppet --version'

# a console, for anything that never came up (no ssh, wrong network, boot failure)
virtctl -n secgen-lab console vm/<vm>

# reach a service inside a guest from your workstation
virtctl -n secgen-lab port-forward vm/<vm> 8080:80
```

Guest logs from the build are in the output of `kubevirt-build` (the guest prints its
hostname, DNS check and one line per puppet module; `--verbose` adds the command lines).
Anything the modules left behind is on the VM's root disk, which is a full clone of the golden
image.

A VM that was halted (`--kubevirt-halt`) has no `VirtualMachineInstance`: `kubevirt-status`
reports it as not running. To bring a lab back up:

```bash
kubectl patch vm <vm> -n secgen-lab --type merge -p '{"spec":{"runStrategy":"Always"}}'
```

Rebuilding a project that already exists in the same directory moves the previous build aside
(`MOVED_<timestamp>/`) rather than overwriting it.

## What this provider does not do (yet)

- **No VLAN tags on a lab network.** A scenario's VLAN is a *logical* grouping here: each VLAN
  becomes its own isolated segment, but the 802.1Q tag is not put on the wire (the
  `--proxmox-vlan` tag arithmetic does not apply - Proxmox tags are for sharing a physical LAN,
  which a cluster lab network does not have). Two VMs on the same VLAN share a segment; two on
  different VLANs do not.
- **No DHCP on a lab network** (`public_network`), because a guest on one is a bridge member with
  a static address and there is no DHCP server on a cluster bridge. DHCP in the guest therefore
  only ever leases the `masquerade` interface (pod network), and `public_network` maps to that
  interface's existing behaviour rather than to a new one - see [Networking](#networking).
- **No router per lab network** (`default_gateway`, per-network `dns_nameservers`, `routes`).
  Use a lab VM as the router if the scenario needs one.
- **No cross-node lab networks without Kube-OVN.** The `bridge` backend is node-local, so a lab
  network only connects VMs on one node - build such a lab with `--kubevirt-placement compact`.
  See [A `bridge` lab network is on one node](#a-bridge-lab-network-is-on-one-node).
- **No VirtualBox bases.** A base is usable here only if it declares `<kubevirt_image>`; the
  Windows bases and the older Debian bases have no golden image.
- **No snapshots.** `--snapshot` is ignored (it is a Vagrant provider feature), and so is
  `--gui-output`, `--nopae`, `--hwvirtex`, `--vtxvpid` and `--cpu-cores` (use
  `--kubevirt-cpus`).
- **`--retries` retries the whole lab**, not individual VMs.
- The generated `Vagrantfile` is written for reference only - it is not used, and says so.
