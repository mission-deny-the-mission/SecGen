# Add llama-swap Provider — Implementation Plan

## Objective

Add a dedicated `llama_swap` LLM provider that connects to the llama-swap proxy at `http://10.1.5.65:8080` or `https://llama-swap.harryslab.xyz`, using its OpenAI-compatible API with Bearer token authentication. Set it as the default provider in `llm_config.json`.

## Context

- llama-swap exposes OpenAI-compatible endpoints: `/v1/models` and `/v1/chat/completions`
- API key: `sk-zbMpoU5ykHkuJa9khgcAwDCsz7FB4I9YWr40qLoDJI`
- Endpoints: `http://10.1.5.65:8080` (HTTP) or `https://llama-swap.harryslab.xyz` (HTTPS)
- The base provider at `modules/generators/narrative_content/lib/llm_provider.rb:46-63` already handles SSL auto-detection via `uri.scheme`

## Implementation Plan

- [ ] **Task 1. Create `modules/generators/narrative_content/lib/llm_provider_llama_swap.rb`**

  New file. Follows the same pattern as `llm_provider_lmstudio.rb` (OpenAI-compatible) but with:
  - Default endpoint: `http://10.1.5.65:8080`
  - Default model: `default`
  - Sends `Authorization: Bearer <api_key>` header (like OpenAI provider does at `llm_provider_openai.rb:19`)
  - `available?` method: GET `/v1/models` with Bearer auth header, 5s timeout (follow `llm_provider_lmstudio.rb:35-44` pattern but add auth header)
  - `validate_config`: set default endpoint if missing, but do NOT require api_key (it's optional for local network, but should be sent if present)
  - `generate` method: POST to `/v1/chat/completions` with model, messages, temperature, max_tokens, stream=false, seed (if set). Include `Authorization` header if api_key is present.

  Reference files:
  - `modules/generators/narrative_content/lib/llm_provider_lmstudio.rb:1-54` (OpenAI-compatible protocol)
  - `modules/generators/narrative_content/lib/llm_provider_openai.rb:1-51` (Bearer token auth pattern)
  - `modules/generators/narrative_content/lib/llm_provider.rb:46-63` (base `http_post` method)

- [ ] **Task 2. Register `llama_swap` in `modules/generators/narrative_content/lib/llm_provider_config.rb`**

  Three changes to this file:
  1. Add `require_relative 'llm_provider_llama_swap'` after line 7
  2. Add `'llama_swap' => LlmProviderLlamaSwap` to the `PROVIDERS` hash at line 19
  3. Insert `'llama_swap'` into the auto-detection order at line 93, between `llama_cpp` and `openai`:
     `%w[ollama lm_studio llama_cpp llama_swap openai anthropic]`

- [ ] **Task 3. Update `llm_config.json`**

  Change the default provider and add the llama_swap section. The file at `llm_config.json:1-33` needs:
  - Line 2: Change `"provider": "ollama"` to `"provider": "llama_swap"`
  - Add new `llama_swap` section with endpoint, model, and api_key:
    ```json
    "llama_swap": {
      "endpoint": "http://10.1.5.65:8080",
      "model": "default",
      "api_key": "sk-zbMpoU5ykHkuJa9khgcAwDCsz7FB4I9YWr40qLoDJI"
    }
    ```

- [ ] **Task 4. Add unit tests in `spec/narrative_content/test_providers.rb`**

  Add after line 7: `require 'llm_provider_llama_swap'`
  Add new test methods inside `TestLlmProviders` class:
  - `test_llama_swap_default_config` — verify default endpoint is `http://10.1.5.65:8080`, model is `default`
  - `test_llama_swap_custom_config` — verify custom endpoint override (e.g. `https://llama-swap.harryslab.xyz`)
  - `test_llama_swap_with_api_key` — verify provider initializes with api_key and `available?` returns true when key is present
  - `test_llama_swap_provider_name` — verify `provider_name` returns `'llama_swap'`

- [ ] **Task 5. Run all tests**

  Execute: `cd /Users/harry/SecGen-narrative && ruby -Ilib -Imodules/generators/narrative_content/lib -e "Dir.glob('spec/narrative_content/test_*.rb').each { |f| require_relative f }" 2>&1`
  
  Expected: All 84+ tests pass with 0 failures, 0 errors.

## Verification Criteria

- [ ] `LlmProviderConfig.available_providers` includes `'llama_swap'`
- [ ] Provider constructs correct OpenAI-compatible API calls to `/v1/chat/completions`
- [ ] Bearer token `Authorization` header is sent when api_key is configured
- [ ] `available?` checks `/v1/models` endpoint with auth
- [ ] Both HTTP (`http://10.1.5.65:8080`) and HTTPS (`https://llama-swap.harryslab.xyz`) endpoints work
- [ ] Environment variable `SECGEN_LLM_PROVIDER=llama_swap` activates the provider
- [ ] Environment variable `SECGEN_LLM_LLAMA_SWAP_API_KEY` resolves the API key
- [ ] All existing tests continue to pass

## Potential Risks and Mitigations

1. **API key in config file committed to git**
   Mitigation: The `llm_config.json` should have the api_key, but `.gitignore` could exclude it. Alternatively, use environment variable `SECGEN_LLM_LLAMA_SWAP_API_KEY` instead.

2. **llama-swap unreachable during test runs**
   Mitigation: Unit tests mock/verify config only, not actual HTTP calls. The `available?` test just checks that api_key presence makes the provider report available (like OpenAI test pattern at `test_providers.rb:40`).

3. **HTTPS certificate for harryslab.xyz**
   Mitigation: Base provider at `llm_provider.rb:48` handles SSL via `uri.scheme` detection. Ruby's Net::HTTP validates certs automatically.

## Alternative Approaches

1. **Just point LM Studio provider at llama-swap**: Works (same API) but loses semantic clarity and can't have different defaults. Not recommended.
2. **Subclass LlmProviderLmstudio**: Saves ~20 lines but creates fragile coupling. Not recommended.
3. **Generic "openai_compatible" provider**: More flexible but less discoverable. Not recommended for a known service.
