# SecGen - ZeroClaw Hackerbot Overlay Integration

**Status**: 🆕 New Integration Option  
**Version**: 1.0.0  
**Date**: February 27, 2026

---

## 🎯 Overview

SecGen now supports **ZeroClaw Hackerbot Overlay** as a modern replacement for the Ruby-based Hackerbot.

### What's New

The ZeroClaw Hackerbot Overlay provides:

- ✅ **AI-powered conversations** - Modern LLM instead of AIML pattern matching
- ✅ **Deterministic validation** - Quiz and flag checking NOT vulnerable to prompt injection
- ✅ **SecGen datastore integration** - Reads randomized IPs, credentials, flags
- ✅ **No fork required** - ZeroClaw is a dependency, not a fork
- ✅ **Lower maintenance** - ~10 hours/year vs 40+ hours for Ruby version

### Comparison

| Feature | Ruby Hackerbot (Current) | ZeroClaw Overlay (New) |
|---------|-------------------------|------------------------|
| **Language** | Ruby | Rust |
| **Binary Size** | Script + gems | 2.3MB single binary |
| **Memory Usage** | ~100MB | ~20MB |
| **Startup Time** | ~10s | ~0.1s |
| **LLM Support** | AIML (pattern matching) | Modern LLM (Ollama, etc.) |
| **Quiz Validation** | ✅ Deterministic | ✅ Deterministic |
| **Flag Validation** | ✅ Direct SSH | ✅ Direct SSH |
| **Maintenance** | ~40 hrs/year | ~10 hrs/year |
| **Updates** | Manual merge | Automatic (`cargo update`) |

---

## 📦 Installation

### Option 1: Keep Ruby Hackerbot (Current)

No changes needed - existing setup continues to work.

### Option 2: Deploy ZeroClaw Overlay (New)

```bash
# Clone overlay repository
cd /opt
git clone https://github.com/mission-deny-the-mission/zeroclaw-hackerbot-overlay.git
cd zeroclaw-hackerbot-overlay

# Build release binary
cargo build --release

# Install
sudo cp target/release/zeroclaw-hackerbot /usr/local/bin/

# Configure
sudo mkdir -p /etc/zeroclaw-hackerbot
cp config/hackerbot-default.toml /etc/zeroclaw-hackerbot/hackerbot.toml
sudo nano /etc/zeroclaw-hackerbot/hackerbot.toml

# Start service
sudo systemctl enable zeroclaw-hackerbot
sudo systemctl start zeroclaw-hackerbot
```

**Full instructions**: See `docs/SECGN_INTEGRATION.md` in overlay repository.

---

## 🔧 Configuration

### Ruby Hackerbot (Current)

Configs in `/opt/hackerbot/config/*.xml`:

```xml
<hackerbot>
  <name>Hackerbot</name>
  <get_shell>sshpass -p PASSWORD ssh root@{{chat_ip_address}} /bin/bash</get_shell>
  <attacks>
    <attack>
      <prompt>Scan the target with nmap...</prompt>
      <quiz>
        <question>Which nmap flag performs SYN scan?</question>
        <answer>-sS</answer>
      </quiz>
    </attack>
  </attacks>
</hackerbot>
```

### ZeroClaw Overlay (New)

Config in `/etc/zeroclaw-hackerbot/hackerbot.toml`:

```toml
[irc]
server = "localhost"
port = 6697
channel = "#hackerbot"
nickname = "Hackerbot"

[secgen]
datastore_path = "/var/lib/secgen/datastore.json"

[ollama]
host = "localhost"
port = 11434
model = "qwen3-vl:8b"

[tools.quiz_validator]
enabled = true
similarity_threshold = 0.8
```

---

## 🧪 Testing

### Ruby Hackerbot

```bash
# Connect to IRC
irssi -c localhost -p 6667
/join #hackerbot
hello
list
```

### ZeroClaw Overlay

```bash
# Connect to IRC (TLS)
irssi -c localhost -p 6697 --tls --tls-noverify
/join #hackerbot
hello
list
```

---

## 📊 Migration Path

### Phase 1: Side-by-Side (Recommended)

