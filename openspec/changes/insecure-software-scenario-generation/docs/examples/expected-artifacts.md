# Expected generated artifacts for `example-intent.yml`

Running `example-intent.yml` (SQL injection, `web` / `easy`, seed `20260611`)
through `GenerationPipeline#run` selects the `sql-injection-web-form` template and
stages the tree below. `<staging>` is the run's staging directory; the on-disk
identity (`vulnerable_web_app_lab`) is derived from the intent `name`.

```
<staging>/
├── intent.normalized.json                     # workspace scaffolding (not hashed)
├── opencode.policy.json                        # workspace scaffolding (not hashed)
├── manifest.json                               # reproducibility manifest
├── modules/vulnerabilities/generated/vulnerable_web_app_lab/
│   ├── secgen_metadata.xml                      # XSD-valid vulnerability metadata
│   ├── vulnerable_web_app_lab.pp                # entry point: `require vulnerable_web_app_lab`
│   ├── manifests/
│   │   ├── init.pp                              # class vulnerable_web_app_lab
│   │   ├── install.pp                           # class …::install
│   │   └── configure.pp                         # class …::configure (leaks the flag)
│   ├── templates/index.php.erb                  # intentionally vulnerable PHP
│   └── secgen_test/vulnerable_web_app_lab.rb    # acceptance test stub
├── scenarios/generated/vulnerable-web-app-lab.xml   # XSD-valid scenario
└── docs/vulnerable-web-app-lab.md               # scenario documentation stub
```

## Expected outcome

- `result['promotion_ready']` is **true** — the staged scenario passes structural,
  convention, and test-coverage validation.
- `manifest.json` contains non-empty `output_hashes` covering the module files,
  scenario, and doc (the absolute-path workspace scaffolding is excluded so a
  fresh-directory regeneration produces identical hashes).
- `scenarios/generated/vulnerable-web-app-lab.xml` validates against
  `lib/schemas/scenario_schema.xsd`; the module `secgen_metadata.xml` validates
  against `lib/schemas/vulnerability_metadata_schema.xsd`.
- The scenario wires the module's deterministic flag value
  (`FLAG{…}`, seed-derived) into a datastore consumed via
  `<input into="strings_to_leak">`.

## Reproducibility

`GenerationPipeline#regenerate(into:, manifest:)` re-runs the pipeline into a
fresh directory and reports `matches: true` when the recomputed `output_hashes`
equal the manifest's — i.e. the same intent + seed + templates reproduce the same
artifacts byte-for-byte.
