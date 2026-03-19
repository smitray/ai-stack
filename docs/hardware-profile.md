# Hardware Profile — RTX 3050 Laptop

**Machine:** ASUS TUF Gaming A15 (FA506IC) - Laptop  
**Last Updated:** March 19, 2026

---

## Specs

| Component | Detail |
|-----------|--------|
| **CPU** | AMD Ryzen 7 4800H (8 cores / 16 threads, 2.9-4.3 GHz) |
| **RAM** | 16 GB DDR4 @ 3200 MHz |
| **GPU (Discrete)** | NVIDIA GeForce RTX 3050 Laptop — **4 GB VRAM (GDDR6)** |
| **GPU (Integrated)** | AMD Radeon Vega (Renoir) — used for display |
| **Storage** | Dual NVMe SSDs (see partition-table.md) |
| **Network** | Gigabit Ethernet (Realtek), WiFi 6 (MediaTek MT7921) |
| **Audio** | PipeWire 1.6.2 |
| **Display** | 2560x1440@144Hz (primary) + 1920x1080@144Hz (secondary) |

---

## OS / Environment

| Component | Detail |
|-----------|--------|
| **Distro** | CachyOS (Arch-based) |
| **Kernel** | 6.19.7-1-cachyos |
| **Compositor** | Hyprland 0.54.2 (Wayland) |
| **NVIDIA Driver** | 595.45.04 |
| **Python Runtime** | mise-managed, Python 3.14.3 |
| **Shell** | ZSH (sources `~/.env`) |

---

## GPU Details: RTX 3050 Laptop

| Specification | Value |
|--------------|-------|
| GPU Code | GA107 |
| Architecture | Ampere |
| CUDA Cores | 2048 |
| Tensor Cores | 64 (3rd gen) |
| RT Cores | 16 (2nd gen) |
| VRAM | 4 GB GDDR6 |
| Memory Bus | 128-bit |
| Memory Bandwidth | 192 GB/s |
| CUDA Compute | **sm_86 (8.6)** |
| TGP | 60-80W |
| Process | 8nm Samsung |
| PCIe Interface | PCIe 4.0 x8 |
| **NVLink Support** | **❌ NOT AVAILABLE** |

### NVLink / Multi-GPU Status

| Feature | Support | Notes |
|---------|---------|-------|
| NVLink Bridge Connectors | ❌ None | Physical connectors not present on mobile GPU |
| NVLink Support | ❌ No | Laptop GPUs do not support NVLink |
| PCIe P2P | ⚠️ Limited | Depends on motherboard topology |
| Multi-GPU Split Modes | ❌ N/A | Single GPU only |

**Implication for llama.cpp:** Use default split mode (`--split-mode none`). Layer/row split modes require multiple GPUs.

---

## VRAM Budget (4096 MB total)

This is the **primary hardware constraint**. All GPU-accelerated services share this 4 GB pool.

**Display rendering is handled by the integrated AMD Radeon (iGPU).** The NVIDIA dGPU is almost entirely free for compute workloads (~4070 MiB usable).

### Updated VRAM Usage (March 19, 2026)

| Service | VRAM Usage | Notes |
|---------|-----------|-------|
| Baseline (Xorg + Hyprland) | ~26 MiB | Minimal -- display on iGPU |
| **STT (large-v3-turbo)** | **~1500-2000 MiB** | CTranslate2 FP16, new model |
| **LLM (4B Q4_K_M)** | **~2000-2500 MiB** | GGUF quantized |
| **LLM (7B Q3_K_S)** | **~3000-3500 MiB** | Larger model, tight fit |

### VRAM States

| State | Used | Free | Notes |
|-------|------|------|-------|
| **All Idle** | ~26 MiB | ~4070 MiB | Baseline |
| **STT Loaded** | ~1500-2000 MiB | ~2070-2570 MiB | Enough for 3B LLM |
| **LLM Loaded (4B)** | ~2000-2500 MiB | ~1570-2070 MiB | Not enough for STT |
| **LLM Loaded (7B)** | ~3000-3500 MiB | ~570-1070 MiB | No coexistence |

### Key Constraints

1. **STT and LLM are mutually exclusive.** New STT model (large-v3-turbo) uses ~1.5-2 GB, leaving insufficient VRAM for LLM.
2. **One model at a time** - llama.cpp router mode with `--models-max 1` enforces this.
3. **Idle-based unloading** - Both services auto-unload after inactivity (STT: 10 min, LLM: 5 min).
4. **No NVLink** - Single GPU, no multi-GPU splitting possible.

---

## RAM Budget (16 GB total)

| Consumer | Estimated Usage |
|----------|----------------|
| OS + Desktop (Hyprland, waybar, etc.) | ~1.5-2 GB |
| Browser (typical) | ~2-4 GB |
| Podman containers (all Phase 1) | ~2-3 GB |
| llama.cpp CPU offload layers | Variable |
| Open WebUI embedding model | ~400 MB |
| **Available headroom** | **~5-8 GB** |

---

## Storage Budget

See `partition-table.md` for full layout.

