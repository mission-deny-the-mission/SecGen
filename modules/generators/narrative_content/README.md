# LLM Narrative Generation for SecGen

## Overview

The LLM Narrative Generation module extends SecGen with AI-powered narrative
content generation for cybersecurity training scenarios. It generates immersive,
contextually appropriate content including scenario introductions, email chains,
internal memos, chat logs, system logs, database records, website content,
CTF narratives, hackerbot investigation scripts, and CyBOK-aligned assessment
questions.

## Quick Start

### 1. Configure an LLM Provider

Edit `llm_config.json` in the SecGen root directory:

```json
{
  "provider": "ollama",
  "ollama": {
    "endpoint": "http://localhost:11434",
    "model": "llama3"
  }
}
```

Or use environment variables:

```bash
export SECGEN_LLM_PROVIDER=ollama
export SECGEN_LLM_MODEL=llama3
export SECGEN_LLM_ENDPOINT=http://localhost:11434
```

### 2. Use in a Scenario XML

```xml
<!-- Generate an organisation profile with LLM -->
<input into_datastore="organisation">
  <generator type="llm_organisation">
    <input into="industry">
      <value>Finance</value>
    </input>
    <input into="theme">
      <value>espionage</value>
    </input>
  </generator>
</input>

<!-- Generate an email chain -->
<input into_datastore="evidence_emails">
  <generator type="llm_email_chain">
    <input into="organisation">
      <datastore>organisation</datastore>
    </input>
    <input into="theme">
      <value>insider_threat</value>
    </input>
    <input into="num_emails">
      <value>5</value>
    </input>
  </generator>
</input>
```

### 3. Use the Narrative XML Element

```xml
<narrative theme="espionage" cybok_ka="MAT">
  <introduction>
    <generator type="llm_ctf_narrative">
      <input into="theme"><value>espionage</value></input>
    </generator>
  </introduction>
  <documents>
    <document type="email_chain" name="suspicious_emails">
      <generator type="llm_email_chain">
        <input into="theme"><value>insider_threat</value></input>
      </generator>
    </document>
  </documents>
</narrative>
```

## Supported LLM Providers

| Provider | Type | Configuration |
|----------|------|---------------|
| Ollama | Local | `endpoint` (default: `http://localhost:11434`) |
| LM Studio | Local | `endpoint` (default: `http://localhost:1234`) |
| llama.cpp | Local | `endpoint` (default: `http://localhost:8080`) |
| OpenAI | Cloud | `api_key` required, `endpoint` optional |
| Anthropic | Cloud | `api_key` required, `endpoint` optional |

### Provider Configuration

Configuration is resolved in order:
1. Environment variables (`SECGEN_LLM_*`)
2. `llm_config.json` in SecGen root
3. `~/.secgen/llm_config.json`

API keys for cloud providers can be set via:
- Config file: `"api_key": "sk-..."` under the provider section
- Environment: `SECGEN_LLM_OPENAI_API_KEY` or `SECGEN_LLM_ANTHROPIC_API_KEY`

### Local-Only Deployment

For environments where no data should leave the local system, use only local
providers (Ollama, LM Studio, llama.cpp). Set:

```json
{ "provider": "ollama" }
```

No external API calls will be made.

## Available Generators

| Generator | Type | Description |
|-----------|------|-------------|
| `llm_organisation` | Organisation profiles | Complete org with employees, industry context |
| `llm_email_chain` | Email conversations | Multi-message chains with investigation clues |
| `llm_memo` | Internal memos | Policy announcements, incident reports |
| `llm_chat_log` | Chat conversations | Team channel, DM, incident channel formats |
| `llm_log_entry` | System logs | Auth logs, system events, web access |
| `llm_database_record` | Database records | Customer data, transactions, audit trails |
| `llm_website_content` | Web pages | Company info, defaced pages, login portals |
| `llm_ctf_narrative` | CTF scenarios | Introductions, characters, evidence descriptions |
| `llm_hackerbot_script` | Investigation scripts | Interactive dialogues with hints |
| `llm_assessment` | Assessment questions | CyBOK-aligned comprehension/application/analysis |

## Common Parameters

All generators accept these parameters:

| Parameter | Description | Default |
|-----------|-------------|---------|
| `theme` | Narrative theme (espionage, investigation, insider_threat, etc.) | `investigation` |
| `seed` | Seed for reproducible generation | None |
| `llm_model` | Override the configured model | Config default |
| `organisation` | Organisation JSON from datastore | None |

## CyBOK Alignment

Generators can align content with CyBOK knowledge areas:

| Code | Knowledge Area |
|------|---------------|
| `MAT` | Malicious Activities and Techniques |
| `SOIM` | Security Operations and Incident Management |
| `NSCA` | Network Security and Countermeasures |
| `AAA` | Authentication, Authorisation, and Accountability |
| `CPS` | Cyber-Physical Systems Security |

Use `cybok_ka` and `cybok_topic` parameters to align generated content.

## Content Caching

Generated content is cached in `lib/cache/llm_narratives/` for:
- **Reproducibility**: Same seed + parameters = same output
- **Cost reduction**: Cached content avoids redundant API calls
- **Version control**: Cached content can be committed to the repository

Cache keys are derived from prompt content hash + generation parameters (model,
temperature, seed).

## Security Considerations

- **Student data protection**: Prompts are checked for student-identifiable
  information before being sent to any LLM provider
- **Content sanitization**: Generated content is sanitized to remove private
  keys, shell injection attempts, and other dangerous patterns
- **Quality validation**: Content is checked for common LLM failure modes
  (refusals, meta-commentary about being an AI)
- **Audit logging**: All LLM usage is logged to `logs/llm_audit.log`
- **Local deployment**: Use local providers to prevent any data from leaving
  the system

## Prompt Templates

Templates are stored in `modules/generators/narrative_content/prompts/` and use
Handlebars-style variable substitution:

- `{{variable}}` - Simple substitution
- `{{object.property}}` - Nested property access
- `{{#each array}}...{{/each}}` - Iteration
- `{{#if condition}}...{{/if}}` - Conditional blocks

### Customizing Templates

Place custom templates in the prompts directory. Existing templates can be
overridden by placing a file with the same name in a custom directory and
passing it via the `custom_dir` parameter.

## Troubleshooting

### Provider Connection Issues

- **Ollama not responding**: Ensure Ollama is running (`ollama serve`)
- **API key errors**: Check environment variables or config file
- **Timeout errors**: Increase `timeout` in config (default: 120 seconds)

### Content Quality Issues

- **Refusals**: Some prompts may trigger LLM safety filters; adjust the theme
- **Short responses**: Increase `max_tokens` in configuration
- **Inconsistent output**: Use a `seed` parameter for reproducibility

### Cache Issues

- **Stale content**: Delete specific cache files from `lib/cache/llm_narratives/`
- **Cache statistics**: Use `LlmContentCache.new.stats` to check cache size
