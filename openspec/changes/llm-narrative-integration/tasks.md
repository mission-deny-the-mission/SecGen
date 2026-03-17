## 1. Core Infrastructure Setup

- [x] 1.1 Create `modules/generators/narrative_content/` directory structure
- [x] 1.2 Create Ruby base class `LlmNarrativeGenerator` extending existing generator framework
- [x] 1.3 Add LLM client library dependencies to Gemfile
- [x] 1.4 Create configuration file structure for LLM provider settings
- [x] 1.5 Add spec helper files for testing narrative generators

## 2. LLM Provider Integration

- [x] 2.1 Implement provider abstraction interface with common methods (generate, validate, configure)
- [x] 2.2 Implement Ollama provider with local endpoint support
- [x] 2.3 Implement OpenAI provider with API key authentication
- [x] 2.4 Implement Anthropic provider with API key authentication
- [x] 2.5 Add llama.cpp provider for local model loading
- [x] 2.6 Implement LM Studio provider for local endpoint
- [x] 2.7 Add provider configuration loader and validator
- [x] 2.8 Implement secure API key storage and retrieval

## 3. Prompt Template System

- [x] 3.1 Create `modules/generators/narrative_content/prompts/` directory
- [x] 3.2 Create Handlebars template loader and parser
- [x] 3.3 Implement variable substitution for `{{organisation.*}}` patterns
- [x] 3.4 Implement iteration support for `{{#each}}` blocks
- [x] 3.5 Create `scenario_introduction.txt` template
- [x] 3.6 Create `email_chain.txt` template
- [x] 3.7 Create `employee_background.txt` template
- [x] 3.8 Create `incident_timeline.txt` template
- [x] 3.9 Create `evidence_description.txt` template
- [x] 3.10 Implement template caching mechanism
- [x] 3.11 Add template validation for syntax errors
- [x] 3.12 Implement template override mechanism for customization

## 4. Organisation Generation

- [x] 4.1 Create `LlmOrganisationGenerator` class
- [x] 4.2 Implement industry-specific prompt templates (Finance, Healthcare, Education, etc.)
- [x] 4.3 Add employee hierarchy generation with job titles and reporting structure
- [x] 4.4 Implement security posture generation
- [x] 4.5 Add seed-based reproducibility for organisation generation
- [x] 4.6 Implement JSON output matching `lib/resources/structured_content/organisations/` schema
- [x] 4.7 Add organisation generator test suite
- [x] 4.8 Create example organisation generation scenarios

## 5. Evidence Document Generators

- [x] 5.1 Create `LlmEmailChainGenerator` class
- [x] 5.2 Implement email chain coherence across multiple messages
- [x] 5.3 Add character voice consistency for multi-email chains
- [x] 5.4 Implement investigation clue embedding in email content
- [x] 5.5 Create `LlmMemoGenerator` class for policy and incident reports
- [x] 5.6 Create `LlmChatLogGenerator` class for team and DM conversations
- [x] 5.7 Create `LlmLogEntryGenerator` class for authentication and system logs
- [x] 5.8 Create `LlmDatabaseRecordGenerator` class for customer data and transactions
- [x] 5.9 Create `LlmWebsiteContentGenerator` class for compromised site content
- [x] 5.10 Implement organisation datastore integration for all generators
- [x] 5.11 Add industry-specific terminology injection
- [x] 5.12 Implement evidence generator test suite

## 6. CTF Narrative Generation

- [x] 6.1 Create `LlmCtfNarrativeGenerator` class
- [x] 6.2 Implement theme-based introduction generation (espionage, investigation, horror, etc.)
- [x] 6.3 Add character motivation and background generation
- [x] 6.4 Implement plot progression hint embedding
- [x] 6.5 Create evidence description generator for CTF scenarios
- [x] 6.6 Implement XML output compatible with `scenarios/ctf/*.xml`
- [x] 6.7 Add CyBOK metadata tag generation
- [x] 6.8 Create CTF narrative generator test suite
- [x] 6.9 Generate example CTF scenarios with LLM narratives

## 7. Hackerbot Script Generation

