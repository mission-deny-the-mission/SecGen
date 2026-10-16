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
every `<network>` in a scenario becomes a Multus bridge interface on the lab's own L2 segment,
carrying the address SecGen assigned it (fixed or auto-assigned), pinned in the cluster rather
than left to the CNI. See [Networking](#networking). Egress is governed by a tier
(`--kubevirt-egress`, default `internet`; `litellm` locks a lab down to the LLM lane), and
`--kubevirt-placement` chooses between spreading a lab over the cluster's nodes and keeping it
on one.

## Requirements

- A Kubernetes cluster running KubeVirt, with CDI (its `DataVolume` API clones the golden
  images).
- `kubectl` and `virtctl` on `PATH` on the machine running SecGen, with a kubeconfig
  (`--kubevirt-kubeconfig` chooses one; otherwise the ambient `KUBECONFIG`/default context is
  used).
- A block storage class that supports the `ReadWriteOnce` volume mode for the lab disks
  (default `ceph-block`, set with `--kubevirt-storage-class`).
- A namespace holding the golden base images (default `secgen-bases`, set with
  `--kubevirt-golden-namespace`).
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
message naming the base. `secgen-base-bookworm-desktop-kde` (34Gi, `ceph-block`) already
exists; `secgen-base-kali-light-msf` is what the Kali base expects.

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
  --storage-class=ceph-block \
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
RoleBinding rendered by `lib/templates/kubevirt_clone_rbac.yaml.erb`; `secgen-lab` already
has them (they were applied by GitOps), so labs there just work.

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
--kubevirt-storage-class [name]    storage class for the cloned root disks (ceph-block)
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
--kubevirt-egress [tier]           egress tier for the lab: internet (default), litellm, none
--kubevirt-placement [placement]   spread (default), compact, or a node name
--kubevirt-llm                     hand the guests the LLM endpoint and key even with
                                   --kubevirt-egress internet (litellm implies it)
--kubevirt-litellm-service [ns/name]  LiteLLM Service to point labs at (litellm/litellm)
--kubevirt-litellm-secret [ns/name:key]  secret holding the LiteLLM master key
                                   (litellm/master-key:litellm-master-key)
```

Multus, and a Multus-aware CNI with whereabouts IPAM, are needed for the lab's own networks;
the cluster this provider was written against runs Multus v4.3.1 with whereabouts v0.9.4. No
lab gets an interface on a scenario network without them, and SecGen says so if the
NetworkAttachmentDefinition cannot be created.

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

# delete the lab VMs and their root disks, its networks and its egress policy
# (golden images are never touched)
ruby secgen.rb --project projects/kv1 --kubevirt-namespace secgen-lab kubevirt-destroy
```

`run`, `build-vms` and `kubevirt-build` all end with the same post-provision tests as the
other providers, but the guests are reached over `virtctl` instead of a network path or the
QEMU Guest Agent, and the pre-test reboot restarts the VMs through the API. The order in a
build is: create the lab's networks, create and boot the VMs, provision them (open egress),
then apply the egress tier and, if it is a `litellm` lab, hand the guests the LLM endpoint and
key.

`--system <name>` restricts these commands to one system of the scenario (the same option
that limits the Vagrant commands); `--retries` retries the whole lab rather than individual
VMs.

## Networking

Every guest has a `masquerade` interface on the pod network, plus one Multus bridge interface
for each `<network>` element in its system definition:

- `masquerade` (always, named `default`) is how SecGen reaches the guest (`virtctl ssh`/`scp`,
  and ports through the API server) and the only interface with a default route, so a lab
  network cannot cut a guest off from its node;
- **nothing outside the cluster can reach a guest on that interface**, and a pod restart moves a
  guest to a new pod-network address, so nothing should depend on it;
- each scenario network is its own L2 segment (`net1`, `net2`, ... in the order the `<network>`
  elements appear) carrying the address SecGen assigned that interface.

Guests reach each other on the pod network (subject to the cluster's NetworkPolicy, and to the
egress tier below) and, while they are on the same node, on their lab networks. README-Networking.md
describes the scenario model itself; this section is what the provider does with it.

### Addresses are pinned, not left to the CNI

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

### A lab network is a bridge on one node

The bridge CNI attaches the interface to a Linux bridge inside the node's network namespace, so a
lab network reaches VMs **on the same node only**: two guests on one node sharing a
NetworkAttachmentDefinition reached each other with no packet loss; two on different nodes
sharing one lost 100% of packets both ways.

The provider therefore defaults to spreading a lab over the cluster's nodes
(`--kubevirt-placement spread`; `topologySpreadConstraints` with
`whenUnsatisfiable: ScheduleAnyway`, so a node with no room is skipped rather than making the
whole lab unschedulable), because a lab whose VMs do not all fit on one node has to be spread to
build at all. The cost is exactly that connectivity: **in a spread lab, VMs only reach each other
on their lab networks while they happen to land on the same node.** When a scenario needs its VMs
to talk over a lab network, build the lab with:

```bash
--kubevirt-placement compact      # the whole lab on one node (required podAffinity)
--kubevirt-placement clarkson     # or one named node (nodeSelector)
```

`compact` uses *required* affinity, so a lab that does not fit fails to schedule instead of
coming up with its VMs unable to reach each other. SecGen also warns at generation time when a
scenario puts two or more systems on one VLAN and the placement is `spread`.

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

- `kubevirt/lab-networks.yaml` - one NetworkAttachmentDefinition per scenario network interface,
  applied before any VM is created;
- `kubevirt/lab-networks.json` - the mapping the rest of the build uses (which system gets which
  interface, on which bridge, at which address).

`kubevirt-destroy` deletes the lab's networks and its egress policy along with the VMs, unless
`--system` limits it to one system - the other VMs are still running and still need their
networks. Empty whereabouts pools are left behind in `kube-system/ippools`; they are harmless
and are reused by the next lab on that subnet.

## Egress tiers

`--kubevirt-egress` decides what a lab may reach. It is applied **after** provisioning, which
needs open egress (package installs, downloads):

| tier | what the lab can reach |
|---|---|
| `internet` (default) | whatever the cluster allows any workload - no policy is created |
| `litellm` | the LiteLLM NodePort on any node, and the resolver the guest was given; nothing else |
| `none` | nothing at all, not even DNS |

The policy is a `CiliumNetworkPolicy` selecting the lab VMs by the `secgen.io/lab-vm` label the VM
template puts on the virt-launcher pod. Cilium replaces an endpoint's whole egress policy, so a
tier is an allow-list and everything not listed is denied - verified from a guest: the registry
mirror and the internet stopped working, with `action deny, match none` in `cilium-dbg monitor`,
while the LiteLLM NodePort answered. Traffic on a Multus lab network does not pass Cilium at all,
so no tier restricts a lab network: only the pod network.

A Cilium rule list cannot be empty (the error is "rule must have at least one of Ingress,
IngressDeny, Egress, EgressDeny", and traffic kept flowing when an empty list was tried), so
`none` is written as an allow-list matching nothing routable: TEST-NET-1, `192.0.2.0/24`
(RFC 5737). Verified from a guest: internet, every node's NodePort and DNS all fail.

Propagation to the datapath took about a minute in testing, and traffic kept flowing until then,
which is why the tier is applied last and the LLM lane is checked afterwards. A tier change is a
rebuild with the new `--kubevirt-egress`: rebuilding with `internet` removes a policy left by an
earlier tier, and `kubevirt-destroy` removes it with the lab.

## The LLM lane

A lab that needs an LLM uses the cluster's LiteLLM proxy rather than the internet. With
`--kubevirt-egress litellm` (or `--kubevirt-llm` on its own, which leaves the rest of the egress
open) every guest is handed:

- an `/etc/hosts` entry `<a node's IP> litellm.lab` - an address, not a name, because a guest in
  this tier has no working DNS (see [Guest DNS](#guest-dns));
- `/etc/profile.d/secgen-llm.sh` with `OPENAI_API_BASE`, `OPENAI_BASE_URL` (and
  `LITELLM_MASTER_KEY`) pointing at it, carrying the master key.

Addressing it is the interesting part. A masquerade guest cannot reach a ClusterIP at all
(verified: the LiteLLM ClusterIP fails and CoreDNS at `10.96.0.10:53` answers `No route to
host`), which rules out a Service's normal address, and it cannot complete a service connection
that stays on, or returns via, **its own** node - so the MetalLB VIP (a local endpoint answers
it) and its own node's NodePort both fail too. What works, verified from a booted guest, is
**any other node's IP on the LiteLLM NodePort**: `http://<other node>:30400` returned `200`,
including an authenticated `/v1/models`, while `http://<its own node>:30400` timed out. SecGen
therefore reads the NodePort off the Service, picks a node that is *not* the guest's own
(preferring one running a replica, since the Service is `externalTrafficPolicy: Local` and a node
without a replica answers nothing), and writes that address into the guest.

The master key is read from the cluster with `kubectl get secret` at build time and reaches the
guests **only**: it is not written into the project, not passed on a command line (the process
table is world-readable on the SecGen host, and `--verbose` prints command lines), and the script
carrying it is copied in with `virtctl scp` and deleted afterwards. Point the provider at another
proxy with `--kubevirt-litellm-service <namespace>/<name>` and
`--kubevirt-litellm-secret <namespace>/<name>:<key>`; the defaults are `litellm/litellm` and
`litellm/master-key:litellm-master-key`. The model IDs the proxy serves are printed when the lane
is set up.

SecGen then checks the lane from inside each guest and waits for it, because a policy takes about
a minute to reach the datapath. A guest that does not answer within five minutes gets a warning
naming what to check, not a failed build; the guest keeps the endpoint and key either way.

## Guest DNS

KubeVirt hands a masquerade guest the *pod's* `resolv.conf` over DHCP, and whichever way that is
configured, the guest cannot use it:

- with the default policy it is the cluster's DNS (CoreDNS ClusterIP) - `No route to host`;
- with `dnsPolicy: Default` it is the *node's* resolver (on Talos, `169.254.116.108`) - the
  guest cannot reach that either.

Every puppet module that installs a package then fails, so SecGen always sets `dnsPolicy: None`
together with an explicit `dnsConfig.nameservers`, defaulting to a public resolver: the guest is
handed exactly that nameserver, and resolution and package installation then work (verified end
to end on a booted VM). To point labs at the lab's own resolver instead:

```bash
--kubevirt-namespace secgen-lab --kubevirt-dns 10.1.0.53,10.1.0.54
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
  becomes its own isolated bridge segment, but the 802.1Q tag is not put on the wire (the
  `--proxmox-vlan` tag arithmetic does not apply - Proxmox tags are for sharing a physical LAN,
  which a cluster bridge does not have). Two VMs on the same VLAN share a segment; two on
  different VLANs do not.
- **No DHCP on a lab network** (`public_network`), because a guest on one is a bridge member with
  a static address and there is no DHCP server on a cluster bridge. DHCP in the guest therefore
  only ever leases the `masquerade` interface (pod network), and `public_network` maps to that
  interface's existing behaviour rather than to a new one - see [Networking](#networking).
- **No router per lab network** (`default_gateway`, per-network `dns_nameservers`, `routes`).
  Use a lab VM as the router if the scenario needs one.
- **No cross-node lab networks.** The bridge is node-local, so a lab network only connects VMs on
  one node - build such a lab with `--kubevirt-placement compact`. See
  [A lab network is a bridge on one node](#a-lab-network-is-a-bridge-on-one-node).
- **No VirtualBox bases.** A base is usable here only if it declares `<kubevirt_image>`; the
  Windows bases and the older Debian bases have no golden image.
- **No snapshots.** `--snapshot` is ignored (it is a Vagrant provider feature), and so is
  `--gui-output`, `--nopae`, `--hwvirtex`, `--vtxvpid` and `--cpu-cores` (use
  `--kubevirt-cpus`).
- **`--retries` retries the whole lab**, not individual VMs.
- The generated `Vagrantfile` is written for reference only - it is not used, and says so.
