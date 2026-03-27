# STT Workflows - Quick Reference

**Two ways to use Speech-to-Text in AI Stack**

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

**Manual** - You control when to switch between LLM and STT:

```bash
# Before using STT (if LLM is loaded):
Super+Alt+R  # Stop Whisper server
# OR
ai-stack gpu stt  # Switch GPU mode

# Use STT:
Super+N  # Toggle recording

# After STT (optional):
ai-stack gpu llm  # Switch back to LLM
```

### Architecture

```
Super+N → hypr-stt → Whisper STT (:7861)
                      ↓
                 Types text
```

**Note:** Does NOT use STT Proxy. Direct connection to Whisper.

---

## Workflow 2: Open WebUI (Chat Interface)

**Use Case:** Voice input in Open WebUI chat

### Configuration

Open WebUI is pre-configured to use STT Proxy at port 7866.

### VRAM Management

**Automatic** - STT Proxy handles everything:

1. Click microphone icon 🎤
2. STT Proxy unloads llama.cpp via API
3. Audio transcribed
4. Next LLM request auto-loads model

### Architecture

```
Open WebUI → STT Proxy (:7866) → llama.cpp /models/unload
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

## Troubleshooting

### Hyprland STT not working

```bash
# Check server
systemctl --user status whisper-server

# Check keybindings
hyprctl keybinds | grep stt

# Test manually
hypr-stt toggle
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

# Unload llama.cpp
llama-router unload

# Or switch GPU mode
ai-stack gpu stt   # For STT
ai-stack gpu llm   # For LLM
```

---

## Key Differences

| Aspect | Hyprland Keybindings | Open WebUI |
|--------|---------------------|------------|
| **VRAM Management** | Manual | Automatic |
| **Uses STT Proxy** | No | Yes |
| **Endpoint** | Direct (:7861) | Proxy (:7866) |
| **Scope** | System-wide | Open WebUI only |
| **Unload llama.cpp** | User responsibility | STT Proxy handles |

---

**Remember:** 
- **Hyprland (Super+N):** You manage VRAM
- **Open WebUI (🎤):** STT Proxy manages VRAM
