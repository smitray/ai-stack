# Hyprland STT - Complete Keybindings Reference

## Quick Reference Card

| Keybinding | Action | Command | Use Case |
|------------|--------|---------|----------|
| <kbd>SUPER</kbd> + <kbd>N</kbd> | Toggle recording | `hypr-stt toggle` | **Most used** - Start/stop voice recording |
| <kbd>SUPER</kbd> + <kbd>ALT</kbd> + <kbd>R</kbd> | Stop server | `hypr-stt stop-server` | Free VRAM when not needed |
| <kbd>SUPER</kbd> + <kbd>SHIFT</kbd> + <kbd>S</kbd> | Start server | `hypr-stt start-server` | Manually start server |
| <kbd>SUPER</kbd> + <kbd>SHIFT</kbd> + <kbd>R</kbd> | Restart server | `hypr-stt restart-server` | Refresh server if stuck |
| <kbd>SUPER</kbd> + <kbd>CTRL</kbd> + <kbd>R</kbd> | Reset STT | `hypr-stt reset` | Clear recording state |

---

## Detailed Descriptions

### 🎤 <kbd>SUPER</kbd> + <kbd>N</kbd> - Toggle Voice Recording
**Most frequently used!**

- **First press**: Starts recording your microphone
- **Second press**: Stops recording and transcribes
- **Result**: Transcribed text appears where your cursor is

**What happens:**
1. Server auto-starts if not running
2. Records audio from default microphone
3. Sends to Whisper API for transcription
4. Types result into focused application

---

### 🛑 <kbd>SUPER</kbd> + <kbd>ALT</kbd> + <kbd>R</kbd> - Stop Server
**Use when you need VRAM back**

- Stops the Whisper API server
- Frees ~500MB of VRAM
- Idle monitor also stops

**When to use:**
- Before playing games
- Before running other GPU-intensive tasks
- When you won't use STT for a while

**Note:** Server auto-stops after 10 minutes of inactivity anyway!

---

### ▶️ <kbd>SUPER</kbd> + <kbd>SHIFT</kbd> + <kbd>S</kbd> - Start Server
**Manually start the server**

- Starts Whisper API server
- Loads model into VRAM (~500MB)
- Takes 5-10 seconds to be ready

**When to use:**
- If auto-start isn't working
- You want to pre-load before recording

---

### 🔄 <kbd>SUPER</kbd> + <kbd>SHIFT</kbd> + <kbd>R</kbd> - Restart Server
**Refresh the server**

- Stops then starts the server
- Useful if server is stuck or misbehaving

**When to use:**
- Server not responding
- After configuration changes
- If transcription fails repeatedly

---

### 🔄 <kbd>SUPER</kbd> + <kbd>CTRL</kbd> + <kbd>R</kbd> - Reset STT State
**Clear recording state**

- Resets internal state machine
- Clears any stuck recording state

**When to use:**
- Recording indicator stuck
- State out of sync
- After errors

---

## Manual Commands

All keybindings execute these commands:

```bash
# Toggle recording (SUPER + N)
~/.local/bin/hypr-stt toggle

# Stop server (SUPER + ALT + R)
~/.local/bin/hypr-stt stop-server

# Start server (SUPER + SHIFT + S)
~/.local/bin/hypr-stt start-server

# Restart server (SUPER + SHIFT + R)
~/.local/bin/hypr-stt restart-server

# Reset state (SUPER + CTRL + R)
~/.local/bin/hypr-stt reset

# Check server status
~/.local/bin/whisper-ctl status

# Stop server (alternative)
~/.local/bin/whisper-ctl stop

# Start server (alternative)
~/.local/bin/whisper-ctl start
```

---

## Waybar Integration

The STT server shows in Waybar with status indicators:

- 🟢 **Green**: Server running and ready
- 🟡 **Yellow**: Server loading
- 🔴 **Red**: Server stopped
- ⚪ **Gray**: Server error

Click the indicator to toggle the server.

---

## Idle Auto-Stop

The server automatically stops after **10 minutes of inactivity**:

- Activity = successful transcription
- Timer resets each time you use STT
- Notification shown when stopping
- Frees VRAM automatically

**To disable auto-stop:**
```bash
systemctl --user disable --now whisper-idle-monitor.service
```

---

## Troubleshooting

### Server won't start
```bash
# Check logs
journalctl --user -u whisper-api.service -f

# Check if port is in use
lsof -i :7861

# Manual start
~/.local/bin/whisper-ctl start
```

### Recording not working
```bash
# List microphones
hypr-stt list-mics

# Select microphone
hypr-stt select-mic

# Check state
hypr-stt status
```

### Keybinding not working
```bash
# Reload Hyprland config
SUPER + SHIFT + C  # Or: hyprctl reload

# Check keybindings
hyprctl keybinds | grep -i stt
```

### VRAM not freed
```bash
# Check what's using VRAM
nvidia-smi

# Force stop server
pkill -f whisper-api-server

# Verify stopped
systemctl --user status whisper-api.service
```

---

## Configuration Files

| File | Purpose |
|------|---------|
| `~/.config/hypr/hyprland.conf` | Keybindings |
| `~/.local/bin/hypr-stt` | STT client script |
| `~/.local/bin/whisper-ctl` | Server management |
| `~/.config/systemd/user/whisper-api.service` | Server service |
| `~/.config/systemd/user/whisper-idle-monitor.service` | Auto-stop service |

---

## Tips

1. **Let auto-stop handle it** - Don't manually stop unless you need VRAM immediately
2. **First use takes longer** - Model loads on first use (~5-10 seconds)
3. **Use good microphone** - Better audio = better transcription
4. **Check VRAM** - `nvidia-smi` shows if server is running
5. **Logs are your friend** - `journalctl --user -u whisper-api.service -f`

---

## Quick Status Check

```bash
# Server status
whisper-ctl status

# VRAM usage
nvidia-smi

# Service status
systemctl --user status whisper-api.service
systemctl --user status whisper-idle-monitor.service
```
