# Logging System Design Spec

## Overview

Extend the `ai-stack logs` CLI command to provide unified, human-readable log viewing for all services (bare-metal + containers) with automatic 7-day retention.

## Architecture

```
ai-stack logs [service] [options]
         │
         ├── Bare-metal services → journalctl -u <service> -o short
         │   └── whisper-server, llama-cpp, stt-proxy
         │
         └── Container services → podman logs <container>
             └── open-webui, postgres, qdrant, searxng, valkey, n8n
```

## Components

### 1. journald Configuration

Configure system-wide 7-day retention:

**File:** `/etc/systemd/journald.conf` (or user-level override)

```ini
[Journal]
SystemMaxUse=7d
SystemMaxFileSize=100M
```

### 2. Enhanced `ai-stack logs` Command

Replace current container-only implementation with dynamic service detection.

**Usage:**

```bash
# All services (default)
ai-stack logs

# Specific service
ai-stack logs whisper-server
ai-stack logs llama-cpp
ai-stack logs stt-proxy
ai-stack logs open-webui
ai-stack logs postgres

# Errors only (from all services)
ai-stack logs errors

# Time range
ai-stack logs --since=1h
ai-stack logs --since=2026-03-30

# Follow mode
ai-stack logs -f

# List available services
ai-stack logs --help
```

### 3. Service Detection

Dynamic discovery of services:

**Bare-metal:** Query systemd user units
```bash
systemctl list-units --user --type=service --no-pager | grep -E "whisper-server|llama-cpp|stt-proxy"
```

**Containers:** Query compose file
```bash
podman compose -f <compose-file> ps --services 2>/dev/null
```

### 4. Output Format

**Bare-metal (journald short format):**
```
Mar 30 10:15:23 whisper-server[1234]: INFO: Model loaded successfully
Mar 30 10:15:24 llama-cpp[5678]: INFO: Server ready on port 7865
```

**Container (podman logs):**
```
open-webui: [2026-03-30 10:15:23] INFO: Listening on 7860
postgres:   [2026-03-30 10:15:24] INFO: Connection established
```

**Errors mode:** Filter for ERROR/WARN/FAIL/perror
```bash
journalctl -u whisper-server -o short | grep -iE "error|warn|fail|critical"
podman logs <container> --tail=100 2>&1 | grep -iE "error|warn|fail|critical"
```

### 5. Log Colors

| Level | Color |
|-------|-------|
| ERROR/CRIT | Red |
| WARN | Yellow |
| INFO | Blue |
| DEBUG | Gray |

## Implementation

### Changes Required

1. **Update `bin/ai-stack`** - Replace `logs` case with new logic
2. **Update `journald.conf`** - Add retention config during install
3. **Update `lib/install-base.sh`** - Ensure journald config is set

### New CLI Code

```bash
logs)
    SERVICE="${1:-all}"
    shift || true

    case "$SERVICE" in
        all)
            # Show logs from all services
            for svc in whisper-server llama-cpp stt-proxy; do
                if systemctl --user is-active "$svc" &>/dev/null; then
                    journalctl --user -u "$svc" -o short --no-pager -n 20
                fi
            done
            for ctr in $(podman compose -f "$COMPOSE_FILE" ps --services 2>/dev/null); do
                podman logs "$ctr" --tail=20 --no-log-group 2>/dev/null | head -20
            done
            ;;
        errors)
            # Show errors from all services
            for svc in whisper-server llama-cpp stt-proxy; do
                journalctl --user -u "$svc" -o short --no-pager -n 50 | grep -iE "error|warn|fail|crit" || true
            done
            ;;
        whisper-server|llama-cpp|stt-proxy)
            # Bare-metal service
            journalctl --user -u "$SERVICE" -o short --no-pager "$@"
            ;;
        *)
            # Container service
            podman logs "$SERVICE" --tail=100 "$@"
            ;;
    esac
    ;;
```

## Configuration

### journald.conf Override

Create user-level override at `~/.config/systemd/journald.conf.d/ai-stack.conf`:

```ini
[Journal]
SystemMaxUse=7d
SystemMaxFileSize=100M
```

This avoids modifying system-wide `/etc/systemd/journald.conf`.

## Testing

1. Run `ai-stack logs` - should show all services
2. Run `ai-stack logs whisper-server` - should show Whisper logs
3. Run `ai-stack logs errors` - should show only errors
4. Run `ai-stack logs --since=1h` - should show recent logs
5. Verify journald config: `journalctl --disk-usage`

---

**Spec complete. Ready for implementation planning?**
