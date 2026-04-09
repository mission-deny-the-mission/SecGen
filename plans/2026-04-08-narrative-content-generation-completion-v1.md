# Narrative Content Generation — Completion Plan

## Objective

Complete the integration of LLM-powered narrative content generation into SecGen by connecting the already-built infrastructure (providers, generators, templates, caching) to the core scenario build pipeline, enabling generated narrative content to flow from scenario XML through to deployed VM files.

---

## Current State Summary

| Component | Status | Location |
|-----------|--------|----------|
| LLM Provider Infrastructure (5 providers) | Complete | `modules/generators/narrative_content/lib/` |
| Generator Modules (10 generators) | Complete | `modules/generators/narrative_content/llm_*/` |
| Prompt Templates (13 templates) | Complete | `modules/generators/narrative_content/prompts/` |
| XML Schema (`<narrative>` element) | Complete | `lib/schemas/scenario_schema.xsd:198-229` |
| Demo Scenarios (2) | Complete | `scenarios/ctf/llm_narrative_*.xml` |
| Configuration System | Complete | `llm_config.json`, `lib/llm_provider_config.rb` |
| Security (Sanitization, Audit, Caching) | Complete | `lib/llm_content_sanitizer.rb`, `lib/llm_audit_logger.rb`, `lib/llm_content_cache.rb` |
| Core Reader Integration (`<narrative>` processing) | **Not implemented** | `lib/readers/system_reader.rb` — no narrative handling |
| Puppet requirement bypass for generators | **Not implemented** | `lib/readers/module_reader.rb:95` — `require_puppet=true` causes crash |
| Puppet Content Deployment | **Not implemented** | No `.pp` files or utilities for narrative content |
| Scenario `<narrative>` → generator pipeline | **Not implemented** | `system_reader.rb:47` XPath doesn't include narrative children |
| Testing | **Not implemented** | No tests for narrative system |
| Documentation (main README) | **Not updated** | `README.md` has no narrative mention |

---

## Implementation Plan

### Phase 1: Unblock Generator Loading (Critical Path)

The generators cannot even be loaded by SecGen because `read_generators` passes `require_puppet=true`, and none of the narrative generators have `.pp` files or `manifests/` directories. This will cause an immediate crash at startup.

- [x] **Task 1.1.** Change `module_reader.rb:95` to pass `require_puppet=false` for generators. Generators produce output via `secgen_local/local.rb` scripts — they don't need Puppet manifests. This is consistent with how the system already works: the `local_calc_file` mechanism (`system.rb:323-353`) runs the Ruby script and captures output, independent of Puppet.

- [x] **Task 1.2.** Create minimal stub Puppet files for the non-narrative generator (`modules/generators/network/pcap/`) if it also lacks them, to ensure backward compatibility. Verify all existing generators under `modules/generators/` still load correctly after the change.

### Phase 2: Narrative Element Processing in System Reader

The `<narrative>` element is defined in the XSD but `system_reader.rb` does not process it. Narrative elements sit at the scenario level (peer to `<system>`), and their child generators need to be resolved and executed during the build.

- [x] **Task 2.1.** Add narrative element parsing to `system_reader.rb:14-133`. After the existing CyBOK parsing (line 20-22), add an XPath for `/scenario/narrative` elements. For each narrative element:
  - Extract the `theme`, `cybok_ka`, and `cybok_topic` attributes
  - Parse `<introduction>` — if it contains a `<generator>`, create a module selector for it
  - Parse `<documents>` — for each `<document>`, if it contains a `<generator>`, create a module selector
  - Store narrative module selectors in a separate list (not tied to a specific system) since narratives are scenario-level

- [x] **Task 2.2.** Create a `NarrativeReader` class or extend `SystemReader` with a `read_narratives` method that returns an array of narrative configuration objects. Each object should contain: theme, CyBOK alignment, introduction generator selector (if any), and document generator selectors with their `type` and `name` attributes.

- [x] **Task 2.3.** Integrate narrative processing into `secgen.rb:103-128` (`build_config` method). After `SystemReader.read_scenario` returns systems, call the narrative reader. The narrative generators should be resolved via the same `resolve_module_selection` pipeline. Store the narrative content in `$datastore` under keys like `narrative_introduction`, `narrative_document_{name}`, etc.

