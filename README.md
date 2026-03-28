# AI Stack

Infrastructure automation for a personal AI workstation on Arch Linux (CachyOS). Manages a hybrid deployment where GPU-intensive services (STT, LLM) run bare-metal, while CPU-bound services (UI, search, database) run in Podman containers.

## 🖥️ Hardware Profile

| Component | Specification |
|-----------|---------------|
| **Laptop** | ASUS TUF Gaming A15 |
| **GPU** | NVIDIA RTX 3050 Laptop (4 GB VRAM) |
| **CPU** | AMD Ryzen 7 4800H |
| **RAM** | 16 GB |
| **OS** | Arch Linux (CachyOS) |
| **NVIDIA Driver** | 595.45.04+ |

## ⚠️ Critical Constraints

### VRAM Management (4 GB Total)

GPU services are **mutually exclusive** — only one can hold VRAM at a time:

| Service | VRAM Usage | Notes |
|---------|------------|-------|
| **STT** (Faster-Whisper) | ~1.5-2 GB | Manual trigger via keybind |
| **LLM** (4B Q4_K_M) | ~2-2.5 GB | Direct connection to Open WebUI |
| **LLM** (7B Q3_K_S) | ~3-3.5 GB | Direct connection to Open WebUI |

**Orchestration:** Built-in via llama.cpp sleep-idle + STT idle-monitor + `ai-stack gpu` commands. No LiteLLM gateway required.

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     User Interfaces                          │
├─────────────────────────────────────────────────────────────┤
│  Open WebUI (7860)  │  Hyprland Keybindings  │  CLI Tools   │
└──────────┬──────────┴──────────┬─────────────┴──────┬───────┘
           │                     │                     │
           ▼                     ▼                     ▼
┌──────────────────┐   ┌─────────────────┐   ┌────────────────┐
│   STT Proxy      │   │  Whisper STT    │   │ llama.cpp      │
│   (7866)         │   │  (7861)         │   │ Router (7865)  │
│   VRAM Orch.     │   │  FastAPI        │   │ OpenAI API     │
└────────┬─────────┘   └────────┬────────┘   └───────┬────────┘
         │                      │                     │
         └──────────────────────┼─────────────────────┘
                                │
                    ┌───────────▼───────────┐
                    │    GPU (RTX 3050)     │
                    │    4 GB VRAM          │
                    └───────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│              Container Services (Podman + CPU)               │
├──────────────┬──────────────┬──────────────┬────────────────┤
│  PostgreSQL  │    Qdrant    │   SearXNG    │     n8n        │
│  (5432)      │   (6333)     │   (7863)     │    (7862)      │
│  Chat DB     │  Vector DB   │  Web Search  │  Automation    │
└──────────────┴──────────────┴──────────────┴────────────────┘
```

## 📁 Project Structure

```
ai-stack/
├── bin/
│   ├── ai-stack                    # Main management CLI
│   └── llama-router                # llama.cpp router management
│
├── bare-metal/
│   ├── stt/                        # Whisper STT server
│   │   ├── src/whisper_stt/        # Python package (FastAPI)
│   │   ├── config/config.yaml      # STT configuration
│   │   ├── scripts/                # Management scripts
│   │   ├── systemd/                # Systemd service files
│   │   └── install.sh              # Installation script
│   │
│   ├── stt-proxy/                  # VRAM orchestration proxy
│   │   ├── stt_proxy.py
│   │   ├── systemd/
│   │   └── install.sh
│   │
│   ├── llama-cpp/                  # Local LLM server
│       ├── config/
│       │   ├── llama-cpp.service
│       │   └── presets.ini         # Router mode config
│       └── install.sh
│   │
│   └── doclific/                   # Local AI documentation tool
│       ├── systemd/
│       └── install.sh
│
├── containers/
│   ├── compose.yaml                # Podman services orchestration
│   ├── open-webui/                 # Chat UI
│   ├── postgres/                   # Database
│   ├── qdrant/                     # Vector database
│   ├── searxng/                    # Web search
│   ├── valkey/                     # Cache
│   └── n8n/                        # Workflow automation
│
├── lib/
│   └── install-base.sh             # System bootstrap script
│
├── templates/
│   └── zshenv.template             # Environment template
│
├── docs/
│   ├── prd/                        # Design specifications
│   ├── superpowers/plans/          # Implementation plans
│   ├── hardware-profile.md
│   ├── huggingface-cli-guide.md
│   ├── llama-cpp-router-mode.md
│   ├── stt-architecture.md
│   └── partition-table.md
│
├── AGENTS.md                       # Developer guide
├── IMPLEMENTATION_SUMMARY.md       # Implementation status
└── LICENSE
```

## 🚀 Quick Start

### Prerequisites

- Arch Linux (CachyOS) with NVIDIA drivers (595.45.04+)
- CUDA toolkit installed at `/opt/cuda`
- Podman and podman-compose
- NVIDIA Container Toolkit
- Python 3.10+
- Hugging Face account (for model downloads)

### Installation

**One-liner Installation:**

```bash
curl -fsSL https://raw.githubusercontent.com/smitray/ai-stack/main/install.sh | bash
```

**Manual Installation:**

```bash
# 1. Clone repository
git clone https://github.com/smitray/ai-stack.git ~/ai-stack
cd ~/ai-stack

