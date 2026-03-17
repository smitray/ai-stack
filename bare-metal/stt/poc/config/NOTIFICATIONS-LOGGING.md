# Whisper STT - Notifications & Logging Guide

## What Changed

### Before (Too Many Notifications)
- ❌ "Starting STT server..." 
- ❌ "Server ready"
- ❌ "Recording... (press again to stop)"
- ❌ "Processing..."
- ❌ "Typed: [text]"
- ❌ "Server stopped"
- ❌ Multiple error dialogs

### After (Minimal Notifications)
- ✅ **Recording** - Only "Recording..." (low priority)
- ✅ **Processing** - Only "Processing..." (low priority)
- ✅ **Result** - Shows transcribed text (low priority)
- ✅ **Errors** - Only critical failures

---

## Logging System

### Log Location
```
~/.local/share/hypr-stt/YYYY-MM-DD.log
```

Example: `~/.local/share/hypr-stt/2026-03-09.log`

### Log Format
```
[YYYY-MM-DD HH:MM:SS] [LEVEL] Message
```

### Log Levels
- **INFO** - Normal operations (server start, recording, etc.)
- **ERROR** - Failures (server crash, transcription failed, etc.)
- **DEBUG** - Detailed debugging (not currently used)

### Example Log
```
[2026-03-09 04:42:15] [INFO] Server not ready, auto-starting...
[2026-03-09 04:42:15] [INFO] Starting Whisper server...
[2026-03-09 04:42:15] [INFO] Waiting for server to load model...
[2026-03-09 04:42:19] [INFO] Server ready, model loaded
[2026-03-09 04:42:19] [INFO] Runtime files verified
[2026-03-09 04:42:19] [INFO] Server started successfully
[2026-03-09 04:42:20] [INFO] Recording started
[2026-03-09 04:42:20] [INFO] Recording from: bluez_input.AC:80:0A:44:BE:9D
[2026-03-09 04:42:37] [INFO] Processing recording...
[2026-03-09 04:42:37] [INFO] Audio file ready
[2026-03-09 04:42:37] [INFO] Transcribing audio...
[2026-03-09 04:42:38] [INFO] Transcribed: Hello world
[2026-03-09 04:42:57] [INFO] Stopping Whisper server...
[2026-03-09 04:42:58] [INFO] Server stopped
```

---

## Server Readiness Check

### What Gets Verified Before Recording Starts

1. **Server Health** - API responds to `/health` endpoint
2. **Model Loaded** - `model_loaded: true` in `/status` response
3. **Runtime Files** - PID file exists or process is running
4. **Audio File Path** - `/run/user/1000/hypr-stt-recording.wav` can be created

### Timeline
```
Press Super+N
  ↓
Check server ready? → No
  ↓
Start server (systemctl)
  ↓
Wait for model loaded (~4-5 seconds)
  ↓
Verify runtime files
  ↓
Show "Recording..." notification
  ↓
Start audio capture
```

**Total time before recording starts: ~5-6 seconds**

This ensures no words are missed!

---

## Notification Flow

### Starting Recording (Server Stopped)
```
User presses Super+N
  ↓
Auto-start server (no notification)
  ↓
Wait for model loaded (no notification)
  ↓
Verify runtime files (no notification)
  ↓
Show: "Recording..." (low priority)
```

### Stopping Recording
```
User presses Super+N
  ↓
Stop audio capture
  ↓
Show: "Processing..." (low priority)
  ↓
Transcribe
  ↓
Show: "[transcribed text]" (low priority, first 40 chars)
```

### Stopping Server
```
User presses Super+Alt+R
  ↓
Stop server (no notification)
  ↓
VRAM freed (no notification)
```

---

## Viewing Logs

### Today's Log
```bash
cat ~/.local/share/hypr-stt/$(date +%Y-%m-%d).log
```

### Recent Logs
```bash
ls -lt ~/.local/share/hypr-stt/*.log | head -5
```

### Live Tail
```bash
tail -f ~/.local/share/hypr-stt/$(date +%Y-%m-%d).log
```

### Search Logs
```bash
# Find errors
grep ERROR ~/.local/share/hypr-stt/*.log

# Find transcriptions
grep "Transcribed:" ~/.local/share/hypr-stt/*.log

# Find server starts
grep "Server ready" ~/.local/share/hypr-stt/*.log
```

---

## Log Retention

Logs are created daily and stored indefinitely. To clean up old logs:

```bash
# Delete logs older than 7 days
find ~/.local/share/hypr-stt -name "*.log" -mtime +7 -delete

# Delete all logs
rm ~/.local/share/hypr-stt/*.log
```

---

## Troubleshooting with Logs

### Server Won't Start
```bash
# Check what happened
tail -30 ~/.local/share/hypr-stt/$(date +%Y-%m-%d).log

# Look for errors
grep ERROR ~/.local/share/hypr-stt/$(date +%Y-%m-%d).log
```

### Recording Not Working
```bash
# Check if recording started
grep "Recording" ~/.local/share/hypr-stt/$(date +%Y-%m-%d).log

# Check audio file
grep "Audio file" ~/.local/share/hypr-stt/$(date +%Y-%m-%d).log
```

### Transcription Failing
```bash
# Check transcription attempts
grep -E "Transcribing|Transcribed|ERROR" ~/.local/share/hypr-stt/$(date +%Y-%m-%d).log
```

---

## Summary

| Event | Notification | Logged |
|-------|--------------|--------|
| Server auto-start | ❌ No | ✅ Yes |
| Server loading | ❌ No | ✅ Yes |
| Model loaded | ❌ No | ✅ Yes |
| Recording started | ✅ "Recording..." | ✅ Yes |
| Processing | ✅ "Processing..." | ✅ Yes |
| Transcription result | ✅ First 40 chars | ✅ Full text |
| Server stop | ❌ No | ✅ Yes |
| Errors | ✅ Critical only | ✅ Yes |

**Result:** Clean, minimal notifications with comprehensive logging!
