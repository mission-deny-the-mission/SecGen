# Scenario intent & template metadata format

This documents the inputs to deterministic scenario generation: the **scenario
intent** (what you want generated) and the **approved template metadata** (the
catalogue of vulnerable-software building blocks). Values below are sourced from
`ScenarioGeneration::Intent` and `ScenarioGeneration::TemplateMetadata`.

## Scenario intent

An intent is a YAML or JSON file loaded via `Intent.load(path)`. Validation runs
in the constructor; any problem raises `IntentError` with all messages joined.

### Required fields

| Field | Meaning |
|-------|---------|
| `name` | Human title; drives the scenario slug, system, module, and datastore identifiers. |
| `scenario_type` | One of `ctf`, `attack_ctf`, `lab`, `security_audit`. |
| `target_platform` | One of `linux`, `debian`, `windows`, `web`. |
| `difficulty` | One of `easy`, `medium`, `hard`, `advanced`. |
| `vulnerability_classes` | Non-empty list; each must resolve to a supported class (see below). |
| `learning_outcomes` | Non-empty list of strings. |
| `cybok` | One or more `{ ka, topic, keywords[] }` entries (KA + topic required). |
| `flags` | Non-empty list of flag descriptions. |
| `evidence` | Non-empty list of evidence descriptions. |
| `seed` | Integer; makes the whole run reproducible. |

### Supported vulnerability classes

`sql_injection`, `xss`, `broken_access_control`, `command_injection`,
`path_traversal`, `insecure_file_upload`, `weak_authentication`,
`insecure_configuration`. Human spellings and aliases are normalised
(e.g. `SQL injection`/`sqli` → `sql_injection`, `idor` → `broken_access_control`,
`directory traversal` → `path_traversal`).

### Field-name aliases

`title`→`name`, `type`→`scenario_type`, `platform`→`target_platform`,
`vulnerabilities`→`vulnerability_classes`, `learning_objectives`→`learning_outcomes`,
`agent`/`agent_generation`→`harness`.

### Optional blocks

- `harness`: `{ name: opencode, isolation_mode: docker|host, retry_limit: <int> }`
  (defaults: `opencode`, `docker`, `3`). Only `opencode` is supported today.
- `narrative_generation`: optional LLM enrichment (see `llm-narrative.md`); never
  required for deterministic generation.

### Derived identifiers

From `name` (plus optional `system_name`/`module_name`/`datastore_prefix`
overrides) the intent derives: `scenario_slug`, `scenario_file` (`<slug>.xml`),
`system_name`, `module_name`, `module_path`
(`modules/vulnerabilities/generated/<module_name>`), and `datastore_prefix`.

## Approved template metadata

Each catalogue entry under
`modules/generators/narrative_content/scenario_generation/templates/` is a YAML
file loaded via `TemplateMetadata.load`. A template is rejected (and recorded in
the catalogue's `load_errors`, not fatal) unless **`approved: true`** and all
required fields are present.

### Required fields

`id`, `name`, `version`, `approved`, `vulnerability_class`,
`supported_platforms`, `difficulties`, `module`, `parameters`, `required_files`,
`flags`, `tests`.

- `module` requires `module_type`, `module_path`, `puppet_entry`,
  `metadata_path` (and may declare `requires:` dependency names).
- `tests` requires `exploit_expectation` and a non-empty `validation_hooks` list.

### Parameter `(type, target)` vocabulary

| `type` | `target` | Rendered as |
|--------|----------|-------------|
| `string` | `template_variable` | the parameter `default` |
| `enum` | `template_variable` | intent difficulty (when named `difficulty`) else first value |
| `datastore` | `generator_input` | `<datastore_prefix>_<name>` |
| `flag` | `strings_to_leak` / `file_content` | deterministic `FLAG{…}` (seed-derived) |

Compatibility matching (section 3.3) selects, per requested vulnerability class,
an approved template whose `supported_platforms` includes the intent platform and
whose `difficulties` includes the intent difficulty. If none matches, generation
fails fast with `TemplateSelectionError` before any file is written.
