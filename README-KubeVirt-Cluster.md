# Setting up a Kubernetes cluster for SecGen's KubeVirt provider

[README-KubeVirt.md](README-KubeVirt.md) describes how SecGen uses a cluster. This file is the
other side: what the cluster has to provide, and one way to build it. Everything here is set up
**once, by whoever runs the cluster** - SecGen itself only creates per-lab objects (VMs, disks,
lab networks) in a namespace it is given.

The versions below are the ones this provider was developed and tested against; nearby versions
should work, but they are the ones known to.

| component | role | tested |
|---|---|---|
| Kubernetes | | 1.37 |
| KubeVirt | runs the lab VMs | v1.9.0 |
| CDI (Containerized Data Importer) | uploads golden images, clones lab root disks | v1.66.1 |
| a CSI storage class | lab root disks; must support cloning | Rook-Ceph RBD |
| Multus (thick plugin) | attaches lab networks as extra interfaces | v4.3.1 |
| Kube-OVN, as a **secondary** CNI | lab networks that span nodes (`ovn` backend) | v1.16.14 |
| bridge CNI + whereabouts | node-local lab networks (`bridge` backend), if no Kube-OVN | whereabouts v0.9.4 |
| a primary CNI with NetworkPolicy | pod network, egress control for labs | Cilium 1.20.2 |

## What the cluster must provide

### Nodes

- **Hardware virtualisation** (`/dev/kvm`): bare-metal nodes, or VMs with nested virtualisation.
  KubeVirt can fall back to software emulation (`useEmulation`), but lab VMs are then too slow to
  provision in a sensible time.
- **Memory** is what limits how many labs fit: each VM gets the memory its scenario asks for, plus
  KubeVirt's per-VM overhead (a few hundred MiB). A two-VM desktop + Kali lab needs about 6-8 GiB.
- **Kernel modules** for Kube-OVN: `openvswitch` and `geneve` (plus the usual bridge/veth/tun/
  conntrack/NAT). Most distribution kernels ship them as modules; immutable distributions may build
  them in (then tell Kube-OVN not to load modules, below).
- **MTU**: Kube-OVN tunnels add about 100 bytes (Geneve). Kube-OVN derives the lab MTU from the
  tunnel interface (1500 - 100 = 1400 on a standard network), and KubeVirt hands that to guests via
  DHCP, so nothing has to change on the network - but if nodes have more than one path between them
  (e.g. a jumbo-frame link and a 1500-byte backup), pin the tunnel interface to the smallest so a
  failover never black-holes full-size frames.
- **Node-to-node UDP 6081** (Geneve) must be open between all nodes.

### Storage

- A **CSI storage class that can clone** volumes. Every lab VM's root disk is a clone of a golden
  image, so cloning speed is build speed. CDI picks a clone strategy per storage class (its
  `StorageProfile`): `csi-clone` or `snapshot` are fast (copy-on-write on Ceph RBD, for example);
  `copy` (host-assisted) works anywhere but copies the whole image for every VM.
- **Golden images and lab disks must be on the same storage class** for CSI cloning.
- If the class is not the cluster's default, pass `--kubevirt-storage-class` to SecGen.
- Capacity: the golden images (tens of GiB each), plus one clone per lab VM. With copy-on-write
  clones a lab disk only grows by what provisioning writes; with `copy`, each costs the full size.

### Networking

- **A primary CNI that leaves room for Multus.** Some CNIs take over `/etc/cni/net.d` and rename
  other CNI configurations away; Cilium does this unless `cni.exclusive=false`.
- **Multus** (thick plugin) to give VMs their lab interfaces. Turn on
  `namespaceIsolation: true` so a pod can only use NetworkAttachmentDefinitions from its own
  namespace; otherwise one lab could attach itself to another lab's network.
- **For labs that span nodes: Kube-OVN as a non-primary CNI.** It provides an isolated L2 segment
  per lab network (a `Vpc` + `Subnet` each), tunnelled between nodes, with per-port addresses and
  port security, so two labs can even use the same subnet at once. It must not become the primary
  network - see the values below.
- **Without Kube-OVN: the bridge CNI and whereabouts.** Each lab network is then a Linux bridge
  on one node, so all of a lab's VMs must run on the same node.
