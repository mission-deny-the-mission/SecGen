# Staged generation, validation, repair & promotion workflow

Deterministic scenario generation is a staged pipeline (`GenerationPipeline`).
Everything is written under a **staging directory**; nothing is promoted into the
repository until a human reviews it. The external harness (OpenCode) runs inside a
container by default and may only write inside the staging area.

## Phases

1. **Load & normalise intent** — `Intent.load` validates and derives identifiers
   and the seed that makes the run reproducible.
2. **Select templates (fail-fast)** — `TemplateCatalog.load` + `TemplateSelector`
   pick one approved, compatible template per requested vulnerability class. If
   any class is unsupported, `TemplateSelectionError` is raised **before any file
   is written**.
3. **Prepare workspace** — `OpenCodeAdapter#prepare_workspace` writes
   `intent.normalized.json` and `opencode.policy.json` into staging. The policy
   pins the allowed write root, container settings, retry limit, approved
   validation commands, and forbidden paths.
4. **Generate modules** — `ModuleGenerator` renders, per selected template, a
   complete XSD-valid SecGen vulnerability module (metadata, entry `.pp`,
   manifests, ERB template, test stub). All output is a pure function of
   seed + identifiers + template, so it is byte-reproducible.
5. **Assemble scenario** — `ScenarioAssembler` builds the XSD-valid `scenario.xml`
   referencing each generated module, wiring deterministic flag values through
   datastores, plus a documentation stub.
6. **Validate** — `Validator` runs structural (scenario + module XSD, required
   files, unresolved references), repository-convention, and test-coverage
   checks, producing a `ValidationReport`. **Any failure blocks promotion.**
7. **Repair loop** — on failure, `RepairLoop` feeds the report's machine-readable
   `repair_context` into `OpenCodeAdapter#repair_command`, runs it (in the
   container), and re-validates, bounded by `retry_limit`. On exhaustion it stops
   **without promoting**.
8. **Manifest** — `Manifest.build` records inputs, seed, templates, generated
   paths, per-file content hashes, harness/provider/model metadata, retry data,
   and the harness trace, then writes `manifest.json`.
9. **Review & promotion** — review status is tracked separately
   (`review: generated → reviewed`, `promotion: staged → promoted`) and never
   overwrites the original generation inputs. Promotion is a deliberate, human
   step gated on `promotion_ready?`.

## Container isolation & bounded writes/commands

- `isolation_mode: docker` (default) runs OpenCode with `--network none`,
  `--cap-drop ALL`, `--security-opt no-new-privileges`, a bind mount limited to
  the staging directory, and a size-limited tmpfs.
- Generated writes are validated against the staging root
  (`validate_staged_paths!`); out-of-scope writes are rejected.
- Validation/test commands must match the adapter's approved profile
  (`validate_validation_command!`); unapproved commands are rejected.

## Optional VM validation

A `vm_validation_command` may be supplied for deeper, out-of-band validation of a
provisioned target. It is optional and not part of the deterministic local path.

## Local execution note

The deterministic pipeline does **not** execute docker/OpenCode locally — harness
phases are constructed as command arrays and recorded in the trace, and the
repair loop uses an injectable command runner. Real container-isolated generation
and validation are asserted at the command-array level (see the test suite).
