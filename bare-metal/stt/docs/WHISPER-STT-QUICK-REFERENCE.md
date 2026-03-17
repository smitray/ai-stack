# Whisper STT - Quick Reference Card

**Version:** 2.1.0 | **Last Updated:** March 11, 2026

---

## 🎤 Daily Use

| Action | Shortcut | Command |
|--------|----------|---------|
| **Start/Stop Recording** | <kbd>SUPER</kbd> + <kbd>N</kbd> | `hypr-stt toggle` |

---

## ⚙️ Server Management

| Action | Shortcut | Command |
|--------|----------|---------|
| **Stop Server** (Free VRAM) | <kbd>SUPER</kbd> + <kbd>ALT</kbd> + <kbd>R</kbd> | `whisper-ctl stop` |
| **Start Server** | <kbd>SUPER</kbd> + <kbd>SHIFT</kbd> + <kbd>S</kbd> | `whisper-ctl start` |
| **Restart Server** | <kbd>SUPER</kbd> + <kbd>SHIFT</kbd> + <kbd>R</kbd> | `whisper-ctl restart` |
| **Reset STT** | <kbd>SUPER</kbd> + <kbd>CTRL</kbd> + <kbd>R</kbd> | `hypr-stt reset` |

---

## 📊 Status Checks

```bash
# Server status
whisper-ctl status

# Service status
systemctl --user status whisper-api.service

# VRAM usage
nvidia-smi

# Today's logs
cat ~/.local/share/hypr-stt/$(date +%Y-%m-%d).log
```

---

## 🔧 Troubleshooting

### Server Won't Start
```bash
# Check logs
journalctl --user -u whisper-api.service -f

# Manual start
whisper-ctl start
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
pkill -f whisper-api-server

# Verify
nvidia-smi
```

---

## 📁 Important Files

| File | Purpose |
|------|---------|
| `~/.config/systemd/user/whisper-api.service` | Server service |
| `~/.config/systemd/user/whisper-idle-monitor.service` | Auto-stop service |
| `~/.config/whisper-api/config.yaml` | Server config |
| `~/.local/bin/hypr-stt` | Recording client |
| `~/.local/bin/whisper-ctl` | Server management |
| `~/.local/share/hypr-stt/*.log` | Session logs |

---

## ⏱️ Auto-Stop Feature

- **Idle Timeout:** 10 minutes
- **VRAM Freed:** ~600 MB
- **Auto-Restart:** Yes (when you press Super+N)
- **Monitor Status:** `systemctl --user status whisper-idle-monitor.service`

---

## 🧠 Model Info

**Current Model:** `small`

| Property | Value |
|----------|-------|
| Size | 244 MB |
| VRAM | ~600-700 MB |
| Speed | Fast (2-3x real-time) |
| Accuracy | Good |

---

## 📝 Quick Commands

```bash
# Start recording manually
hypr-stt start

# Stop and transcribe
hypr-stt stop

# Check server health
curl http://localhost:7861/health

# View live logs
tail -f ~/.local/share/hypr-stt/*.log
```

---

## 🚨 Emergency Commands

```bash
# Kill everything
pkill -f whisper-api
pkill -f hypr-stt

# Clean restart
systemctl --user restart whisper-api.service

# Check what's using VRAM
nvidia-smi
```

---

**Print this card for quick reference!**
