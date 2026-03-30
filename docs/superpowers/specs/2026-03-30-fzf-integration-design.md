# fzf Integration Design Spec

## Overview

Add `ai-stack fzf` subcommand to ai-stack CLI for interactive workflows using fzf, rg, bat, and other CLI tools already in the user's system.

## Architecture

```
ai-stack fzf <command>
         │
         ├── logs     → Interactive log viewer (fzf + bat + rg)
         ├── services → Interactive service picker with status
         └── models   → HuggingFace model search
```

## Components

### 1. fzf Logs Viewer (`ai-stack fzf logs`)

**Features:**
1. **Service Picker** - fzf lists all services (bare-metal + containers)
2. **Log Viewer** - Shows logs with bat syntax highlighting
3. **Search** - rg integration to search within logs
4. **Time Filter** - Filter by time range

**Workflow:**
```
1. fzf shows: whisper-server, llama-cpp, stt-proxy, open-webui, postgres, qdrant, searxng, n8n
2. User selects service (arrow keys + enter)
3. Shows logs with bat highlighting
4. Ctrl+R to search with rg
```

**Shortcut:** `ai-stack logs --fzf`

### 2. fzf Service Picker (`ai-stack fzf services`)

**Features:**
1. **Interactive List** - fzf shows all services with status
2. **Status Info** - Running/stopped, port, PID
3. **Quick Actions** - View status of selected service

### 3. fzf Model Search (`ai-stack fzf models`)

**Features:**
1. **Search HF** - Search HuggingFace Hub
2. **Model Info** - Size, downloads, likes
3. **Select** - Shows download command

## Dependencies

Assumes user already has installed:
- `fzf` - Fuzzy finder
- `rg` (ripgrep) - Search in logs
- `bat` - Syntax highlighting
- `hf` - HuggingFace CLI (already installed by ai-stack)

Graceful error if fzf not installed.

## Design Decisions

1. **Opt-in** - Only works if fzf is installed
2. **Single subcommand** - `ai-stack fzf <mode>` as subcommand
3. **Fallback** - Regular commands still work without fzf
4. **Composability** - Uses existing tools already in user's workflow

## Files Changed

- `bin/ai-stack` - Add fzf subcommand and helper functions

## Testing

```bash
# Verify fzf installed
which fzf

# Test logs picker
ai-stack fzf logs

# Test services
ai-stack fzf services

# Test models
ai-stack fzf models

# Test shortcut
ai-stack logs --fzf
```
