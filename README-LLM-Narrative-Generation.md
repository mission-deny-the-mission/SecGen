# Using LLMs for Narrative Content Generation in SecGen

This document describes the LLM-powered narrative content generation system integrated into SecGen. The system generates immersive, unique scenario content such as email chains, internal memos, chat logs, system logs, and organisation profiles, while maintaining educational alignment with CyBOK knowledge areas.

---

## Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Configuration](#configuration)
4. [Available Generators](#available-generators)
5. [Scenario XML Usage](#scenario-xml-usage)
6. [Deployment Utilities](#deployment-utilities)
7. [Demo Scenarios](#demo-scenarios)
8. [Testing](#testing)
9. [Implementation Considerations](#implementation-considerations)
10. [Scenarios with Existing Narrative Content](#scenarios-with-existing-narrative-content)

---

## Overview

SecGen's LLM narrative system generates unique, context-rich content for cybersecurity training scenarios. Each time a scenario is built, the LLM creates fresh narrative content that:

- Produces realistic organisation profiles with employees, managers, and domain info
- Creates email chains, memos, chat logs, and system logs with embedded evidence
- Aligns content with CyBOK knowledge areas for educational value
- Caches generated content for reproducibility
- Sanitises output to remove private keys, AI meta-commentary, and student data

The system supports both local LLM providers (Ollama, LM Studio, llama.cpp) for offline use and cloud providers (OpenAI, Anthropic) for higher quality output.

---

## Architecture

The implementation follows a Strategy + Template Method pattern:

```
Scenario XML (<narrative>)
    |
    v
SystemReader.read_narratives()  -->  NarrativeConfig objects
    |
    v
secgen.rb: resolve_narratives()  -->  System.select_modules()
    |
    v
LlmNarrativeGenerator.build_prompt()  -->  Prompt template rendering
    |
    v
LlmProvider.generate()  -->  LLM API call (or cache hit)
    |
    v
LlmContentSanitizer.sanitize()  -->  Content cleaning
    |
    v
$datastore['narrative_document_*']  -->  Puppet deployment utilities
```

### Key Components

| Component | Location | Purpose |
|-----------|----------|---------|
| LLM Provider abstraction | `modules/generators/narrative_content/lib/llm_provider*.rb` | 5 provider backends (Ollama, OpenAI, Anthropic, llama.cpp, LM Studio) |
| Provider config & auto-detection | `modules/generators/narrative_content/lib/llm_provider_config.rb` | Config resolution, env vars, auto-detection |
| Base narrative generator | `modules/generators/narrative_content/lib/llm_narrative_generator.rb` | Template method for prompt/parse/sanitize pipeline |
| Prompt template engine | `modules/generators/narrative_content/lib/llm_prompt_template.rb` | Handlebars-style templating |
| Content caching | `modules/generators/narrative_content/lib/llm_content_cache.rb` | SHA256-based cache for reproducibility |
| Content sanitization | `modules/generators/narrative_content/lib/llm_content_sanitizer.rb` | Removes private keys, AI commentary, student data |
| CyBOK alignment | `modules/generators/narrative_content/lib/llm_cybok.rb` | Maps knowledge areas to learning objectives |
| Audit logging | `modules/generators/narrative_content/lib/llm_audit_logger.rb` | Logs all LLM API calls |
| NarrativeConfig object | `lib/objects/narrative_config.rb` | Parsed narrative XML configuration |
| Narrative parser | `lib/readers/system_reader.rb` | Parses `<narrative>` elements from scenario XML |
| Narrative resolver | `secgen.rb:resolve_narratives()` | Resolves generators through module selection pipeline |

---

## How to Use LLMs for Narrative Generation
## Configuration

### Configuration File (`llm_config.json`)

```json
{
  "provider": "ollama",
  "temperature": 0.7,
  "max_tokens": 2048,
  "seed": null,
  "timeout": 120,
  "ollama": { "endpoint": "http://localhost:11434", "model": "llama3" },
  "openai": { "endpoint": "https://api.openai.com", "model": "gpt-4o-mini", "api_key": null },
  "anthropic": { "endpoint": "https://api.anthropic.com", "model": "claude-3-haiku-20240307", "api_key": null },
  "llama_cpp": { "endpoint": "http://localhost:8080" },
  "lm_studio": { "endpoint": "http://localhost:1234", "model": "local-model" }
}
```

### Environment Variables

| Variable | Description |
|----------|-------------|
| `SECGEN_LLM_PROVIDER` | Override provider selection |
| `SECGEN_LLM_MODEL` | Override model name |
| `SECGEN_LLM_ENDPOINT` | Override API endpoint |
| `SECGEN_LLM_TEMPERATURE` | Override temperature |
| `SECGEN_LLM_MAX_TOKENS` | Override max tokens |
| `SECGEN_LLM_SEED` | Set seed for reproducibility |
| `SECGEN_LLM_*_API_KEY` | API key for specific provider |

### Auto-Detection

If no provider is configured, auto-detection tries: `ollama -> lm_studio -> llama_cpp -> openai -> anthropic`

### Skipping Narrative Generation

Use `--no-narrative` to skip LLM generation when no provider is available:
```bash
ruby secgen.rb --scenario scenarios/ctf/llm_narrative_demo.xml --no-narrative run
```
---

## Scenarios with Existing Narrative Content

### Strong Narrative Scenarios (non-LLM)

| Scenario | Location | Narrative Elements |
|----------|----------|-------------------|
| **Agent Zero: Licence to Hack** | `scenarios/ctf/agent001.xml` | Secret agent storyline, "The Organization", operative "viper", cover businesses |
| **A Brief Case (of murder)** | `scenarios/ctf/brief_case.xml` | Murder mystery, detective Jones, missing persons report, drug dealing operation |
| **Fictional Organisation Security Audit** | `scenarios/security_audit/team_project.xml` | Company intranet, employee accounts, security audit remit, acceptable use policy |
| **Live Analysis Investigation** | `modules/generators/structured_content/hackerbot_config/live_analysis/` | Honeynet Project compromised server, hackerbot-guided investigation |

---

### CTF Scenarios with Narrative Elements (`scenarios/ctf/`)

| Scenario File | Theme |
|---------------|-------|
| `agent001.xml` | Espionage/secret agent |
| `agent_zero.xml` | Espionage/secret agent |
| `brief_case.xml` | Murder investigation |
| `catching_sparks.xml` | Investigation theme |
| `nosferatu.xml` | Horror/vampire theme |
| `post_it.xml` | Sticky note clues |
| `time_to_patch.xml` | Patch management story |
| `administration_woes.xml` | IT administration challenges |
| `disastrous_development.xml` | Development security failures |
| `hackme_crackme.xml` | Cracking challenge |
| `smash_crack_grab_run.xml` | Multi-stage CTF |

---

### Lab Scenarios with Narrative Potential (`scenarios/labs/`)

| Category | Scenarios |
|----------|-----------|
| **Cyber Security Landscape** | `3_phishing.xml` (social engineering), `4_encoding_encryption.xml` |
| **Forensics** | `trashed_evidence.xml` (evidence recovery) |
| **Software & Malware Analysis** | `1_dynamic_and_static_analysis.xml`, `11_coconut.xml`, malware investigation series |
| **Response & Investigation** | `7_live_analysis.xml`, `8_dead_analysis.xml`, incident response series |
| **Web Security** | `1_intro_web_security.xml` through `7_additional_web.xml` |
| **Systems Security** | Authentication, access controls, containers, AppArmor |

---

### Security Audit Scenarios (`scenarios/security_audit/`)

| Scenario | Description |
|----------|-------------|
| `team_project.xml` | Multi-VM fictional organisation with desktop, webserver, intranet |
| `wns_assessment_onlinestore.xml` | Online store security assessment |
| `authentication_access_control_vulns.xml` | Auth-focused audit |

---

## Available Generators

All 10 generator modules are in `modules/generators/narrative_content/`:

| Generator | Module Path | Content Type |
|-----------|-------------|-------------|
| Organisation profiles | `llm_organisation/` | JSON org data with employees, manager, domain |
| Email chains | `llm_email_chain/` | Multi-message email conversations |
| Internal memos | `llm_memo/` | Policy announcements, incident reports |
| Chat logs | `llm_chat_log/` | Team channel, DM, incident channel |
| System logs | `llm_log_entry/` | Auth logs, system events |
| Database records | `llm_database_record/` | Customer data, audit trails |
| Website content | `llm_website_content/` | Company pages, portals |
| CTF narratives | `llm_ctf_narrative/` | Full scenario introductions |
| Hackerbot scripts | `llm_hackerbot_script/` | Interactive investigation dialogues |
| Assessment questions | `llm_assessment/` | CyBOK-aligned questions |

13 prompt templates are in `modules/generators/narrative_content/prompts/`.

---

## Scenario XML Usage

### Narrative Element

The `<narrative>` element is a scenario-level element (peer of `<system>`) that defines LLM-generated content:

```xml
<scenario>
  <narrative theme="espionage" cybok_ka="MAT">
    <introduction>
      <generator type="llm_ctf_narrative">
        <input into="theme"><value>espionage</value></input>
        <input into="cybok_ka"><value>MAT</value></input>
      </generator>
    </introduction>
    <documents>
      <document type="email_chain" name="suspicious_emails">
        <generator type="llm_email_chain">
          <input into="theme"><value>insider_threat</value></input>
          <input into="num_emails"><value>5</value></input>
        </generator>
      </document>
    </documents>
  </narrative>

  <system>...</system>
</scenario>
```

Narrative content is stored in `$datastore` under keys like `narrative_introduction` and `narrative_document_{name}`. Any system in the scenario can access this content via `<datastore>narrative_document_suspicious_emails</datastore>`.

### System-Level Generators

LLM generators can also be used within `<system>` blocks like any other generator:

```xml
<system>
  <system_name>target_server</system_name>
  <input into_datastore="organisation">
    <generator type="llm_organisation">
      <input into="industry"><value>Finance</value></input>
      <input into="theme"><value>espionage</value></input>
    </generator>
  </input>
</system>
```

---

## Deployment Utilities

Generated content is deployed onto VMs using Puppet utility modules in `modules/utilities/unix/narrative/`:

| Utility | Default Deploy Path | Purpose |
|---------|-------------------|---------|
| `narrative_deploy` | Configurable | Generic file deployment |
| `narrative_email_deploy` | `/var/mail/` | Email content deployment |
| `narrative_log_deploy` | `/var/log/` | Log entry deployment |
| `narrative_document_deploy` | `/home/` | Document file deployment |
| `narrative_website_deploy` | `/var/www/` | Website content deployment |

Example usage in scenario XML:

```xml
<utility module_path=".*/narrative_email_deploy">
  <input into="file_content">
    <datastore>narrative_document_suspicious_emails</datastore>
  </input>
  <input into="filename">
    <value>suspicious_emails.mbox</value>
  </input>
</utility>
```

---

## Demo Scenarios

Two demo scenarios showcase the full narrative integration:

| Scenario | File | Difficulty | CyBOK |
|----------|------|-----------|-------|
| Corporate Espionage Investigation | `scenarios/ctf/llm_narrative_demo.xml` | Medium | MAT/SOIM |
| Healthcare Data Breach Investigation | `scenarios/ctf/llm_narrative_healthcare_breach.xml` | Hard | SOIM |

Both demonstrate the `<narrative>` XML element, LLM organisation generation, email/memo/log deployment, and multiple document types.

---

## Testing

84 tests with 369 assertions cover the full narrative system:

```bash
cd /path/to/SecGen
ruby -Ilib -Imodules/generators/narrative_content/lib -e "Dir.glob('spec/narrative_content/test_*.rb').each { |f| require_relative f }"
```

Test files are in `spec/narrative_content/`:
- `test_providers.rb` - Provider instantiation and configuration
- `test_provider_config.rb` - Config resolution and env var overrides
- `test_content_cache.rb` - Caching, invalidation, and stats
- `test_content_sanitizer.rb` - Sanitization and quality validation
- `test_prompt_template.rb` - Template rendering and validation
- `test_cybok.rb` - CyBOK alignment and coverage validation
- `test_end_to_end.rb` - Full pipeline integration with mock provider
- `test_narrative_parsing.rb` - Narrative XML parsing and NarrativeConfig

---

## Implementation Considerations

### Security
- Student data protection: prompts are checked for student emails/IDs before sending to LLM
- Content sanitization: removes accidentally generated private keys and shell injection
- Quality validation: detects LLM refusals and AI meta-commentary
- Audit logging: all LLM API calls logged with provider, model, prompt hash, duration
- Local-only mode: prioritizes local providers to prevent data from leaving the system

### Quality Control
- Content validation checks minimum/maximum length
- CyBOK alignment validation ensures coverage of target knowledge areas
- Seed-based reproducibility for deterministic output
- Caching reduces API costs and ensures consistent results

### Performance
- Content caching with SHA256-based keys avoids redundant LLM calls
- Local providers (Ollama, LM Studio) provide fast offline generation
- Graceful degradation when no LLM provider is available

---

## Scenarios with Existing Narrative Content
