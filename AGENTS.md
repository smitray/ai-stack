# AI Stack — Developer Guide

## Overview

ai-stack is an infrastructure automation project for a personal AI workstation on Arch Linux (CachyOS). It manages a hybrid deployment: GPU-intensive services (STT, LLM) run bare-metal, while CPU-bound services (UI, search, database) run in Podman containers.

**Hardware:** ASUS TUF Gaming A15, RTX 3050 Laptop (4 GB VRAM), 16 GB RAM, Ryzen 7 4800H.

## Critical Constraints

### VRAM (4 GB total)

GPU services are **mutually exclusive** — only one can hold VRAM at a time:

| Service | VRAM | Notes |
|---------|------|-------|
| STT (large-v3-turbo) | ~1.5-2 GB | Manual trigger via keybind |
| LLM (3B Q4_K_M) | ~2-2.5 GB | Direct connection to Open WebUI |
| LLM (7B Q3_K_S) | ~3-3.5 GB | Direct connection to Open WebUI |

**Orchestration:** Built-in (llama.cpp sleep-idle + STT idle-monitor + ai-stack gpu). No LiteLLM gateway.

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
│   └── llama-cpp/     # Local LLM server (OpenAI-compatible API)
├── containers/
│   ├── compose.yaml   # Podman services
│   ├── open-webui/    # Chat UI (connects directly to llama.cpp)
│   ├── qdrant/        # Vector database for RAG
│   ├── searxng/       # Web search
│   └── postgres/      # Database for chat history
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

# Model management
ai-stack models list          # List downloaded models
ai-stack models status        # Check model download status
ai-stack models download <repo> # Download specific model

# VRAM status
nvidia-smi --query-gpu=memory.used,memory.free --format=csv
```

## Model Downloads

Models are downloaded via Hugging Face CLI to the central HF cache. Set `HF_TOKEN` in `~/.env`:
```bash
HF_TOKEN=hf_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

### HF Cache Location
All models are stored in: `~/.cache/huggingface/hub/`

### Download Commands
```bash
# Install HF CLI
pip install -U huggingface_hub[cli]

# Authenticate
hf auth login --token $HF_TOKEN

# Download STT model
hf download deepdml/faster-whisper-large-v3-turbo-ct2

# Download LLM model
hf download unsloth/Qwen3.5-4B-GGUF Q4_K_M.gguf

# Check cache
hf cache ls
```

### Model Reference

| Service | Model | VRAM | Cache Path |
|---------|-------|------|------------|
| STT | `deepdml/faster-whisper-large-v3-turbo-ct2` | ~1.5-2 GB | `~/.cache/huggingface/hub/models--deepdml--faster-whisper-large-v3-turbo-ct2/` |
| LLM | `unsloth/Qwen3.5-4B-GGUF` (Q4_K_M) | ~2-2.5 GB | `~/.cache/huggingface/hub/models--unsloth--Qwen3.5-4B-GGUF/` |
| Embedding | `nomic-ai/nomic-embed-text-v1.5` | ~400 MB | Auto-download by Open WebUI |

## Model Management CLI

The `ai-stack` CLI includes model management commands:

```bash
# List downloaded models
ai-stack models list

# Download specific model
ai-stack models download deepdml/faster-whisper-large-v3-turbo-ct2
ai-stack models download unsloth/Qwen3.5-4B-GGUF:Q4_K_M

# Add llama.cpp model to presets.ini
ai-stack models add-llama <name> <hf-repo> [--ctx-size 4096]

# Cleanup cache
ai-stack models cleanup [--dry-run]

# Check model download status
ai-stack models status
```

### Default Models Installation

During `ai-stack install all`:
1. HF CLI installed globally via pip
2. Authenticated with `HF_TOKEN` from `.env`
3. Default models pre-downloaded to HF cache:
   - STT: `deepdml/faster-whisper-large-v3-turbo-ct2`
   - LLM: `unsloth/Qwen3.5-4B-GGUF:Q4_K_M`

### llama.cpp Integration

llama.cpp uses `presets.ini` with `hf-repo` format:
```ini
[qwen-3b-chat]
hf-repo = unsloth/Qwen3.5-4B-GGUF:Q4_K_M
load-on-startup = true
```

Models auto-download on first use via HF cache. Only one model loaded at a time (`models-max = 1`).

### STT Architecture

The STT service has been rewritten as a production-quality FastAPI application:
- Python package (`whisper_stt/`) with modular structure
- OpenAI-compatible `/v1/audio/transcriptions` endpoint
- Pydantic validation + YAML config + structured JSON logging
- Systemd services: `whisper-server` + `whisper-idle-monitor` (10 min timeout)
- Unified bash CLI (`whisper-client`) for server management

## Troubleshooting

### VRAM not freeing
```bash
systemctl --user stop whisper-server llama-cpp
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

### LLM not responding
```bash
curl http://localhost:8080/v1/models
```
