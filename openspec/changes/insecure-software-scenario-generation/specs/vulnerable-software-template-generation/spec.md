## ADDED Requirements

### Requirement: Approved vulnerable software templates
The system SHALL generate vulnerable software modules only from approved templates that declare their vulnerability class, supported platforms, parameters, required files, expected flags, and test expectations.

#### Scenario: Template metadata drives generation
- **WHEN** a compatible template is selected for a scenario intent
- **THEN** the system uses the template metadata to generate module files, parameters, metadata, and tests

#### Scenario: Unapproved template cannot be used
- **WHEN** a template is missing approval metadata or required template descriptors
- **THEN** the system refuses to generate a vulnerable software module from that template

### Requirement: Module skeleton generation
The system SHALL generate a complete vulnerable software module skeleton containing the required SecGen file layout, Puppet entry point, supporting manifests, application templates or files, `secgen_metadata.xml`, and module test stubs.

#### Scenario: Module skeleton contains required files
- **WHEN** vulnerable software generation succeeds
- **THEN** the generated module directory contains the expected SecGen module entry point, metadata, implementation files, and test files for the selected template

### Requirement: Parameterized vulnerable behavior
The system SHALL support template parameters for difficulty, flag placement, datastore inputs, credentials, table names, routes, service ports, and evidence strings where the selected template supports those values.

#### Scenario: Parameters are rendered into generated files
- **WHEN** the selected template declares supported parameters and the intent supplies compatible values
- **THEN** the generated module files contain deterministic rendered values for those parameters

### Requirement: Testable exploit target
The system SHALL generate module-level test stubs or validation hooks that describe the expected vulnerable behavior and flag/evidence location.

#### Scenario: Exploit expectation is documented for tests
- **WHEN** a vulnerable module is generated
- **THEN** the generated test stub or validation metadata identifies the vulnerability entry point and expected successful evidence or flag condition
