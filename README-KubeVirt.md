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

**Phase 1 scope:** networking is pod/masquerade only. Each guest gets an address on the
cluster pod network and is reached through the API server. Scenario modules that expect a
static IP on an isolated L2 network or VLAN are **not** supported yet - that needs Multus
(phase 2). SecGen warns about network modules in a scenario rather than silently producing a
lab whose network configuration is wrong; see [Networking](#networking-phase-1-masquerade-only).

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
```

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

# what is running, and where it is on the pod network
ruby secgen.rb --project projects/kv1 --kubevirt-namespace secgen-lab kubevirt-status

# delete the lab VMs and their root disks (golden images are never touched)
ruby secgen.rb --project projects/kv1 --kubevirt-namespace secgen-lab kubevirt-destroy
```

`run`, `build-vms` and `kubevirt-build` all end with the same post-provision tests as the
other providers, but the guests are reached over `virtctl` instead of a network path or the
QEMU Guest Agent, and the pre-test reboot restarts the VMs through the API.

`--system <name>` restricts these commands to one system of the scenario (the same option
that limits the Vagrant commands); `--retries` retries the whole lab rather than individual
VMs.

## Networking (phase 1: masquerade only)

Every guest has one interface, `masquerade` on the pod network:

- guests can reach the internet (and, subject to the cluster's NetworkPolicy, each other) via
  the node;
- **nothing outside the cluster can reach a guest directly**, and the address shown by
  `kubevirt-status` is only meaningful inside the cluster;
- a pod restart moves a guest to a new address, so nothing should depend on it.

Scenario modules that configure a static address on an isolated network (SecGen's
`compute_vlan` model, `modules/networks/**`) are therefore not honoured: the interfaces,
addresses, VLAN tags and isolation they describe do not exist in the lab. SecGen prints a
warning naming each such module when the project is generated. Lab scenarios that only rely
on services within a single VM (most of `scenarios/labs` and `scenarios/ctf`) work as they are;
multi-VM scenarios that need a specific address or isolation need Multus support, which is
phase 2.

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

- **No isolated L2/VLAN networking** (Multus) - see above.
- **No VirtualBox bases.** A base is usable here only if it declares `<kubevirt_image>`; the
  Windows bases and the older Debian bases have no golden image.
- **No snapshots.** `--snapshot` is ignored (it is a Vagrant provider feature), and so is
  `--gui-output`, `--nopae`, `--hwvirtex`, `--vtxvpid` and `--cpu-cores` (use
  `--kubevirt-cpus`).
- **`--retries` retries the whole lab**, not individual VMs.
- The generated `Vagrantfile` is written for reference only - it is not used, and says so.