- [x] **Task 2.4.** Ensure narrative-generated content flows into `$datastore` so that it can be consumed by downstream modules (vulnerabilities, utilities) via the existing `<input><datastore access="...">narrative_document_email_chain</datastore></input>` mechanism.

### Phase 3: Puppet Content Deployment Utilities

Generated narrative content needs to be placed onto VMs as files. The Vagrantfile template (`Vagrantfile.erb:348-378`) only provisions Puppet for `vulnerability`, `service`, `utility`, and `build` module types — generators are not provisioned. The content needs deployment utilities.

- [ ] **Task 3.1.** Create a Puppet utility module `modules/utilities/generators/narrative_deploy/` that accepts narrative content via Facter inputs and deploys it as files on the VM. This utility should:
  - Accept a `narrative_files` input (JSON array of `{path, content, permissions}` objects)
  - Create the specified files at the given paths with appropriate ownership/permissions
  - Support common deployment targets: `/var/log/` for logs, `/home/` for emails/memos, `/var/www/` for website content, `/opt/` for database records

- [ ] **Task 3.2.** Create specific deployment utility modules for each narrative content type:
  - `narrative_email_deploy` — places email files in `/var/mail/` or `/home/{user}/mail/`
  - `narrative_log_deploy` — appends to `/var/log/auth.log`, `/var/log/syslog`, etc.
  - `narrative_document_deploy` — places memos, reports as PDF/txt in appropriate directories
  - `narrative_website_deploy` — places content in web server document roots
  - These can be thin wrappers around the generic deploy utility with sensible defaults.

- [ ] **Task 3.3.** Update the Vagrantfile template (`lib/templates/Vagrantfile.erb`) to handle `generator` module types in the provisioning section (currently line 348 only handles `vulnerability`, `service`, `utility`, `build`). For generators that have Puppet files (the deployment utilities), provision them the same way as utilities.

- [ ] **Task 3.4.** Alternatively (or additionally), add a post-build narrative injection step in `project_files_creator.rb` that writes narrative content files into the project directory and uses a shared folder or `vm.provision 'shell'` to deploy them. This avoids needing Puppet for simple file placement.

### Phase 4: Scenario-to-VM Content Flow Integration

Connect all the pieces so that a scenario with `<narrative>` elements produces actual files on the built VMs.

- [ ] **Task 4.1.** Update the demo scenarios (`scenarios/ctf/llm_narrative_demo.xml`, `scenarios/ctf/llm_narrative_healthcare_breach.xml`) to include the deployment utilities. For example, add a `<utility type="narrative_email_deploy">` that reads from `$datastore['narrative_document_emails']` and deploys the email chain onto the target VM.

- [ ] **Task 4.2.** Implement the full pipeline integration test manually:
  1. Scenario XML defines `<narrative>` with email chain generator
  2. `system_reader.rb` parses the narrative and creates generator selectors
  3. `system.rb` resolves the generators (matches by type `llm_email_chain`)
  4. `system.rb:323-353` runs `secgen_local/local.rb` which calls the LLM
  5. Output is stored in `$datastore`
  6. A deployment utility reads from `$datastore` and the Vagrantfile provisions it
  7. The VM has the email files deployed

- [ ] **Task 4.3.** Add error handling for when no LLM provider is available. The `LlmProviderConfig` auto-detection should fail gracefully with a clear error message rather than a crash. Consider adding a `--no-narrative` CLI flag to skip narrative generation entirely and use empty/placeholder content.

### Phase 5: Testing

- [ ] **Task 5.1.** Create unit tests for the LLM provider layer:
  - Test each provider's `available?` method (mock HTTP responses)
  - Test `generate()` with mocked HTTP to verify correct API formatting for Ollama, OpenAI, Anthropic, llama.cpp, LM Studio
  - Test `LlmProviderConfig` resolution order and environment variable overrides
  - Test `LlmContentCache` key generation and cache hit/miss behavior

- [ ] **Task 5.2.** Create unit tests for the generator modules:
  - Test each generator's `build_prompt` method produces valid prompts
  - Test `parse_response` for each generator type
  - Test `LlmContentSanitizer` detects private keys, PII, refusals
  - Test `LlmPromptTemplate` variable substitution (simple, nested, each, if)

