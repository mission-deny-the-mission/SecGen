## 1. Intent Schema

- [ ] 1.1 Choose the implementation location for scenario generation code using existing SecGen Ruby/module conventions.
- [ ] 1.2 Define the structured scenario intent schema with required fields for name, type, platform, difficulty, vulnerability classes, learning outcomes, CyBOK alignment, flags, evidence, and seed.
- [ ] 1.3 Implement an intent loader that accepts intent files and reports missing or unsupported fields with actionable errors.
- [ ] 1.4 Implement deterministic normalization for scenario names, system names, module names, datastore keys, and output paths.
- [ ] 1.5 Add unit tests for valid intent loading, missing required fields, unsupported values, and identifier normalization.

## 2. Template Catalog

- [ ] 2.1 Define the approved vulnerable software template metadata format, including vulnerability class, platform support, parameters, required files, flags, and test expectations.
- [ ] 2.2 Add initial approved templates for a small web-focused set such as SQL injection, XSS, broken access control, command injection, and path traversal.
- [ ] 2.3 Implement template catalog loading and compatibility matching from scenario intent.
- [ ] 2.4 Implement early failure when no approved template supports the requested intent.
- [ ] 2.5 Add tests for template catalog loading, compatibility matching, and unapproved template rejection.

## 3. Vulnerable Module Generation

- [ ] 3.1 Implement staged vulnerable module generation from selected templates.
- [ ] 3.2 Generate SecGen-compatible module layout, Puppet entry point, supporting manifests, files/templates, and `secgen_metadata.xml`.
- [ ] 3.3 Render template parameters for difficulty, flags, datastore inputs, credentials, routes, service ports, and evidence strings.
- [ ] 3.4 Generate module test stubs or validation hooks that describe the expected vulnerable behavior and flag/evidence location.
- [ ] 3.5 Add tests that verify generated module layout, metadata, rendered parameters, and test stubs.

## 4. Scenario Assembly

- [ ] 4.1 Implement staged scenario XML generation from normalized intent and selected module outputs.
- [ ] 4.2 Generate scenario metadata including name, author/source marker, description, type, difficulty, and CyBOK entries.
- [ ] 4.3 Generate systems, bases, networks, vulnerabilities, services, utilities, generators, encoders, and datastore wiring required by the selected templates.
- [ ] 4.4 Support optional attacker/support systems when the selected scenario pattern requires them.
- [ ] 4.5 Generate a scenario documentation stub covering purpose, learning outcomes, systems, vulnerability classes, review status, and validation commands.
- [ ] 4.6 Add tests for generated XML structure, generated module references, metadata, datastores, and optional support systems.

## 5. Validation and Promotion Gates

- [ ] 5.1 Implement structural validation for generated scenario XML, module directories, metadata files, required files, and template references.
- [ ] 5.2 Implement repository convention validation for names, module paths, metadata attributes, input parameter names, and scenario placement.
- [ ] 5.3 Require generated scenario/module test stubs or validation hooks before promotion.
- [ ] 5.4 Produce a validation report listing passed checks, failed checks, warnings, artifact paths, and promotion readiness.
- [ ] 5.5 Add tests for valid output, malformed XML, missing metadata, unresolved references, missing tests, and convention violations.

## 6. Reproducibility

- [ ] 6.1 Create a generation manifest containing original intent, normalized intent, seed, selected templates, module names, generated paths, tool version, timestamp, and output hashes.
- [ ] 6.2 Implement regeneration from manifest using the same templates and tool version.
- [ ] 6.3 Implement drift detection for changed templates, changed tool version, changed intent, manual edits, and output hash mismatches.
- [ ] 6.4 Track review and promotion status without overwriting original generation inputs.
- [ ] 6.5 Add tests for manifest creation, deterministic regeneration, matching hashes, drift reporting, and review status updates.

## 7. Documentation and Examples

- [ ] 7.1 Document the scenario intent format and supported vulnerability template metadata.
- [ ] 7.2 Document the staged generation, validation, review, and promotion workflow.
- [ ] 7.3 Add an example intent file and expected generated artifact summary for a simple vulnerable web application scenario.
- [ ] 7.4 Document how optional LLM narrative content can enrich generated scenarios without being required for deterministic generation.

## 8. End-to-End Verification

- [ ] 8.1 Add an end-to-end test that generates a staged scenario from an example intent.
- [ ] 8.2 Verify the generated staged scenario passes validation and produces a reproducibility manifest.
- [ ] 8.3 Verify regeneration from the manifest produces matching output hashes.
- [ ] 8.4 Run the existing relevant test suite and document any tests that cannot be run locally.
