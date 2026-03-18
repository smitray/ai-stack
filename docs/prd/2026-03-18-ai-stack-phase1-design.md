# ai-stack Design Specification

**Date:** 2026-03-18
**Author:** debasmitr + Antigravity
**Status:** Draft

---

## 1. Purpose

ai-stack is an infrastructure automation repository that reproducibly sets up a personal AI stack on Arch Linux (CachyOS). It provides bash and python scripts to install, configure, and manage a collection of AI services split across two deployment modes:

- **Bare metal** -- GPU-dependent services (STT, llama.cpp) installed directly on the host
- **Podman containers** -- All other services orchestrated via `podman compose`

The stack is designed for a single user on a single machine with constrained hardware (4 GB VRAM, 16 GB RAM).

---

## 2. Hardware Constraints

| Component | Spec | Impact |
|-----------|------|--------|
| GPU | RTX 3050 Laptop, 4 GB VRAM | Only one GPU service active at a time |
| RAM | 16 GB DDR4 | ~5-8 GB available for stack after OS + browser |
| CPU | Ryzen 7 4800H (8c/16t) | Sufficient for CPU offload and container workloads |
| Storage | Dual NVMe, `/srv` = 440 GB for Podman data | Ample for models and databases |
| Display | iGPU (AMD Radeon) drives displays | dGPU fully available for compute (~4070 MiB usable) |

**Critical constraint:** STT and local LLM are mutually exclusive in VRAM. Only one can be loaded at any time.

---

## 3. Phase 1 Services

### 3.1 Service Inventory

| Service | Deployment | Port | GPU | Purpose |
|---------|-----------|------|-----|---------|
| **Whisper STT** | Bare metal | 7861 | Yes (~1.5-2 GB) | Speech-to-text via Faster-Whisper (large-v3-turbo) |
| **llama.cpp** | Bare metal | 8080 | Yes (~2-3.5 GB) | Local LLM inference server |
| **LiteLLM** | Podman | 4000 | No | API gateway routing local + cloud LLMs |
| **Open WebUI** | Podman | 3000 | No | Chat UI, RAG, web search |
| **SearXNG** | Podman | 8888 | No | Privacy-respecting metasearch |
| **Qdrant** | Podman | 6333 | No | Vector database for RAG |
| **Valkey** | Podman | 6379 | No | Cache/rate-limiting (Redis-compatible) |
| **PostgreSQL** | Podman | 5432 | No | Relational DB for LiteLLM + Open WebUI |

### 3.2 Runtime Data Flow

Shows how data moves between services at runtime. This is **not** the compose startup order (see 3.3).

```
  ┌─────────────┐
  │  Open WebUI  │ :3000
  │  (Frontend)  │
  └──┬──┬──┬──┬─┘
     │  │  │  │
     │  │  │  └──────────────────────┐
     │  │  └───────────┐             │
     │  │              ▼             ▼
     │  │        ┌──────────┐  ┌──────────┐
     │  │        │  Qdrant  │  │ SearXNG  │ :8888
     │  │        │ :6333    │  │ (Search) │
     │  │        └──────────┘  └──────────┘
     │  │
     │  └──► PostgreSQL :5432 (chat history, user data)
     │
     ▼
  ┌──────────┐
  │ LiteLLM  │ :4000
  │ (Gateway)│
  └──┬──┬──┬─┘
     │  │  │
     │  │  └──► SearXNG :8888 (tool call web search)
     │  │
     │  └──► Cloud APIs (Gemini, Groq, OpenRouter, Anthropic)
     │
     └──► llama.cpp :8080 (bare metal, local LLM)

  LiteLLM ──► PostgreSQL :5432 (spend tracking, virtual keys)
  LiteLLM ──► Valkey :6379 (response cache, rate limiting)
  SearXNG ──► Valkey :6379 (rate limiting)

  ┌─────────────┐
  │ Whisper STT │ :7861  (bare metal, independent, keybind-triggered)
  └─────────────┘
```

### 3.3 Compose Startup Order & Health Checks

Podman compose `depends_on` with health check conditions:

**Tier 1 -- No dependencies (start first):**
- **PostgreSQL** -- healthcheck: `pg_isready -U aistack`
- **Valkey** -- healthcheck: `valkey-cli ping`
- **Qdrant** -- healthcheck: `curl -f http://localhost:6333/readyz`

