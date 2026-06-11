## ADDED Requirements

### Requirement: Generation manifest
The system SHALL create a generation manifest for each generated scenario that records the original intent, normalized intent, seed, selected templates, selected module names, generated paths, tool version, timestamp, harness/provider/model metadata, retry metadata, and output hashes.

#### Scenario: Manifest is created after successful generation
- **WHEN** scenario generation completes successfully
- **THEN** a manifest exists in the staged output and records all reproducibility metadata

### Requirement: Deterministic regeneration from manifest
The system SHALL support regenerating the same staged artifacts from a manifest when the referenced templates and tool version are available.

#### Scenario: Regeneration produces matching hashes
- **WHEN** the system regenerates a scenario from a manifest using the same templates and tool version
- **THEN** generated file hashes match the hashes recorded in the manifest

### Requirement: Drift detection
The system SHALL detect when regenerated output differs from the manifest because of changed templates, changed tool version, changed intent, or manual edits.

#### Scenario: Changed template causes drift report
- **WHEN** regeneration output differs from the manifest
- **THEN** the system reports which files or generation inputs drifted

### Requirement: Review traceability
The system SHALL record review status and promotion status separately from generated content so educators and developers can distinguish generated, reviewed, and accepted artifacts.

#### Scenario: Review status is tracked
- **WHEN** generated artifacts are reviewed or promoted
- **THEN** the manifest or accompanying review record reflects the updated status without losing the original generation inputs

### Requirement: Harness trace reproducibility metadata
The system SHALL persist enough harness trace metadata to audit which prompts, provider settings, validation failures, and repair attempts produced the staged artifacts.

#### Scenario: Harness run can be audited
- **WHEN** a reviewer inspects a generated scenario manifest
- **THEN** the reviewer can identify the harness, phases, provider/model settings, retry count, and validation outcomes used during generation
