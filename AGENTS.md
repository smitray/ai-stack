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
│   ├── llama-cpp/     # Local LLM server (OpenAI-compatible API)
│   └── doclific/      # AI documentation service (inactive by default, port 7864)
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
| LLM (Reasoning) | `Jackrong/Qwen3.5-4B-Claude-4.6-Opus-Reasoning-Distilled-v2-GGUF` (Q4_K_M) | ~2-2.5 GB | `~/.cache/huggingface/hub/models--Jackrong--Qwen3.5-4B-Claude-4.6-Opus-Reasoning-Distilled-v2-GGUF/` |
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

### VRAM Management: STT Proxy + llama.cpp Router Mode

**Two STT Workflows:**

1. **Hyprland Keybindings (Super+N)** - Direct to Whisper STT
2. **Open WebUI (Microphone icon)** - Via STT Proxy (with VRAM management)

---

#### **Workflow 1: Hyprland Keybindings (Super+N)**

```
User presses Super+N
    ↓
hypr-stt script (independent client)
    ↓
Records audio from microphone
    ↓
Sends directly to Whisper STT (:7861)
    ↓
Types transcription result
```

**Key Points:**
- **Does NOT use STT Proxy** - Direct connection to Whisper
- **Does NOT unload llama.cpp** - Assumes user manages VRAM via keybindings
- **Independent of Open WebUI** - Works system-wide
- **VRAM Management:** User manually unloads llama.cpp with `Super+Alt+R` before using STT

**Keybindings:**
| Shortcut | Command | Purpose |
|----------|---------|---------|
| <kbd>SUPER</kbd> + <kbd>N</kbd> | `hypr-stt toggle` | Start/stop recording |
| <kbd>SUPER</kbd> + <kbd>ALT</kbd> + <kbd>R</kbd> | `whisper-client stop` | Stop server (free VRAM) |
| <kbd>SUPER</kbd> + <kbd>SHIFT</kbd> + <kbd>S</kbd> | `whisper-client start` | Start server |

---

#### **Workflow 2: Open WebUI (Microphone Icon)**

```
Open WebUI (port 7860)
    ↓ Click microphone
    ↓
STT Proxy (port 7866)
    ├─→ POST /models/unload → llama.cpp Router API (port 7865)
    │   └─→ Unloads model via native API (faster than systemd)
    ├─→ Wait for Whisper STT ready (port 7861)
    └─→ Forward audio → Return transcription
```

**Key Points:**
- **Uses STT Proxy** - Automatic VRAM management
- **Auto-unloads llama.cpp** - No manual intervention needed
- **Open WebUI only** - Configured in compose.yaml

---

**llama.cpp Router Mode Features:**
- `--models-max 1`: Only 1 model loaded at a time (4GB VRAM constraint)
- `--sleep-idle-seconds 300`: Auto-unload after 5 min idle
- **API Endpoints:**
  - `GET /models` - List models with status
  - `POST /models/load` - Load a model
  - `POST /models/unload` - Unload a model (used by STT Proxy)

**Configuration:**
| Service | Port | Purpose | Used By |
|---------|------|---------|---------|
| STT Proxy | `7866` | VRAM-aware STT routing | Open WebUI |
| Whisper STT | `7861` | Transcription service | Both |
| llama.cpp Router | `7865` | LLM with model management API | Both |

**Environment Variables (Open WebUI):**
```yaml
AUDIO_STT_ENGINE: "openai"
AUDIO_STT_OPENAI_API_BASE_URL: "http://host.containers.internal:7866/v1"
AUDIO_STT_OPENAI_API_KEY: "sk-no-key-required"
AUDIO_STT_MODEL: "whisper-stt"
```

**Why llama.cpp Router Mode Doesn't Replace STT Proxy:**

llama.cpp router mode manages **only llama.cpp models (GGUF format)**:
- ✅ Can load/unload LLM models via `/models/unload`
- ❌ **Cannot manage Whisper STT** (different framework, CTranslate2 backend)
- ❌ **Cannot route `/v1/audio/transcriptions` requests**

Therefore, STT Proxy is still needed to:
1. Intercept STT requests from Open WebUI
2. Call llama.cpp's `/models/unload` API (native, faster than systemd)
3. Forward to Whisper STT
4. Return transcription

**Install STT Proxy:**
```bash
bash bare-metal/stt-proxy/install.sh
systemctl --user start stt-proxy
```

**Manual Configuration (if needed):**
1. Open Open WebUI at `http://localhost:7860`
2. Go to **Admin Settings** → **Audio** tab
3. Set Speech-to-Text Engine to `OpenAI`
4. Enter API Base URL: `http://localhost:7866/v1` (STT Proxy!)
5. Enter any API key (e.g., `sk-no-key-required`)
6. Click **Save**

**Voice Input in Open WebUI:**
- Click the **microphone icon** in the chat input
- STT Proxy calls llama.cpp `/models/unload` API (native, fast)
- Audio is sent to Whisper STT for transcription
- Transcribed text appears in the chat input
- llama.cpp model auto-reloads on next LLM request (or via `/models/load` API)

**Hyprland Keybindings (Super+N):**
- Press <kbd>SUPER</kbd> + <kbd>N</kbd> to toggle recording
- **Important:** Unload llama.cpp first with <kbd>SUPER</kbd> + <kbd>ALT</kbd> + <kbd>R</kbd> if LLM is loaded
- Or use `ai-stack gpu stt` to switch GPU mode

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
