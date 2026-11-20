#!/usr/bin/env bash
# End-to-end: real BotManager + real Cinch over a real (tiny) IRC server, with FAKE decision/LLM servers.
# Needs ruby with ircinch nokogiri nori thwait kramdown httparty, and python3. No GPU, no models.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"; ROOT="$HERE/../../.."; W="$(mktemp -d)"
cp -r "$ROOT"/. "$W/bot" 2>/dev/null; rm -rf "$W/bot/config"/*.xml "$W/bot/.git"; cp "$HERE/config/e2e_bot.xml" "$W/bot/config/"
export FAKE_LOG="$W/fakes.log" IRC_HOST=127.0.0.1 IRC_PORT=6667 HB3_DECISION_URL=http://127.0.0.1:18081 HB3_DECISION_LOG="$W/decisions.jsonl"
export no_proxy=127.0.0.1 NO_PROXY=127.0.0.1
if [ "${LIVE:-0}" = 1 ]; then
  export HB3_DECISION_URL=http://10.1.1.66:8001 HB3_DECISION_MODEL=clef-flash HB3_EMBED_URL=http://10.1.1.65:8002 HB3_EMBED_MODEL=qwen3-embedding HB3_DECISION_STRATEGY=twopass
  LLM_URL=http://10.1.1.65:8000/v1; LLM_MODEL=qwen3.6-35b-a3b; export no_proxy='*' NO_PROXY='*'
  sed -i "/<strategy>full<\/strategy>/d; s#http://127.0.0.1:18080/v1#$LLM_URL#; s#fake-llm#$LLM_MODEL#" "$W/bot/config/e2e_bot.xml"; P1=
else LLM_URL=http://127.0.0.1:18080/v1; LLM_MODEL=fake-llm
  python3 "$HERE/fakes.py" & P1=$!
fi
python3 "$ROOT/simple_irc_server.py" > "$W/irc.log" 2>&1 & P2=$!
export LLM_URL LLM_MODEL
sleep 1
( cd "$W/bot" && ruby -e '
  require "ircinch"; require "thwait"; require "./bot_manager.rb"
  bm = BotManager.new("127.0.0.1:6667".split(":").first, "openai", "x", 1, ENV["LLM_MODEL"], "none", ENV["LLM_URL"], "localhost", 8000, "localhost", 30000, false, {enable_rag: false}, nil)
  bm.read_bots; bm.start_bots' > "$W/bot.log" 2>&1 ) & P3=$!
sleep 6
python3 "$HERE/irc_probe.py" 127.0.0.1 6667 '#E2EBot' "what is a siem" "what does kibana do" "can you write the rsyslog rule for me" "what is the capital of france" "answer 2" "hello"
echo "--- decision log"; cat "$W/decisions.jsonl" 2>/dev/null | cut -c1-220
echo "--- fake server hits"; sort "$W/fakes.log" | uniq -c
[ -n "$P1" ] && kill $P1 2>/dev/null; kill $P2 2>/dev/null; pkill -P $P3 2>/dev/null; kill $P3 2>/dev/null; pkill -f "[s]imple_irc_server" 2>/dev/null; sleep 0.5; echo "--- bot log tail"; tail -8 "$W/bot.log"; echo "workdir: $W"