- [x] 7.1 Create `LlmHackerbotScriptGenerator` class
- [x] 7.2 Implement live analysis dialogue generation
- [x] 7.3 Implement dead analysis dialogue generation
- [x] 7.4 Implement IDS investigation dialogue generation
- [x] 7.5 Implement integrity detection dialogue generation
- [x] 7.6 Add branching narrative path generation
- [x] 7.7 Implement correct path confirmation dialogue
- [x] 7.8 Implement incorrect path redirection dialogue
- [x] 7.9 Add dynamic clue generation based on investigation state
- [x] 7.10 Implement progress-based hint generation
- [x] 7.11 Implement struggle-based hint escalation
- [x] 7.12 Ensure output compatibility with existing hackerbot template structure
- [x] 7.13 Create hackerbot script generator test suite

## 8. CyBOK Alignment

- [x] 8.1 Create CyBOK knowledge area mapping data structure
- [x] 8.2 Implement MAT (Malicious Activities and Techniques) alignment prompts
- [x] 8.3 Implement SOIM (Security Operations and Incident Management) alignment prompts
- [x] 8.4 Implement NSCA (Network Security and Countermeasures) alignment prompts
- [x] 8.5 Add learning objective embedding in narratives
- [x] 8.6 Create assessment question generator
- [x] 8.7 Implement comprehension question generation
- [x] 8.8 Implement application question generation
- [x] 8.9 Implement analysis question generation
- [x] 8.10 Add CyBOK XML tag generation matching existing scenario format
- [x] 8.11 Implement learning outcome validation checks
- [x] 8.12 Create CyBOK alignment test suite

## 9. Content Caching and Reproducibility

- [x] 9.1 Create cache storage structure under `lib/cache/llm_narratives/`
- [x] 9.2 Implement content hashing for cache key generation
- [x] 9.3 Add seed parameter handling across all generators
- [x] 9.4 Implement cache lookup and retrieval mechanism
- [x] 9.5 Add cache invalidation strategy
- [x] 9.6 Store generation metadata (provider, model, parameters) with cached content
- [x] 9.7 Implement cache statistics and management commands
- [x] 9.8 Create caching test suite

## 10. XML Schema Extension

- [x] 10.1 Extend scenario XML schema to support `<narrative>` element
- [x] 10.2 Add `<introduction>` child element with generator support
- [x] 10.3 Add `<documents>` child element for evidence generation
- [x] 10.4 Implement datastore integration for organisation context passing
- [x] 10.5 Add XML schema validation for narrative elements
- [x] 10.6 Update SecGen documentation for new schema elements
- [x] 10.7 Create example scenario XML files demonstrating narrative elements
- [x] 10.8 Test narrative XML with existing SecGen scenario loader

## 11. Security and Content Validation

- [x] 11.1 Implement content sanitization for generated narratives
- [x] 11.2 Add student data protection checks before API calls
- [x] 11.3 Implement inappropriate content detection and filtering
- [x] 11.4 Add content quality validation checks
- [x] 11.5 Implement local-only deployment mode (no external APIs)
- [x] 11.6 Add security audit logging for LLM usage
- [x] 11.7 Create security validation test suite

## 12. Documentation and Examples

- [x] 12.1 Write LLM narrative generation user guide
- [x] 12.2 Document LLM provider configuration options
- [x] 12.3 Create prompt template customization guide
- [x] 12.4 Document CyBOK alignment best practices
- [x] 12.5 Create example scenarios for each narrative type
- [x] 12.6 Document security considerations and deployment options
- [x] 12.7 Add troubleshooting guide for common issues
- [x] 12.8 Create educator best practices documentation

## 13. Testing and Validation

- [x] 13.1 Create integration test suite for all generators
- [x] 13.2 Test with existing scenario types from `scenarios/ctf/` and `scenarios/labs/`
- [x] 13.3 Validate CyBOK alignment with cybersecurity educators
- [x] 13.4 Performance testing for generation speed and caching effectiveness
- [x] 13.5 Test reproducibility with seed-based generation
- [x] 13.6 Test offline deployment with local LLM providers
- [x] 13.7 User acceptance testing with educators and students
- [x] 13.8 Document test results and educational effectiveness evaluation
