# Hackerbot 3 role-play characters

`hb3_roleplay_character` generates a chat-only bot that plays a person in the scenario: an employee of a
fictional company, a witness, a client, a lab tutor. It runs no attacks and holds no flags; add it next to the
scenario's Hackerbot (one generator per character). **A new character is data, not code.**

How it answers:
1. Instructor-written Q/A pairs in the character's voice, picked by the decision router (Clef), with the
   answer-fit check. Instant and exactly as written.
2. Anything else: the LLM, with a system prompt built from the persona, background facts and rules, plus the
   conversation so far, so it improvises in character and stays consistent.

## Character file (`characters/<name>.json`)

| Field | Required | Use |
|---|---|---|
| `nick` | yes | IRC nick (also the Pidgin buddy name): letters, digits, `_` `-`, max 16 |
| `persona` | yes | who they are, where they work, who the student is to them, personality, tone |
| `background` | | facts they know; the LLM is told never to contradict them |
| `rules` | | character-specific limits (e.g. never share credentials). Fixed rules are always added: stay in character, admit to being an AI if sincerely asked, no flags, quiz answers or challenge solutions, short chat replies |
| `facts` | | `{{key}}` placeholders used in any text. `{{main_user}}` is the scenario's first account |
| `pairs` | | `[{id, tier, q, a}]`. Tier `challenge_adjacent` marks refusals (skips the fit check) |
| `greeting`, `help`, `no_attacks`, `non_answer` | | stock chat messages (`no_attacks` answers `ready`, `next`, `list`...) |
| `display_name`, `role`, `organisation`, `summary` | | descriptive; shown in the generated XML comment |
| `max_context_length`, `max_tokens`, `temperature` | | defaults 12000 chars, 300, 0.7 |

Bundled: `nova_meridian_it_ops` (Dana Okafor, IT Operations Lead, for the integrity lab),
`harbourside_ransomware_witness` (Gwen Arthur, duty manager who found a ransom note; for an incident-response
scenario not yet written), `integrity_lab_tutor` (Sam, a lab tutor).

## In a scenario

```xml
<generator module_path=".*/hb3_roleplay_character">
  <input into="accounts"><datastore>accounts</datastore></input>
  <input into="character"><value>nova_meridian_it_ops</value></input>
</generator>
```

Other ways to give the character:
- `character_file`: a path to your own JSON file.
- Inputs only, no file (set `character` to empty): `nick`, `persona`, `greeting`, `facts_json`, `pairs_json`.
- A bundled character plus overrides: any of those inputs replaces that field.

List the nick in Pidgin's `buddies` input so the student sees it:
`<input into="buddies"><value>Dana</value><value>Hackerbot</value></input>`.

The generator stops the build on: a missing `nick` or `persona`, a bad nick, a `{{fact}}` that isn't defined,
or a pair without an id, q or a.

Example scenario: `scenarios/labs/response_and_investigation/1_integrity_protection_hackerbot3_nova_meridian.xml`.
