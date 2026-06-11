## 1. Intent Schema

- [x] 1.1 Choose the implementation location for scenario generation code using existing SecGen Ruby/module conventions.
- [x] 1.2 Define the structured scenario intent schema with required fields for name, type, platform, difficulty, vulnerability classes, learning outcomes, CyBOK alignment, flags, evidence, and seed.
- [x] 1.3 Implement an intent loader that accepts intent files and reports missing or unsupported fields with actionable errors.
- [x] 1.4 Implement deterministic normalization for scenario names, system names, module names, datastore keys, and output paths.
- [x] 1.5 Add unit tests for valid intent loading, missing required fields, unsupported values, and identifier normalization.

## 2. External Harness Integration

- [x] 2.1 Define the external harness adapter contract for plan, generate, validate, test, repair, report, and stop conditions.
- [x] 2.2 Verify OpenCode noninteractive invocation, model/provider configuration, staged workspace support, logs/transcripts, and CI suitability.
- [x] 2.3 Document why OpenCode is the first supported harness and why Pi, ForgeCode, and Forge ACP are deferred.
- [x] 2.4 Implement Docker/container isolation, staged file-write restrictions, retry limits, optional VM validation hooks, and approved validation/test command profiles around OpenCode.
- [x] 2.5 Add tests for harness phase transitions, retry stopping, rejected out-of-scope writes, rejected unapproved commands, and unsupported harness selection.

## 3. Template Catalog

- [x] 3.1 Define the approved vulnerable software template metadata format, including vulnerability class, platform support, parameters, required files, flags, and test expectations.
- [x] 3.2 Add initial approved templates for a small web-focused set such as SQL injection, XSS, broken access control, command injection, and path traversal.
- [x] 3.3 Implement template catalog loading and compatibility matching from scenario intent.
- [x] 3.4 Implement early failure when no approved template supports the requested intent.
- [x] 3.5 Add tests for template catalog loading, compatibility matching, and unapproved template rejection.

## 4. Vulnerable Module Generation

- [x] 4.1 Implement staged vulnerable module generation from selected templates.
- [x] 4.2 Generate SecGen-compatible module layout, Puppet entry point, supporting manifests, files/templates, and `secgen_metadata.xml`.
- [x] 4.3 Render template parameters for difficulty, flags, datastore inputs, credentials, routes, service ports, and evidence strings.
- [x] 4.4 Generate module test stubs or validation hooks that describe the expected vulnerable behavior and flag/evidence location.
- [x] 4.5 Add tests that verify generated module layout, metadata, rendered parameters, and test stubs.

## 5. Scenario Assembly

- [x] 5.1 Implement staged scenario XML generation from normalized intent and selected module outputs.
- [x] 5.2 Generate scenario metadata including name, author/source marker, description, type, difficulty, and CyBOK entries.
- [x] 5.3 Generate systems, bases, networks, vulnerabilities, services, utilities, generators, encoders, and datastore wiring required by the selected templates.
- [x] 5.4 Support optional attacker/support systems when the selected scenario pattern requires them.
- [x] 5.5 Generate a scenario documentation stub covering purpose, learning outcomes, systems, vulnerability classes, review status, and validation commands.
- [x] 5.6 Add tests for generated XML structure, generated module references, metadata, datastores, and optional support systems.

## 6. Validation, Repair, and Promotion Gates

- [x] 6.1 Implement structural validation for generated scenario XML, module directories, metadata files, required files, and template references.
- [x] 6.2 Implement repository convention validation for names, module paths, metadata attributes, input parameter names, and scenario placement.
- [x] 6.3 Require generated scenario/module test stubs or validation hooks before promotion.
- [x] 6.4 Produce a validation report listing passed checks, failed checks, warnings, artifact paths, promotion readiness, and machine-readable repair context.
- [x] 6.5 Feed validation/test failures back into the external harness repair loop until the artifacts pass or retry limits are reached.
- [x] 6.6 Add tests for valid output, malformed XML, missing metadata, unresolved references, missing tests, convention violations, and repair-context formatting.

## 7. Reproducibility

- [ ] 7.1 Create a generation manifest containing original intent, normalized intent, seed, selected templates, module names, generated paths, tool version, timestamp, harness/provider/model metadata, retry metadata, and output hashes.
- [ ] 7.2 Implement regeneration from manifest using the same templates and tool version.
- [ ] 7.3 Implement drift detection for changed templates, changed tool version, changed intent, manual edits, and output hash mismatches.
- [ ] 7.4 Track review and promotion status without overwriting original generation inputs.
- [ ] 7.5 Add harness trace summaries for prompts or prompt hashes, phase decisions, validation attempts, repair attempts, and final status.
- [ ] 7.6 Add tests for manifest creation, deterministic regeneration, matching hashes, drift reporting, review status updates, and harness trace metadata.

## 8. Documentation and Examples

- [ ] 8.1 Document the scenario intent format and supported vulnerability template metadata.
- [ ] 8.2 Document the staged external-harness generation, container validation, repair, review, optional VM validation, and promotion workflow.
- [ ] 8.3 Add an example intent file and expected generated artifact summary for a simple vulnerable web application scenario.
- [ ] 8.4 Document how optional LLM narrative content can enrich generated scenarios without being required for deterministic generation.
- [ ] 8.5 Document harness/provider selection guidance, including OpenCode, Pi, ForgeCode, local providers, Docker/VM isolation requirements, and deferral criteria.

## 9. End-to-End Verification

- [ ] 9.1 Add an end-to-end test that generates a staged scenario from an example intent through the selected external harness adapter.
- [ ] 9.2 Verify the generated staged scenario passes validation and produces a reproducibility manifest.
- [ ] 9.3 Verify regeneration from the manifest produces matching output hashes.
- [ ] 9.4 Verify a failing generated artifact is repaired by the external harness loop or reported after retry exhaustion.
- [ ] 9.5 Run the existing relevant test suite and document any tests that cannot be run locally.
