# AI Stack — Developer Guide

## Overview

ai-stack is an infrastructure automation project for a personal AI workstation on Arch Linux (CachyOS). It manages a hybrid deployment: GPU-intensive services (STT, LLM) run bare-metal, while CPU-bound services (gateway, UI, search, database) run in Podman containers.

**Hardware:** ASUS TUF Gaming A15, RTX 3050 Laptop (4 GB VRAM), 16 GB RAM, Ryzen 7 4800H.

## Critical Constraints

### VRAM (4 GB total)

GPU services are **mutually exclusive** — only one can hold VRAM at a time:

| Service | VRAM | Notes |
|---------|------|-------|
| STT (large-v3-turbo) | ~1.5-2 GB | Manual trigger via keybind |
| LLM (3B Q4_K_M) | ~2-2.5 GB | Auto via LiteLLM |
| LLM (7B Q3_K_S) | ~3-3.5 GB | Auto via LiteLLM |

**Orchestration:** Built-in (llama.cpp sleep-idle + STT idle-monitor + LiteLLM fallback). No custom code needed.

### Environment

- **Secrets:** All in `~/.env` (API keys, HF_TOKEN). Never commit `.env`.
- **Shell:** ZSH. `~/.zshrc` sources `~/.env` and exports CUDA paths.
- **Container engine:** Podman only. No Docker.

### CUDA Paths

Arch Linux installs CUDA to `/opt/cuda`. Always export:
```bash
export CUDA_HOME=/opt/cuda
export PATH=$CUDA_HOME/bin:$PATH
export LD_LIBRARY_PATH=$CUDA_HOME/lib64:$LD_LIBRARY_PATH
```

## Project Structure

```
ai-stack/
├── bare-metal/
│   ├── stt/           # Whisper STT server + client
│   └── llama-cpp/     # Local LLM server
├── containers/
│   ├── compose.yaml   # Podman services
│   ├── litellm/      # API gateway
│   ├── open-webui/    # Chat UI
│   └── ...
├── bin/ai-stack       # Main CLI
└── lib/               # Shared scripts
```

## Development Workflow

1. **Branches:** Feature branches from `main`
2. **Commits:** Atomic commits per task. Every discrete task gets its own commit.
3. **Plan Mode:** Design must be approved before implementation.
4. **Testing:** Verify scripts work before committing.

## Key Files

| File | Purpose |
|------|---------|
| `AGENTS.md` | This file |
| `docs/prd/*.md` | Design specifications |
| `docs/superpowers/plans/*.md` | Implementation plans |
| `.env.example` | Environment template |
| `bin/ai-stack` | Main management CLI |

## Common Tasks

```bash
# Install everything
ai-stack install all

# Start/stop containers
ai-stack up
ai-stack down

# GPU mode switching
ai-stack gpu stt    # Activate STT
ai-stack gpu llm     # Activate LLM
ai-stack gpu off     # Free all VRAM
ai-stack gpu status # Show usage

# VRAM status
nvidia-smi --query-gpu=memory.used,memory.free --format=csv
```

## Model Downloads

Models are downloaded via Hugging Face. Set `HF_TOKEN` in `~/.env`:
```bash
HF_TOKEN=hf_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

| Service | Model | Location |
|---------|-------|----------|
| STT | `deepdml/faster-whisper-large-v3-turbo-ct2` | `/srv/llama-cpp/models` |
| LLM | Qwen2.5-3B-Instruct-Q4_K_M.gguf | `/srv/llama-cpp/models` |
| Embedding | `nomic-ai/nomic-embed-text-v1.5` | HuggingFace (auto-download) |

## Troubleshooting

### VRAM not freeing
```bash
systemctl --user stop whisper-api llama-cpp
nvidia-smi --query-gpu=memory.used --format=csv
```

### Container won't start
```bash
podman compose -f containers/compose.yaml logs <service>
```

### STT not responding
```bash
curl http://localhost:7861/health
```
