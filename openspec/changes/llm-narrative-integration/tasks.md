## 1. Core Infrastructure Setup

- [ ] 1.1 Create `modules/generators/narrative_content/` directory structure
- [ ] 1.2 Create Ruby base class `LlmNarrativeGenerator` extending existing generator framework
- [ ] 1.3 Add LLM client library dependencies to Gemfile
- [ ] 1.4 Create configuration file structure for LLM provider settings
- [ ] 1.5 Add spec helper files for testing narrative generators

## 2. LLM Provider Integration

- [ ] 2.1 Implement provider abstraction interface with common methods (generate, validate, configure)
- [ ] 2.2 Implement Ollama provider with local endpoint support
- [ ] 2.3 Implement OpenAI provider with API key authentication
- [ ] 2.4 Implement Anthropic provider with API key authentication
- [ ] 2.5 Add llama.cpp provider for local model loading
- [ ] 2.6 Implement LM Studio provider for local endpoint
- [ ] 2.7 Add provider configuration loader and validator
- [ ] 2.8 Implement secure API key storage and retrieval

## 3. Prompt Template System

- [ ] 3.1 Create `modules/generators/narrative_content/prompts/` directory
- [ ] 3.2 Create Handlebars template loader and parser
- [ ] 3.3 Implement variable substitution for `{{organisation.*}}` patterns
- [ ] 3.4 Implement iteration support for `{{#each}}` blocks
- [ ] 3.5 Create `scenario_introduction.txt` template
- [ ] 3.6 Create `email_chain.txt` template
- [ ] 3.7 Create `employee_background.txt` template
- [ ] 3.8 Create `incident_timeline.txt` template
- [ ] 3.9 Create `evidence_description.txt` template
- [ ] 3.10 Implement template caching mechanism
- [ ] 3.11 Add template validation for syntax errors
- [ ] 3.12 Implement template override mechanism for customization

## 4. Organisation Generation

- [ ] 4.1 Create `LlmOrganisationGenerator` class
- [ ] 4.2 Implement industry-specific prompt templates (Finance, Healthcare, Education, etc.)
- [ ] 4.3 Add employee hierarchy generation with job titles and reporting structure
- [ ] 4.4 Implement security posture generation
- [ ] 4.5 Add seed-based reproducibility for organisation generation
- [ ] 4.6 Implement JSON output matching `lib/resources/structured_content/organisations/` schema
- [ ] 4.7 Add organisation generator test suite
- [ ] 4.8 Create example organisation generation scenarios

## 5. Evidence Document Generators

- [ ] 5.1 Create `LlmEmailChainGenerator` class
- [ ] 5.2 Implement email chain coherence across multiple messages
- [ ] 5.3 Add character voice consistency for multi-email chains
- [ ] 5.4 Implement investigation clue embedding in email content
- [ ] 5.5 Create `LlmMemoGenerator` class for policy and incident reports
- [ ] 5.6 Create `LlmChatLogGenerator` class for team and DM conversations
- [ ] 5.7 Create `LlmLogEntryGenerator` class for authentication and system logs
- [ ] 5.8 Create `LlmDatabaseRecordGenerator` class for customer data and transactions
- [ ] 5.9 Create `LlmWebsiteContentGenerator` class for compromised site content
- [ ] 5.10 Implement organisation datastore integration for all generators
- [ ] 5.11 Add industry-specific terminology injection
- [ ] 5.12 Implement evidence generator test suite

## 6. CTF Narrative Generation

- [ ] 6.1 Create `LlmCtfNarrativeGenerator` class
- [ ] 6.2 Implement theme-based introduction generation (espionage, investigation, horror, etc.)
- [ ] 6.3 Add character motivation and background generation
- [ ] 6.4 Implement plot progression hint embedding
- [ ] 6.5 Create evidence description generator for CTF scenarios
- [ ] 6.6 Implement XML output compatible with `scenarios/ctf/*.xml`
- [ ] 6.7 Add CyBOK metadata tag generation
- [ ] 6.8 Create CTF narrative generator test suite
- [ ] 6.9 Generate example CTF scenarios with LLM narratives

## 7. Hackerbot Script Generation