# 2. Run base installation
bash lib/install-base.sh

# 3. Configure environment variables
# Edit ~/.zshenv and add your API keys (see Configuration section)

# 4. Source environment
source ~/.zshenv

# 5. Install all components
ai-stack install all
```

### Verify Installation

```bash
# Check container status
ai-stack status

# Check GPU services
ai-stack gpu status

# Check VRAM usage
nvidia-smi --query-gpu=memory.used,memory.free --format=csv
```

## ⚙️ Configuration

### Environment Variables (~/.zshenv)

```bash
# Cloud API Keys (optional)
export ANTHROPIC_API_KEY=""
export GOOGLE_API_KEY=""
export GROQ_API_KEY=""
export OPENROUTER_API_KEY=""

# Hugging Face (required for model downloads)
export HF_TOKEN="hf_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"

# PostgreSQL
export POSTGRES_USER=aistack
export POSTGRES_PASSWORD="<generate-secure-password>"
export OPENWEBUI_DB_PASSWORD="<generate-secure-password>"

# Open WebUI
export WEBUI_SECRET_KEY="<generate-secure-key>"

# Qdrant
export QDRANT_API_KEY="<generate-secure-key>"

# SearXNG
export SEARXNG_SECRET="<generate-secure-secret>"

# Paths (XDG defaults)
export AI_STACK_DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/ai-stack"
export AI_STACK_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/ai-stack"
export AI_STACK_MODELS_DIR="${HOME}/.cache/huggingface/hub"

# CUDA Paths (Arch Linux)
export CUDA_HOME=/opt/cuda
export PATH="$CUDA_HOME/bin:$PATH"
export LD_LIBRARY_PATH="$CUDA_HOME/lib64:$LD_LIBRARY_PATH"
```

### STT Configuration (~/.config/ai-stack/stt/config.yaml)

```yaml
server:
  host: "127.0.0.1"
  port: 7861
  workers: 1

model:
  name: "deepdml/faster-whisper-large-v3-turbo-ct2"
  device: "auto"
  compute_type: "float16"

gpu:
  min_vram_mb: 1500
  fallback_to_cpu: true

idle:
  timeout_seconds: 600  # 10 minutes
  check_interval: 10
```

### llama.cpp Configuration (~/.config/ai-stack/llama-cpp/presets.ini)

```ini
version = 1

[*]
models-max = 1                  # ONE model at a time (4GB VRAM)
sleep-idle-seconds = 300        # 5 min idle timeout
n-gpu-layers = 99               # Full GPU offload
c = 4096                        # Context window
flash-attn = true               # Reduce VRAM for attention
cache-type-k = q4_0             # Quantized KV cache
cache-type-v = q4_0

