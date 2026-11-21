# Hackerbot 3

Hackerbot 3 is Hackerbot 2 with a **canned-response decision router** in front of the LLM fallback.
When a student asks the bot a question, a small decision model (Clef-Flash on vLLM) scores it against
the lab's curated question/answer pairs (`decision/pairs/labhelp_pairs.json`). A confident match gets
the instructor-written answer in ~0.1–0.3 s; anything else (off-topic, "do it for me", unknown) goes
to the LLM exactly as in Hackerbot 2. Attacks, quizzes and flags are unchanged, so `hb2_*` bot
templates work as-is.

Upstream source: https://github.com/mission-deny-the-mission/hackerbot3 (this directory is a copy of it).

## Labs

| Scenario | Generator | Router lab id | Pairs |
|---|---|---|---|
| `scenarios/labs/response_and_investigation/9_siem_hackerbot3.xml` | `hb3_siem` | `hb2_siem` | 42 |
| `scenarios/labs/response_and_investigation/1_integrity_protection_hackerbot3.xml` | `hb3_integrity_protection` | `hb2_integrity_protection` | 20 |

The `hb3_*` generators render the matching `hb2_*` template and add a `<decision_router>` element
(see `lib/objects/local_hackerbot_config_generator.rb`, `decision_router_lab`). To make another
Hackerbot 2 lab into a Hackerbot 3 lab: add its pairs to `decision/pairs/labhelp_pairs.json`, copy
`hb3_siem` pointing at the new template and lab id, and copy the scenario switching
`.*/hackerbot2` → `.*/hackerbot3` and the generator.

## Build options

The LLM fallback still uses the `--hb2-*` options. The router adds:

```
ruby secgen.rb -s scenarios/labs/response_and_investigation/9_siem_hackerbot3.xml \
  --hb2-openai-base-url http://10.1.1.65:8000/v1 --hb2-llm-model qwen3.6-35b-a3b --hb2-openai-api-key none \
  --hb3-decision-url http://10.1.1.66:8001 --hb3-embed-url http://10.1.1.65:8002 run
```

(or `HB3_DECISION_URL`, `HB3_EMBED_URL`, ... in the environment). With no decision URL the router
is off and the bot behaves like Hackerbot 2. Puppet writes all of it to `/opt/hackerbot3/config/hb3.env`,
read by `hackerbot3.service`. Without an embedding URL use `--hb3-decision-strategy full`.

The hackerbot server VM needs a network path to the model servers (the Sparks); on an isolated lab
VLAN that means a route or proxy to them.

## Fixes over the Hackerbot 2 copy

- Attack results crashed the bot (`undefined method check_output_conditions for Cinch::Callback`):
  the helpers are now captured as method objects like the others, so conditions run and flags are awarded.
- Multi-alternative messages (`say_ready`, `next`, ...) were sent as a Ruby array string; one is now picked.
- `hb2_integrity_protection` attack 5 had no `<condition>`s, so the bot crashed when it did get a shell.
- `teaching_assistant_bot.xml` is shipped as `.example` so lab servers run only the lab's bot.

## Lab sheet

The bot server hosts the lab sheet on `http://<hackerbot_server>/` (port input, default 80), so
students open it from the lab desktop. The hackerbot_config generator renders it from the bot XML's
`<tutorial>` elements into the generator's `templates/labsheet.html.erb`, and assets come from
`files/www`. Upstream Hackerbot 2 dropped this in favour of externally hosted sheets; Hackerbot 3
keeps it, so a lab works offline.
