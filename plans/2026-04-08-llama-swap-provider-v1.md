# Add llama-swap Provider Support

## Objective

Add a dedicated `llama_swap` LLM provider that connects to the llama-swap proxy at `http://10.1.5.65:8080` (or `https://llama-swap.harryslab.xyz`), leveraging its OpenAI-compatible API. Also update `llm_config.json` to use it as the default provider.

## Implementation Plan

- [ ] Task 1. Create `llm_provider_llama_swap.rb` — a new provider class that extends `LlmProvider` and uses the OpenAI-compatible `/v1/chat/completions` endpoint (same protocol as LM Studio/OpenAI). Default endpoint: `http://10.1.5.65:8080`. Supports HTTPS via `https://llama-swap.harryslab.xyz`. Availability check: GET `/v1/models`.
- [ ] Task 2. Register `llama_swap` in `llm_provider_config.rb` — add the require, add to `PROVIDERS` hash, and add to the auto-detection order (before cloud providers, after local providers).
- [ ] Task 3. Update `llm_config.json` — set `provider` to `llama_swap`, add `llama_swap` section with both endpoint URLs (primary HTTP, alternate HTTPS) and a sensible default model.
- [ ] Task 4. Add unit tests for the new provider in `spec/narrative_content/test_providers.rb`.
- [ ] Task 5. Run all tests to verify nothing is broken.

## Verification Criteria

- [ ] `llama_swap` provider appears in `LlmProviderConfig.available_providers`
- [ ] Provider correctly constructs OpenAI-compatible API calls to `/v1/chat/completions`
- [ ] `available?` check hits `/v1/models` endpoint
- [ ] Both HTTP (`http://10.1.5.65:8080`) and HTTPS (`https://llama-swap.harryslab.xyz`) endpoints work (SSL auto-detected from URI scheme)
- [ ] Environment variable `SECGEN_LLM_PROVIDER=llama_swap` activates the provider
- [ ] All 84+ existing tests continue to pass
- [ ] New provider tests pass

## Potential Risks and Mitigations

1. **llama-swap may not be reachable during testing**
   Mitigation: Tests mock HTTP calls; availability check has timeout/rescue
2. **HTTPS certificate for harryslab.xyz**
   Mitigation: `http.use_ssl = (uri.scheme == 'https')` in base provider handles this; Ruby's Net::HTTP validates certs by default
3. **Model name must match what llama-swap has loaded**
   Mitigation: Config allows model override via env var or config file

## Alternative Approaches

1. **Just configure LM Studio provider to point at llama-swap**: Works since the API is compatible, but loses the semantic clarity of a named provider and doesn't allow different defaults (e.g., endpoint, model)
2. **Subclass LlmProviderLmstudio**: Minimal code but creates a fragile inheritance chain; better to have a clean standalone class
3. **Add a generic "openai_compatible" provider**: More flexible but less user-friendly than a named provider
