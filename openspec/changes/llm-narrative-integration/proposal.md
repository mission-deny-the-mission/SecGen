## Why

SecGen scenarios lack immersive narrative content that enhances educational engagement and contextual learning. While SecGen has infrastructure for structured content generation (organisations, scenarios, generators), narratives are currently manual and limited. LLMs can extend this infrastructure to generate coherent, immersive narratives that improve the educational value of cybersecurity exercises.

## What Changes

- New LLM narrative generator module integrated into SecGen's generator framework
- Extended scenario XML schema with `<narrative>` element support
- New prompt template system for reusable narrative generation
- Datastore integration for passing organisation context between generators
- Support for multiple content types: email chains, memos, chat logs, incident reports, scenario introductions
- CyBOK-aligned narrative generation for learning outcome integration
- Local and API-based LLM provider support with caching for reproducibility

## Capabilities

### New Capabilities

- `llm-organisation-generation`: Generate complete organisation profiles with backstories, industry context, employee relationships, and security policies
- `llm-ctf-narratives`: Generate immersive CTF scenario descriptions, character backgrounds, plot progression, and evidence descriptions
- `llm-evidence-documents`: Generate realistic evidence content including email chains, internal memos, log entries, database records, website content, and chat logs
- `llm-hackerbot-scripts`: Generate interactive investigation dialogues with branching narrative paths, dynamic clues, and personalized hints
- `llm-cybok-alignment`: Generate narratives aligned with CyBOK knowledge areas with embedded learning objectives and assessment questions
- `llm-prompt-templates`: Reusable prompt template system for consistent narrative generation across content types
- `llm-provider-integration`: LLM provider abstraction supporting local models (Ollama, llama.cpp) and API-based providers (OpenAI, Anthropic) with caching

### Modified Capabilities

- None (this is a net-new capability set)

## Impact

- **New module**: `modules/generators/narrative_content/` with Ruby generator classes
- **Schema changes**: Extended scenario XML schema to support `<narrative>` elements
- **Existing integrations**: Datastore system extended to pass organisation context between generators
- **Configuration**: New LLM provider configuration in SecGen settings
- **Dependencies**: LLM client libraries (dependent on provider choice)
- **Content**: New prompt templates in `modules/generators/narrative_content/prompts/`
- **Existing scenarios**: Can be enhanced with LLM-generated narratives but remain backward compatible