- **A NetworkPolicy-capable primary CNI**, so the cluster can decide what lab VMs may reach (see
  [Egress](#egress-for-labs)).

### Cluster objects

- A **golden-image namespace** (default `secgen-bases`) holding one PVC per base, named
  `secgen-base-<slug>` (see README-KubeVirt.md, *Preparing golden images*).
- One or more **lab namespaces**. KubeVirt's virt-launcher pods do not pass the `restricted` Pod
  Security level; label lab namespaces `pod-security.kubernetes.io/enforce: privileged` (or
  `baseline` if your KubeVirt version allows).
- A **clone grant**: the lab namespace's service accounts need `create` on
  `datavolumes/source` (and `get`/`list` on PVCs, so SecGen can size clones) in the golden
  namespace. See README-KubeVirt.md, *Cluster RBAC*.
- A **ResourceQuota** on lab namespaces, if several people share the cluster - limit storage and
  PVC count rather than CPU/memory, so VM pods are never rejected half-way through a lab.

### The account SecGen runs as

SecGen only needs a kubeconfig; it never stores credentials in a project. For people who should
build labs but not run the cluster, a namespace-scoped account is enough:

- in the lab namespace: full access to VMs/VMIs (`kubevirt.io`), DataVolumes (`cdi.kubevirt.io`),
  PVCs and NetworkAttachmentDefinitions; the `subresources.kubevirt.io` subresources (`virtctl`
  start/stop/restart, ssh/scp/port-forward, console); `get`/`list`/`watch` on pods, `pods/log`,
  services and events; `get`/`list` on nodes (cluster-wide; SecGen reports where VMs run). No
  `patch` on pods is needed (SecGen then applies `secgen.io/phase=ready` from the VM's next
  boot), and none should be given - it would let the account change a running pod's image;
- in the golden namespace: the clone grant above;
- cluster-wide, only for the `ovn` backend: Kube-OVN `vpcs` and `subnets`. These objects are
  cluster-scoped, so restrict which ones an account may create or change - for example with a
  `ValidatingAdmissionPolicy` that only admits names and labels belonging to that account's lab
  namespace. SecGen labels each with `secgen.io/lab-namespace` and names them after the lab.

## Egress for labs

SecGen does not apply any policy. It labels every lab VM's virt-launcher pod:

| label | value |
|---|---|
| `secgen.io/lab-vm` | `"true"` |
| `secgen.io/lab` | the lab namespace |
| `secgen.io/phase` | `provisioning` while puppet runs, then `ready` |

Provisioning usually needs package mirrors; a finished lab usually should not reach anything
outside itself. So the policy to write selects `secgen.io/lab-vm=true` with
`secgen.io/phase notin (provisioning)` - which also catches a VM with no phase label - and allows
only what finished labs need (a shared service, or nothing). With Cilium, as a cluster-wide policy
that lab owners cannot modify:

```yaml
apiVersion: cilium.io/v2
kind: CiliumClusterwideNetworkPolicy
metadata:
  name: secgen-lab-egress
spec:
  endpointSelector:
    matchLabels:
      secgen.io/lab-vm: "true"
    matchExpressions:
      - key: secgen.io/phase
        operator: NotIn
        values: ["provisioning"]
  egress: []        # deny everything; add rules for shared services labs may use
```

A plain Kubernetes `NetworkPolicy` per lab namespace works too (`podSelector` with the same
labels, `policyTypes: [Egress]`).

Things that are easy to get wrong:

- Traffic on lab networks (Kube-OVN or bridge) never passes the primary CNI, so this policy only
  governs the guest's pod-network interface. Lab-to-lab isolation comes from separate segments.
- `virtctl ssh/scp/console` go through the API server, so a lab with no egress at all is still
  fully manageable.
- A guest on a masquerade interface cannot reach a ClusterIP service, nor a NodePort on its own
  node; publish shared services on node or LoadBalancer addresses and let labs use any node.
- With Cilium's socket-level load balancing, a NodePort connection may be translated to the
  backend pod *before* policy is checked, so allow the backend pods as well as the node port.

## Shared services

Anything several labs use (an LLM gateway for chatbot scenarios, a package mirror) is deployed
once, outside SecGen, and handed to scenarios through ordinary module inputs - the same way as on
any other provider. Do not deploy them per lab.

## Building such a cluster, step by step

Any conformant Kubernetes distribution works. The order matters mostly for networking.

1. **Nodes.** Bare metal (or nested-virt VMs) with `/dev/kvm`, the `openvswitch` and `geneve`
   modules available, and UDP 6081 open between nodes. Three nodes give etcd and Kube-OVN's
   `ovn-central` a quorum.

2. **Primary CNI.** Install it with Multus coexistence enabled - for Cilium:

   ```bash
   helm install cilium cilium/cilium -n kube-system --set cni.exclusive=false
   ```

3. **Storage.** A CSI driver with clone support and a StorageClass for VM disks (for example
   Rook-Ceph with an RBD pool). Check CDI later picks a fast strategy:
   `kubectl get storageprofile <class> -o jsonpath='{.status.cloneStrategy}'`.

4. **Multus (thick plugin)**, from its release manifest
   (`deployments/multus-daemonset-thick.yml`), with `"namespaceIsolation": true` in the daemon
   configuration. Its first CNI configuration file must be the primary CNI's (Multus's
   `multusConfigFile: auto` uses the lowest-sorted file in `/etc/cni/net.d` as every pod's
   default network).

5. **Lab networks**, one of:

   - **Kube-OVN, non-primary** (labs span nodes):

     ```bash
     helm repo add kubeovn https://kubeovn.github.io/kube-ovn/
     kubectl label node <each control node> kube-ovn/role=master
     helm install kube-ovn kubeovn/kube-ovn --version v1.16.14 -n kube-system -f values.yaml
     ```

     with, at least:

     ```yaml
     MASTER_NODES: "<comma-separated IPs of the labelled nodes>"
     networking:
       TUNNEL_TYPE: geneve
       IFACE: <the node interface tunnels should use; it also sets the MTU>
     cni_conf:
       NON_PRIMARY_CNI: true        # never the pods' default network
       CNI_CONFIG_PRIORITY: "90"    # its conflist must sort after the primary CNI's
     func:
       ENABLE_NP: false             # the primary CNI owns policy and services
       ENABLE_LB: false
       ENABLE_LB_SVC: false
     ipv4:                          # internal ranges; keep clear of everything else you route
       POD_CIDR: "10.251.0.0/16"
       JOIN_CIDR: "10.250.0.0/16"
       SVC_CIDR: "<the cluster's service CIDR>"
     ```

     On an immutable OS with the modules built into the kernel, also set
     `DISABLE_MODULES_MANAGEMENT: true` and point `OVN_DIR` / `OPENVSWITCH_DIR` at writable host
     paths (e.g. `/var/lib/ovn`, `/var/lib/openvswitch`).

   - **or bridge + whereabouts** (node-local labs): install the reference CNI plugins on every
     node and whereabouts from its release manifests.

6. **KubeVirt and CDI**, from their operator manifests:

   ```bash
   KV=v1.9.0; CDI=v1.66.1
   kubectl apply -f https://github.com/kubevirt/kubevirt/releases/download/$KV/kubevirt-operator.yaml
   kubectl apply -f https://github.com/kubevirt/kubevirt/releases/download/$KV/kubevirt-cr.yaml
   kubectl apply -f https://github.com/kubevirt/containerized-data-importer/releases/download/$CDI/cdi-operator.yaml
   kubectl apply -f https://github.com/kubevirt/containerized-data-importer/releases/download/$CDI/cdi-cr.yaml
   ```

   and `virtctl` (same version) on every machine that runs SecGen.

7. **SecGen namespaces and grants**: the golden namespace, lab namespace(s) with their Pod
   Security label and quota, the clone grant, and - for restricted users - the account and
   admission policy described above. Keep these in version control with the rest of the cluster.

8. **Egress policy** for lab VMs (above), and any shared services.

9. **Golden images**: upload one PVC per base into the golden namespace (README-KubeVirt.md,
   *Preparing golden images*), then boot a throwaway clone of each to check it reaches ssh.

## Checking the cluster

| check | how | expect |
|---|---|---|
| KVM is available | `kubectl get nodes -o custom-columns=N:.metadata.name,KVM:.status.allocatable.devices\.kubevirt\.io/kvm` | non-zero on every node |
| clones are fast | `kubectl get storageprofile <class> -o jsonpath='{.status.cloneStrategy}'` | `csi-clone` or `snapshot` |
| Kube-OVN is healthy | `kubectl -n kube-system get pods -l app=kube-ovn-cni` (and `ovn-central`, `ovs-ovn`) | running on every node, no restarts |
| pods keep their default network | create any pod; check `ip addr` | primary CNI address on `eth0` only |
| lab networks cross nodes | two pods or VMs on one Kube-OVN subnet, on different nodes, ping each other | no loss; full-size frames at the lab MTU |
| labs are isolated | two such subnets with the same CIDR and addresses | each works; no traffic between them |
| NADs are namespaced | a pod referencing another namespace's NetworkAttachmentDefinition | refused by Multus |
| egress | from a finished lab VM, try the internet and each allowed service | only the allowed ones answer |
| end to end | `ruby secgen.rb -s scenarios/labs/introducing_attacks/1_intro_linux.xml --kubevirt-namespace <lab ns> run` | post-provision tests pass |