[unsloth/Qwen3.5-4B-GGUF:Q4_K_M]
chat-template = qwen
load-on-startup = false
```

## 📖 Usage

### Main CLI Commands

#### Container Management

```bash
ai-stack up                    # Start all containers
ai-stack down                  # Stop all containers
ai-stack restart [service]     # Restart specific service
ai-stack status                # Show container status
ai-stack logs [service]        # View logs
```

#### GPU Mode Management

```bash
ai-stack gpu stt               # Switch to STT mode (stop LLM, start STT)
ai-stack gpu llm               # Switch to LLM mode (stop STT, start LLM)
ai-stack gpu off               # Stop all GPU services
ai-stack gpu status            # Show GPU and service status
```

#### VRAM Orchestration

```bash
ai-stack vram stt              # Unload LLM, prepare for STT
ai-stack vram llm              # Wait for STT, prepare for LLM
ai-stack vram status           # Show VRAM status
ai-stack vram state            # Show state file content
ai-stack vram clear            # Clear state file
ai-stack vram history          # Show VRAM switch history
```

#### Model Management

```bash
ai-stack models list                    # List downloaded models
ai-stack models status                  # Check download status
ai-stack models download <repo>         # Download specific model
ai-stack models add-llama <n> <repo>    # Add model to presets
ai-stack models cleanup [--dry-run]     # Cleanup HF cache
```

### STT CLI (whisper-client)

```bash
whisper-client start           # Start STT server
whisper-client stop            # Stop STT server (free VRAM)
whisper-client restart         # Restart server
whisper-client status          # Show detailed status
whisper-client health          # Check health endpoint
whisper-client vram            # Show GPU VRAM usage
whisper-client wait-ready      # Wait for server to be ready
```

### llama.cpp Router CLI (llama-router)

```bash
llama-router models            # List all models with status
llama-router load <model>      # Load specific model
llama-router unload [model]    # Unload current model
llama-router status            # Show router status
llama-router health            # Check health endpoint
```

### Systemd Service Management

```bash
# STT services
systemctl --user start whisper-server
systemctl --user stop whisper-server
systemctl --user status whisper-server

# llama.cpp service
systemctl --user start llama-cpp
systemctl --user stop llama-cpp
systemctl --user status llama-cpp

# STT Proxy service
systemctl --user start stt-proxy
systemctl --user stop stt-proxy
systemctl --user status stt-proxy

# View logs
journalctl --user -u whisper-server -f
journalctl --user -u llama-cpp -f
journalctl --user -u stt-proxy -f
```

### Hyprland Keybindings

| Shortcut | Command | Purpose |
|----------|---------|---------|
| <kbd>SUPER</kbd> + <kbd>N</kbd> | `hypr-stt toggle` | Start/stop recording (system-wide) |
| <kbd>SUPER</kbd> + <kbd>ALT</kbd> + <kbd>R</kbd> | `whisper-client stop` | Stop STT server (free VRAM) |
| <kbd>SUPER</kbd> + <kbd>SHIFT</kbd> + <kbd>S</kbd> | `whisper-client start` | Start STT server |

## 🧠 Models

### Model Reference

| Service | Model | VRAM | Cache Path |
|---------|-------|------|------------|
| **STT** | `deepdml/faster-whisper-large-v3-turbo-ct2` | ~1.5-2 GB | `~/.cache/huggingface/hub/models--deepdml--faster-whisper-large-v3-turbo-ct2/` |
| **LLM** (Default) | `unsloth/Qwen3.5-4B-GGUF:Q4_K_M` | ~2-2.5 GB | `~/.cache/huggingface/hub/models--unsloth--Qwen3.5-4B-GGUF/` |
| **LLM** (Reasoning) | `Jackrong/Qwen3.5-4B-Claude-4.6-Opus-Reasoning-Distilled-v2-GGUF:Q4_K_M` | ~2-2.5 GB | `~/.cache/huggingface/hub/models--Jackrong--.../` |
| **Embedding** | `nomic-ai/nomic-embed-text-v1.5` | ~400 MB | Auto-download by Open WebUI |

### Download Models Manually

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

## 🧪 Services Overview

### Bare-Metal Services (GPU)

| Service | Port | VRAM | Purpose |
|---------|------|------|---------|
| **Whisper STT** | 7861 | ~1.5-2 GB | Speech-to-text via Faster-Whisper |
| **llama.cpp Router** | 7865 | ~2-2.5 GB | Local LLM inference (OpenAI-compatible API) |
| **STT Proxy** | 7866 | None | VRAM orchestration for Open WebUI |

### Bare-Metal Services (CPU)

| Service | Port | Memory Limit | Purpose |
|---------|------|--------------|---------|
| **Doclific** | 7864 | None | Local documentation tool with AI support (inactive by default) |

### Container Services (CPU)

| Service | Port | Memory Limit | Purpose |
|---------|------|--------------|---------|
| **Open WebUI** | 7860 | 1 GB | Chat UI with RAG and web search |
| **PostgreSQL** | 5432 | 512 MB | Chat history database |
| **Qdrant** | 6333 | 512 MB | Vector database for RAG |
| **SearXNG** | 7863 | 256 MB | Privacy-respecting web search |
| **Valkey** | 6379 | 384 MB | Cache/rate-limiting (Redis-compatible) |
| **n8n** | 7862 | 1 GB | Workflow automation |

## 🔍 Testing

```bash
# Test STT Proxy + Router Mode integration
test-router-mode.sh