- [ ] 7.1 Create `LlmHackerbotScriptGenerator` class
- [ ] 7.2 Implement live analysis dialogue generation
- [ ] 7.3 Implement dead analysis dialogue generation
- [ ] 7.4 Implement IDS investigation dialogue generation
- [ ] 7.5 Implement integrity detection dialogue generation
- [ ] 7.6 Add branching narrative path generation
- [ ] 7.7 Implement correct path confirmation dialogue
- [ ] 7.8 Implement incorrect path redirection dialogue
- [ ] 7.9 Add dynamic clue generation based on investigation state
- [ ] 7.10 Implement progress-based hint generation
- [ ] 7.11 Implement struggle-based hint escalation
- [ ] 7.12 Ensure output compatibility with existing hackerbot template structure
- [ ] 7.13 Create hackerbot script generator test suite

## 8. CyBOK Alignment

- [ ] 8.1 Create CyBOK knowledge area mapping data structure
- [ ] 8.2 Implement MAT (Malicious Activities and Techniques) alignment prompts
- [ ] 8.3 Implement SOIM (Security Operations and Incident Management) alignment prompts
- [ ] 8.4 Implement NSCA (Network Security and Countermeasures) alignment prompts
- [ ] 8.5 Add learning objective embedding in narratives
- [ ] 8.6 Create assessment question generator
- [ ] 8.7 Implement comprehension question generation
- [ ] 8.8 Implement application question generation
- [ ] 8.9 Implement analysis question generation
- [ ] 8.10 Add CyBOK XML tag generation matching existing scenario format
- [ ] 8.11 Implement learning outcome validation checks
- [ ] 8.12 Create CyBOK alignment test suite

## 9. Content Caching and Reproducibility

- [ ] 9.1 Create cache storage structure under `lib/cache/llm_narratives/`
- [ ] 9.2 Implement content hashing for cache key generation
- [ ] 9.3 Add seed parameter handling across all generators
- [ ] 9.4 Implement cache lookup and retrieval mechanism
- [ ] 9.5 Add cache invalidation strategy
- [ ] 9.6 Store generation metadata (provider, model, parameters) with cached content
- [ ] 9.7 Implement cache statistics and management commands
- [ ] 9.8 Create caching test suite

## 10. XML Schema Extension

- [ ] 10.1 Extend scenario XML schema to support `<narrative>` element
- [ ] 10.2 Add `<introduction>` child element with generator support
- [ ] 10.3 Add `<documents>` child element for evidence generation
- [ ] 10.4 Implement datastore integration for organisation context passing
- [ ] 10.5 Add XML schema validation for narrative elements
- [ ] 10.6 Update SecGen documentation for new schema elements
- [ ] 10.7 Create example scenario XML files demonstrating narrative elements
- [ ] 10.8 Test narrative XML with existing SecGen scenario loader

## 11. Security and Content Validation

- [ ] 11.1 Implement content sanitization for generated narratives
- [ ] 11.2 Add student data protection checks before API calls
- [ ] 11.3 Implement inappropriate content detection and filtering
- [ ] 11.4 Add content quality validation checks
- [ ] 11.5 Implement local-only deployment mode (no external APIs)
- [ ] 11.6 Add security audit logging for LLM usage
- [ ] 11.7 Create security validation test suite

## 12. Documentation and Examples

- [ ] 12.1 Write LLM narrative generation user guide
- [ ] 12.2 Document LLM provider configuration options
- [ ] 12.3 Create prompt template customization guide
- [ ] 12.4 Document CyBOK alignment best practices
- [ ] 12.5 Create example scenarios for each narrative type
- [ ] 12.6 Document security considerations and deployment options
- [ ] 12.7 Add troubleshooting guide for common issues
- [ ] 12.8 Create educator best practices documentation

## 13. Testing and Validation

- [ ] 13.1 Create integration test suite for all generators
- [ ] 13.2 Test with existing scenario types from `scenarios/ctf/` and `scenarios/labs/`
- [ ] 13.3 Validate CyBOK alignment with cybersecurity educators
- [ ] 13.4 Performance testing for generation speed and caching effectiveness
- [ ] 13.5 Test reproducibility with seed-based generation
- [ ] 13.6 Test offline deployment with local LLM providers
- [ ] 13.7 User acceptance testing with educators and students
- [ ] 13.8 Document test results and educational effectiveness evaluation
