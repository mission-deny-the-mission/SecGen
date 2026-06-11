## Why

SecGen can assemble scenarios from existing modules, but creating a new insecure software scenario still requires substantial manual work across scenario XML, vulnerable application templates, metadata, validation, and test assets. A guided generation capability would make it faster to produce consistent, educationally aligned scenarios while preserving SecGen's deterministic build model.

## What Changes

- Add a workflow for generating new insecure software scenarios from structured scenario intent, such as vulnerability class, learning goals, difficulty, target platform, and flag/evidence requirements.
- Add reusable templates for generating vulnerable software modules and scenario XML that conform to existing SecGen module, datastore, generator, and CyBOK conventions.
- Add scenario assembly logic that creates complete scenario directories, module skeletons, metadata, tests, and documentation stubs.
- Add validation for generated scenario XML, module metadata, required files, build references, and exploitability hints before generated scenarios are accepted.
- Add reproducibility controls so generated scenarios can be regenerated or audited from the same inputs.
- Integrate with the existing LLM narrative work as optional context enrichment, without requiring LLMs for deterministic scenario generation.

## Capabilities

### New Capabilities

- `scenario-intent-schema`: Defines the structured input model for requesting new insecure software scenarios, including vulnerability classes, difficulty, learning outcomes, platforms, services, flags, and evidence.
- `vulnerable-software-template-generation`: Generates vulnerable software module skeletons, templates, Puppet manifests, metadata, and tests from approved vulnerability patterns.
- `scenario-assembly-generation`: Generates complete scenario XML and supporting files that wire bases, networks, vulnerabilities, services, utilities, generators, encoders, and datastores together.
- `generated-scenario-validation`: Validates generated scenarios and modules before use, including XML structure, module references, metadata consistency, required files, and test coverage expectations.
- `scenario-generation-reproducibility`: Records generation inputs, seeds, selected templates, and generated artifact manifests so scenarios can be regenerated and reviewed.

### Modified Capabilities

- None.

## Impact

- **New modules**: Scenario-generation code under a dedicated generator/tooling area, likely aligned with existing `modules/generators/` patterns.
- **New templates**: Approved insecure software templates for common vulnerability classes such as injection, XSS, broken access control, insecure deserialization, weak authentication, file upload, path traversal, command injection, and insecure configuration.
- **Scenario output**: Generated XML files under `scenarios/` and generated module skeletons under `modules/` using existing SecGen conventions.
- **Validation**: New tests or validation commands for generated XML, module metadata, template references, and reproducibility manifests.
- **Documentation**: Guidance for educators/developers on requesting, reviewing, customizing, and accepting generated insecure software scenarios.
- **Compatibility**: Existing scenarios and modules remain unchanged; generated scenarios are opt-in artifacts.