# Test individual services
curl http://localhost:7861/health      # Whisper STT
curl http://localhost:7865/health      # llama.cpp
curl http://localhost:7866/health      # STT Proxy
curl http://localhost:7860             # Open WebUI

# Monitor VRAM during testing
watch -n1 nvidia-smi
```

## 🐛 Troubleshooting

### VRAM Not Freeing

```bash
# Check what's using VRAM
nvidia-smi

# Force unload
ai-stack vram stt
# or
llama-router unload

# Stop services
systemctl --user stop whisper-server llama-cpp
```

### Container Won't Start

```bash
# Check logs
podman compose -f containers/compose.yaml logs <service>

# Check dependencies
podman compose -f containers/compose.yaml ps
```

### STT Not Responding

```bash
curl http://localhost:7861/health
systemctl --user status whisper-server
journalctl --user -u whisper-server -f
```

### llama.cpp Not Responding

```bash
curl http://localhost:7865/v1/models
systemctl --user status llama-cpp
journalctl --user -u llama-cpp -f
```

### Common Issues

1. **CUDA paths on Arch Linux** - CUDA installs to `/opt/cuda`, not `/usr/local/cuda`. Always export:
   ```bash
   export CUDA_HOME=/opt/cuda
   export PATH=$CUDA_HOME/bin:$PATH
   export LD_LIBRARY_PATH=$CUDA_HOME/lib64:$LD_LIBRARY_PATH
   ```

2. **Podman only, no Docker** - All containers run in Podman. Docker commands will not work.

3. **Secrets in ~/.zshenv** - Never commit `.env` files. All secrets stored in `~/.zshenv` (gitignored).

4. **Hugging Face authentication required** - Set `HF_TOKEN` in `~/.zshenv` before installing models.

## 📊 Performance Expectations

| Operation | Time | Notes |
|-----------|------|-------|
| Model unload (native API) | ~1s | `POST /models/unload` |
| Model unload (systemd) | ~5s | `systemctl stop` |
| Model load (cold) | ~10-30s | From HF cache |
| Model load (warm) | ~1-2s | Already cached |
| STT transcription | ~5-60s | Depends on audio length |
| Token generation (4B) | ~20-40 tok/s | RTX 3050 Laptop |

## 💾 Storage Layout

All data stored in XDG directories:
- **Configs:** `~/.config/ai-stack/`
- **Data:** `~/.local/share/ai-stack/`
- **Models:** `~/.cache/huggingface/hub/`

On `/srv` partition (440 GB) for Podman volumes:
- `/srv/containers/` - Podman graphroot
- `/srv/databases/` - PostgreSQL, Qdrant, Valkey data
- `/srv/open-webui/` - Open WebUI uploads

## 📚 Documentation

- [AGENTS.md](AGENTS.md) - Developer guide
- [IMPLEMENTATION_SUMMARY.md](IMPLEMENTATION_SUMMARY.md) - Implementation status
- [docs/prd/](docs/prd/) - Design specifications
- [docs/superpowers/plans/](docs/superpowers/plans/) - Implementation plans
- [docs/hardware-profile.md](docs/hardware-profile.md) - Hardware specifications
- [docs/huggingface-cli-guide.md](docs/huggingface-cli-guide.md) - Model management guide
- [docs/llama-cpp-router-mode.md](docs/llama-cpp-router-mode.md) - Router configuration
- [docs/stt-architecture.md](docs/stt-architecture.md) - STT design document

## 📄 License

MIT License - see [LICENSE](LICENSE) for details.