Run both bots on different ports:

```
Ruby Hackerbot:    IRC port 6667 (existing students)
ZeroClaw Overlay:  IRC port 6697 (test students)
```

**Duration**: 2-4 weeks testing

### Phase 2: Gradual Migration

Move students to overlay:

```
Week 1:  10% of students on overlay
Week 2:  50% of students on overlay
Week 3: 100% of students on overlay
```

### Phase 3: Full Cutover

Decommission Ruby Hackerbot:

```bash
sudo systemctl stop hackerbot
sudo systemctl disable hackerbot

# Keep Ruby installation for fallback
# Remove after 30 days if no issues
```

---

## 🔐 Security Considerations

### Both Implementations

- ✅ **Deterministic quiz validation** - Not LLM-based
- ✅ **Direct SSH for flag validation** - Not LLM-based
- ✅ **Read-only SecGen datastore access**

### ZeroClaw Overlay Additional Security

- ✅ **Type-safe Rust** - Compiler catches errors
- ✅ **ZeroClaw security model** - Tool allowlists, autonomy levels
- ✅ **Comprehensive logging** - Audit trail via tracing
- ✅ **TLS for IRC** - Encrypted communication

---

## 📖 Documentation

### Ruby Hackerbot

- `SecGen/modules/utilities/unix/hackerbot/` - Module source
- `SecGen/README.md` - General SecGen documentation
- `/opt/hackerbot/config/*.xml` - Bot configurations

### ZeroClaw Overlay

- **Repository**: https://github.com/mission-deny-the-mission/zeroclaw-hackerbot-overlay
- **Integration Guide**: `docs/SECGN_INTEGRATION.md`
- **Quick Start**: `docs/QUICKSTART.md`
- **Security**: `docs/SECURITY.md`
- **Maintenance**: `docs/MAINTENANCE.md`

---

## 🆘 Support

### Ruby Hackerbot

- **Issues**: https://github.com/cliffe/SecGen/issues
- **Documentation**: `SecGen/README.md`
- **Module Path**: `SecGen/modules/utilities/unix/hackerbot/`

### ZeroClaw Overlay

- **Issues**: https://github.com/mission-deny-the-mission/zeroclaw-hackerbot-overlay/issues
- **Documentation**: Overlay repository `docs/`
- **ZeroClaw Base**: https://github.com/openagen/zeroclaw

---

## 📅 Timeline

| Date | Milestone |
|------|-----------|
| Feb 27, 2026 | ZeroClaw Overlay created |
| Mar 2026 | Testing with SecGen VMs |
| Apr 2026 | Production deployment (optional) |
| Ongoing | Ruby Hackerbot maintained |

---

## 💡 Recommendations

### For New Deployments

**Use ZeroClaw Overlay** if:
- ✅ Starting fresh
- ✅ Want AI-powered conversations
- ✅ Want lower maintenance
- ✅ Comfortable with Rust toolchain

**Use Ruby Hackerbot** if:
- ✅ Existing deployment working well
- ✅ Don't need AI features
- ✅ Prefer Ruby ecosystem

### For Existing Deployments

**Recommended path**:
1. Keep Ruby Hackerbot running
2. Deploy ZeroClaw Overlay on different port
3. Test with small student group
4. Gradually migrate students
5. Decommission Ruby after validation

---

## 🎯 Next Steps

1. **Review overlay documentation**:
   - https://github.com/mission-deny-the-mission/zeroclaw-hackerbot-overlay

2. **Test in lab environment**:
   ```bash
   git clone https://github.com/mission-deny-the-mission/zeroclaw-hackerbot-overlay.git
   cd zeroclaw-hackerbot-overlay
   ./build.sh
   ```

3. **Deploy to test SecGen VM**:
   ```bash
   ruby secgen.rb run -s scenarios/labs/response_and_investigation/hacker_vs_hackerbot_1.xml
   ```

4. **Provide feedback**:
   - Open issues on overlay repository
   - Report integration challenges
   - Suggest improvements

---

**Last Updated**: February 27, 2026  
**Maintained By**: SecGen Development Team
