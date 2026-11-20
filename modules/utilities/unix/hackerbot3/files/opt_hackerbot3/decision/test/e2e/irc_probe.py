#!/usr/bin/env python3
"""Join the bot's channel as a student, send messages, print what the bot replies. stdlib only."""
import socket, sys, time
host, port, chan = sys.argv[1], int(sys.argv[2]), sys.argv[3]
msgs = sys.argv[4:]
s = socket.create_connection((host, port)); s.settimeout(0.5)
def send(l): s.sendall((l + "\r\n").encode())
buf = ""
def drain(wait):
    global buf
    end = time.time() + wait; out = []
    while time.time() < end:
        try: d = s.recv(4096).decode(errors="replace")
        except socket.timeout: continue
        if not d: break
        buf += d
        while "\r\n" in buf:
            l, buf = buf.split("\r\n", 1)
            if l.startswith("PING"): send("PONG " + l.split(" ", 1)[1])
            elif "PRIVMSG" in l: out.append(l)
    return out
send("NICK student1"); send("USER student1 0 * :student1"); drain(1.5)
send("JOIN " + chan); drain(1.5)
for m in msgs:
    send(f"PRIVMSG {chan} :{m}")
    replies = drain(4)
    print(f"> {m}")
    for r in replies:
        print("  <", r.split("PRIVMSG", 1)[1].split(":", 1)[1] if ":" in r.split("PRIVMSG", 1)[1] else r)
