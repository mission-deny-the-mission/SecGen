# Harness & provider selection guidance

The authoritative rationale for the harness decision lives in
[`../harness-selection.md`](../harness-selection.md) (why OpenCode is first; why
Pi, ForgeCode, and Forge ACP CLI are deferred). This page summarises the
practical selection guidance for operators.

## Harness

- **OpenCode (supported).** Selected via `HarnessAdapter.for` — it is the only
  harness `name` accepted today. Drives staged `plan`/`build`/`repair` phases
  through `opencode run` with JSON output.
- **Pi / ForgeCode / Forge ACP CLI (deferred).** Candidates for future support.
  Deferral criteria: verified headless CLI behaviour, logging/transcript capture,
  license fit, CI/container execution path, and a permission/isolation story
  compatible with the staging-first model. An ACP abstraction is deferred until a
  second concrete harness exists.

## Providers

The deterministic generation path uses **no LLM provider**. Providers are only
relevant to optional narrative enrichment (`narrative_generation.provider`), which
accepts `ollama`, `openai`, `anthropic`, `llama_cpp`, or `lm_studio`.

- Prefer **local providers** (`ollama`, `llama_cpp`, `lm_studio`) for offline or
  data-sensitive deployments — no content leaves the host.
- Hosted providers (`openai`, `anthropic`) require API keys and network egress;
  keep keys out of the staging directory (the policy lists `*.env`/`llm_config.json`
  among forbidden paths).

## Isolation

- **Docker (default).** `isolation_mode: docker` runs the harness with
  `--network none`, `--cap-drop ALL`, `--security-opt no-new-privileges`, a bind
  mount scoped to the staging directory, and a size-limited tmpfs. This is the
  primary containment boundary for generated insecure code and harness execution.
- **Host.** `isolation_mode: host` runs without a container and is intended for
  CI/test contexts where docker is unavailable; it relies on the staged-write and
  approved-command guards rather than container isolation.
- **Optional VM validation.** A `vm_validation_command` can validate a fully
  provisioned target out-of-band; it is optional and never part of the
  deterministic local path.

Requirement: run untrusted/agentic generation inside Docker (or an equivalent VM
boundary) for any non-CI use. Generation is staged and must be reviewed before
promotion regardless of isolation mode.
