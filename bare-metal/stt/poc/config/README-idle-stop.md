# Whisper STT - Idle Auto-Stop Setup

## Overview
The Whisper STT server now automatically stops after 10 minutes of inactivity to free VRAM.
When you press **Super+N**, the server starts fresh if it's stopped.

## How It Works

### Components

1. **whisper-api.service** - The main Whisper STT server
   - Starts when you run `whisper-ctl start` or press Super+N
   - Runs the OpenAI-compatible STT API on port 7861

2. **whisper-idle-monitor.service** - Monitors server activity
   - Starts automatically when the server starts
   - Checks if the server is being used
   - Stops the server after 10 minutes of no activity

3. **whisper-activity** - Activity tracker
   - Records timestamps when you use the STT
   - Called automatically by hypr-stt after successful transcription

4. **hypr-stt** - Voice recording client
   - Press **Super+N** to toggle voice recording
   - Automatically records activity when transcription succeeds

### Activity Flow

```
1. Press Super+N (first time)
   → hypr-stt starts recording
   → whisper-ctl starts the server
   → whisper-idle-monitor starts (10 min timer)

2. Speak and transcribe
   → hypr-stt sends audio to API
   → API returns transcription
   → whisper-activity records timestamp (resets 10 min timer)

3. No activity for 10 minutes
   → whisper-idle-monitor stops the server
   → VRAM is freed
   → notify-send shows "Server stopped" notification

4. Press Super+N again
   → Server starts fresh
   → Cycle repeats
```

## Commands

### Manual Control

```bash
# Start server (also starts idle monitor)
whisper-ctl start

# Stop server
whisper-ctl stop

# Check status
whisper-ctl status

# View logs
journalctl --user -u whisper-api.service -f
```

### Keyboard Shortcuts

- **Super+N** - Toggle voice recording (starts server if needed)
- **Super+Shift+S** - Start server manually
- **Super+Alt+R** - Stop server manually
- **Super+Shift+R** - Restart server

## Configuration

### Change Idle Timeout

Edit `~/.config/whisper-api/whisper-idle-monitor.sh`:
```bash
readonly IDLE_TIMEOUT=600  # Change to desired seconds (600 = 10 min)
```

### Disable Auto-Stop

```bash
systemctl --user disable --now whisper-idle-monitor.service
```

## Troubleshooting

### Server not stopping automatically

Check idle monitor logs:
```bash
journalctl --user -u whisper-idle-monitor.service -f
```

### Activity not being recorded

Test manually:
```bash
~/.local/bin/whisper-activity record
cat /run/user/1000/whisper-api-idle  # Should show current timestamp
```

### Check if monitor is running

```bash
systemctl --user status whisper-idle-monitor.service
```

### VRAM not being freed

Check server stopped:
```bash
nvidia-smi
whisper-ctl status
```

## Files

- `~/.config/systemd/user/whisper-api.service` - Server service
- `~/.config/systemd/user/whisper-idle-monitor.service` - Idle monitor service
- `~/.config/whisper-api/whisper-idle-monitor.sh` - Idle monitor script
- `~/.local/bin/whisper-activity` - Activity tracker
- `~/.local/bin/whisper-ctl` - Server management CLI
- `~/.local/bin/hypr-stt` - Voice recording client
- `/run/user/1000/whisper-api-idle` - Activity timestamp file
