# llama.cpp - Research Notes

**Last Updated:** March 18, 2026

---

## Server Architecture

llama-server has two modes:

### 1. Inference Mode (single model)
- Standard: `llama-server -m model.gguf -c 4096 -ngl 99`
- One model, one endpoint

### 2. Router Mode (multi-model, recommended for ai-stack)
- Start without specifying a model: `llama-server --models-preset presets.ini`
- Routes requests to correct backend based on `"model"` field in request body
- Auto-loads models on demand (disable with `--no-models-autoload`)
- `--models-max 1` -- only one model in VRAM at a time

---

## Models Preset INI Format

```ini
version = 1

; Global defaults (overridden per-model)
[*]
c = 4096
n-gpu-layers = 99
flash-attn = true
cache-type-k = q4_0
cache-type-v = q4_0
sleep-idle-seconds = 300

; Chat model - use HF repo as section name (recommended)
[unsloth/Qwen3.5-4B-GGUF:Q4_K_M]
c = 4096
chat-template = qwen
load-on-startup = false

; Coding model
[Qwen/Qwen2.5-Coder-3B-Instruct-GGUF:Q4_K_M]
c = 2048
chat-template = qwen
```

**Precedence:** CLI args > model-specific preset > global preset

**Exclusive preset options:**
- `load-on-startup` (boolean) -- preload model at server start
- `stop-timeout` (integer seconds) -- timeout for stopping model

---

## VRAM Management Flags

| Flag | Purpose | Recommended Value |
|------|---------|-------------------|
| `--sleep-idle-seconds N` | Auto-unload model after N seconds idle | 300-600 (5-10 min) |
| `--models-max 1` | Only one model in VRAM at a time | 1 (mandatory for 4GB) |
| `--n-gpu-layers N` | Layers offloaded to GPU | 99 (all) for 3B models |
| `--flash-attn on` | Enables flash attention (less VRAM) | on |
| `--cache-type-k q4_0` | Quantize K cache | q4_0 or iq4_nl |
| `--cache-type-v q4_0` | Quantize V cache | q4_0 or iq4_nl |
| `--fit` | Auto-adjust args to fit device memory | Use as safety net |

**Sleep/Wake lifecycle:**
1. Server starts, no model loaded (router mode)
2. Request arrives with `"model": "qwen-3b"` → model loaded into VRAM
3. Model serves requests
4. No requests for `sleep-idle-seconds` → model unloaded from VRAM
5. Health/props/models endpoints do NOT trigger wake or reset timer
6. Next request → model reloaded automatically

---

## VRAM Budget for RTX 3050 (4096 MiB)

With ~4070 MiB usable (display on iGPU), ~3270 MiB when STT loaded:

### 3B Models (best fit for 4GB)

| Model | Quant | Model Size | KV Cache (4K ctx, f16) | Total Est. | Fits? |
|-------|-------|-----------|----------------------|------------|-------|
| Qwen2.5-3B | Q4_K_M | ~2.0 GB | ~256 MB | ~2.5 GB | Yes |
| Qwen2.5-3B | Q4_K_S | ~1.8 GB | ~256 MB | ~2.3 GB | Yes |
| Phi-3.5-mini (3.8B) | Q4_K_M | ~2.4 GB | ~384 MB | ~3.0 GB | Yes |

### 7B Models (tight, needs KV cache quant)

| Model | Quant | Model Size | KV Cache (4K ctx, f16) | Total Est. | Fits? |
|-------|-------|-----------|----------------------|------------|-------|
| Qwen2.5-7B | Q4_K_M | ~4.4 GB | ~512 MB | ~5.0 GB | No (full GPU) |
| Qwen2.5-7B | Q3_K_S | ~3.0 GB | ~512 MB | ~3.7 GB | Tight |
| Qwen2.5-7B | IQ3_XS | ~2.8 GB | ~256 MB (q4_0) | ~3.3 GB | Maybe |

### With Flash Attention + KV Cache Quantization
- `--flash-attn on --cache-type-k q4_0 --cache-type-v q4_0`
- Reduces KV cache VRAM by ~4x vs f16
- Makes 7B Q3_K_S viable at 2K-4K context

---

## Build Configuration (Arch Linux / RTX 3050)

RTX 3050 Laptop = Ampere architecture = Compute Capability 8.6 (sm_86)

```bash
# Prerequisites (Arch)
pacman -S cmake gcc cuda cudnn

# Clone and build
git clone https://github.com/ggml-org/llama.cpp
cd llama.cpp
cmake -B build \
  -DGGML_CUDA=ON \
  -DGGML_NATIVE=ON \
  -DCMAKE_CUDA_ARCHITECTURES="86" \
  -DCMAKE_BUILD_TYPE=Release
cmake --build build --config Release -j$(nproc)
```

Binary output: `build/bin/llama-server`, `build/bin/llama-cli`, `build/bin/llama-quantize`

---

## Integration with STT (VRAM Orchestration)

The existing STT idle monitor pattern + llama-server's sleep-idle-seconds creates natural time-sharing:

```
STT active (826 MiB) → idle 10min → unloaded (26 MiB)
                                         ↓
LLM request via Open WebUI → llama-server wakes → loads model (~2-3 GB) → serves
                                         ↓
LLM idle N min → unloaded → VRAM free
                                         ↓
Super+N pressed → STT auto-starts → loads Whisper model (826 MiB) → serves
```

**Edge case:** If user sends LLM request while STT is loaded, llama-server will fail to allocate VRAM. Options:
1. Let it fail gracefully (user manually stops STT first)
2. The `ai-stack` CLI orchestrates: stops STT before starting LLM
3. llama-server uses `--fit` to partially offload to CPU (slower but works)