**Tier 2 -- Depend on Tier 1:**
- **SearXNG** -- depends on Valkey (`service_healthy`) for rate limiting; healthcheck: `curl -f http://localhost:8080/healthz`
- **LiteLLM** -- depends on PostgreSQL (`service_healthy`), Valkey (`service_healthy`); healthcheck: `curl -f http://localhost:4000/health/liveliness`

**Tier 3 -- Depend on Tier 2:**
- **Open WebUI** -- depends on LiteLLM (`service_healthy`), PostgreSQL (`service_healthy`), Qdrant (`service_healthy`), SearXNG (`service_started`)

All `depends_on` entries use `condition: service_healthy` unless noted. This prevents crash-loops from containers connecting to unready backends.

**Bare metal services are independent (not in compose):**
- **Whisper STT** -- systemd user service, on-demand via keybind
- **llama.cpp** -- systemd user service, on-demand with sleep-idle. Restart policy: `Restart=on-failure`, `RestartSec=5s`

---

## 4. Architecture

### 4.1 Bare Metal Layer

#### Whisper STT (rewritten for quality)

The ai-stack repo implements a production-quality STT service with proper architecture (FastAPI + Pydantic + structured logging).

**Model:** `deepdml/faster-whisper-large-v3-turbo-ct2` (chosen for accuracy - fixes word skipping issues)

**Key components:**
- `whisper_stt` Python package (`src/whisper_stt/`)
  - `server.py` -- FastAPI application with OpenAI-compatible API
  - `service.py` -- Transcription orchestration logic
  - `config.py` -- YAML config with environment overrides
  - `models.py` -- Pydantic schemas for request/response validation
- `whisper-client` -- Unified bash CLI (merged hypr-stt + whisper-ctl functionality)
- `idle-monitor.sh` -- Auto-unloads model after 10 min idle
- systemd user services for lifecycle management

**VRAM lifecycle:**
```
Idle (0 MiB) → Super+N pressed → model loads (~1.5-2 GB) → transcribes → idle 10 min → unloads (0 MiB)
```

**Systemd service config:**
- `Restart=on-failure`, `RestartSec=5s`
- No watchdog

#### llama.cpp (new)

Built from source with CUDA support targeting sm_86 (RTX 3050 Ampere).

**Server mode:** Router mode with `--models-preset` INI file.

**Key flags:**
- `--models-preset presets.ini` -- Model definitions
- `--models-max 1` -- One model in VRAM at a time
- `--sleep-idle-seconds 300` -- Auto-unload after 5 min idle
- `--flash-attn on` -- Reduce VRAM for attention
- `--cache-type-k q4_0 --cache-type-v q4_0` -- Quantized KV cache

**Model strategy:**
- 3B models (Qwen2.5-3B, etc.) at Q4_K_M: ~2.0-2.5 GB VRAM, 4K context
- 7B models at Q3_K_S with KV quant: ~3.0-3.5 GB VRAM, 2K context
- Models stored at `/srv/llama-cpp/models/` (persistent across OS reinstalls, NVMe 1)

**VRAM lifecycle:**
```
Idle (0 MiB) → LLM request via LiteLLM → model loads (~2-3 GB) → serves → idle 5 min → unloads (0 MiB)
```

### 4.2 Container Layer

All containerized services run in a single Podman pod via `podman compose`, sharing a bridge network. Containers communicate by service name (DNS resolution within the Podman network).

**Host binding:** `127.0.0.1` only (localhost). No LAN exposure in Phase 1.

**Container memory limits:** Hard `mem_limit` set in `compose.yaml` to prevent any single service from consuming all available RAM:

| Service | `mem_limit` |
|---------|-------------|
| PostgreSQL | 512m |
| Valkey | 384m |
| Qdrant | 512m |
| SearXNG | 256m |
| LiteLLM | 512m |
| Open WebUI | 1g |

#### LiteLLM (API Gateway)

Central routing layer. All consumers talk to `localhost:4000`, never directly to providers.

**Capabilities:**
- Routes between local llama.cpp and cloud APIs (Anthropic, OpenAI, Google Gemini, Groq, OpenRouter)
- Fallback: local → cloud when local is unavailable (VRAM occupied by STT)
- Per-provider rate limiting (TPM/RPM)
- Spend tracking via PostgreSQL
- Virtual API keys
- SearXNG web search integration (tool call interception)
- Response caching via Valkey

**Cloud providers configured:**
- Google Gemini
- Groq
- OpenRouter
- Anthropic

#### Open WebUI (Chat Frontend)

