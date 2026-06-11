## ADDED Requirements

### Requirement: Structured scenario intent input
The system SHALL accept a structured scenario intent document that captures the requested scenario name, scenario type, target platform, vulnerability classes, difficulty, learning outcomes, CyBOK alignment, flag requirements, evidence requirements, generation seed, and optional harness/model configuration.

#### Scenario: Valid intent is accepted
- **WHEN** a scenario intent document contains all required fields with supported values
- **THEN** the system accepts the intent for template selection and scenario generation

#### Scenario: Missing required intent fields are rejected
- **WHEN** a scenario intent document omits required fields such as scenario name, vulnerability class, difficulty, or target platform
- **THEN** the system rejects the intent and reports the missing fields

### Requirement: Supported vulnerability class selection
The system SHALL map each requested vulnerability class to an approved generation template or fail before writing generated artifacts.

#### Scenario: Supported vulnerability class maps to template
- **WHEN** the intent requests a supported vulnerability class such as SQL injection, XSS, broken access control, command injection, path traversal, insecure file upload, weak authentication, or insecure configuration
- **THEN** the system selects an approved template compatible with the requested platform and difficulty

#### Scenario: Unsupported vulnerability class fails early
- **WHEN** the intent requests a vulnerability class with no approved compatible template
- **THEN** the system fails before creating scenario or module output files

### Requirement: Educational metadata capture
The system SHALL require educational metadata that can be rendered into scenario XML and module metadata, including learning objectives, difficulty, scenario type, and CyBOK knowledge area data.

#### Scenario: Educational metadata is available for assembly
- **WHEN** a valid intent includes learning objectives and CyBOK data
- **THEN** scenario assembly can include equivalent metadata in generated scenario XML or supporting documentation

### Requirement: Intent normalization
The system SHALL normalize intent values into repository-safe identifiers for scenario names, system names, module names, datastore keys, and file paths.

#### Scenario: Human-readable names become safe identifiers
- **WHEN** the intent contains a human-readable scenario title
- **THEN** the system derives deterministic kebab-case or snake-case identifiers suitable for generated files and XML references

### Requirement: Harness configuration capture
The system SHALL capture optional harness configuration including harness name, provider, model, retry limit, local-only mode, staging path, isolation mode, container image, sandbox mode, and approved validation profile, with OpenCode as the default harness and Docker/container isolation as the default isolation mode.

#### Scenario: Harness configuration is available to adapter
- **WHEN** a valid intent includes harness configuration
- **THEN** the normalized intent exposes the configuration for the harness adapter without requiring generation to start
