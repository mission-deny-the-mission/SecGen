#!/usr/bin/env python3
"""Fake decision model + fake OpenAI-compatible LLM for the IRC end-to-end test (stdlib only).
Decision model: picks siem_what_is_siem when the message contains 'siem', else escalate.
LLM: always answers 'LLM-FALLBACK'. Every request is appended to FAKE_LOG."""
import json, os, sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

LOG = os.environ.get("FAKE_LOG", "/tmp/fakes.log")


class H(BaseHTTPRequestHandler):
    def log_message(self, *a): pass

    def _send(self, obj):
        b = json.dumps(obj).encode()
        self.send_response(200); self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(b))); self.end_headers(); self.wfile.write(b)

    def do_POST(self):
        body = json.loads(self.rfile.read(int(self.headers.get("Content-Length", 0))) or b"{}")
        with open(LOG, "a") as f: f.write(json.dumps({"path": self.path, "port": self.server.server_port}) + "\n")
        if self.path == "/v1/systemone":
            crit = body["questions"]["best_match"]["criteria"]
            msg = body["state"]["user_message"].lower()
            pick = "siem_what_is_siem" if "siem" in msg and "siem_what_is_siem" in crit else "escalate"
            probs = {k: (0.9 if k == pick else 0.1 / (len(crit) - 1)) for k in crit}
            return self._send({"answers": {"best_match": {"choice": pick, "probabilities": probs}}})
        if self.path.endswith("/chat/completions"):
            return self._send({"choices": [{"message": {"role": "assistant", "content": "LLM-FALLBACK"}}]})
        self.send_response(404); self.end_headers()


if __name__ == "__main__":
    srvs = [ThreadingHTTPServer(("127.0.0.1", p), H) for p in (18080, 18081)]
    import threading
    for s in srvs[1:]: threading.Thread(target=s.serve_forever, daemon=True).start()
    srvs[0].serve_forever()