Single backend: LiteLLM at `localhost:4000/v1`. Model dropdown populated from LiteLLM's `/v1/models` endpoint.

**Capabilities:**
- Chat UI with model selection (all models from LiteLLM visible)
- RAG via Qdrant (document upload → chunk → embed → semantic search)
- Web search via SearXNG
- Tool/function calling
- PostgreSQL for persistent chat history

**Auth:** Disabled (`WEBUI_AUTH=false`). Single user, localhost only.

**Embedding model for RAG:** `nomic-ai/nomic-embed-text-v1.5`
- 768-dimensional embeddings (Matryoshka-capable, can reduce to 256/128 if needed)
- Runs on CPU via SentenceTransformers engine (no GPU needed)
- ~300-500 MB additional RAM when loaded in Open WebUI
- Configured via environment variables:
  ```
  RAG_EMBEDDING_ENGINE=              # empty = SentenceTransformers (local CPU)
  RAG_EMBEDDING_MODEL=nomic-ai/nomic-embed-text-v1.5
  RAG_EMBEDDING_BATCH_SIZE=26
  ```

#### SearXNG (Search)

Privacy-respecting metasearch. Used by both Open WebUI (UI-level search) and LiteLLM (API-level tool calls).

**Engines enabled:** Google, DuckDuckGo, Wikipedia, GitHub, Stack Overflow, Arch Wiki.

**Rate limiting:** Via Valkey integration.

#### Qdrant (Vector DB)

Stores document embeddings for RAG. Open WebUI handles embedding generation; Qdrant only stores and queries vectors.

**Config:** `on_disk_payload: true` to save RAM.

#### Valkey (Cache)

Multi-tenant cache using Redis database numbers:
- DB 0: SearXNG rate limiting
- DB 1: LiteLLM caching + rate limiting

**Config:** `maxmemory 256mb`, `allkeys-lru` eviction, AOF persistence.

#### PostgreSQL

Shared relational database:
- Database `litellm`: virtual keys, spend logs, rate limits
- Database `openwebui`: chat history, user data, settings

**Image:** `postgres:17-alpine` (lightweight).

---

## 5. VRAM Orchestration

### 5.1 Mutual Exclusion Model

STT and local LLM are mutually exclusive. The system enforces this through idle timeouts -- not an active orchestrator.

| State | STT VRAM | LLM VRAM | Total | Available |
|-------|----------|----------|-------|-----------|
| Both idle | 0 MiB | 0 MiB | ~26 MiB | ~4070 MiB |
| STT active | ~826 MiB | 0 MiB | ~826 MiB | ~3270 MiB |
| LLM active (3B) | 0 MiB | ~2500 MiB | ~2500 MiB | ~1570 MiB |
| LLM active (7B) | 0 MiB | ~3500 MiB | ~3500 MiB | ~570 MiB |

### 5.2 Conflict Resolution

When STT is loaded and a local LLM request arrives:
1. llama-server attempts to allocate VRAM → fails (or fits if using small model)
2. LiteLLM detects failure → marks local deployment as "cooled down"
3. LiteLLM falls back to cloud API (e.g., Gemini, Groq)
4. After cooldown period (default: 60s, configurable via `router_settings.cooldown_time`), LiteLLM retries local on next request
5. Meanwhile, STT idle monitor unloads Whisper after 10 min
6. Next local LLM request succeeds (VRAM free)

**LiteLLM cooldown config:**
```yaml
router_settings:
  allowed_fails: 3        # failures before cooldown
  cooldown_time: 60        # seconds before retrying failed deployment
  retry_policy:
    TimeoutError: 2
    InternalServerError: 3
```

**This requires zero custom orchestration code.** LiteLLM's built-in fallback + llama-server's sleep-idle + STT's idle monitor handle everything.

### 5.3 Manual Override

The `ai-stack` CLI provides explicit switching for when you want immediate control:
```bash
ai-stack gpu stt    # Stops llama-server, starts STT
ai-stack gpu llm    # Stops STT, starts llama-server
ai-stack gpu off    # Stops both, frees all VRAM
ai-stack gpu status # Shows what's loaded and VRAM usage
```

---

## 6. Repository Structure

