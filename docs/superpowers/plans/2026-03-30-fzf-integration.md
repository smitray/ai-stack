# fzf Integration Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `ai-stack fzf` subcommand for interactive workflows using fzf, rg, bat.

**Architecture:** Add fzf subcommand to existing ai-stack CLI with three modes: logs, services, models. Use existing tools (fzf, rg, bat) already in user's system.

**Tech Stack:** Bash, fzf, rg, bat, hf CLI

---

## Chunk 1: Core Implementation

### Task 1.1: Add fzf helper functions

**Files:**
- Modify: `bin/ai-stack`

- [ ] **Step 1: Add helper functions after line 33 (after readonly VERSION)**

```bash
# === fzf Helper Functions ===

check_fzf() {
    if ! command -v fzf &>/dev/null; then
        echo -e "${RED}Error: fzf not installed${NC}"
        echo "Install with: pacman -S fzf"
        return 1
    fi
}

get_all_services() {
    # Bare-metal services
    echo "whisper-server"
    echo "llama-cpp"
    echo "stt-proxy"
    
    # Container services (from compose)
    if [ -f "$COMPOSE_FILE" ]; then
        podman compose -f "$COMPOSE_FILE" ps --services 2>/dev/null | while read -r svc; do
            echo "$svc"
        done
    fi
}

get_logs_cmd() {
    local svc="$1"
    case "$svc" in
        whisper-server|llama-cpp|stt-proxy)
            echo "journalctl --user -u $svc -o short --no-pager -n 200"
            ;;
        *)
            echo "podman logs $svc --tail 200"
            ;;
    esac
}

fzf_logs() {
    local services
    services=$(get_all_services | sort | uniq)
    local selected
    selected=$(echo "$services" | fzf --prompt="Select service: " --height=40%)
    [ -z "$selected" ] && return
    
    local logs_cmd
    logs_cmd=$(get_logs_cmd "$selected")
    echo -e "${BLUE}=== Logs: $selected ===${NC}"
    eval "$logs_cmd" | bat --style=auto -l log --color=always
}

fzf_services() {
    local services
    services=$(get_all_services | sort | uniq)
    local selected
    selected=$(echo "$services" | fzf --prompt="Select service: " --height=40% \
        --preview="echo '=== Status ===' && ai-stack status 2>/dev/null | grep {1} || echo 'service not running'")
    [ -z "$selected" ] && return
    
    # Show status of selected service
    echo -e "${BLUE}=== Status: $selected ===${NC}"
    if [[ "$selected" == "whisper-server" || "$selected" == "llama-cpp" || "$selected" == "stt-proxy" ]]; then
        systemctl --user status "$selected" --no-pager
    else
        podman compose -f "$COMPOSE_FILE" ps "$selected"
    fi
}

fzf_models() {
    echo -e "${BLUE}Searching HuggingFace Hub...${NC}"
    local model
    model=$(hf hub list 2>/dev/null | fzf --prompt="Search model: " --height=60% \
        --preview="hf hub info {1} 2>/dev/null | head -20")
    [ -z "$model" ] && return
    
    echo -e "${GREEN}Selected: $model${NC}"
    echo "Download with: hf download $model"
}
```

- [ ] **Step 2: Commit**

```bash
git add bin/ai-stack
git commit -m "feat(fzf): add helper functions for fzf integration"
```

---

### Task 1.2: Add fzf subcommand

**Files:**
- Modify: `bin/ai-stack` (add fzf case before the help section)

- [ ] **Step 1: Add fzf case**

```bash
    fzf)
        check_fzf || exit 1
        FZF_MODE="${1:-}"
        shift 2>/dev/null || true
        
        case "$FZF_MODE" in
            logs) fzf_logs ;;
            services) fzf_services ;;
            models) fzf_models ;;
            *)
                echo "Usage: ai-stack fzf {logs|services|models}"
                echo ""
                echo "  logs      Interactive log viewer (fzf + bat)"
                echo "  services  Interactive service picker"
                echo "  models    Search HuggingFace models"
                exit 1
                ;;
        esac
        ;;
```

- [ ] **Step 2: Update help text**

Add to help section:
```bash
  fzf             Interactive mode (ai-stack fzf {logs|services|models})
```

- [ ] **Step 3: Verify syntax**

Run: `bash -n bin/ai-stack`

- [ ] **Step 4: Commit**

```bash
git add bin/ai-stack
git commit -m "feat(fzf): add ai-stack fzf subcommand"
```

---

### Task 1.3: Add --fzf shortcut to logs

**Files:**
- Modify: `bin/ai-stack`

- [ ] **Step 1: Add --fzf flag to logs case**

At the beginning of the logs case, add:
```bash
logs)
    # Check for --fzf flag
    if [[ "$1" == "--fzf" ]]; then
        check_fzf
        fzf_logs
        exit 0
    fi
    # ... existing logs code ...
```

- [ ] **Step 2: Commit**

```bash
git add bin/ai-stack
git commit -m "feat(fzf): add --fzf shortcut to logs command"
```

---

## Summary

| Task | Files | Commits |
|------|-------|---------|
| 1.1 Helper functions | bin/ai-stack | 1 |
| 1.2 fzf subcommand | bin/ai-stack | 1 |
| 1.3 --fzf shortcut | bin/ai-stack | 1 |
| **Total** | **1** | **3** |

---

## Verification

```bash
bash -n bin/ai-stack
ai-stack fzf
ai-stack fzf logs
ai-stack fzf services
ai-stack fzf models
ai-stack logs --fzf
```
