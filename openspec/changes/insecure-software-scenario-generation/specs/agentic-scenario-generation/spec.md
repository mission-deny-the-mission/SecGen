## ADDED Requirements

### Requirement: OpenCode generate-test-repair workflow
The system SHALL integrate OpenCode as the first supported open-source coding-agent harness that plans, generates, validates, tests, repairs, and reports on staged insecure software scenario artifacts from a validated scenario intent.

#### Scenario: Successful agent run produces reviewed staged output
- **WHEN** the agent run generates artifacts that pass validation and tests
- **THEN** the system records the generated files, validation results, test results, provider metadata, and review status in the staged output

#### Scenario: Failing agent run reports unresolved issues
- **WHEN** the agent reaches its retry limit without passing validation or tests
- **THEN** the system stops the run and reports the unresolved failures without promoting generated artifacts

### Requirement: Harness adapter interface
The system SHALL define a harness adapter interface for configuring, invoking, monitoring, and collecting outputs from supported open-source coding-agent harnesses.

#### Scenario: OpenCode is invoked through adapter
- **WHEN** a scenario generation run selects OpenCode
- **THEN** the system prepares the staged workspace, invokes OpenCode through its adapter, and collects generated outputs and logs

#### Scenario: Unsupported harness fails early
- **WHEN** a scenario generation run selects an unsupported harness
- **THEN** the system fails before creating generated artifacts and reports supported harness names

### Requirement: OpenCode integration verification
The system SHALL verify OpenCode supports the required SecGen integration properties before relying on it for end-to-end scenario generation.

#### Scenario: OpenCode verification is documented
- **WHEN** OpenCode verification completes
- **THEN** the design or documentation records invocation mode, model/provider configuration, staged workspace behavior, log/transcript capture, and unresolved risks

### Requirement: Bounded file and command access
The system SHALL restrict harness-generated file writes to a staging directory and restrict validation or test execution to approved commands for scenario generation.

#### Scenario: Harness attempts an out-of-scope write
- **WHEN** a harness output requests writing outside the staging directory
- **THEN** the harness rejects the write and records a policy failure

#### Scenario: Harness requests an unapproved command
- **WHEN** a harness output requests a command outside the approved validation/test command set
- **THEN** the harness rejects the command and records a policy failure

### Requirement: Repair feedback loop
The system SHALL feed validation and test failures back into the external harness as structured repair context until artifacts pass or the configured retry limit is reached.

#### Scenario: Validation failure is repaired
- **WHEN** generated artifacts fail validation and retries remain
- **THEN** the system provides the failure report to the harness and applies the next staged repair attempt

### Requirement: Harness trace summary
The system SHALL record a trace summary for each harness run, including harness name/version, model/provider when available, prompts or prompt hashes, tool/phase decisions, validation attempts, repair attempts, and final status.

#### Scenario: Trace summary is available for review
- **WHEN** an agent run completes or fails
- **THEN** reviewers can inspect a trace summary without needing to reconstruct the run from logs