```
ai-stack/
├── bare-metal/
│   ├── stt/
│   │   ├── install.sh              # Arch-specific: pip deps, systemd units, keybinds
│   │   ├── config/                 # Config templates (config.yaml, systemd units)
│   │   ├── docs/                   # WHISPER-*.md knowledge base
│   │   └── poc/                    # Original POC code (reference only)
│   │       ├── bin/                # hypr-stt, whisper-ctl, etc.
│   │       ├── config/             # Original configs
│   │       └── systemd/            # Original service files
│   └── llama-cpp/
│       ├── install.sh              # Build from source (CUDA, sm_86)
│       ├── config/                 # presets.ini, systemd units
│       └── docs/                   # Research notes
│
├── containers/
│   ├── compose.yaml                # All Podman services
│   ├── open-webui/
│   │   ├── config/                 # Custom overrides
│   │   └── docs/                   # Research notes
│   ├── litellm/
│   │   ├── config/                 # litellm-config.yaml
│   │   └── docs/                   # Research notes
│   ├── searxng/
│   │   ├── config/                 # settings.yml, uwsgi.ini
│   │   └── docs/                   # Research notes
│   ├── qdrant/
│   │   ├── config/                 # production.yaml
│   │   └── docs/                   # Research notes
│   ├── valkey/
│   │   ├── config/                 # valkey.conf (optional)
│   │   └── docs/                   # Research notes
│   └── postgres/
│       ├── config/                 # init.sql (multi-DB setup)
│       └── docs/                   # Research notes
│
├── bin/
│   └── ai-stack                    # Main CLI script
│
├── lib/
│   └── common.sh                   # Shared bash helpers
│
├── docs/
│   ├── prd/                        # PRDs and architecture docs
│   ├── hardware-profile.md         # Hardware constraints reference
│   └── partition-table.md          # Storage layout reference
│
├── .env.example                    # Global env template
├── .gitignore
└── LICENSE
```

---

## 7. CLI Design (`bin/ai-stack`)

Single entry point bash script with subcommands:

### 7.1 Container Management

```bash
ai-stack up                    # Start all Podman services
ai-stack down                  # Stop all Podman services
ai-stack restart [service]     # Restart specific service or all
ai-stack status                # Show status of all services
ai-stack logs [service]        # Tail logs for a service
```

### 7.2 GPU Management

```bash
ai-stack gpu status            # Show VRAM usage and what's loaded
ai-stack gpu stt               # Activate STT mode (stop LLM, start STT)
ai-stack gpu llm               # Activate LLM mode (stop STT, start LLM)
ai-stack gpu off               # Free all VRAM
```

### 7.3 Installation

```bash
ai-stack install stt           # Run bare-metal/stt/install.sh
ai-stack install llama-cpp     # Run bare-metal/llama-cpp/install.sh
ai-stack install containers    # Pull images, create volumes, initialize DBs
ai-stack install all           # Full setup
```

### 7.4 Zsh Aliases (optional convenience)

```bash
# In ~/.zshrc or sourced from ai-stack
alias ais="ai-stack status"
alias aiu="ai-stack up"
alias aid="ai-stack down"
alias aigstt="ai-stack gpu stt"
alias aigllm="ai-stack gpu llm"
```

### 7.5 Hyprland Keybinds

```conf
# In ~/.config/hypr/keybindings.conf
# Existing STT keybinds remain
bind = SUPER, N, exec, hypr-stt toggle

# New: GPU mode switching
bind = SUPER ALT, L, exec, ai-stack gpu llm
bind = SUPER ALT, S, exec, ai-stack gpu stt
bind = SUPER ALT, O, exec, ai-stack gpu off
```

---

## 8. Configuration Management

### 8.1 Environment Variables

A single `.env` file at the repo root (gitignored) holds all secrets and host-specific config. The `compose.yaml` references it via `env_file: ../.env` (one level up from `containers/` to repo root). Template in `.env.example`:

```bash
# === Cloud API Keys ===
ANTHROPIC_API_KEY=
GOOGLE_API_KEY=
GROQ_API_KEY=
OPENROUTER_API_KEY=

# === LiteLLM ===
LITELLM_MASTER_KEY=sk-ai-stack-master-key
LITELLM_DATABASE_URL=postgresql://litellm:${LITELLM_DB_PASSWORD}@postgres:5432/litellm

# === PostgreSQL ===
POSTGRES_PASSWORD=
LITELLM_DB_PASSWORD=
OPENWEBUI_DB_PASSWORD=

# === Open WebUI ===
WEBUI_SECRET_KEY=
OPENWEBUI_DATABASE_URL=postgresql://openwebui:${OPENWEBUI_DB_PASSWORD}@postgres:5432/openwebui

# === Paths (XDG defaults, overridable) ===
AI_STACK_DATA_DIR=${XDG_DATA_HOME:-$HOME/.local/share}/ai-stack
AI_STACK_CONFIG_DIR=${XDG_CONFIG_HOME:-$HOME/.config}/ai-stack
AI_STACK_MODELS_DIR=/srv/llama-cpp/models
```

