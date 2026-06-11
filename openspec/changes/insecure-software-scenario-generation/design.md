## Context

SecGen already generates training environments from XML scenario definitions and module metadata. Existing vulnerable web application scenarios, such as the random webapp scenario, combine bases, vulnerabilities, generators, encoders, datastores, services, and networks to produce varied CTF and lab environments. Creating a new scenario still requires hand-authoring several coordinated artifacts: scenario XML, vulnerable software module files, Puppet manifests, ERB templates, `secgen_metadata.xml`, tests, flags, and documentation.

This change introduces an agentic generation workflow for new insecure software scenarios. It is additive and should use the existing scenario/module model rather than replacing it. Generated scenarios must remain reviewable, deterministic enough for education and grading, and compatible with the existing SecGen build flow.

The existing LLM narrative implementation already provides provider configuration and API/local-model adapters under `modules/generators/narrative_content/lib`. Scenario generation should reuse its provider configuration where useful, but the code-generation loop should be delegated to OpenCode rather than implemented from scratch in SecGen. SecGen should own the wrapper contract: intent, templates, staging paths, policies, validation commands, manifests, and review gates.

Stakeholders include SecGen developers, cybersecurity educators creating exercises, and students who consume generated CTF/lab scenarios.

## Goals / Non-Goals

**Goals:**

- Provide a structured scenario intent format that captures vulnerability, platform, difficulty, learning, flag, and evidence requirements.
- Use OpenCode to plan, generate, validate, test, and repair insecure software scenario artifacts in a bounded loop.
- Generate scenario XML and vulnerable software module skeletons that follow SecGen conventions.
- Support approved vulnerability templates for common insecure software patterns.
- Validate generated files before they are accepted into `scenarios/` or `modules/`.
- Record enough metadata to reproduce, review, and audit generated scenarios.
- Allow optional integration with LLM-generated narrative content without making LLMs mandatory.

**Non-Goals:**

- Automatically proving exploitability of every generated vulnerability.
- Replacing existing hand-written scenario and module authoring workflows.
- Generating arbitrary unreviewed code outside approved templates and policy constraints.
- Running scenario generation during student exercises.
- Changing the existing scenario XML runtime semantics for existing scenarios.

## Decisions

### 1. Use a Structured Intent Model

**Decision:** Represent generation requests as structured intent data before any files are created.

**Rationale:** SecGen scenario generation needs more than a prose prompt. A structured model makes validation, reproducibility, and template selection possible, and maps naturally to current XML filters such as difficulty, type, platform, CyBOK fields, and module metadata.

**Alternatives considered:**

- Free-form prompt only: easier to start with, but difficult to validate or reproduce.
- Scenario XML only as input: too low-level for educators who want to describe learning goals and vulnerability classes.

### 2. Template-First Vulnerable Software Generation

**Decision:** Generate vulnerable software from approved templates and vulnerability patterns rather than unconstrained source generation, even when an agent is doing the generation.

**Rationale:** Insecure software scenarios must be intentionally vulnerable, understandable, testable, and safe to review. Templates keep generated code inside known patterns while still allowing variation through parameters, seeds, flags, datastore values, and narrative/evidence content.

**Alternatives considered:**

- Fully generated arbitrary applications: higher variety, but much harder to review and validate.
- Only selecting existing modules: safer, but does not meet the goal of generating new scenarios.

### 3. OpenCode Harness Adapter

**Decision:** Use OpenCode as the first supported coding-agent harness rather than building the coding-agent loop in SecGen.

**Rationale:** OpenCode already implements the hard parts of autonomous code editing: repository exploration, file edits, shell/tool execution, planning/build modes, model-provider integration, session state, and repair iteration. SecGen should avoid duplicating that machinery. Instead, SecGen should provide the domain-specific wrapper: scenario intent, approved vulnerability templates, isolated staging directories, policy files, validation commands, retry limits, manifests, and human review gates.

**Agent options considered:**