- [ ] **Task 5.3.** Create integration tests for the narrative pipeline:
  - Test `SystemReader.read_scenario` with a narrative-containing scenario XML
  - Test that narrative generator selectors are created correctly
  - Test that `$datastore` receives narrative content after module resolution
  - Test end-to-end with a mock LLM provider (returns canned responses)

- [ ] **Task 5.4.** Add tests to `spec/` using the project's existing test framework. Check `spec/` directory structure and follow existing patterns.

### Phase 6: Documentation and Polish

- [ ] **Task 6.1.** Update `README.md` with a section on LLM narrative generation: what it does, how to configure it, and how to use `<narrative>` elements in scenario XML.

- [ ] **Task 6.2.** Update `README-LLM-Narrative-Generation.md` to reflect the completed state, add troubleshooting guidance, and document the deployment utilities.

- [ ] **Task 6.3.** Add inline code comments to the new integration code in `system_reader.rb`, `secgen.rb`, and `project_files_creator.rb` explaining the narrative flow.

---

## Verification Criteria

- [ ] `bundle exec ruby secgen.rb --scenario scenarios/ctf/llm_narrative_demo.xml build-project` completes without error (with Ollama running)
- [ ] The built project directory contains narrative content in the datastore output
- [ ] `vagrant up` deploys narrative content files onto the VM
- [ ] Running without an LLM provider produces a clear error message (or graceful fallback with `--no-narrative`)
- [ ] All new tests pass
- [ ] Existing SecGen functionality is not broken (regression test with a non-narrative scenario)

---

## Potential Risks and Mitigations

1. **Generator Puppet requirement crash**
   - Risk: Changing `require_puppet=false` for all generators may break existing generators that do have Puppet files.
   - Mitigation: Audit all existing generators first. Only `modules/generators/network/pcap/` has a `.pp` file. The change is safe because `require_puppet` only controls validation at load time — modules with Puppet files still work fine without the check.

2. **LLM provider unavailability**
   - Risk: Scenarios fail to build if no LLM provider is running.
   - Mitigation: Implement a `--no-narrative` flag and/or static fallback content. The caching system (`llm_content_cache.rb`) already mitigates repeated calls.

3. **Narrative element scope ambiguity**
   - Risk: The `<narrative>` element is scenario-level (not system-level), but generators need to be resolved within the module selection pipeline which is system-scoped.
   - Mitigation: Process narratives as a separate pass after system resolution, storing results in `$datastore` for cross-system access.

4. **Content variability and quality**
   - Risk: LLM output is non-deterministic and may produce low-quality or inappropriate content.
   - Mitigation: The existing sanitization layer (`llm_content_sanitizer.rb`) handles this. The seed parameter enables reproducibility. Caching avoids regeneration.

5. **Performance impact**
   - Risk: LLM API calls during build add significant latency.
   - Mitigation: Caching prevents redundant calls. The system already supports local providers (Ollama, llama.cpp, LM Studio) for offline operation.

---

## Alternative Approaches

1. **Keep generators as scenario-level elements, deploy via shell provisioner**: Instead of creating Puppet utilities, inject narrative content directly via `vm.provision 'shell', inline: "..."` in the Vagrantfile. Simpler but less maintainable and doesn't integrate with Puppet's idempotency.

2. **Pre-generate narrative content as a separate step**: Add a `secgen generate-narratives` command that runs LLM generation and stores output in a cache file. Scenarios then reference cached content. This decouples LLM availability from the build process but adds workflow complexity.

3. **Treat narrative generators as encoders rather than generators**: The encoder module type already has the `local_calc_file` mechanism and doesn't require Puppet. This would require minimal infrastructure changes but is semantically incorrect (encoders transform existing data, generators create new data).

---

## Dependency Order

```
Phase 1 (unblock loading) → Phase 2 (narrative parsing) → Phase 3 (deployment) → Phase 4 (integration) → Phase 5 (testing) → Phase 6 (docs)
```

Phases 1 and 2 are the critical path. Phase 3 can proceed in parallel with Phase 2 once the design is agreed. Phase 5 should be developed alongside Phases 2-4.
