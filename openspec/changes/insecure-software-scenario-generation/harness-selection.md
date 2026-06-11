## Harness Selection

### Decision

OpenCode is the first supported coding-agent harness for insecure software scenario generation.

### Why OpenCode First

- It is already available in the local development environment and exposes a noninteractive CLI through `opencode run`.
- It supports JSON event output with `--format json`, which gives SecGen a workable integration surface for logs and trace summaries.
- It provides separate `plan` and `build` agents. Local verification showed `plan` is read-oriented and denies broad edits, while `build` supports editing and command execution.
- It supports model selection with `--model`, agent selection with `--agent`, staged working directories with `--dir`, and session export with `opencode export`.
- It can run inside a Docker/container boundary, which is now the primary containment model for generated insecure code and harness execution.

### Deferred Alternatives

#### Pi

Pi remains a useful candidate because it is a compact open-source agent toolkit with a coding-agent CLI and unified provider API. It is deferred because its own permission model is intentionally minimal. With Docker/VM isolation as the primary boundary this is not disqualifying, but OpenCode is further along for immediate CLI integration in this repository.

#### ForgeCode

ForgeCode remains a candidate for future multi-agent workflows. It is deferred until its headless CLI behavior, release maturity, license fit, logging/transcript capture, and CI/container execution path are verified against SecGen’s generation loop.

#### Forge ACP CLI

Forge ACP CLI is deferred because it is better suited as a future compatibility layer across multiple coding agents. The first implementation only needs one concrete harness adapter, so adding an ACP abstraction now would add complexity before there is a second supported harness.

### Isolation Model

Harness-native permission systems are defense in depth only. SecGen should run generation and validation inside Docker by default, mount only the staged workspace as writable, collect artifacts/logs/manifests from that workspace, and reserve VM-backed validation for later high-fidelity SecGen scenario builds.