| Option | Fit | Trade-off |
|--------|-----|-----------|
| OpenCode | Selected first adapter: mature open-source coding agent, terminal/IDE/desktop surfaces, built-in plan/build agents, many model providers, privacy-oriented posture | Need to verify noninteractive invocation, config format, and container execution shape |
| Pi | Good minimal harness candidate: agent core, coding-agent CLI, unified multi-provider LLM API, MIT license | Its own README states it has no built-in permission system, so SecGen must rely on container or VM isolation |
| ForgeCode | Strong production-oriented candidate: multi-agent architecture, model mixing, context engine, published benchmark claims | Need to verify CLI automation interface, license/release maturity, and whether it can run cleanly in CI/headless mode |
| Forge ACP CLI | Useful abstraction candidate: Agent Client Protocol terminal interface that can manage multiple coding agents including OpenCode | Very young, fewer signals, and may be better as a future compatibility layer than first implementation |
| Custom Ruby harness + `LlmProviderConfig` | Maximum control and direct integration with current narrative code | Duplicates existing harness work and is no longer preferred |

**Preferred path:** Create a SecGen harness adapter interface for OpenCode first. Keep Pi and ForgeCode as deferred alternatives if OpenCode cannot support reliable noninteractive/headless operation, isolated staged-workspace execution, log collection, or model/provider configuration in the way SecGen needs. Pi remains attractive for a smaller programmable core because container/VM isolation removes the need to trust harness-native permissions. ForgeCode remains attractive for multi-agent production workflows but needs license, automation, and maturity verification before adoption.

**Adapter contract:**

- Prepare a staged workspace containing intent, templates, policy, and validation commands.
- Invoke OpenCode with a constrained prompt and SecGen-specific instructions inside the isolated workspace.
- Run the harness and validation commands in a Docker container by default.
- Use a VM execution path for later high-fidelity SecGen build validation where Docker is insufficient.
- Treat harness-native permissions and path checks as defense in depth, not the primary boundary.
- Run SecGen-owned validation commands after each harness attempt inside the same isolated context where practical.
- Feed validation failures back through the harness for repair.
- Persist harness logs, transcript paths or hashes, provider/model metadata, and final status.

### 4. Container-First Isolation

**Decision:** Use Docker/container isolation as the primary safety boundary for harness execution and generated insecure software tests, with VM validation as the later high-fidelity path.

**Rationale:** The system intentionally asks an agent to generate insecure software and run commands against it. Harness permission systems vary across OpenCode, Pi, ForgeCode, and future adapters, so they should not be the trusted boundary. Docker gives faster, repeatable, CI-friendly isolation for generation and validation. SecGen VM builds remain important for final realism, but they are slower and should be used after staged artifacts pass the container validation loop.

**Alternatives considered:**

- Relying primarily on harness permissions: too harness-specific and weak for tools that have no built-in permission model.
- Running directly in the developer checkout: convenient, but risks unrelated file edits and host-side effects.
- VM-only validation: most realistic for SecGen, but too slow for the inner repair loop.

### 5. Generate Into a Staging Area First

**Decision:** Write generated scenarios and modules into a staging directory before promotion into `scenarios/` and `modules/`.

**Rationale:** Generation can create multiple files and partial outputs. Staging allows validation and human review before changing the active scenario/module tree.

**Alternatives considered:**

- Direct writes to final locations: simpler, but risks leaving invalid artifacts in active paths.
- External artifact bundles only: reviewable, but disconnected from existing SecGen workflows.

### 6. Reuse Existing SecGen Composition Primitives

**Decision:** Scenario assembly must use current SecGen XML concepts: systems, bases, vulnerabilities, services, utilities, networks, generators, encoders, and datastores.

**Rationale:** The value of this change is faster authoring, not a parallel scenario engine. Reusing existing primitives preserves compatibility with current builds and lets generated scenarios use the existing module selection logic.

**Alternatives considered:**

