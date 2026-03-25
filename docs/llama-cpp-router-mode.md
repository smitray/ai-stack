# llama.cpp Router Mode - Model Management

## Overview

llama.cpp server includes **router mode** - a built-in model management system that enables dynamic loading, unloading, and switching between multiple models without restarting the server.

## Key Features

| Feature | Description |
|---------|-------------|
| **On-Demand Loading** | Models load automatically when first requested |
| **LRU Eviction** | Least-recently-used model unloads when hitting `--models-max` |
| **Auto-Unload** | `--sleep-idle-seconds` unloads models after inactivity |
| **Multi-Process** | Each model runs in isolated child process |
| **Preset Support** | INI file for declarative model configuration |

## Hardware Context: RTX 3050 Laptop

| Specification | Value | Router Mode Implication |
|--------------|-------|------------------------|
| GPU | RTX 3050 Laptop (4 GB VRAM) | Only 1 model fits at a time |
| Architecture | Ampere (GA107) | CUDA compute sm_86 |
| NVLink | ❌ Not supported | No multi-GPU splitting |
| Split Mode | `none` (single GPU) | Default, no config needed |

## Quick Start

### Simple Mode (Recommended)

```bash
# Direct HF model loading - auto-downloads and caches
llama-server \
    -hf unsloth/Qwen3.5-4B-GGUF:Q4_K_M \
    --host 127.0.0.1 \
    --port 8080 \
    --sleep-idle-seconds 300
```

### Router with Presets (Advanced)

```bash
# Use INI file for multiple models
llama-server \
    --host 127.0.0.1 \
    --port 8080 \
    --models-max 1 \
    --models-preset presets.ini \
    --sleep-idle-seconds 300
```

## Presets INI File Format

### Example: Single Model with HF Auto-Download

```ini
[*]
# Global defaults - applied to all models
n-gpu-layers = 99
ctx-size = 4096
flash-attn = on
cache-type-k = q4_0
cache-type-v = q4_0

[qwen-3b]
# HF repo with quantization tag - auto-downloads on first use
hf-repo = unsloth/Qwen3.5-4B-GGUF:Q4_K_M
load-on-startup = true  # Pre-load on server start
```

### Example: Multiple Models (One at a Time)

```ini
[*]
# Global defaults
n-gpu-layers = 99
ctx-size = 4096
flash-attn = on
sleep-idle-seconds = 300

[qwen-3b-chat]
hf-repo = unsloth/Qwen3.5-4B-GGUF:Q4_K_M
chat-template = qwen

[qwen-3b-code]
hf-repo = Qwen/Qwen2.5-Coder-3B-Instruct-GGUF:Q4_K_M
chat-template = qwen

[phi-4-mini]
hf-repo = Mungert/Phi-4-mini-reasoning-GGUF:Q4_K_M
chat-template = phi
```

### INI Keys Reference

| Key | CLI Equivalent | Description |
|-----|---------------|-------------|
| `hf-repo` | `-hf` | HuggingFace repo in format `user/model:quant` |
| `model` | `-m` | Path to GGUF file (alternative to hf-repo) |
| `n-gpu-layers` | `-ngl` | GPU layers to offload |
| `ctx-size` | `-c` | Context window size |
| `flash-attn` | `--flash-attn` | Enable flash attention |
| `cache-type-k` | `--cache-type-k` | KV cache quantization |
| `cache-type-v` | `--cache-type-v` | KV cache quantization |
| `chat-template` | `--chat-template` | Chat template name |
| `load-on-startup` | (preset-only) | Pre-load model on start |
| `sleep-idle-seconds` | `--sleep-idle-seconds` | Auto-unload timeout |

## Command-Line Flags Reference

| Flag | Default | Description |
|------|---------|-------------|
| `--models-dir PATH` | (none) | Directory with GGUF files |
| `--models-preset PATH` | (none) | INI file with model configs |
| `--models-max N` | 4 | Max models loaded simultaneously |
| `--models-autoload` | enabled | Auto-load on first request |
| `--sleep-idle-seconds N` | 0 | Auto-unload after N seconds idle |
| `--no-models-autoload` | disabled | Require explicit `/models/load` calls |

## VRAM Management Strategy

### For 4 GB VRAM (RTX 3050 Laptop)

```
┌─────────────────────────────────────────────────────────┐
│  Idle State (0 MiB VRAM)                               │
│  - Server running, no model loaded                     │
│  - Ready to accept requests                            │
└─────────────────────────────────────────────────────────┘
                          ↓ Request arrives
┌─────────────────────────────────────────────────────────┐
│  Model Loading (~2-2.5 GB VRAM)                        │
│  - Load Q4_K_M quantized 4B model                      │
│  - Takes ~3-10 seconds (cold start)                    │
└─────────────────────────────────────────────────────────┘
                          ↓ Serving
┌─────────────────────────────────────────────────────────┐
│  Serving Requests (~2-2.5 GB VRAM)                     │
│  - Process chat completions                            │
│  - Activity recorded for idle tracking                 │
└─────────────────────────────────────────────────────────┘
                          ↓ 5 min idle (sleep-idle-seconds)
┌─────────────────────────────────────────────────────────┐
│  Auto-Unload (0 MiB VRAM)                              │
│  - Model unloaded, VRAM freed                          │
│  - Back to idle state                                  │
└─────────────────────────────────────────────────────────┘
```

