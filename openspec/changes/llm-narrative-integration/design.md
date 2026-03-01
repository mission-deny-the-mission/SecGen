## Context

SecGen generates cybersecurity training scenarios (CTFs, labs, security audits) with structured data but limited narrative content. Existing scenarios have basic narrative elements (e.g., agent001.xml espionage theme, brief_case.xml murder mystery), but these are manually crafted and not scalable.

Current infrastructure:
- Organisation data in `lib/resources/structured_content/organisations/`
- Scenario XML definitions in `scenarios/`
- Generator modules in `modules/generators/`
- Hackerbot templates in `modules/generators/structured_content/hackerbot_config/`

Constraints:
- Must support offline/local LLM deployment (Ollama, llama.cpp) for sensitive environments
- Generated content must be reproducible (seeded generation, version control)
- Must integrate with existing datastore system for context passing
- Must maintain CyBOK alignment for educational outcomes
- Cannot send real student data to external APIs

Stakeholders: SecGen developers, cybersecurity educators, students

## Goals / Non-Goals

**Goals:**
- Integrate LLM narrative generation into SecGen's existing generator framework
- Support multiple narrative content types (emails, memos, chat logs, scenario intros, hackerbot scripts)
- Enable organisation context propagation through datastores
- Provide reusable prompt template system
- Support both local and cloud LLM providers
- Maintain CyBOK alignment in generated learning narratives
- Ensure reproducibility through seeding and content caching

**Non-Goals:**
- Replacing existing manual narrative content in shipped scenarios
- Real-time LLM generation during student exercises (pre-generation only)
- Automatic quality validation of generated content (manual review required)
- Support for multimodal LLMs (text-only for initial implementation)

## Decisions

### 1. Generator Module Architecture
**Decision:** Create new `modules/generators/narrative_content/` with Ruby generator classes following existing generator patterns

**Rationale:** 
- Aligns with SecGen's existing module structure (e.g., `modules/generators/structured_content/`)
- Reuses existing generator invocation mechanism via XML `<generator>` elements
- Enables integration with datastore system for context passing

**Alternatives considered:**
- External microservice: Adds complexity, network dependencies, and deployment overhead
- Pre-generation script: Loses integration with scenario XML system and datastore context passing

### 2. LLM Provider Abstraction
**Decision:** Implement provider abstraction layer supporting both local (Ollama, llama.cpp) and API-based (OpenAI, Anthropic) providers

**Rationale:**
- Local models required for offline/sensitive deployments
- API providers offer higher quality for cloud-based generation
- Abstraction allows swapping providers without changing generator logic

**Alternatives considered:**
- Single provider only: Limits deployment options
- Complex multi-provider orchestration: Unnecessary for initial implementation

### 3. XML Schema Extension
**Decision:** Add `<narrative>` element support to scenario XML schema with `<introduction>` and `<documents>` children

**Rationale:**
- Keeps narrative content logically separated from system definition
- Aligns with existing XML structure patterns
- Enables declarative narrative generation in scenario definitions

**Alternatives considered:**
- Reuse existing `<description>` element: Loses distinction between static and generated content
- Separate narrative YAML files: Breaks single-file scenario portability

### 4. Content Caching Strategy
**Decision:** Cache generated narratives with seed-based reproducibility, storing generation parameters alongside content

**Rationale:**
- Ensures scenario reproducibility for grading and testing
- Reduces LLM API costs for repeated generation
- Enables version control of generated content

**Alternatives considered:**
- No caching (regenerate each time): Expensive, non-reproducible
- Full scenario snapshots: Harder to update individual elements

### 5. Prompt Template System
**Decision:** Store prompt templates in `modules/generators/narrative_content/prompts/` with Handlebars-style variable substitution

**Rationale:**
- Enables reuse across scenarios
- Separates prompt engineering from generator logic
- Allows educators to customize prompts without code changes

**Alternatives considered:**
- Hardcoded prompts: Inflexible, harder to maintain
- External prompt management service: Unnecessary complexity

## Risks / Trade-offs

| Risk | Impact | Mitigation |
|------|--------|------------|
| LLM generates inappropriate/harmful content | High | Manual review workflow, content sanitization, local model deployment option |
| Generated content lacks educational quality | Medium | CyBOK alignment validation, educator review process, test scenarios |
| Non-deterministic output affects grading | Medium | Seed-based generation, content caching, version-controlled generated assets |
| LLM API costs for cloud providers | Medium | Caching strategy, local model option, pre-generation workflow |
| Performance impact on scenario generation | Low | Async generation, pre-generation before deployment, streaming for large content |
| Dependency on external LLM libraries | Low | Provider abstraction layer, support multiple backends, local model option |

## Migration Plan

1. **Phase 1: Core Infrastructure** (Weeks 1-2)
   - Create `modules/generators/narrative_content/` directory structure
   - Implement LLM provider abstraction layer
   - Build prompt template system

2. **Phase 2: Generator Implementation** (Weeks 3-4)
   - Implement organisation generator
   - Implement evidence document generators (emails, memos, logs)
   - Implement scenario introduction generator

3. **Phase 3: Integration** (Weeks 5-6)
   - Extend scenario XML schema
   - Integrate with datastore system
   - Implement caching mechanism

4. **Phase 4: Enhancement** (Weeks 7-8)
   - Implement hackerbot script generator
   - Add CyBOK alignment features
   - Create documentation and examples

5. **Phase 5: Validation** (Weeks 9-10)
   - Test with existing scenario types
   - Evaluate educational effectiveness
   - Document best practices

**Rollback Strategy:** 
- New functionality is additive; existing scenarios remain unchanged
- LLM generation is opt-in via XML configuration
- Can disable LLM providers via configuration without affecting core SecGen

## Open Questions

1. Which LLM providers to prioritize for initial implementation? (Recommendation: Ollama for local, OpenAI for cloud)
2. What content sanitization checks are required before VM deployment?
3. Should generated content be committed to repository or generated at build time?
4. What validation rules ensure CyBOK alignment quality?
