## Context

SecGen already generates training environments from XML scenario definitions and module metadata. Existing vulnerable web application scenarios, such as the random webapp scenario, combine bases, vulnerabilities, generators, encoders, datastores, services, and networks to produce varied CTF and lab environments. Creating a new scenario still requires hand-authoring several coordinated artifacts: scenario XML, vulnerable software module files, Puppet manifests, ERB templates, `secgen_metadata.xml`, tests, flags, and documentation.

This change introduces a generation workflow for new insecure software scenarios. It is additive and should use the existing scenario/module model rather than replacing it. Generated scenarios must remain reviewable, deterministic enough for education and grading, and compatible with the existing SecGen build flow.

Stakeholders include SecGen developers, cybersecurity educators creating exercises, and students who consume generated CTF/lab scenarios.

## Goals / Non-Goals

**Goals:**

- Provide a structured scenario intent format that captures vulnerability, platform, difficulty, learning, flag, and evidence requirements.
- Generate scenario XML and vulnerable software module skeletons that follow SecGen conventions.
- Support approved vulnerability templates for common insecure software patterns.
- Validate generated files before they are accepted into `scenarios/` or `modules/`.
- Record enough metadata to reproduce, review, and audit generated scenarios.
- Allow optional integration with LLM-generated narrative content without making LLMs mandatory.

**Non-Goals:**

- Automatically proving exploitability of every generated vulnerability.
- Replacing existing hand-written scenario and module authoring workflows.
- Generating arbitrary unreviewed code outside approved templates.
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

**Decision:** Generate vulnerable software from approved templates and vulnerability patterns rather than unconstrained source generation.

**Rationale:** Insecure software scenarios must be intentionally vulnerable, understandable, testable, and safe to review. Templates keep generated code inside known patterns while still allowing variation through parameters, seeds, flags, datastore values, and narrative/evidence content.

**Alternatives considered:**

- Fully generated arbitrary applications: higher variety, but much harder to review and validate.
- Only selecting existing modules: safer, but does not meet the goal of generating new scenarios.

### 3. Generate Into a Staging Area First

**Decision:** Write generated scenarios and modules into a staging directory before promotion into `scenarios/` and `modules/`.

**Rationale:** Generation can create multiple files and partial outputs. Staging allows validation and human review before changing the active scenario/module tree.

**Alternatives considered:**

- Direct writes to final locations: simpler, but risks leaving invalid artifacts in active paths.
- External artifact bundles only: reviewable, but disconnected from existing SecGen workflows.

### 4. Reuse Existing SecGen Composition Primitives

**Decision:** Scenario assembly must use current SecGen XML concepts: systems, bases, vulnerabilities, services, utilities, networks, generators, encoders, and datastores.

**Rationale:** The value of this change is faster authoring, not a parallel scenario engine. Reusing existing primitives preserves compatibility with current builds and lets generated scenarios use the existing module selection logic.

**Alternatives considered:**

- New scenario DSL: could improve ergonomics, but would require translation and duplicate existing concepts.
- Hardcoded generated VM definitions: brittle and less reusable.

### 5. Validate Before Promotion

**Decision:** Generated artifacts must pass structural and repository-specific validation before promotion.

**Rationale:** Broken XML, missing metadata, dangling template references, and untested modules are common risks when generating multi-file artifacts. Validation gives developers a clear acceptance gate.

**Alternatives considered:**

- Manual review only: necessary but insufficient for repeatable generation.
- Full VM build as the only validation: valuable later, but too slow as the first feedback loop.

## Risks / Trade-offs

- Unintended unsafe generated code -> Restrict generation to approved templates, require review before promotion, and record generated artifacts in manifests.
- Low-quality or unrealistic scenarios -> Require learning goals, difficulty, vulnerability class, flags, and validation checks in the intent model.
- Drift from SecGen conventions -> Generate from local templates and validate module metadata, XML references, and expected file layout.
- Reproducibility gaps -> Store seed, intent, template versions, selected options, and output hashes in a generation manifest.
- Overly rigid templates -> Version templates and allow parameterized variation without allowing arbitrary unreviewed code generation.
- Validation false confidence -> Treat validation as a minimum gate; exploit walkthroughs and educator review remain required for accepted scenarios.

## Migration Plan

1. Add the intent schema and loader for generation requests.
2. Add approved vulnerable software templates and template metadata.
3. Add staging generation for module skeletons, scenario XML, tests, and documentation stubs.
4. Add validation for staged output.
5. Add manifest creation for reproducibility and review.
6. Document the generation and promotion workflow.

Rollback is straightforward because the feature is additive. Generated artifacts remain staged until explicitly promoted, and existing scenarios continue to build through the current workflow.

## Open Questions

1. Which initial vulnerability template set should be implemented first: web application vulnerabilities only, or web plus local/system misconfiguration patterns?
2. Should generated scenarios be promoted by a CLI command, a review checklist, or both?
3. Where should staged generated artifacts live permanently: under `tmp/`, `generated/`, or an OpenSpec-defined path?
4. Should exploit walkthrough files be required for promotion in the first implementation, or only recommended?
