## ADDED Requirements

### Requirement: Complete scenario XML generation
The system SHALL generate complete SecGen scenario XML that includes scenario metadata, systems, bases, networks, generated vulnerabilities, and any required services, utilities, generators, encoders, or datastore wiring.

#### Scenario: Scenario XML references generated module
- **WHEN** a vulnerable software module is generated for a scenario
- **THEN** the generated scenario XML references that module through SecGen-compatible vulnerability selection attributes

#### Scenario: Scenario XML includes learning metadata
- **WHEN** the intent includes scenario type, difficulty, and CyBOK alignment
- **THEN** the generated scenario XML includes the corresponding metadata elements

### Requirement: Multi-system scenario support
The system SHALL support generation of at least one target system and optional attacker/support systems when the intent or selected template requires them.

#### Scenario: Attacker system is included when required
- **WHEN** the selected scenario pattern requires a Kali or support system
- **THEN** the generated scenario XML includes the additional system with compatible base, utility, and network configuration

### Requirement: Datastore and generated content wiring
The system SHALL wire datastores, generators, encoders, and literal values into generated scenario XML when templates require shared generated values.

#### Scenario: Shared generated values use datastores
- **WHEN** a generated scenario needs shared values such as IP addresses, credentials, table names, flags, or evidence strings
- **THEN** the scenario XML stores and retrieves those values using SecGen datastore inputs

### Requirement: Documentation stub generation
The system SHALL generate a scenario documentation stub summarizing the scenario purpose, intended learning outcomes, generated systems, vulnerability classes, review status, and validation commands.

#### Scenario: Documentation accompanies generated scenario
- **WHEN** scenario assembly completes successfully
- **THEN** a documentation stub exists alongside the staged generated artifacts
