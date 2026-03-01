## ADDED Requirements

### Requirement: Prompt Template Storage
The system SHALL store reusable prompt templates in a dedicated directory structure.

#### Scenario: Store scenario introduction template
- **WHEN** system is installed
- **THEN** `modules/generators/narrative_content/prompts/scenario_introduction.txt` exists

#### Scenario: Store email chain template
- **WHEN** system is installed
- **THEN** `modules/generators/narrative_content/prompts/email_chain.txt` exists

#### Scenario: Store employee background template
- **WHEN** system is installed
- **THEN** `modules/generators/narrative_content/prompts/employee_background.txt` exists

#### Scenario: Store incident timeline template
- **WHEN** system is installed
- **THEN** `modules/generators/structured_content/prompts/incident_timeline.txt` exists

#### Scenario: Store evidence description template
- **WHEN** system is installed
- **THEN** `modules/generators/narrative_content/prompts/evidence_description.txt` exists

### Requirement: Template Variable Substitution
The system SHALL support Handlebars-style variable substitution in prompt templates.

#### Scenario: Substitute organisation variables
- **WHEN** template contains `{{organisation.business_name}}`
- **THEN** generator replaces with actual organisation name from datastore

#### Scenario: Substitute theme variables
- **WHEN** template contains `{{narrative_theme}}`
- **THEN** generator replaces with specified theme parameter

#### Scenario: Support iteration variables
- **WHEN** template contains `{{#each participants}}...{{/each}}`
- **THEN** generator iterates over participants array and renders block for each

### Requirement: Template Loading and Caching
The system SHALL load and cache prompt templates for efficient reuse.

#### Scenario: Load template from file
- **WHEN** generator requests template by name
- **THEN** system loads template file from prompts directory

#### Scenario: Cache loaded templates
- **WHEN** template is loaded multiple times
- **THEN** system serves from cache after initial load

#### Scenario: Handle missing template gracefully
- **WHEN** generator requests non-existent template
- **THEN** system returns error with helpful message about available templates

### Requirement: Template Customization
The system SHALL allow educators to customize templates without code changes.

#### Scenario: Override default template
- **WHEN** educator places custom template in configuration directory
- **THEN** system uses custom template instead of default

#### Scenario: Create new template
- **WHEN** educator creates new template file in prompts directory
- **THEN** system makes template available to generators

### Requirement: Template Validation
The system SHALL validate template syntax before use.

#### Scenario: Validate template syntax
- **WHEN** template is loaded
- **THEN** system validates Handlebars syntax and reports errors

#### Scenario: Validate required variables
- **WHEN** template declares required variables
- **THEN** system verifies all required variables are provided at generation time
