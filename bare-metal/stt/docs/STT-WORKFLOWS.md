# STT Workflows - Quick Reference

**Two ways to use Speech-to-Text in AI Stack**

**VRAM Rule:** Only ONE model loaded at a time (STT or LLM)

---

## Workflow 1: Hyprland Keybindings (System-Wide)

**Use Case:** Type transcribed text anywhere in Hyprland

### Keybindings

| Shortcut | Action |
|----------|--------|
| <kbd>SUPER</kbd> + <kbd>N</kbd> | Toggle recording |
| <kbd>SUPER</kbd> + <kbd>ALT</kbd> + <kbd>R</kbd> | Stop server (free VRAM) |
| <kbd>SUPER</kbd> + <kbd>SHIFT</kbd> + <kbd>S</kbd> | Start server |

### VRAM Management

**Automatic** - `ai-vram-manager` checks and unloads LLM before STT:

```bash
# When you press Super+N:
# 1. ai-vram-manager checks llama.cpp /models API
# 2. If LLM loaded → auto-unload via API (~1s)
# 3. Continue with recording
```

**Manual override (optional):**
```bash
# Before using STT (if LLM is loaded):
ai-vram-manager ensure-stt  # Manually ensure VRAM ready

# Or switch GPU mode:
ai-stack gpu stt  # Switch GPU mode
```

### Architecture

```
Super+N → hypr-stt → ai-vram-manager ensure-stt
                      ↓ (if LLM loaded: unload)
                      ↓
                 Whisper STT (:7861)
                      ↓
                 Types text
```

**Note:** Automatic VRAM management via ai-vram-manager.

---

## Workflow 2: Open WebUI (Chat Interface)

**Use Case:** Voice input in Open WebUI chat

### Configuration

Open WebUI is pre-configured to use STT Proxy at port 7866.

### VRAM Management

**Automatic** - STT Proxy handles everything:

1. Click microphone icon 🎤
2. STT Proxy calls ai-vram-manager logic
3. llama.cpp model unloaded via API (~1s)
4. Audio transcribed
5. State file updated

### Architecture

```
Open WebUI → STT Proxy (:7866) → ai-vram-manager logic
                                  ↓
                             llama.cpp /models/unload
                                  ↓
                             Whisper STT (:7861)
                                  ↓
                             Returns text
```

---

## Port Summary

| Port | Service | Used By |
|------|---------|---------|
| 7861 | Whisper STT | Both workflows |
| 7865 | llama.cpp Router | Both workflows |
| 7866 | STT Proxy | Open WebUI only |

---

## Commands

### VRAM Management

```bash
# Check VRAM status
ai-vram-manager status

# Ensure ready for STT (unload LLM)
ai-vram-manager ensure-stt

# Ensure ready for LLM (wait for STT)
ai-vram-manager ensure-llm

# Show state file
ai-vram-manager state

# Clear state
ai-vram-manager clear
```

### Management

```bash
# llama.cpp router status
llama-router status

# Unload model manually
llama-router unload

# List models
llama-router models
```

### Testing

```bash
# Test all endpoints
test-router-mode.sh

# Test STT Proxy
curl http://localhost:7866/health

# Test Whisper STT
curl http://localhost:7861/health

# Test llama.cpp
curl http://localhost:7865/health
```

### Service Control

```bash
# Start all
systemctl --user start llama-cpp whisper-server stt-proxy

# Stop all
systemctl --user stop llama-cpp whisper-server stt-proxy

# Check status
systemctl --user status llama-cpp
systemctl --user status stt-proxy
```

---

## State File

**Location:** `/run/user/1000/ai-stack-vram-state`

**Format:**
```json
{"active": "stt", "timestamp": 1234567890}
```

**Values:**
- `"active": "stt"` - STT recently active
- `"active": "llm"` - LLM recently active
- `"active": "none"` - No active service

**Used by:**
- `ai-vram-manager` - Read/write state
- `hypr-stt` - Writes via ai-vram-manager
- `STT Proxy` - Writes after unload
- `llama.cpp` - Can check before loading LLM

---

## Troubleshooting

### Hyprland STT not working

```bash
# Check server
systemctl --user status whisper-server

# Check keybindings
hyprctl keybinds | grep stt

# Test manually
hypr-stt toggle

# Check VRAM status
ai-vram-manager status
```

### Open WebUI STT not working

```bash
# Check STT Proxy
systemctl --user status stt-proxy

# Test endpoint
curl http://localhost:7866/health

# Check Open WebUI config
# Admin Settings → Audio → Speech-to-Text Engine
# API Base URL should be: http://localhost:7866/v1
```

### VRAM conflicts

```bash
# Check VRAM
nvidia-smi

# Check state
ai-vram-manager status

# Unload llama.cpp
ai-vram-manager ensure-stt
# OR
llama-router unload

# Or switch GPU mode
ai-stack gpu stt   # For STT
ai-stack gpu llm   # For LLM
```

### LLM won't load

```bash
# Check if STT is active
ai-vram-manager state

# If STT active, wait or clear
ai-vram-manager ensure-llm  # Waits for STT to finish
```

---

## Key Differences

| Aspect | Hyprland Keybindings | Open WebUI |
|--------|---------------------|------------|
| **VRAM Management** | Automatic (ai-vram-manager) | Automatic (STT Proxy) |
| **Uses STT Proxy** | No | Yes |
| **Endpoint** | Direct (:7861) | Proxy (:7866) |
| **Scope** | System-wide | Open WebUI only |
| **State File** | Updated | Updated |

---

**Remember:** 
- Both workflows now have **automatic VRAM management**
- State file tracks active service
- Only ONE model in VRAM at a time