### Configuration for Your Hardware

```ini
[*]
# Critical settings for 4GB VRAM
models-max = 1              # Only 1 model at a time
sleep-idle-seconds = 300    # 5 min idle timeout
n-gpu-layers = 99           # Full GPU offload
ctx-size = 4096             # Reasonable context (adjust based on VRAM)
flash-attn = on             # Reduce VRAM for attention
cache-type-k = q4_0         # Quantized KV cache (saves VRAM)
cache-type-v = q4_0
```

## API Usage

### OpenAI-Compatible Chat Completions

```bash
curl http://localhost:8080/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "qwen-3b-chat",
    "messages": [
      {"role": "user", "content": "Hello!"}
    ]
  }'
```

### List Available Models

```bash
curl http://localhost:8080/v1/models
```

### Load Model Explicitly (Optional)

```bash
curl -X POST http://localhost:8080/models/load \
  -H "Content-Type: application/json" \
  -d '{"model": "qwen-3b-chat"}'
```

### Unload Model

```bash
curl -X POST http://localhost:8080/models/unload
```

## Systemd Service Configuration

### Simple Mode (HF Auto-Download)

```ini
[Unit]
Description=llama.cpp Server
After=network.target

[Service]
Type=simple
EnvironmentFile=%h/.env
ExecStart=%h/.local/share/ai-stack/llama-cpp/llama-server \
    -hf unsloth/Qwen3.5-4B-GGUF:Q4_K_M \
    --host 127.0.0.1 \
    --port 8080 \
    --sleep-idle-seconds 300
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=default.target
```

### Router Mode (Multiple Models)

```ini
[Unit]
Description=llama.cpp Router Server
After=network.target

[Service]
Type=simple
EnvironmentFile=%h/.env
ExecStart=%h/.local/share/ai-stack/llama-cpp/llama-server \
    --host 127.0.0.1 \
    --port 8080 \
    --models-max 1 \
    --models-preset %h/.config/ai-stack/llama-cpp/presets.ini \
    --sleep-idle-seconds 300
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=default.target
```

## Integration with Open WebUI (LiteLLM Removed)

**⚠️ Update:** LiteLLM has been removed from ai-stack due to security concerns. Open WebUI now connects directly to llama.cpp.

### Direct Connection (Current)

```yaml
# Open WebUI environment (in compose.yaml)
OPENAI_API_BASE_URL=http://host.containers.internal:8080/v1
```

Open WebUI connects directly to llama.cpp router at `http://host.containers.internal:8080/v1` (or `localhost:8080` from host).

### Benefits
- Simpler architecture (no middleware)
- No dependency on external gateway
- Full control over VRAM management via `ai-stack gpu`

### Trade-offs
- No automatic cloud fallback when VRAM is occupied
- Manual VRAM management required: `ai-stack gpu stt` ↔ `ai-stack gpu llm`
- No virtual API keys or spend tracking

---

## Troubleshooting

### Model Not Loading

```bash
# Check HF cache
hf cache ls

# Verify model downloaded
ls -la ~/.cache/huggingface/hub/models--unsloth--Qwen3.5-4B-GGUF/

# Check llama.cpp logs
journalctl --user -u llama-cpp -f
```

### VRAM Not Freeing

```bash
# Check current VRAM usage
nvidia-smi --query-gpu=memory.used,memory.free --format=csv

# Force unload via API
curl -X POST http://localhost:8080/models/unload

# Restart service
systemctl --user restart llama-cpp
```

### Slow Cold Start

```ini
# Add to presets.ini for pre-loading
[qwen-3b]
hf-repo = unsloth/Qwen3.5-4B-GGUF:Q4_K_M
load-on-startup = true
```

## Best Practices

1. **Use `models-max = 1`** for 4GB VRAM - prevents OOM errors
2. **Set `sleep-idle-seconds`** - auto-frees VRAM when not in use
3. **Use Q4_K_M quantization** - best quality/size balance for 4B models
4. **Enable flash attention** - reduces VRAM usage
5. **Quantize KV cache** - `cache-type-k = q4_0` saves significant VRAM
6. **Pre-load critical models** - `load-on-startup = true` for frequently used models

## References

- [llama.cpp Server README](https://github.com/ggml-org/llama.cpp/blob/master/examples/server/README.md)
- [Hugging Face Model Management Blog](https://huggingface.co/blog/ggml-org/model-management-in-llamacpp)
- [Router Mode Discussion](https://github.com/ggml-org/llama.cpp/discussions/18939)
