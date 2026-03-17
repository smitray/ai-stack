# Whisper STT - Issues Fixed

## Summary of Issues Fixed

### Issue 1: Super+Alt+R Not Working
**Problem:** The keybinding was configured but the commands weren't mapped in the script.

**Fix:** Added missing command mappings in `hypr-stt`:
- `stop-server` → `cmd_stop_server`
- `start-server` → `cmd_start_server`
- `restart-server` → `cmd_restart_server`
- `reset` → `cmd_reset`

---

### Issue 2: Server Not Auto-Starting on Super+N
**Problem:** When pressing Super+N, it showed "Server not ready. Run: whisper-ctl start"

**Fix:** Modified `start_recording()` function to auto-start the server if not running:
```bash
if ! server_ready; then
    start_server  # Auto-start via systemctl
fi
```

---

### Issue 3: Server/VRAM Not Properly Managed
**Problem:** Server was started directly (not via systemd), causing:
- systemd losing track of the process
- VRAM not being freed properly
- 704MB+ VRAM stuck even after "stopping"

**Fix:** Updated `start_server()` and `stop_server()` to use `systemctl --user`:
- Primary method: `systemctl --user start/stop whisper-api.service`
- Fallback: Direct process management (for non-systemd setups)

---

### Issue 4: HTTP 500 Transcription Errors
**Problem:** Server was running but systemd showed "inactive", causing API errors.

**Root Cause:** Mismatch between how the server was started (direct) vs stopped (systemctl).

**Fix:** Consistent use of systemctl for both start and stop operations.

---

## Current Status (All Working ✅)

| Feature | Status | Details |
|---------|--------|---------|
| Super+N Toggle | ✅ Working | Auto-starts server if needed |
| Super+Alt+R Stop | ✅ Working | Stops server, frees VRAM |
| Super+Shift+S Start | ✅ Working | Starts server via systemctl |
| Super+Shift+R Restart | ✅ Working | Restarts server cleanly |
| Super+Ctrl+R Reset | ✅ Working | Resets STT state |
| Auto-stop (10 min) | ✅ Working | Frees VRAM automatically |
| VRAM Management | ✅ Working | Properly freed on stop |
| Desktop Services | ✅ Safe | No cascade failures |

---

## Test Results

### Test 1: Super+N (First Use - Server Stopped)
```
Before: VRAM 18 MiB (server stopped)
Press: Super+N
Result: Server auto-starts, begins recording
After: VRAM ~700 MiB (server running)
```

### Test 2: Super+N (Stop Recording)
```
Press: Super+N (while recording)
Result: Stops recording, transcribes text
Text: "You" (or whatever was spoken)
Server: Still running
```

### Test 3: Super+Alt+R (Stop Server)
```
Press: Super+Alt+R
Result: Server stops
After: VRAM 18 MiB (freed!)
```

### Test 4: Idle Auto-Stop
```
Wait: 10 minutes without using STT
Result: Server auto-stops
VRAM: Freed automatically
```

---

## Files Modified

| File | Changes |
|------|---------|
| `~/.local/bin/hypr-stt` | - Added command mappings for stop-server, start-server, restart-server, reset<br>- Updated `start_server()` to use systemctl<br>- Updated `stop_server()` to use systemctl<br>- Modified `start_recording()` to auto-start server |
| `~/.config/systemd/user/whisper-api.service` | - Removed `Wants=graphical-session.target` (prevents cascade)<br>- Removed `RemainAfterExit=yes` |
| `~/.config/systemd/user/whisper-idle-monitor.service` | - Changed `BindsTo` to `PartOf` |
| `~/.config/whisper-api/whisper-idle-monitor.sh` | - Changed to use `pkill` instead of `systemctl stop` |
| `~/.config/whisper-api/whisper-cleanup.sh` | - Made more specific (kills only exact path match) |

---

## Quick Reference

### Start Server
- **Shortcut:** Super+Shift+S
- **Command:** `~/.local/bin/hypr-stt start-server`
- **Alternative:** `~/.local/bin/whisper-ctl start`

### Stop Server (Free VRAM)
- **Shortcut:** Super+Alt+R
- **Command:** `~/.local/bin/hypr-stt stop-server`
- **Alternative:** `~/.local/bin/whisper-ctl stop`

### Toggle Recording
- **Shortcut:** Super+N
- **Command:** `~/.local/bin/hypr-stt toggle`
- **Auto-starts server if needed**

### Check Status
```bash
# Server status
~/.local/bin/whisper-ctl status

# Service status
systemctl --user status whisper-api.service

# VRAM usage
nvidia-smi
```

---

## Troubleshooting

### Server Won't Start
```bash
# Check logs
journalctl --user -u whisper-api.service -f

# Manual start
systemctl --user start whisper-api.service

# Check if port is in use
lsof -i :7861
```

### VRAM Not Freed
```bash
# Force stop
pkill -f whisper-api-server

# Verify
nvidia-smi
```

### Keybinding Not Working
```bash
# Reload Hyprland
SUPER+Shift+C  # Or: hyprctl reload

# Check keybindings
hyprctl keybinds | grep -i stt
```

---

## Documentation Created

1. `~/.config/whisper-api/KEYBINDINGS.md` - Complete keybindings reference
2. `~/.config/whisper-api/README-idle-stop.md` - Idle auto-stop guide
3. `~/.config/whisper-api/FIXES.md` - This file (issues and fixes)
