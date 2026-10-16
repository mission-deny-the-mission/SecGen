# Why there is a private key in the repository

`vagrant_insecure_key` is the **published Vagrant "insecure" key pair** (HashiCorp's
well-known default, created for the vagrant user of every Vagrant base box). SecGen's
base images deliberately install its public half in the `vagrant` user's
`authorized_keys`, which is what lets the KubeVirt provider provision a freshly cloned
lab VM over `virtctl ssh` with no key-injection step.

It is public knowledge by design and is **not a secret**: every Vagrant box on the
internet that has not regenerated its key trusts it. It confers access to nothing beyond
a disposable lab VM built from a SecGen base image - which is also why lab VMs must never
hold anything worth protecting.

If you would rather not carry it, pass `--kubevirt-ssh-key <path>` (or set
`options[:kubevirtsshkey]`) to use a different key, and make sure the matching public key
is present in the base image's `vagrant` account.