| Mount | Size | Purpose for AI Stack |
|-------|------|---------------------|
| `/home` | 80 GB | XDG configs, scripts, runtimes |
| `/workspace` | 300 GB | This repo, development |
| `/srv` | 440 GB | Podman images, model weights, databases |

---

## CUDA Configuration (Arch Linux)

### Installation Path

```bash
CUDA_HOME=/opt/cuda
```

### Environment Variables (add to ~/.zshrc)

```bash
# CUDA Paths (Arch Linux)
export CUDA_HOME=/opt/cuda
export PATH=$CUDA_HOME/bin:$PATH
export LD_LIBRARY_PATH=$CUDA_HOME/lib64:$LD_LIBRARY_PATH
```

### Verify Installation

```bash
# Check CUDA toolkit
nvcc --version

# Check NVIDIA driver and VRAM
nvidia-smi

# Check CUDA compute capability
deviceQuery 2>&1 | grep "CUDA Capability"
```

---

## Service Deployment Strategy

### Bare-Metal Services (GPU)

| Service | Reason |
|---------|--------|
| **Whisper STT** | Direct GPU access, low latency for keybind trigger |
| **llama.cpp** | Direct GPU access, router mode for model switching |

### Container Services (CPU)

| Service | Reason |
|---------|--------|
| **LiteLLM** | CPU-bound API gateway, no GPU needed |
| **Open WebUI** | Frontend + RAG (embedding on CPU) |
| **PostgreSQL** | Database, CPU-only |
| **Valkey** | Cache, CPU-only |
| **Qdrant** | Vector DB, CPU-only |
| **SearXNG** | Metasearch, CPU-only |

---

## Model Specifications

### STT Model (Updated)

| Attribute | Value |
|-----------|-------|
| **Model** | `deepdml/faster-whisper-large-v3-turbo-ct2` |
| **Format** | CTranslate2 (FP16) |
| **Source** | Hugging Face Hub |
| **VRAM** | ~1.5-2 GB |
| **Why** | Fixes word skipping issues from smaller models |
| **Languages** | 100 languages |

### LLM Model Recommendations

| Model | Quantization | VRAM | Strengths | Download Command |
|-------|-------------|------|-----------|-----------------|
| `unsloth/Qwen3.5-4B-GGUF` | Q4_K_M | ~2-2.5 GB | All-rounder (recommended) | `hf download unsloth/Qwen3.5-4B-GGUF Q4_K_M.gguf` |
| `Qwen/Qwen2.5-Coder-3B-Instruct-GGUF` | Q4_K_M | ~2 GB | Coding specialist | `hf download Qwen/Qwen2.5-Coder-3B-Instruct-GGUF Q4_K_M.gguf` |
| `Mungert/Phi-4-mini-reasoning-GGUF` | Q4_K_M | ~2 GB | Best reasoning | `hf download Mungert/Phi-4-mini-reasoning-GGUF Q4_K_M.gguf` |

---

## Performance Expectations

### STT (Whisper large-v3-turbo)

| Metric | Expected |
|--------|----------|
| Load Time | ~3-5 seconds |
| Transcription Speed | ~1-2x real-time |
| VRAM Usage | ~1.5-2 GB |

### LLM (4B Q4_K_M)

| Metric | Expected |
|--------|----------|
| Load Time (cold) | ~5-10 seconds |
| Load Time (warm) | ~1-2 seconds |
| Token Generation | ~20-40 tokens/sec |
| VRAM Usage | ~2-2.5 GB |
| Context Window | 4096 tokens |

---

## Monitoring Commands

### VRAM Usage

```bash
# Simple view
nvidia-smi --query-gpu=memory.used,memory.free --format=csv

# Watch mode
watch -n 1 nvidia-smi
```

### Service Status

```bash
# Systemd services
systemctl --user status whisper-api llama-cpp

# Container services
podman compose -f containers/compose.yaml ps
```

### HF Cache

```bash
# List cached models
hf cache ls

# Check specific model
hf cache verify deepdml/faster-whisper-large-v3-turbo-ct2
```

---

## Troubleshooting

### VRAM Not Freeing

```bash
# Check what's using VRAM
nvidia-smi

# Stop services
systemctl --user stop whisper-api llama-cpp

# Verify freed
nvidia-smi --query-gpu=memory.used --format=csv
```

### CUDA Not Found

```bash
# Verify installation
ls -la /opt/cuda

# Check environment
echo $CUDA_HOME
echo $LD_LIBRARY_PATH
```

### Model Download Failed

```bash
# Clear HF cache and retry
hf cache rm deepdml/faster-whisper-large-v3-turbo-ct2
hf download deepdml/faster-whisper-large-v3-turbo-ct2
```

---

## References

- [RTX 3050 Laptop Specs](https://www.notebookcheck.net/NVIDIA-GeForce-RTX-3050-Laptop-GPU-Benchmarks-and-Specs.513790.0.html)
- [NVLink Compatibility Chart](https://www.pugetsystems.com/labs/articles/nvidia-nvlink-bridge-compatibility-chart-1330/)
- [llama.cpp Multi-GPU Discussion](https://github.com/ggml-org/llama.cpp/discussions/7678)
- [Hugging Face CLI Guide](https://huggingface.co/docs/huggingface_hub/guides/cli)
