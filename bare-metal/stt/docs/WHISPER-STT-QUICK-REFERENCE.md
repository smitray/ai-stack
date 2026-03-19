# Whisper STT - Quick Reference Card

**Version:** 3.0.0 | **Last Updated:** March 19, 2026  
**Architecture:** FastAPI rewrite with Hugging Face model integration

---

## 🎤 Daily Use

| Action | Shortcut | Command |
|--------|----------|---------|
| **Start/Stop Recording** | <kbd>SUPER</kbd> + <kbd>N</kbd> | `hypr-stt toggle` |

---

## ⚙️ Server Management

| Action | Shortcut | Command |
|--------|----------|---------|
| **Start Server** | <kbd>SUPER</kbd> + <kbd>SHIFT</kbd> + <kbd>S</kbd> | `whisper-client start` |
| **Stop Server** (Free VRAM) | <kbd>SUPER</kbd> + <kbd>ALT</kbd> + <kbd>R</kbd> | `whisper-client stop` |
| **Restart Server** | <kbd>SUPER</kbd> + <kbd>SHIFT</kbd> + <kbd>R</kbd> | `systemctl --user restart whisper-server` |
| **Check Status** | <kbd>SUPER</kbd> + <kbd>ALT</kbd> + <kbd>S</kbd> | `whisper-client status` |

---

## 📊 Status Checks

```bash
# Server status (new unified CLI)
whisper-client status

# Service status
systemctl --user status whisper-server.service

# VRAM usage
whisper-client vram
# or
nvidia-smi --query-gpu=memory.used,memory.free --format=csv

# Health check
curl http://localhost:7861/health
```

---

## 🔧 Troubleshooting

### Server Won't Start
```bash
# Check logs
journalctl --user -u whisper-server.service -f

# Manual start
whisper-client start

# Check model download
hf cache ls | grep faster-whisper
```

### Recording Not Working
```bash
# List microphones
hypr-stt list-mics

# Select mic
hypr-stt select-mic
```

### Idle Monitor Not Running
```bash
# Check status
systemctl --user status whisper-idle-monitor.service

# Restart
systemctl --user restart whisper-idle-monitor.service
```

### VRAM Not Freed
```bash
# Force stop
systemctl --user stop whisper-server

# Verify VRAM freed
nvidia-smi
```

### Model Download Issues
```bash
# Check HF token
echo $HF_TOKEN

# Download model manually
hf download deepdml/faster-whisper-large-v3-turbo-ct2

# List cached models
hf cache ls
```

---

## 📁 Important Files

| File | Purpose |
|------|---------|
| `~/.config/systemd/user/whisper-server.service` | FastAPI server service |
| `~/.config/systemd/user/whisper-idle-monitor.service` | Auto-stop service |
| `~/.config/ai-stack/stt/config.yaml` | Server config |
| `~/.local/bin/whisper-client` | Unified server management CLI |
| `~/.local/bin/hypr-stt` | Recording client (unchanged) |
| `~/.local/share/ai-stack/stt/` | Python virtual environment |

---

## ⏱️ Auto-Stop Feature

- **Idle Timeout:** 10 minutes
- **VRAM Freed:** ~1.5-2 GB
- **Auto-Restart:** Yes (when you press Super+N)
- **Monitor Status:** `systemctl --user status whisper-idle-monitor.service`

---

## 🧠 Model Info

**Current Model:** `deepdml/faster-whisper-large-v3-turbo-ct2`

| Property | Value |
|----------|-------|
| Size | ~1.6 GB |
| VRAM | ~1.5-2 GB |
| Speed | Real-time to 2x (depends on CPU/GPU) |
| Accuracy | Excellent (large-v3-turbo) |
| Source | Hugging Face (auto-download via HF CLI) |

---

## 📝 Quick Commands

```bash
# Start recording manually
hypr-stt start

# Stop and transcribe
hypr-stt stop

# Check server health
curl http://localhost:7861/health

# Download model (if missing)
ai-stack models download deepdml/faster-whisper-large-v3-turbo-ct2

# View server logs
journalctl --user -u whisper-server.service -f
```

---

## 🚨 Emergency Commands

```bash
# Kill everything
pkill -f whisper_stt
pkill -f hypr-stt

# Clean restart
systemctl --user restart whisper-server.service

# Force free VRAM
ai-stack gpu off

# Check what's using VRAM
nvidia-smi
```

---

## 🚀 New Features (v3.0)

1. **FastAPI server** with OpenAI-compatible API
2. **Unified CLI** (`whisper-client`) replaces `whisper-ctl`
3. **Hugging Face integration** - models auto-download from HF
4. **Structured JSON logging** for better debugging
5. **Pydantic validation** for API requests/responses
6. **YAML config** with environment variable overrides

---

**Print this card for quick reference!**
