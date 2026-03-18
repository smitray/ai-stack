# Whisper STT Architecture

**Date:** 2026-03-19  
**Status:** Approved  
**Model:** `deepdml/faster-whisper-large-v3-turbo-ct2`

---

## 1. Overview

The STT component provides speech-to-text transcription via a local Whisper API. It is designed for continuous operation with intelligent GPU memory management.

### Key Requirements

- **Model:** `deepdml/faster-whisper-large-v3-turbo-ct2` (replaces `small` due to accuracy issues)
- **VRAM:** ~1.5-2 GB (FP16 CTranslate2 format)
- **API:** OpenAI-compatible `/v1/audio/transcriptions`
- **Idle Unload:** Auto-unload model after 10 minutes of inactivity
- **Trigger:** Hyprland keybind (Super+N)

---

## 2. Architecture

```
bare-metal/stt/
├── pyproject.toml              # Project metadata, dependencies
├── src/whisper_stt/
│   ├── __init__.py            # Package init, version
│   ├── __main__.py            # Entry: python -m whisper_stt
│   ├── config.py              # Config management (YAML + env)
│   ├── models.py              # Pydantic request/response models
│   ├── server.py              # FastAPI application
│   ├── service.py             # Core transcription logic
│   └── logging_config.py      # Structured logging setup
├── scripts/
│   ├── whisper-client         # CLI client (bash)
│   └── idle-monitor.sh        # VRAM idle monitor
├── config/
│   ├── config.yaml            # Default config
│   └── logging.yaml           # Structured logging config
├── systemd/
│   ├── whisper-server.service
│   └── whisper-idle-monitor.service
├── tests/
│   ├── test_config.py
│   ├── test_models.py
│   ├── test_service.py
│   └── test_server.py
└── install.sh                 # Installation script
```

---

## 3. Layer Responsibilities

| Layer | File | Responsibility |
|-------|------|----------------|
| **Entry** | `__main__.py` | CLI entry, uvicorn startup |
| **API** | `server.py` | FastAPI routes, OpenAPI docs |
| **Business** | `service.py` | Transcription orchestration |
| **Config** | `config.py` | YAML loading, env overrides, validation |
| **Models** | `models.py` | Pydantic schemas for API |
| **Logging** | `logging_config.py` | Structured logging with rotation |

---

## 4. API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| `POST` | `/v1/audio/transcriptions` | OpenAI-compatible transcription |
| `GET` | `/health` | Simple health check |
| `GET` | `/ready` | Model loaded check |
| `GET` | `/status` | Detailed status (model, VRAM, device) |
| `GET` | `/vram` | GPU VRAM usage |

---

## 5. Configuration

### config.yaml

```yaml
server:
  host: "127.0.0.1"
  port: 7861
  workers: 1

model:
  name: "deepdml/faster-whisper-large-v3-turbo-ct2"
  device: "auto"
  compute_type: "float16"
  download_path: "/srv/llama-cpp/models"

gpu:
  min_vram_mb: 1500
  fallback_to_cpu: true

idle:
  timeout_seconds: 600
  check_interval: 10

logging:
  level: "INFO"
  format: "json"
  file: "/var/log/whisper-stt/server.log"
```

### Environment Overrides

```bash
WHISPER_PORT=7861
WHISPER_MODEL=deepdml/faster-whisper-large-v3-turbo-ct2
WHISPER_DEVICE=auto
```

---

## 6. VRAM Lifecycle

```
Idle (0 MiB)
    ↓
Super+N pressed
    ↓
Model loads (~1.5-2 GB)
    ↓
Transcribes audio
    ↓
Activity recorded
    ↓
Idle for 10 min
    ↓
Model unloads (0 MiB)
```

---

## 7. Dependencies

```toml
[project]
name = "whisper-stt"
version = "1.0.0"
requires-python = ">=3.10"

[project.dependencies]
fastapi = ">=0.109.0"
uvicorn = ">=0.27.0"
faster-whisper = ">=1.0.0"
ctranslate2 = ">=4.0.0"
pydantic = ">=2.0.0"
pyyaml = ">=6.0"
python-multipart = ">=0.0.6"
```

---

## 8. Systemd Services

### whisper-server.service

```ini
[Unit]
Description=Whisper STT API Server
After=network.target

[Service]
Type=simple
EnvironmentFile=%h/.env
ExecStart=%h/.local/share/ai-stack/whisper-venv/bin/python -m whisper_stt \
    --config %h/.config/ai-stack/stt/config.yaml
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=default.target
```

### whisper-idle-monitor.service

```ini
[Unit]
Description=Whisper Idle Monitor
After=whisper-server.service

[Service]
Type=simple
ExecStart=%h/.local/bin/whisper-idle-monitor.sh

[Install]
WantedBy=default.target
```

---

## 9. Testing Strategy

| Test File | Coverage |
|-----------|----------|
| `test_config.py` | YAML loading, env overrides, validation |
| `test_models.py` | Pydantic schema validation |
| `test_service.py` | Transcription logic, device detection |
| `test_server.py` | API endpoints, health checks |

---

## 10. Migration from POC

| POC Component | New Component | Status |
|---------------|---------------|--------|
| `poc/bin/whisper-api-server` | `src/whisper_stt/server.py` | Rewrite |
| `poc/bin/hypr-stt` | `scripts/whisper-client` | Merge + simplify |
| `poc/bin/whisper-ctl` | `scripts/whisper-client` | Merge + simplify |
| `poc/config/config.yaml` | `config/config.yaml` | Update model |
| `poc/config/whisper-idle-monitor.sh` | `scripts/idle-monitor.sh` | Improve |
| N/A | `tests/` | New |

---

## 11. Success Criteria

1. Model loads successfully with ~1.5-2 GB VRAM
2. Transcription accuracy improved (no skipped words)
3. API responds within 500ms for health checks
4. Idle monitor unloads model after 10 min
5. All unit tests pass
6. Systemd services start/stop cleanly
