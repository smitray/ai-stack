# Unified Logging Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extend `ai-stack logs` CLI to provide unified log viewing for bare-metal + container services with 7-day retention.

**Architecture:** Use journald for bare-metal services (already systemd), poll podman logs for containers, auto-detect services dynamically. Configure 7-day retention via journald.conf.d override.

**Tech Stack:** Bash (ai-stack CLI), systemd/journald, podman

---

## Chunk 1: Core Implementation

### Task 1.1: Create journald retention config

**Files:**
- Create: `lib/journald-ai-stack.conf`

- [ ] **Step 1: Create journald config file**

```ini
[Journal]
SystemMaxUse=7d
SystemMaxFileSize=100M
```

- [ ] **Step 2: Commit**

```bash
git add lib/journald-ai-stack.conf
git commit -m "feat(logs): add journald retention config (7 days)"
```

---

### Task 1.2: Install journald config in install-base.sh

**Files:**
- Modify: `lib/install-base.sh`

- [ ] **Step 1: Add journald config installation**

Add after line 93 (after compose.yaml install), before "7. Create XDG data directories":

```bash
# ---------------------------------------------------------------------------
# Configure journald retention
# ---------------------------------------------------------------------------
echo "[6/5] Configuring journald retention..."
JOURNALD_DIR="$HOME/.config/systemd/journald.conf.d"
mkdir -p "$JOURNALD_DIR"
cp "$REPO_ROOT/lib/journald-ai-stack.conf" "$JOURNALD_DIR/ai-stack.conf"
echo "  Configured 7-day log retention at $JOURNALD_DIR/ai-stack.conf"
```

- [ ] **Step 2: Commit**

```bash
git add lib/install-base.sh
git commit -m "feat(logs): install journald retention config during install"
```

---

### Task 1.3: Update ai-stack logs command

**Files:**
- Modify: `bin/ai-stack:41-43`

- [ ] **Step 1: Read current logs implementation**

Run: `sed -n '35,50p' bin/ai-stack`

- [ ] **Step 2: Replace logs case**

Replace the current `logs)` case (line 41-43) with:

```bash
    logs)
        SERVICE="${1:-all}"
        shift 2>/dev/null || true

        case "$SERVICE" in
            all)
                echo -e "\033[0;34m=== AI Stack Logs ===\033[0m"
                echo ""
                # Bare-metal services
                for svc in whisper-server llama-cpp stt-proxy; do
                    if systemctl --user is-active "$svc" &>/dev/null; then
                        echo -e "\033[1;33m[$svc]\033[0m"
                        journalctl --user -u "$svc" -o short --no-pager -n 10 2>/dev/null || echo "  (no logs)"
                        echo ""
                    fi
                done
                # Container services
                if [ -f "$COMPOSE_FILE" ]; then
                    for ctr in $(podman compose -f "$COMPOSE_FILE" ps --services 2>/dev/null); do
                        echo -e "\033[1;33m[$ctr]\033[0m"
                        podman logs "$ctr" --tail=10 --no-log-group 2>/dev/null | head -10 || echo "  (no logs)"
                        echo ""
                    done
                fi
                ;;
            errors)
                echo -e "\033[0;31m=== Errors from all services ===\033[0m"
                echo ""
                for svc in whisper-server llama-cpp stt-proxy; do
                    journalctl --user -u "$svc" -o short --no-pager -n 100 2>/dev/null | grep -iE "error|warn|fail|crit" && echo "" || true
                done
                if [ -f "$COMPOSE_FILE" ]; then
                    for ctr in $(podman compose -f "$COMPOSE_FILE" ps --services 2>/dev/null); do
                        podman logs "$ctr" --tail=100 2>/dev/null | grep -iE "error|warn|fail|crit" | sed "s/^/[$ctr] /" || true
                    done
                fi
                ;;
            whisper-server|llama-cpp|stt-proxy)
                journalctl --user -u "$SERVICE" -o short --no-pager -n 100 "$@"
                ;;
            --help|-h)
                echo "Usage: ai-stack logs [service|errors|--help]"
                echo ""
                echo "Services:"
                echo "  whisper-server  STT service logs (journald)"
                echo "  llama-cpp       LLM service logs (journald)"
                echo "  stt-proxy       STT Proxy logs (journald)"
                echo "  errors          Show errors from all services"
                echo ""
                echo "Container services (auto-detected from compose):"
                for ctr in $(podman compose -f "$COMPOSE_FILE" ps --services 2>/dev/null); do
                    echo "  $ctr"
                done
                echo ""
                echo "Options:"
                echo "  --since=1h      Time range"
                echo "  -f              Follow mode"
                ;;
            *)
                if [ -f "$COMPOSE_FILE" ] && podman compose -f "$COMPOSE_FILE" ps --services 2>/dev/null | grep -q "^$SERVICE$"; then
                    podman logs "$SERVICE" --tail=100 "$@"
                else
                    echo "Unknown service: $SERVICE"
                    echo "Run 'ai-stack logs --help' for available services"
                    exit 1
                fi
                ;;
        esac
        ;;
```

- [ ] **Step 3: Update help text**

Replace the `logs` line in the help message (around line 272) with:

```bash
  logs            View logs (ai-stack logs [service|errors|--help])
```

- [ ] **Step 4: Verify syntax**

Run: `bash -n bin/ai-stack`

- [ ] **Step 5: Commit**

```bash
git add bin/ai-stack
git commit -m "feat(logs): unified log viewing for bare-metal + containers

- ai-stack logs: show all services (bare-metal + containers)
- ai-stack logs <service>: show specific service
- ai-stack logs errors: show errors from all services
- ai-stack logs --help: list available services
- Auto-detects services from systemd + compose file"
```

---

## Summary

| Task | Files | Commits |
|------|-------|---------|
| 1.1 | journald-ai-stack.conf | 1 |
| 1.2 | install-base.sh | 1 |
| 1.3 | bin/ai-stack | 1 |
| **Total** | **3** | **3** |

---

## Verification

```bash
# Syntax check
bash -n bin/ai-stack

# Test help
ai-stack logs --help

# Test all services
ai-stack logs

# Test specific service
ai-stack logs whisper-server

# Test errors
ai-stack logs errors
```
