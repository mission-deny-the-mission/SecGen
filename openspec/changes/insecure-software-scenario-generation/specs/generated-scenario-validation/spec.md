## ADDED Requirements

### Requirement: Structural validation
The system SHALL validate generated scenario XML, module directory layout, metadata files, and template references before artifacts can be promoted from staging.

#### Scenario: Valid generated artifacts pass structural validation
- **WHEN** generated artifacts contain well-formed scenario XML, required module files, valid metadata, and resolvable template references
- **THEN** structural validation passes

#### Scenario: Invalid generated artifacts block promotion
- **WHEN** generated artifacts contain malformed XML, missing module metadata, missing required files, or unresolved references
- **THEN** validation fails and promotion is blocked

### Requirement: Repository convention validation
The system SHALL validate generated artifacts against SecGen repository conventions for naming, module paths, metadata attributes, input parameter names, and scenario placement.

#### Scenario: Convention violations are reported
- **WHEN** generated artifacts use invalid names, unsupported metadata values, or inconsistent module paths
- **THEN** validation reports actionable convention errors

### Requirement: Test coverage validation
The system SHALL require generated scenarios and modules to include test stubs or validation hooks before promotion.

#### Scenario: Missing tests block promotion
- **WHEN** generated artifacts do not include scenario or module test stubs
- **THEN** validation fails and identifies the missing test artifact

### Requirement: Validation report
The system SHALL produce a validation report containing passed checks, failed checks, warnings, generated artifact paths, and promotion readiness.

#### Scenario: Validation report summarizes readiness
- **WHEN** validation completes
- **THEN** the report states whether artifacts are ready for promotion and lists any remaining issues
