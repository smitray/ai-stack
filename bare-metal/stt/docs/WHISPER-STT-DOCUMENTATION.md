# Whisper STT - Complete Project Documentation

**Last Updated:** March 11, 2026  
**Version:** 2.1.0  
**Author:** debasmitr  

---

## Table of Contents

1. [Project Overview](#project-overview)
2. [File Structure](#file-structure)
3. [File Descriptions](#file-descriptions)
4. [Keybindings Reference](#keybindings-reference)
5. [Issues Fixed](#issues-fixed)
6. [Features](#features)
7. [Troubleshooting](#troubleshooting)

---

## Project Overview

This is a **local speech-to-text (STT) system** for Hyprland Wayland compositor using:
- **Faster-Whisper** - Optimized Whisper model inference
- **OpenAI-compatible API** - Local transcription service
- **Systemd integration** - Auto-start, auto-stop, idle monitoring
- **Hyprland keybindings** - Seamless voice recording workflow

**Primary Use Case:** Voice dictation and transcription directly into any application.

---

## File Structure

```
/home/debasmitr/
├── .config/
│   ├── systemd/user/
│   │   ├── whisper-api.service              # Main server systemd service
│   │   └── whisper-idle-monitor.service     # Auto-stop idle monitor
│   │
│   ├── whisper-api/
│   │   ├── config.yaml                      # Server configuration
│   │   ├── port                             # API port number
│   │   ├── whisper-cleanup.sh               # Cleanup script
│   │   ├── whisper-idle-monitor.sh          # Idle monitoring script
│   │   └── *.md                             # Documentation files
│   │
│   └── hypr/
│       └── keybindings.conf                 # Hyprland keybindings
│
└── .local/
    ├── bin/
    │   ├── hypr-stt                         # Main STT client
    │   ├── whisper-activity                 # Activity tracker
    │   ├── whisper-api-server               # API server entry point
    │   └── whisper-ctl                      # Server management CLI
    │
    └── share/
        └── hypr-stt/                        # Session logs
            └── YYYY-MM-DD.log
```

---

## File Descriptions

### Systemd Services

#### `~/.config/systemd/user/whisper-api.service`
**Purpose:** Manages the Whisper API server lifecycle

**What it does:**
- Starts the Whisper transcription server on boot or manual request
- Loads the AI model into GPU memory
- Provides automatic restart on failure
- Triggers idle monitor after server is ready

**Key Features:**
- Auto-starts idle monitor 10 seconds after server starts
- Restarts on failure (prevents permanent downtime)
- 10-minute startup timeout (allows model download on first use)

---

#### `~/.config/systemd/user/whisper-idle-monitor.service`
**Purpose:** Automatically stops server after 10 minutes of inactivity

**What it does:**
- Monitors API usage in real-time
- Tracks time since last transcription
- Stops server after 10 minutes idle (frees VRAM)
- Exits cleanly when server stops

**Key Features:**
- Waits for server to be ready before monitoring
- Survives server restarts
- Prevents VRAM waste when not in use

---

### Configuration Files

#### `~/.config/whisper-api/config.yaml`
**Purpose:** Main server configuration

**Contains:**
- Server settings (host, port)
- Model selection (currently: `small`)
- Device configuration (CUDA/GPU)
- Compute type (float16 for speed)

**Current Settings:**
- Model: `small` (244MB, ~600MB VRAM)
- Port: `7861`
- Device: `cuda`
- Compute: `float16`

---

#### `~/.config/whisper-api/port`
**Purpose:** Stores the API port number

**Contains:** Single line with port number (7861)

---

### Scripts

#### `~/.local/bin/hypr-stt`
**Purpose:** Main user-facing STT client (triggered by Super+N)

**What it does:**
- Toggles voice recording on/off
- Auto-starts server if not running
- Records audio from microphone
- Sends to Whisper API for transcription
- Types result into focused application

**Key Features:**
- **Auto-start:** Server starts automatically if stopped
- **Readiness check:** Waits for model to fully load before recording
- **Minimal notifications:** Only shows essential info
- **Logging:** All actions logged to `~/.local/share/hypr-stt/`

**Recording Flow:**
1. Press Super+N
2. Check if server ready → Auto-start if not
3. Wait for model loaded + runtime files verified
4. Show "Ready to record" notification
5. Start audio capture
6. Press Super+N again
7. Show "Processing..." notification
8. Transcribe and type text (silent)

---

#### `~/.local/bin/whisper-ctl`
**Purpose:** Server management command-line interface

**Commands:**
- `start` - Start server manually
- `stop` - Stop server and free VRAM
- `restart` - Restart server
- `status` - Show server status and VRAM usage
- `waybar` - JSON output for Waybar widget

**Usage:**
```bash
whisper-ctl start    # Manual start
whisper-ctl stop     # Free VRAM
whisper-ctl status   # Check status
```

---

#### `~/.local/bin/whisper-activity`
**Purpose:** Activity tracking for idle monitor

**What it does:**
- Records timestamp when STT is used
- Starts idle monitor if not running
- Resets 10-minute idle timer

**Called by:**
- `hypr-stt` after successful transcription
- `whisper-ctl start` when server starts

---

#### `~/.local/bin/whisper-api-server`
**Purpose:** Python entry point for the API server

**What it does:**
- Initializes Faster-Whisper model
- Starts OpenAI-compatible HTTP API
- Handles transcription requests
- Manages GPU memory

**Technical Details:**
- Runs on `127.0.0.1:7861`
- Uses `small` model by default
- Supports float16 for faster inference

---

#### `~/.config/whisper-api/whisper-cleanup.sh`
**Purpose:** Cleanup script run after server stops

**What it does:**
- Kills any remaining whisper processes
- Removes stale PID files
- Cleans up runtime files

**When it runs:**
- After server is stopped (via systemd ExecStopPost)
- Prevents "address already in use" errors on restart

---

#### `~/.config/whisper-api/whisper-idle-monitor.sh`
**Purpose:** Idle monitoring logic

**What it does:**
1. Waits for server to start (up to 60 seconds)
2. Tracks time since last API usage
3. Stops server after 10 minutes idle
4. Exits cleanly

**Algorithm:**
```
Wait for server → Track idle time → Stop at 10 min → Exit
```

---

### Hyprland Integration

#### `~/.config/hypr/keybindings.conf`
**Purpose:** Defines keyboard shortcuts for STT

**Keybindings:**
| Shortcut | Action |
|----------|--------|
| Super+N | Toggle recording |
| Super+Ctrl+R | Reset STT state |
| Super+Alt+R | Stop server |
| Super+Shift+S | Start server |
| Super+Shift+R | Restart server |

---

## Keybindings Reference

### Daily Use

| Keybinding | Action | Description |
|------------|--------|-------------|
| **Super+N** | Toggle recording | Start/stop voice recording |

### Server Management

| Keybinding | Action | Description |
|------------|--------|-------------|
| **Super+Alt+R** | Stop server | Stop server, free VRAM |
| **Super+Shift+S** | Start server | Manually start server |
| **Super+Shift+R** | Restart server | Refresh server |
| **Super+Ctrl+R** | Reset STT | Clear stuck state |

---

## Issues Fixed

### Issue 1: Whisper Service Restart Loop Killing Hyprland
**Problem:** Service was restarting rapidly (10 times/minute), killing entire desktop session

**Root Cause:** Missing Python dependency (`httpx`)

**Fix:**
```bash
~/.local/share/mise/installs/python/3.14.3/bin/python3 -m pip install httpx
```

**Files Modified:**
- `~/.local/share/mise/installs/python/3.14.3/` (package installed)

**Result:** Service now starts and runs stably

---

### Issue 2: keyd Not Starting on Boot
**Problem:** keyd keyboard remapper failing to start randomly

**Root Cause:** Race condition - keyd starting before input devices ready

**Fix:** Updated systemd service with proper dependencies
- Added `systemd-udev-settle.service` dependency
- Added `systemd-udev-trigger.service` dependency
- Increased startup timeout

**Files Modified:**
- `/etc/systemd/system/keyd.service`

**Result:** keyd now starts reliably on every boot

---

### Issue 3: Whisper Server Restarting Every 5 Minutes
**Problem:** Server dying exactly every 5 minutes

**Root Cause:** Watchdog timeout (300 seconds) without keepalive

**Fix:** Removed watchdog configuration from service file

**Files Modified:**
- `~/.config/systemd/user/whisper-api.service`

**Result:** Server runs continuously without forced restarts

---

### Issue 4: Cascade Failure - Stopping Whisper Killed Desktop
**Problem:** Stopping whisper server killed waybar, dunst, hypridle, wallpaper, etc.

**Root Cause:**
- Service had `Wants=graphical-session.target` (dangerous dependency)
- Cleanup script killed ALL processes matching "whisper-api"
- `BindsTo` created tight coupling

**Fix:**
1. Removed `Wants=graphical-session.target`
2. Removed `RemainAfterExit=yes`
3. Made cleanup script more specific (exact path match)
4. Changed idle monitor to use `pkill` instead of `systemctl stop`

**Files Modified:**
- `~/.config/systemd/user/whisper-api.service`
- `~/.config/systemd/user/whisper-idle-monitor.service`
- `~/.config/whisper-api/whisper-cleanup.sh`
- `~/.config/whisper-api/whisper-idle-monitor.sh`

**Result:** Stopping whisper only stops whisper - desktop stays intact

---

### Issue 5: Super+Alt+R and Other Keybindings Not Working
**Problem:** Keybindings configured but commands not mapped in script

**Root Cause:** `hypr-stt` script had functions but no command dispatcher entries

**Fix:** Added missing case statements for:
- `stop-server`
- `start-server`
- `restart-server`
- `reset`

**Files Modified:**
- `~/.local/bin/hypr-stt`

**Result:** All keybindings now work correctly

---

### Issue 6: Server Not Auto-Starting on Super+N
**Problem:** Pressing Super+N showed "Server not ready, run whisper-ctl start"

**Root Cause:** `start_recording()` didn't auto-start server

**Fix:** Modified `start_recording()` to call `start_server()` if server not ready

**Files Modified:**
- `~/.local/bin/hypr-stt`

**Result:** Server auto-starts when needed

---

### Issue 7: HTTP 500 Errors & VRAM Not Freed
**Problem:** Server running outside systemd control, VRAM stuck at 704MB

**Root Cause:** Mismatch between how server was started (direct) vs stopped (systemctl)

**Fix:** Updated `start_server()` and `stop_server()` to use `systemctl --user`

**Files Modified:**
- `~/.local/bin/hypr-stt`

**Result:** Proper systemd management, VRAM correctly freed

---

### Issue 8: Too Many Notifications
**Problem:** 6-8 notification popups per session (annoying)

**Root Cause:** Notifications for every step (starting, CUDA ready, recording, processing, result, etc.)

**Fix:**
- Removed all startup notifications
- Only show "Ready to record" after everything loaded
- Removed text result notification
- Only show "Processing..." briefly

**Files Modified:**
- `~/.local/bin/hypr-stt`
- `~/.local/bin/whisper-ctl`

**Result:** Clean, minimal notifications (1-2 per session)

---

### Issue 9: Words Missed at Start of Recording
**Problem:** First few words not captured

**Root Cause:** Recording started before server/runtime files fully ready

**Fix:** Added verification before recording starts:
1. Server health check
2. Model loaded confirmation
3. PID file exists
4. Process running

**Files Modified:**
- `~/.local/bin/hypr-stt`

**Result:** No words missed - recording only starts when fully ready

---

### Issue 10: Long Conversations Failing
**Problem:** Transcriptions failing for audio >2 minutes

**Root Cause:**
- API timeout: 120 seconds (too short)
- Only 3 retries
- No user feedback for long transcriptions

**Fix:**
- Increased timeout: 120s → 600s (10 minutes)
- Increased retries: 3 → 5
- Added notification for recordings >60s
- Better error handling

**Files Modified:**
- `~/.local/bin/hypr-stt`

**Result:** Supports conversations up to 10 minutes

---

### Issue 11: Idle Auto-Stop Not Working After Reboot
**Problem:** Idle monitor dying after reboot, server not auto-stopping

**Root Cause:**
- Monitor bound to server with `BindsTo` (killed when server stopped)
- Monitor exited immediately if server not ready
- No restart mechanism

**Fix:**
- Changed to `PartOf=whisper-api.service` (looser coupling)
- Added 10-second delay before monitor starts (waits for model load)
- Monitor starts via `ExecStartPost` in server service
- `Restart=on-failure` (only restarts if crashes)

**Files Modified:**
- `~/.config/systemd/user/whisper-api.service`
- `~/.config/systemd/user/whisper-idle-monitor.service`
- `~/.config/whisper-api/whisper-idle-monitor.sh`

**Result:** Idle monitor survives reboots, auto-stops after 10 minutes

---

## Features

### Auto-Start
- Server starts automatically when you press Super+N
- No manual intervention needed
- Waits for model to fully load before recording

### Auto-Stop (Idle Monitor)
- Stops server after 10 minutes of inactivity
- Frees ~600MB VRAM automatically
- Restarts automatically when needed

### Minimal Notifications
- **Startup:** "Ready to record" (single notification)
- **Processing:** "Processing..." (briefly)
- **Result:** Text typed silently (no notification)

### Comprehensive Logging
- **Location:** `~/.local/share/hypr-stt/YYYY-MM-DD.log`
- **Format:** `[timestamp] [level] message`
- **Retention:** Daily logs, stored indefinitely

### Long Conversation Support
- **Timeout:** 10 minutes (supports up to 10 min audio)
- **Retries:** 5 attempts with exponential backoff
- **Feedback:** Notification for recordings >60s

### Runtime File Verification
- Verifies server ready before recording
- Checks model loaded
- Checks PID file exists
- No words missed

---

## Troubleshooting

### Server Won't Start
```bash
# Check logs
journalctl --user -u whisper-api.service -f

# Manual start
whisper-ctl start

# Check if port in use
lsof -i :7861
```

### Idle Monitor Not Running
```bash
# Check status
systemctl --user status whisper-idle-monitor.service

# Restart
systemctl --user restart whisper-idle-monitor.service

# View logs
journalctl --user -u whisper-idle-monitor.service -f
```

### VRAM Not Freed
```bash
# Check what's using VRAM
nvidia-smi

# Force stop server
pkill -f whisper-api-server

# Verify stopped
systemctl --user status whisper-api.service
```

### Recording Not Working
```bash
# List microphones
hypr-stt list-mics

# Select microphone
hypr-stt select-mic

# Check state
hypr-stt status
```

### Check Logs
```bash
# Today's log
cat ~/.local/share/hypr-stt/$(date +%Y-%m-%d).log

# Live tail
tail -f ~/.local/share/hypr-stt/*.log

# Search for errors
grep ERROR ~/.local/share/hypr-stt/*.log
```

---

## Quick Reference

### Start Server
```bash
whisper-ctl start
# or
hypr-stt start-server  # Super+Shift+S
```

### Stop Server
```bash
whisper-ctl stop
# or
hypr-stt stop-server  # Super+Alt+R
```

### Check Status
```bash
whisper-ctl status
# or
systemctl --user status whisper-api.service
```

### View Logs
```bash
# Server logs
journalctl --user -u whisper-api.service -f

# Session logs
cat ~/.local/share/hypr-stt/$(date +%Y-%m-%d).log
```

---

## Model Information

**Current Model:** `small`

| Property | Value |
|----------|-------|
| Parameters | 244 million |
| Size | ~244 MB |
| VRAM Usage | ~600-700 MB |
| Speed | Fast (~2-3x real-time) |
| Accuracy | Good |
| Best For | Daily conversations, dictation |

---

## Credits

- **Faster-Whisper:** https://github.com/SYSTRAN/faster-whisper
- **Hyprland:** https://hyprland.org
- **OpenAI Whisper:** https://github.com/openai/whisper

---

**End of Documentation**