- New scenario DSL: could improve ergonomics, but would require translation and duplicate existing concepts.
- Hardcoded generated VM definitions: brittle and less reusable.

### 7. Validate Before Promotion

**Decision:** Generated artifacts must pass structural and repository-specific validation before promotion, and validation failures must be fed back into the agent as repair context before the run fails.

**Rationale:** Broken XML, missing metadata, dangling template references, and untested modules are common risks when generating multi-file artifacts. Validation gives developers a clear acceptance gate.

**Alternatives considered:**

- Manual review only: necessary but insufficient for repeatable generation.
- Full VM build as the only validation: valuable later, but too slow as the first feedback loop.

### 8. Bounded Harness Repair Loop

**Decision:** The external harness loop must be wrapped by explicit phases, retry limits, file allowlists, command allowlists, and a final human review gate.

**Rationale:** The system is intentionally generating insecure software for training, so it needs stronger boundaries than a generic code generator. A bounded loop prevents unreviewed or runaway changes while still allowing the agent to respond to concrete test and validation output.

**Loop phases:**

1. Load and normalize scenario intent.
2. Select templates, generation policy, and the OpenCode adapter.
3. Invoke OpenCode for a generation plan.
4. Run OpenCode in the isolated staging environment.
5. Allow generated files only in the mounted staging workspace.
6. Run structural validation and tests inside the container.
7. Feed failures back to the agent for repair.
8. Repeat until pass, retry limit, or blocked condition.
9. Produce a manifest, validation report, and review checklist.

## Risks / Trade-offs

- Unintended unsafe generated code -> Restrict generation to approved templates, require review before promotion, and record generated artifacts in manifests.
- External harness modifies unrelated files -> Run the harness in a container or VM with only the staging workspace mounted writable, then reject outputs outside allowed paths.
- Generated insecure software affects the host -> Run generation and validation inside Docker by default and reserve VM execution for later SecGen build validation.
- External harness lacks a stable noninteractive mode -> Treat the harness comparison spike as a gate before implementation.
- Harness loops without converging -> Enforce retry limits and require the final report to include unresolved validation failures.
- Provider-specific behavior changes -> Keep provider/model/harness metadata in the manifest and support local providers where the selected harness supports them.
- Low-quality or unrealistic scenarios -> Require learning goals, difficulty, vulnerability class, flags, and validation checks in the intent model.
- Drift from SecGen conventions -> Generate from local templates and validate module metadata, XML references, and expected file layout.
- Reproducibility gaps -> Store seed, intent, template versions, selected options, and output hashes in a generation manifest.
- Overly rigid templates -> Version templates and allow parameterized variation without allowing arbitrary unreviewed code generation.
- Validation false confidence -> Treat validation as a minimum gate; exploit walkthroughs and educator review remain required for accepted scenarios.

## Migration Plan

1. Add the intent schema and loader for generation requests.
2. Add the OpenCode harness adapter interface and verify OpenCode against SecGen container execution requirements.
3. Add approved vulnerable software templates and template metadata.
4. Add staging generation for module skeletons, scenario XML, tests, and documentation stubs.
5. Add validation and repair feedback for staged output.
6. Add manifest creation for reproducibility, harness/provider metadata, trace summaries, and review.
7. Document the generation and promotion workflow.

Rollback is straightforward because the feature is additive. Generated artifacts remain staged until explicitly promoted, and existing scenarios continue to build through the current workflow.

## Open Questions

1. Which initial vulnerability template set should be implemented first: web application vulnerabilities only, or web plus local/system misconfiguration patterns?
2. Should generated scenarios be promoted by a CLI command, a review checklist, or both?
3. Where should staged generated artifacts live permanently: under `tmp/`, `generated/`, or an OpenSpec-defined path?
4. Should exploit walkthrough files be required for promotion in the first implementation, or only recommended?
5. What is the minimum reliable OpenCode invocation mode for Dockerized CI/headless generation?
