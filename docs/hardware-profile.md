# Hardware Profile

**Machine:** ASUS TUF Gaming A15 (FA506IC) - Laptop
**Last Updated:** March 18, 2026

---

## Specs

| Component | Detail |
|-----------|--------|
| **CPU** | AMD Ryzen 7 4800H (8 cores / 16 threads, 2.9-4.3 GHz) |
| **RAM** | 16 GB DDR4 |
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

---

## VRAM Budget (4096 MB total)

This is the primary hardware constraint. All GPU-accelerated services share this 4 GB pool.

**Display rendering is handled by the integrated AMD Radeon (iGPU).** The NVIDIA dGPU is almost entirely free for compute workloads.

| Service | VRAM Usage | Notes |
|---------|-----------|-------|
| Xorg + Hyprland (on dGPU) | ~26 MB | Minimal -- display is on iGPU |
| Whisper STT (small model) | ~600-700 MB | Freed after 10-min idle |
| **Available for LLM** | **~3.3-4.0 GB** | Depends on STT state |

### Key Constraints

1. **STT and LLM may struggle to coexist in VRAM.** STT uses ~700 MB, leaving ~3.3 GB. Depending on LLM model and quantization, they might fit together or need time-sharing via the idle monitor.
2. **LLM model sizes are constrained.** With ~3.3-4.0 GB usable, small-to-medium quantized models fit (e.g., 3B-8B at Q4_K_M). Larger models need partial CPU offloading (n_gpu_layers).
3. **No GPU passthrough for containers.** GPU services (STT, llama.cpp) run bare metal to avoid container GPU overhead.
4. **VRAM orchestration may be needed.** Depending on chosen model sizes, a mechanism to ensure only one GPU-heavy service is loaded at a time.

---

## RAM Budget (16 GB total)

| Consumer | Estimated Usage |
|----------|----------------|
| OS + Desktop (Hyprland, waybar, etc.) | ~1.5-2 GB |
| Browser (typical) | ~2-4 GB |
| Podman containers (all Phase 1) | ~2-3 GB |
| llama.cpp CPU offload layers | Variable |
| **Available headroom** | **~5-8 GB** |

---

## Storage Budget

See `partition-table.md` for full layout.

| Mount | Size | Purpose for AI Stack |
|-------|------|---------------------|
| `/home` | 80 GB | XDG configs, scripts, runtimes |
| `/workspace` | 300 GB | This repo, development |
| `/srv` | 440 GB | Podman images, model weights, databases |
