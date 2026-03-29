# llama.cpp Router Mode + STT Proxy

## Overview

This implementation uses llama.cpp's **native router mode** for model management, with an STT Proxy to handle cross-service VRAM orchestration.

## Architecture

```
Open WebUI (7860)
    ├─→ llama.cpp Router (7865) ────→ LLM inference
    │       ├─ GET  /models
    │       ├─ POST /models/load
    │       └─ POST /models/unload
    │
    └─→ STT Proxy (7866) ──────────→ Whisper STT (7861)
            └─ Calls /models/unload before STT
```

## Quick Start

### 1. Install Components

```bash
# Install STT Proxy
bash bare-metal/stt-proxy/install.sh

# Install llama.cpp (if not already)
bash bare-metal/llama-cpp/install.sh
```

### 2. Start Services

```bash
# Start llama.cpp in router mode
systemctl --user start llama-cpp

# Start STT Proxy
systemctl --user start stt-proxy

# Check status
systemctl --user status llama-cpp stt-proxy
```

### 3. Test Router Mode

```bash
# Test all endpoints
test-router-mode.sh

# Or use the management CLI
ai-stack gpu status
ai-stack gpu off
curl http://localhost:7865/models
```

### 4. Configure Open WebUI

Open WebUI is pre-configured in `containers/compose.yaml`:

```yaml
AUDIO_STT_OPENAI_API_BASE_URL: "http://host.containers.internal:7866/v1"
```

To manually configure:
1. Open http://localhost:7860
2. Admin Settings → Audio
3. Speech-to-Text Engine: `OpenAI`
4. API Base URL: `http://localhost:7866/v1`
5. API Key: `sk-no-key-required`
6. Save

## llama.cpp Router Mode

### Configuration

**Service:** `~/.config/systemd/user/llama-cpp.service`

```ini
ExecStart=llama-server \
    --models-preset ~/.config/ai-stack/llama-cpp/presets.ini \
    --models-max 1 \
    --sleep-idle-seconds 300 \
    --host 127.0.0.1 \
    --port 7865
```

**Presets:** `~/.config/ai-stack/llama-cpp/presets.ini`

```ini
[*]
models-max = 1
sleep-idle-seconds = 300
n-gpu-layers = 99

[unsloth/Qwen3.5-4B-GGUF:Q4_K_M]
chat-template = qwen
load-on-startup = false
```

### API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/models` | GET | List all models with status |
| `/models/load` | POST | Load a model |
| `/models/unload` | POST | Unload a model |
| `/health` | GET | Health check |
| `/v1/chat/completions` | POST | Chat (auto-loads model) |

### Usage Examples

```bash
# List models
curl http://localhost:7865/models

# Unload model
curl -X POST http://localhost:7865/models/unload \
  -H "Content-Type: application/json" \
  -d '{"model": "unsloth/Qwen3.5-4B-GGUF:Q4_K_M"}'

# Load model
curl -X POST http://localhost:7865/models/load \
  -H "Content-Type: application/json" \
  -d '{"model": "unsloth/Qwen3.5-4B-GGUF:Q4_K_M"}'

# Chat (auto-loads model)
curl -X POST http://localhost:7865/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model": "unsloth/Qwen3.5-4B-GGUF:Q4_K_M", "messages": [{"role": "user", "content": "Hello"}]}'
```

### Management CLI

```bash
# Status
ai-stack gpu status

# Unload model
ai-stack gpu off

# Or via curl
curl http://localhost:7865/models
curl -X POST http://localhost:7865/models/unload
```

## STT Proxy

### Purpose

The STT Proxy intercepts STT requests from Open WebUI and:
1. Calls llama.cpp `/models/unload` API to free VRAM
2. Forwards audio to Whisper STT
3. Returns transcription

### Configuration

**Service:** `~/.config/systemd/user/stt-proxy.service`

```ini
ExecStart=python -m stt_proxy
```

**Port:** `7866`

### Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/v1/audio/transcriptions` | POST | Transcribe audio (with VRAM management) |
| `/health` | GET | Health check |
| `/status` | GET | Service status |

### Test

```bash
# Run test suite
test-router-mode.sh

# Test health
curl http://localhost:7866/health

# Test status
curl http://localhost:7866/status
```

## VRAM Management Flow

```
1. User clicks microphone in Open WebUI
         ↓
2. Open WebUI → STT Proxy (:7866)
         ↓
3. STT Proxy: POST /models/unload → llama.cpp (:7865)
         ↓
4. llama.cpp unloads model (VRAM freed)
         ↓
5. STT Proxy forwards to Whisper (:7861)
         ↓
6. Whisper transcribes and returns
         ↓
7. Next LLM request auto-loads llama.cpp model
```

## Troubleshooting

### llama.cpp not responding

```bash
# Check service
systemctl --user status llama-cpp

# View logs
journalctl --user -u llama-cpp -f

# Restart
systemctl --user restart llama-cpp
```

### STT Proxy not working

```bash
# Check service
systemctl --user status stt-proxy

# View logs
journalctl --user -u stt-proxy -f

# Test endpoint
curl http://localhost:7866/health
```

### VRAM not freeing

```bash
# Check VRAM
nvidia-smi

# Manually unload
ai-stack gpu off

# Or via API
curl -X POST http://localhost:7865/models/unload
```

### Test suite fails

```bash
# Run with verbose output
bash -x test-router-mode.sh

# Check all services
systemctl --user status llama-cpp whisper-server stt-proxy
```

## Monitoring

```bash
# Watch VRAM usage
watch -n1 nvidia-smi

# Watch model status
watch -n2 'curl -s http://localhost:7865/models | jq'

# Combined monitoring
tmux
  # Pane 1: nvidia-smi
  # Pane 2: journalctl -u llama-cpp -f
  # Pane 3: journalctl -u stt-proxy -f
```

## Performance

| Operation | Time | Method |
|-----------|------|--------|
| Model unload (API) | ~1s | Native `/models/unload` |
| Model unload (systemd) | ~5s | `systemctl stop` |
| Model load | ~10-30s | From HF cache |
| STT transcription | ~5-60s | Depends on audio length |

## Key Files

| File | Purpose |
|------|---------|
| `bare-metal/llama-cpp/config/llama-cpp.service` | llama.cpp systemd service |
| `bare-metal/llama-cpp/config/presets.ini` | Router mode configuration |
| `bare-metal/stt-proxy/stt_proxy.py` | STT Proxy application |
| `bare-metal/stt-proxy/systemd/stt-proxy.service` | STT Proxy systemd service |
| `bin/ai-stack` | Main management CLI |
| `bare-metal/stt-proxy/test-router-mode.sh` | Test suite |
