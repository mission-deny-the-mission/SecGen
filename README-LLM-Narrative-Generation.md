# Using LLMs for Narrative Content Generation in SecGen

This document outlines how Large Language Models (LLMs) can be integrated into SecGen to generate narrative content for cybersecurity lab VMs and CTF scenarios.

---

## Table of Contents

1. [Overview](#overview)
2. [How to Use LLMs for Narrative Generation](#how-to-use-llms-for-narrative-generation)
3. [Scenarios with Existing Narrative Content](#scenarios-with-existing-narrative-content)
4. [Recommended Integration Points](#recommended-integration-points)
5. [Example Implementation](#example-implementation)

---

## Overview

SecGen already has infrastructure for structured content generation including:
- Organisation data (`lib/resources/structured_content/organisations/`)
- Scenario XML definitions (`scenarios/`)
- Generator modules (`modules/generators/`)
- Hackerbot investigation templates (`modules/generators/structured_content/hackerbot_config/`)

LLMs can extend this infrastructure to generate immersive, coherent narratives that enhance the educational value of cybersecurity exercises.

---

## How to Use LLMs for Narrative Generation

### 1. Organisation/Fictional Company Generation

**Location:** `lib/resources/structured_content/organisations/`

LLMs can generate complete organisation profiles with:
- Company backstories and history
- Industry-specific context (healthcare, finance, education, etc.)
- Employee relationships and organisational dynamics
- Security policies and culture descriptions

**Example JSON structure enhancement:**
```json
{
  "business_name": "Northern Banking",
  "business_motto": "We'll keep your money safe!",
  "company_history": "Founded in 1805 in Huddersfield...",
  "recent_events": "Recently experienced a phishing campaign targeting...",
  "security_posture": "Basic security controls in place but...",
  "industry": "Finance",
  "manager": {...},
  "employees": [...]
}
```

---

### 2. CTF Challenge Narratives

**Location:** `scenarios/ctf/*.xml`

LLMs can generate immersive scenario descriptions including:
- Scenario introductions and context
- Character backgrounds and motivations
- Plot progression hints
- Evidence descriptions and document content

**Current example from `agent001.xml`:**
```xml
<description>
In this scenario, as a secret agent analyst specializing in cyber security, 
you are authorized to conduct offensive operations against those who threaten 
the digital safety and security of your country.

You have been tasked with conducting a penetration test and to investigate 
the operations of 'The Organization' in order to discover their evil plans...
</description>
```

---

### 3. Evidence & Document Generation

LLMs can create realistic content for:

| Content Type | Example Use |
|--------------|-------------|
| Email chains | Communication between suspicious employees |
| Internal memos | Policy announcements, incident reports |
| Log entries | System logs with narrative context |
| Database records | Customer data telling a story |
| Website content | Compromised organisation web presence |
| Chat logs | Slack/Teams conversations revealing evidence |

**Integration point:** Use datastores to pass organisation context:
```xml
<input into_datastore="organisation">
  <encoder type="line_selector">
    <input into="file_path">
      <value>lib/resources/structured_content/organisations/json_organisations</value>
    </input>
  </encoder>
</input>

<!-- Then use in vulnerability/service content -->
<vulnerability module_path=".*email_server">
  <input into="emails">
    <generator type="llm_email_generator">
      <input into="organisation">
        <datastore>organisation</datastore>
      </input>
      <input into="scenario_theme">
        <value>insider_threat</value>
      </input>
    </generator>
  </input>
</vulnerability>
```

---

### 4. Hackerbot/Chatbot Scripts

**Location:** `modules/generators/structured_content/hackerbot_config/`

LLMs can generate:
- Interactive investigation dialogues
- Branching narrative paths based on student actions
- Dynamic clues and feedback
- Personalised hints based on progress

**Template files:**
- `live_analysis/templates/live_investigation.md`
- `dead_analysis/templates/dead_investigation.md`
- `integrity_detection/templates/integrity.md`
- `ids/templates/IDS.md`

---

### 5. CyBOK-Aligned Learning Narratives

Scenarios are tagged with CyBOK (Cyber Security Body of Knowledge) metadata. LLMs can:
- Generate narratives aligned with specific CyBOK knowledge areas
- Create learning objectives embedded in storylines
- Produce assessment questions based on scenario events

**Example CyBOK tags from scenarios:**
```xml
<CyBOK KA="MAT" topic="Attacks and exploitation">
  <keyword>EXPLOITATION</keyword>
</CyBOK>
<CyBOK KA="SOIM" topic="PENETRATION TESTING">
  <keyword>PENETRATION TESTING - ACTIVE PENETRATION</keyword>
</CyBOK>
```

---

## Scenarios with Existing Narrative Content

### Strong Narrative Scenarios

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

## Recommended Integration Points

### 1. New Generator Module Structure

```
modules/generators/narrative_content/
├── llm_narrative_generator.rb
├── templates/
│   ├── email_chain.erb
│   ├── memo.erb
│   ├── chat_log.erb
│   ├── incident_report.erb
│   └── scenario_introduction.erb
└── secgen_metadata.xml
```

### 2. Extended Scenario XML Schema

Add `<narrative>` element support:
```xml
<scenario>
  <name>Example Scenario</name>
  <description>...</description>
  
  <!-- New narrative section -->
  <narrative>
    <introduction generator="llm_narrative_generator">
      <input into="theme">
        <value>insider_threat</value>
      </input>
      <input into="organisation">
        <datastore>organisation</datastore>
      </input>
    </introduction>
    
    <documents>
      <document type="email" generator="llm_email_generator">
        <input into="participants">
          <datastore>employees</datastore>
        </input>
      </document>
    </documents>
  </narrative>
  
  <system>...</system>
</scenario>
```

### 3. LLM Provider Integration

Options for LLM integration:
- **Local models** (Ollama, LM Studio, llama.cpp) for offline use
- **API-based** (OpenAI, Anthropic, etc.) for cloud generation
- **Hybrid** (cache generated content for reuse)

### 4. Prompt Template System

Create reusable prompt templates:
```
modules/generators/narrative_content/prompts/
├── scenario_introduction.txt
├── email_chain.txt
├── employee_background.txt
├── incident_timeline.txt
└── evidence_description.txt
```

---

## Example Implementation

### Creating an LLM-Generated Email Chain

```xml
<?xml version="1.0"?>
<scenario xmlns="http://www.github/cliffe/SecGen/scenario"
          xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">

  <name>Insider Threat Investigation</name>
  <description>Investigate a potential insider threat at a fictional organisation.</description>
  
  <system>
    <system_name>mail_server</system_name>
    <base distro="Debian 12" type="server"/>
    
    <!-- Generate organisation context -->
    <input into_datastore="organisation">
      <encoder type="line_selector">
        <input into="file_path">
          <value>lib/resources/structured_content/organisations/json_organisations</value>
        </input>
      </encoder>
    </input>
    
    <!-- Generate email chain narrative -->
    <utility module_path=".*/mail_server">
      <input into="emails">
        <generator type="llm_email_chain_generator">
          <input into="organisation">
            <datastore>organisation</datastore>
          </input>
          <input into="narrative_theme">
            <value>data_exfiltration</value>
          </input>
          <input into="participants">
            <datastore access_json="['employees']">organisation</datastore>
          </input>
          <input into="num_emails">
            <value>5</value>
          </input>
        </generator>
      </input>
    </utility>
    
    <network type="private_network"/>
  </system>
</scenario>
```

### Sample LLM Prompt Template

```
You are generating email content for a cybersecurity training scenario.

Organisation: {{organisation.business_name}}
Industry: {{organisation.industry}}
Theme: {{narrative_theme}}

Participants:
{{#each participants}}
- {{name}} ({{email_address}}) - {{job_title}}
{{/each}}

Generate {{num_emails}} emails that tell a coherent story related to {{narrative_theme}}.
Include subtle clues that students can discover during their investigation.

Format each email as:
From: <email>
To: <email>
Date: <timestamp>
Subject: <subject>

<email body>
```

---

## Implementation Considerations

### Security
- Never send real student data to external LLM APIs
- Use local models for sensitive deployments
- Sanitise all generated content before VM deployment

### Quality Control
- Implement validation for generated content
- Ensure CyBOK alignment is maintained
- Test narratives for educational effectiveness

### Performance
- Cache generated narratives for reuse
- Pre-generate common scenario types
- Use streaming for real-time generation where appropriate

### Reproducibility
- Seed LLM generation for deterministic output
- Store generation parameters with scenarios
- Version control generated content

---

## Next Steps

1. **Prototype** a simple LLM generator module
2. **Test** with existing scenario types
3. **Evaluate** educational effectiveness
4. **Document** best practices for narrative design
5. **Integrate** with CyBOK learning outcomes

---

## References

- CyBOK (Cyber Security Body of Knowledge): https://www.cybok.org/
- SecGen Documentation: `README.md`, `README-Creating-Scenarios.md`
- Existing narrative scenarios: `scenarios/ctf/`, `scenarios/security_audit/`
- Structured content: `lib/resources/structured_content/`
