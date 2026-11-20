# Decision router: canned lab-help answers before the LLM

Hackerbot 3 answers a student's catch-all message in two steps:

1. A **decision model** (System One, `POST /v1/systemone`) picks the canned question that matches the student's
   message from the lab's list, or `escalate`.
2. Only if it is confident does the bot reply with the canned answer. Otherwise the message goes to the LLM exactly as
   before (RAG, chat history, personalities, VM context).

It sits **inside the existing fallback handler only**, after every deterministic handler (`hello`, `help`, `next`,
`goto N`, `answer ...`, `ready`, ...). Quizzes, flags, attack prompts and marking are untouched and must stay that way.

## Rules for the pairs (`pairs/labhelp_pairs.json`)

- Lab help only: concepts, tooling, troubleshooting, where to look. Answers may restate what the lab sheet says.
- No quiz answers, flags, attack prompts, `correct_answer` text or anything that gates a student. Challenge/flag
  requests get a pointer or a polite refusal (`tier: challenge_adjacent`), never the solution.
- Each pair has `labs`: the lab ids it applies to. The bot offers only its own lab's pairs, which also keeps the
  option list short.
- The current set is a **synthetic draft** (58 pairs: 42 `hb2_siem`, 20 `hb2_integrity_protection`, 4 shared). It
  needs review of wording before real use. `hb2_live_analysis` and `hb2_ids_exfiltration` have no pairs yet.

## Turning it on

Per bot, in the bot XML (see `config/example_decision_router.xml.example`):

```xml
<decision_router>
  <enabled>true</enabled>
  <lab>hb2_siem</lab>
  <!-- optional: <threshold>0.5</threshold> <strategy>twopass</strategy> <shortlist_k>8</shortlist_k> <pairs_file>...</pairs_file> -->
</decision_router>
```

Servers and tuning come from the environment (e.g. `config/hb2.env`):

| Variable | Meaning |
|---|---|
| `HB3_DECISION_URL` | Decision model base URL (serves `/v1/systemone`). **Required**: without it the router stays off. |
| `HB3_DECISION_MODEL` | Model name for vLLM-style servers (llama.cpp ignores it) |
| `HB3_DECISION_THRESHOLD` | Top-option probability needed to serve a canned answer (default 0.5) |
| `HB3_DECISION_STRATEGY` | `full`, `shortlist` or `twopass` (default `twopass`; falls back to `full` with no embedder) |
| `HB3_DECISION_SHORTLIST_K` | Embedder shortlist size (default 8) |
| `HB3_EMBED_URL`, `HB3_EMBED_MODEL` | OpenAI-compatible embeddings server (e.g. Qwen3-Embedding-0.6B) |
| `HB3_DECISION_TIMEOUT` | Seconds per HTTP call (default 4) |
| `HB3_DECISION_LOG` | Optional JSONL decision log. **Stores student messages**: leave unset unless students have been told. |
| `HB3_DECISION_PAIRS` | Alternative pairs file |

No URL, no `<decision_router>` element, or `<enabled>false</enabled>` means the bot behaves like Hackerbot 2.

## Failure behaviour

Any error (timeout, bad JSON, server down) escalates to the LLM. After 5 consecutive failures the router skips the
decision model for 30 s. A dead embedder falls back to sending the whole list. The router can make the bot slower in
the worst case, never worse than the plain LLM fallback.

## Measured behaviour (synthetic data, so optimistic)

Clef-Flash 9B Q8 on 219 synthetic held-out messages (185 answerable) with this exact rule (top option, not `escalate`,
p >= T): T=0.5 gives 161 right, 11 bad canned answers (precision 93.6%, coverage 87.0%); T=0.8 gives 144 right, 2 bad
(precision 98.6%, coverage 77.8%). Raise the threshold if a wrong canned answer is worse than an LLM call. Embedder
top-8 then the full list on low confidence ("twopass") matched full-list accuracy at ~103 ms vs 167 ms on a DGX Spark.
No real student messages have been tested.

Reproduce from saved probabilities (no model needed): `ruby decision/eval/replay.rb <raw_lh_*.json> [threshold]`.

## Live check on the Spark layout (2026-10-09)

With the Spark suite up (embed 10.1.1.65:8002, Clef-Flash vLLM plugin 10.1.1.66:8001, fast 10.1.1.65:8000) and
`config/hb3.env.example` as the environment, `ruby decision/eval/live.rb <strategy> <threshold>` scores the 219
synthetic messages against the real servers, one student at a time:

| strategy | right | bad canned | precision | coverage | median | p95 |
|---|---|---|---|---|---|---|
| full | 159 | 11 | 93.5% | 85.9% | 200 ms | 203 ms |
| twopass (embedder top 8, then full list) | 161 | 11 | 93.6% | 87.0% | 99 ms | 301 ms |

(bad canned = wrong + false + leak.) The same weak spots as the 3090 runs remain, e.g. "write the rsyslog rule for sudo
for me" gets the how-to at p=0.9-0.97 instead of the deflection pair. `LIVE=1 bash decision/test/e2e/run_e2e.sh` runs
the real bot over IRC against these servers.

## Tests

- `ruby decision/test/test_decision_router.rb`: unit tests with fake HTTP (no network, no models).
- `bash decision/test/e2e/run_e2e.sh` (`LIVE=1` for the real Spark servers): the real bot over a real IRC server with fake decision and LLM servers.
  Checks that a matching question gets the canned answer, a joke goes to the LLM, and `answer 2` / `hello` never
  reach the decision model.

## Known issue carried over from Hackerbot 2

The fallback guard regex is unanchored and case-sensitive, so a message that merely contains `list`, `answer`, `help`,
`next` etc. ("how do I list boots", "is my answer right") is excluded from the fallback and gets no reply at all.
Not changed here; the router never sees those messages.