**Loading strategy:**
- `containers/compose.yaml` uses `env_file` to load from the root `.env`
- `bare-metal/*/install.sh` scripts source the root `.env` for path variables
- No second `.env.example` exists in `containers/` -- single source of truth

### 8.2 Config File Locations

| Service | Config Source (repo) | Deploy Target |
|---------|---------------------|---------------|
| STT | `bare-metal/stt/config/` | `~/.config/whisper-api/` |
| llama.cpp | `bare-metal/llama-cpp/config/` | `~/.config/llama-cpp/` |
| LiteLLM | `containers/litellm/config/` | Mounted into container |
| SearXNG | `containers/searxng/config/` | Mounted into container |
| Qdrant | `containers/qdrant/config/` | Mounted into container |

---

## 9. Data Persistence

### 9.1 Podman Volumes

| Volume | Mount Point | Content |
|--------|------------|---------|
| `postgres-data` | `/var/lib/postgresql/data` | All SQL data |
| `valkey-data` | `/data` | Cache persistence |
| `qdrant-storage` | `/qdrant/storage` | Vector collections |
| `qdrant-snapshots` | `/qdrant/snapshots` | Backups |
| `open-webui-data` | `/app/backend/data` | Uploads, cache |

### 9.2 Future: /srv Migration (Phase 2)

Per partition-table.md, Podman data will eventually live on `/srv` (NVMe 1, 440 GB). This means configuring Podman's `graphroot` to `/srv/containers/` and mapping named volumes to `/srv/databases/`, `/srv/openwebui/`, etc. This is a Phase 2 task.

---

## 10. Resource Budget (Phase 1)

### 10.1 RAM Budget

| Service | Estimated RAM |
|---------|--------------|
| PostgreSQL | ~150 MB |
| Valkey | ~256 MB (capped) |
| Qdrant | ~200 MB |
| SearXNG | ~150 MB |
| LiteLLM | ~300 MB |
| Open WebUI (app) | ~400 MB |
| Open WebUI (embedding model) | ~400 MB |
| **Container total** | **~1.9 GB** |
| OS + Desktop | ~2 GB |
| Browser (typical) | ~3 GB |
| **Headroom** | **~9.1 GB** |

Note: The embedding model (`nomic-embed-text-v1.5`) runs inside the Open WebUI container on CPU. It loads on first RAG operation and stays resident. The ~400 MB estimate covers the model weights in RAM.

### 10.2 VRAM Budget

| State | Used | Free | Notes |
|-------|------|------|-------|
| All idle | 26 MiB | 4070 MiB | Baseline |
| STT loaded (large-v3-turbo) | ~1500-2000 MiB | ~2070-2570 MiB | Enough for 3B LLM at Q4_K_M |
| LLM loaded (3B Q4_K_M) | ~2500 MiB | ~1570 MiB | Not enough for STT |
| LLM loaded (7B Q3_K_S) | ~3500 MiB | ~570 MiB | No coexistence possible |

**Coexistence:** STT + 3B LLM might fit together (~4-4.5 GB needed), but 7B models are mutually exclusive with STT.

---

## 11. Phase 2 Scope (Future)

Not designed in this spec, but noted for awareness:

- TTS + voice cloning
- Crawl4AI (web crawling)
- Docling (document processing)
- RAG pipeline improvements
- LAN-wide access (other devices on home network)
- `/srv` partition migration for Podman data
- Image generation (ComfyUI or API-based)

---

## 12. Success Criteria

Phase 1 is complete when:

1. `ai-stack install all` on a fresh CachyOS machine sets up the entire stack
2. STT works via Super+N (existing functionality preserved)
3. llama.cpp serves local models via LiteLLM with idle-based VRAM management
4. Open WebUI shows all models (local + cloud) from LiteLLM
5. Web search works via SearXNG (both in Open WebUI and via LiteLLM tool calls)
6. RAG works via document upload in Open WebUI → Qdrant
7. Cloud API fallback works when local GPU is occupied
8. `ai-stack gpu stt/llm/off` switches GPU modes
9. `ai-stack up/down/status` manages container lifecycle
10. All config is reproducible from the repo (no manual steps beyond `.env`)
