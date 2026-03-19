# Whisper STT Rewrite Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking. Every task MUST end with a git commit.

**Goal:** Rewrite the Whisper STT component with production-quality code, replacing the POC implementation with a proper FastAPI application using the `deepdml/faster-whisper-large-v3-turbo-ct2` model.

**Architecture:** Python package (`whisper_stt`) with FastAPI server, Pydantic models, YAML config, and structured logging. Bash CLI wrapper for client operations.

**Tech Stack:** Python 3.10+, FastAPI, uvicorn, faster-whisper, Pydantic, PyYAML, pytest.

---

## Chunk 1: Python Package Structure

**Files:**
- Create: `bare-metal/stt/pyproject.toml`
- Create: `bare-metal/stt/src/whisper_stt/__init__.py`
- Create: `bare-metal/stt/src/whisper_stt/__main__.py`
- Create: `bare-metal/stt/src/whisper_stt/config.py`
- Create: `bare-metal/stt/src/whisper_stt/models.py`
- Create: `bare-metal/stt/src/whisper_stt/logging_config.py`

### Task 1: Create Package Metadata and Init

- [ ] **Step 1: Write `bare-metal/stt/pyproject.toml`**

```toml
[project]
name = "whisper-stt"
version = "1.0.0"
description = "Whisper STT API server for local speech-to-text"
requires-python = ">=3.10"
dependencies = [
    "fastapi>=0.109.0",
    "uvicorn[standard]>=0.27.0",
    "faster-whisper>=1.0.0",
    "ctranslate2>=4.0.0",
    "pydantic>=2.0.0",
    "pyyaml>=6.0",
    "python-multipart>=0.0.6",
]

[project.optional-dependencies]
test = [
    "pytest>=7.0.0",
    "pytest-asyncio>=0.21.0",
    "httpx>=0.25.0",
]

[project.scripts]
whisper-stt = "whisper_stt.__main__:cli_entry"

[build-system]
requires = ["hatchling"]
build-backend = "hatchling.build"
```

- [ ] **Step 2: Create source directory structure**

```bash
mkdir -p bare-metal/stt/src/whisper_stt
mkdir -p bare-metal/stt/tests
```

- [ ] **Step 3: Write `bare-metal/stt/src/whisper_stt/__init__.py`**

```python
"""Whisper STT - Local speech-to-text API server."""

__version__ = "1.0.0"
```

- [ ] **Step 4: Commit package structure**

```bash
git add bare-metal/stt/pyproject.toml bare-metal/stt/src/whisper_stt/__init__.py
git commit -m "feat(stt): create python package structure with pyproject.toml"
```

### Task 2: Configuration Management

- [ ] **Step 1: Write `bare-metal/stt/src/whisper_stt/config.py`**

```python
"""Configuration management for Whisper STT."""

import os
from dataclasses import dataclass, field
from pathlib import Path
from typing import Optional

import yaml


@dataclass
class ServerConfig:
    """Server configuration."""
    host: str = "127.0.0.1"
    port: int = 7861
    workers: int = 1


@dataclass
class ModelConfig:
    """Model configuration."""
    name: str = "deepdml/faster-whisper-large-v3-turbo-ct2"
    device: str = "auto"  # auto, cuda, cpu
    compute_type: str = "float16"


@dataclass
class GPUConfig:
    """GPU configuration."""
    min_vram_mb: int = 1500
    fallback_to_cpu: bool = True


@dataclass
class IdleConfig:
    """Idle monitoring configuration."""
    timeout_seconds: int = 600
    check_interval: int = 10


@dataclass
class LoggingConfig:
    """Logging configuration."""
    level: str = "INFO"
    format: str = "json"
    file: Optional[str] = None


@dataclass
class Config:
    """Main configuration container."""
    server: ServerConfig = field(default_factory=ServerConfig)
    model: ModelConfig = field(default_factory=ModelConfig)
    gpu: GPUConfig = field(default_factory=GPUConfig)
    idle: IdleConfig = field(default_factory=IdleConfig)
    logging: LoggingConfig = field(default_factory=LoggingConfig)

    @classmethod
    def load(cls, config_path: Optional[Path] = None) -> "Config":
        """Load configuration from YAML file with environment overrides."""
        config = cls()

        # Load from YAML if provided
        if config_path and config_path.exists():
            with open(config_path) as f:
                data = yaml.safe_load(f)
                if data:
                    config._apply_dict(data)

        # Environment variable overrides
        config._apply_env()

        return config

    def _apply_dict(self, data: dict) -> None:
        """Apply configuration from dictionary."""
        if "server" in data:
            for key, value in data["server"].items():
                if hasattr(self.server, key):
                    setattr(self.server, key, value)

        if "model" in data:
            for key, value in data["model"].items():
                if hasattr(self.model, key):
                    setattr(self.model, key, value)

        if "gpu" in data:
            for key, value in data["gpu"].items():
                if hasattr(self.gpu, key):
                    setattr(self.gpu, key, value)

        if "idle" in data:
            for key, value in data["idle"].items():
                if hasattr(self.idle, key):
                    setattr(self.idle, key, value)

        if "logging" in data:
            for key, value in data["logging"].items():
                if hasattr(self.logging, key):
                    setattr(self.logging, key, value)

    def _apply_env(self) -> None:
        """Apply environment variable overrides."""
        if port := os.environ.get("WHISPER_PORT"):
            self.server.port = int(port)
        if model := os.environ.get("WHISPER_MODEL"):
            self.model.name = model
        if device := os.environ.get("WHISPER_DEVICE"):
            self.model.device = device
        if compute_type := os.environ.get("WHISPER_COMPUTE_TYPE"):
            self.model.compute_type = compute_type
```

- [ ] **Step 2: Commit config module**

```bash
git add bare-metal/stt/src/whisper_stt/config.py
git commit -m "feat(stt): add configuration management with YAML and env overrides"
```

### Task 3: Pydantic Models

- [ ] **Step 1: Write `bare-metal/stt/src/whisper_stt/models.py`**

```python
"""Pydantic models for API request/response validation."""

from pydantic import BaseModel, Field
from typing import Optional, List


class TranscriptionRequest(BaseModel):
    """Request model for transcription endpoint."""
    file: bytes  # Handled via Form in FastAPI
    model: Optional[str] = Field(default=None, description="Model to use")
    language: Optional[str] = Field(default=None, description="Language code")
    response_format: Optional[str] = Field(default="json", description="Response format")
    timestamp_granularities: Optional[List[str]] = Field(
        default=None, description="Timestamp granularities"
    )


class TranscriptionResponse(BaseModel):
    """Response model for transcription endpoint."""
    text: str = Field(..., description="Transcribed text")
    language: str = Field(..., description="Detected language")
    duration: float = Field(..., description="Audio duration in seconds")


class Segment(BaseModel):
    """Transcription segment with timing."""
    id: int
    start: float
    end: float
    text: str
    avg_logprob: float
    compression_ratio: float
    no_speech_prob: float


class DetailedTranscriptionResponse(BaseModel):
    """Detailed response with segments."""
    text: str
    segments: List[Segment]
    language: str
    duration: float


class HealthResponse(BaseModel):
    """Health check response."""
    status: str = "healthy"
    model_loaded: bool = False


class StatusResponse(BaseModel):
    """Detailed status response."""
    status: str
    model: str
    device: str
    compute_type: str
    model_loaded: bool
    used_mb: Optional[int] = None
    total_mb: Optional[int] = None
    percent: Optional[float] = None


class VRAMResponse(BaseModel):
    """VRAM usage response."""
    used_mb: int
    total_mb: int
    free_mb: int
    percent: float
```

- [ ] **Step 2: Commit models module**

```bash
git add bare-metal/stt/src/whisper_stt/models.py
git commit -m "feat(stt): add Pydantic models for API validation"
```

### Task 4: Logging Configuration

- [ ] **Step 1: Write `bare-metal/stt/src/whisper_stt/logging_config.py`**

```python
"""Structured logging configuration."""

import logging
import sys
from pathlib import Path
from logging.handlers import RotatingFileHandler
from typing import Optional


def setup_logging(
    level: str = "INFO",
    log_format: str = "json",
    log_file: Optional[str] = None,
) -> None:
    """Configure application logging.

    Args:
        level: Log level (DEBUG, INFO, WARNING, ERROR, CRITICAL)
        log_format: Format type (json or text)
        log_file: Optional path to log file
    """
    # Configure root logger
    root_logger = logging.getLogger()
    root_logger.setLevel(getattr(logging, level.upper()))

    # Remove existing handlers
    root_logger.handlers.clear()

    # Create formatter
    if log_format == "json":
        formatter = JsonFormatter()
    else:
        formatter = logging.Formatter(
            "%(asctime)s [%(levelname)s] %(name)s: %(message)s",
            datefmt="%Y-%m-%d %H:%M:%S",
        )

    # Console handler
    console_handler = logging.StreamHandler(sys.stdout)
    console_handler.setFormatter(formatter)
    console_handler.setLevel(logging.DEBUG)
    root_logger.addHandler(console_handler)

    # File handler (if configured)
    if log_file:
        log_path = Path(log_file)
        log_path.parent.mkdir(parents=True, exist_ok=True)
        file_handler = RotatingFileHandler(
            log_path,
            maxBytes=10 * 1024 * 1024,  # 10 MB
            backupCount=5,
        )
        file_handler.setFormatter(formatter)
        file_handler.setLevel(logging.INFO)
        root_logger.addHandler(file_handler)


class JsonFormatter(logging.Formatter):
    """JSON log formatter for structured logging."""

    def format(self, record: logging.LogRecord) -> str:
        """Format log record as JSON."""
        import json

        log_data = {
            "timestamp": self.formatTime(record),
            "level": record.levelname,
            "logger": record.name,
            "message": record.getMessage(),
        }

        if record.exc_info:
            log_data["exception"] = self.formatException(record.exc_info)

        return json.dumps(log_data)
```

- [ ] **Step 2: Commit logging module**

```bash
git add bare-metal/stt/src/whisper_stt/logging_config.py
git commit -m "feat(stt): add structured logging with JSON formatter"
```

---

## Chunk 2: Core Application

**Files:**
- Create: `bare-metal/stt/src/whisper_stt/service.py`
- Create: `bare-metal/stt/src/whisper_stt/server.py`

### Task 5: Transcription Service

- [ ] **Step 1: Write `bare-metal/stt/src/whisper_stt/service.py`**

```python
"""Core transcription service logic."""

import logging
from pathlib import Path
from typing import Optional, Tuple

from faster_whisper import WhisperModel

from .config import Config
from .models import Segment, DetailedTranscriptionResponse

logger = logging.getLogger(__name__)


class TranscriptionService:
    """Handles model loading and transcription."""

    def __init__(self, config: Config):
        self.config = config
        self.model: Optional[WhisperModel] = None
        self._model_path: Optional[Path] = None

    def load_model(self) -> None:
        """Load the Whisper model."""
        model_name = self.config.model.name
        device = self._detect_device()
        compute_type = self.config.model.compute_type

        logger.info(f"Loading model: {model_name} on {device} ({compute_type})")

        self.model = WhisperModel(
            model_name,
            device=device,
            compute_type=compute_type,
            download_root=self.config.model.download_path,
        )

        logger.info("Model loaded successfully")

    def _detect_device(self) -> str:
        """Detect best available device."""
        if self.config.model.device != "auto":
            return self.config.model.device

        # Try CUDA first
        try:
            import torch
            if torch.cuda.is_available():
                return "cuda"
        except ImportError:
            pass

        # Check for nvidia-smi
        import subprocess
        try:
            result = subprocess.run(
                ["nvidia-smi"],
                capture_output=True,
                timeout=5,
            )
            if result.returncode == 0:
                return "cuda"
        except (subprocess.TimeoutExpired, FileNotFoundError):
            pass

        logger.warning("GPU not available, falling back to CPU")
        return "cpu"

    def unload_model(self) -> None:
        """Unload the model to free VRAM."""
        if self.model is not None:
            logger.info("Unloading model to free VRAM")
            del self.model
            self.model = None

    def is_model_loaded(self) -> bool:
        """Check if model is loaded."""
        return self.model is not None

    def transcribe(
        self,
        audio_path: Path,
        language: Optional[str] = None,
    ) -> DetailedTranscriptionResponse:
        """Transcribe audio file.

        Args:
            audio_path: Path to audio file
            language: Optional language code (None for auto-detect)

        Returns:
            Transcription response with segments
        """
        if self.model is None:
            raise RuntimeError("Model not loaded")

        logger.info(f"Transcribing: {audio_path}")

        segments, info = self.model.transcribe(
            str(audio_path),
            language=language,
            vad_filter=True,  # Voice activity detection
            vad_parameters=dict(
                min_silence_duration_ms=500,
                speech_pad_ms=200,
            ),
        )

        # Convert segments to response format
        segment_list = []
        full_text = []

        for i, segment in enumerate(segments):
            segment_list.append(Segment(
                id=i,
                start=segment.start,
                end=segment.end,
                text=segment.text,
                avg_logprob=segment.avg_logprob,
                compression_ratio=segment.compression_ratio,
                no_speech_prob=segment.no_speech_prob,
            ))
            full_text.append(segment.text)

        return DetailedTranscriptionResponse(
            text="".join(full_text),
            segments=segment_list,
            language=info.language,
            duration=info.duration,
        )
```

- [ ] **Step 2: Commit service module**

```bash
git add bare-metal/stt/src/whisper_stt/service.py
git commit -m "feat(stt): add transcription service with device detection"
```

### Task 6: FastAPI Server

- [ ] **Step 1: Write `bare-metal/stt/src/whisper_stt/server.py`**

```python
"""FastAPI application for Whisper STT."""

import logging
import tempfile
from pathlib import Path
from typing import Optional

from fastapi import FastAPI, File, Form, UploadFile, HTTPException
from fastapi.responses import JSONResponse

from .config import Config
from .models import (
    HealthResponse,
    StatusResponse,
    VRAMResponse,
    DetailedTranscriptionResponse,
)
from .service import TranscriptionService

logger = logging.getLogger(__name__)


def create_app(config: Config) -> FastAPI:
    """Create and configure FastAPI application."""

    app = FastAPI(
        title="Whisper STT",
        description="Local speech-to-text API using Whisper",
        version="1.0.0",
    )

    # Initialize service
    service = TranscriptionService(config)

    @app.on_event("startup")
    async def startup_event():
        """Load model on startup."""
        service.load_model()

    @app.on_event("shutdown")
    async def shutdown_event():
        """Unload model on shutdown."""
        service.unload_model()

    @app.get("/health", response_model=HealthResponse)
    async def health_check():
        """Simple health check."""
        return HealthResponse(status="healthy", model_loaded=service.is_model_loaded())

    @app.get("/ready", response_model=HealthResponse)
    async def readiness_check():
        """Check if model is loaded and ready."""
        if not service.is_model_loaded():
            raise HTTPException(status_code=503, detail="Model not loaded")
        return HealthResponse(status="ready", model_loaded=True)

    @app.get("/status", response_model=StatusResponse)
    async def get_status():
        """Get detailed server status."""
        vram = _get_vram_info()

        return StatusResponse(
            status="ready" if service.is_model_loaded() else "loading",
            model=config.model.name,
            device=config.model.device,
            compute_type=config.model.compute_type,
            model_loaded=service.is_model_loaded(),
            used_mb=vram.get("used_mb"),
            total_mb=vram.get("total_mb"),
            percent=vram.get("percent"),
        )

    @app.get("/vram", response_model=VRAMResponse)
    async def get_vram():
        """Get GPU VRAM usage."""
        vram = _get_vram_info()
        return VRAMResponse(**vram)

    @app.post("/v1/audio/transcriptions", response_model=DetailedTranscriptionResponse)
    async def transcribe_audio(
        file: UploadFile = File(...),
        model: Optional[str] = Form(None),
        language: Optional[str] = Form(None),
        response_format: Optional[str] = Form("json"),
    ):
        """Transcribe audio file (OpenAI-compatible endpoint)."""
        if not service.is_model_loaded():
            raise HTTPException(status_code=503, detail="Model not loaded")

        # Validate file type
        if not file.content_type or not file.content_type.startswith("audio/"):
            raise HTTPException(status_code=400, detail="Invalid audio file")

        # Save uploaded file temporarily
        with tempfile.NamedTemporaryFile(delete=False, suffix=".wav") as tmp:
            content = await file.read()
            tmp.write(content)
            tmp_path = Path(tmp.name)

        try:
            # Transcribe
            result = service.transcribe(tmp_path, language)

            # Return based on format
            if response_format == "text":
                return JSONResponse(content={"text": result.text})
            elif response_format == "verbose_json":
                return result
            else:  # json
                return DetailedTranscriptionResponse(
                    text=result.text,
                    segments=result.segments,
                    language=result.language,
                    duration=result.duration,
                )
        finally:
            # Cleanup temp file
            tmp_path.unlink(missing_ok=True)

    def _get_vram_info() -> dict:
        """Get GPU VRAM information."""
        try:
            import subprocess
            result = subprocess.run(
                [
                    "nvidia-smi",
                    "--query-gpu=memory.used,memory.total,memory.free",
                    "--format=csv,noheader,nounits",
                ],
                capture_output=True,
                text=True,
                timeout=5,
            )
            if result.returncode == 0:
                used, total, free = map(int, result.stdout.strip().split(", "))
                return {
                    "used_mb": used,
                    "total_mb": total,
                    "free_mb": free,
                    "percent": round((used / total) * 100, 1) if total > 0 else 0,
                }
        except Exception as e:
            logger.debug(f"Failed to get VRAM info: {e}")

        return {
            "used_mb": 0,
            "total_mb": 0,
            "free_mb": 0,
            "percent": 0,
        }

    return app
```

- [ ] **Step 2: Commit server module**

```bash
git add bare-metal/stt/src/whisper_stt/server.py
git commit -m "feat(stt): add FastAPI server with OpenAI-compatible endpoint"
```

---

## Chunk 3: Entry Point and CLI

**Files:**
- Create: `bare-metal/stt/src/whisper_stt/__main__.py`
- Create: `bare-metal/stt/scripts/whisper-client`
- Create: `bare-metal/stt/scripts/idle-monitor.sh`

### Task 7: Main Entry Point

- [ ] **Step 1: Write `bare-metal/stt/src/whisper_stt/__main__.py`**

```python
"""Main entry point for Whisper STT."""

import argparse
import sys
from pathlib import Path

import uvicorn

from .config import Config
from .server import create_app
from .logging_config import setup_logging


def cli_entry():
    """CLI entry point for whisper-stt command."""
    parser = argparse.ArgumentParser(description="Whisper STT API Server")
    parser.add_argument(
        "--config", "-c",
        type=Path,
        help="Path to config file",
    )
    parser.add_argument(
        "--port", "-p",
        type=int,
        help="Server port (overrides config)",
    )
    parser.add_argument(
        "--host",
        type=str,
        help="Host to bind to (overrides config)",
    )
    parser.add_argument(
        "--log-level",
        type=str,
        choices=["debug", "info", "warning", "error"],
        help="Log level",
    )

    args = parser.parse_args()

    # Load configuration
    config = Config.load(args.config)

    # Apply CLI overrides
    if args.port:
        config.server.port = args.port
    if args.host:
        config.server.host = args.host
    if args.log_level:
        config.logging.level = args.log_level.upper()

    # Setup logging
    setup_logging(
        level=config.logging.level,
        log_format=config.logging.format,
        log_file=config.logging.file,
    )

    # Create app
    app = create_app(config)

    # Run server
    print(f"Starting Whisper STT on {config.server.host}:{config.server.port}")
    uvicorn.run(
        app,
        host=config.server.host,
        port=config.server.port,
        workers=config.server.workers,
    )


if __name__ == "__main__":
    cli_entry()
```

- [ ] **Step 2: Commit entry point**

```bash
git add bare-metal/stt/src/whisper_stt/__main__.py
git commit -m "feat(stt): add CLI entry point with uvicorn server"
```

### Task 8: Bash CLI Client

- [ ] **Step 1: Write `bare-metal/stt/scripts/whisper-client`**

```bash
#!/usr/bin/env bash
#
# whisper-client - Whisper STT CLI
#
# Unified client for Whisper STT server management and transcription.
#

set -euo pipefail

readonly SCRIPT_NAME="whisper-client"
readonly VERSION="1.0.0"

# Configuration
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/ai-stack/stt"
PORT_FILE="$CONFIG_DIR/port"
PORT="${WHISPER_PORT:-$(cat "$PORT_FILE" 2>/dev/null || echo 7861)}"
API_URL="http://localhost:$PORT"

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
log_success() { echo -e "${GREEN}[OK]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# Server management
cmd_start() {
    if systemctl --user start whisper-server.service 2>/dev/null; then
        log_info "Waiting for server to be ready..."
        local waited=0
        while [[ $waited -lt 120 ]]; do
            if curl -sf "$API_URL/ready" >/dev/null 2>&1; then
                log_success "Server ready"
                return 0
            fi
            sleep 1
            ((waited++))
        done
        log_error "Server timeout"
        return 1
    else
        log_error "Failed to start server"
        return 1
    fi
}

cmd_stop() {
    if systemctl --user stop whisper-server.service 2>/dev/null; then
        log_success "Server stopped"
    else
        log_info "Server not running"
    fi
}

cmd_status() {
    local response
    if response=$(curl -sf "$API_URL/status" 2>/dev/null); then
        echo "$response" | python3 -m json.tool
    else
        log_error "Server not responding"
        return 1
    fi
}

cmd_vram() {
    if command -v nvidia-smi &>/dev/null; then
        nvidia-smi --query-gpu=memory.used,memory.total,memory.free --format=csv
    else
        log_error "nvidia-smi not found"
    fi
}

cmd_health() {
    if curl -sf "$API_URL/health" >/dev/null 2>&1; then
        log_success "Server healthy"
    else
        log_error "Server unhealthy"
        return 1
    fi
}

cmd_help() {
    cat <<EOF
$SCRIPT_NAME v$VERSION - Whisper STT CLI

Usage: $SCRIPT_NAME <command>

Commands:
  start       Start the server
  stop        Stop the server
  status      Show server status
  vram        Show GPU VRAM usage
  health      Check server health
  help        Show this help

Environment Variables:
  WHISPER_PORT    API server port (default: 7861)
EOF
}

# Main
main() {
    local command="${1:-help}"
    shift || true

    case "$command" in
        start) cmd_start ;;
        stop) cmd_stop ;;
        status) cmd_status ;;
        vram) cmd_vram ;;
        health) cmd_health ;;
        help|--help|-h) cmd_help ;;
        *)
            log_error "Unknown command: $command"
            cmd_help
            exit 1
            ;;
    esac
}

main "$@"
```

- [ ] **Step 2: Make executable and commit**

```bash
chmod +x bare-metal/stt/scripts/whisper-client
git add bare-metal/stt/scripts/whisper-client
git commit -m "feat(stt): add unified bash CLI client"
```

### Task 9: Idle Monitor Script

- [ ] **Step 1: Write `bare-metal/stt/scripts/idle-monitor.sh`**

```bash
#!/usr/bin/env bash
#
# whisper-idle-monitor - Auto-unload model after idle timeout
#

set -euo pipefail

readonly IDLE_TIMEOUT=600  # 10 minutes
readonly CHECK_INTERVAL=10
readonly PORT="${WHISPER_PORT:-7861}"
readonly API_URL="http://localhost:$PORT"
readonly IDLE_FILE="/run/user/$(id -u)/whisper-api-idle"

log() {
    echo "[$(date '+%H:%M:%S')] [idle-monitor] $*" >&2
}

record_activity() {
    date +%s > "$IDLE_FILE" 2>/dev/null || true
}

get_last_activity() {
    if [[ -f "$IDLE_FILE" ]]; then
        cat "$IDLE_FILE" 2>/dev/null || date +%s
    else
        date +%s
    fi
}

is_server_running() {
    curl -sf "$API_URL/health" >/dev/null 2>&1
}

stop_server() {
    log "Stopping server (idle for ${IDLE_TIMEOUT}s)"
    notify-send "Whisper STT" "Server stopped (idle timeout - VRAM freed)" -u low 2>/dev/null || true
    systemctl --user stop whisper-server.service 2>/dev/null || true
    rm -f "$IDLE_FILE" 2>/dev/null || true
}

main() {
    log "Starting idle monitor (timeout: ${IDLE_TIMEOUT}s)"

    # Wait for server
    local wait_count=0
    while [[ $wait_count -lt 12 ]]; do
        if is_server_running; then
            log "Server detected"
            break
        fi
        sleep 5
        ((wait_count++))
    done

    if ! is_server_running; then
        log "Server not running, exiting"
        exit 0
    fi

    record_activity
    log "Activity tracking started"

    while is_server_running; do
        local last_activity current_time idle_time
        last_activity=$(get_last_activity)
        current_time=$(date +%s)
        idle_time=$((current_time - last_activity))

        log "Idle for ${idle_time}s"

        if [[ $idle_time -ge $IDLE_TIMEOUT ]]; then
            stop_server
            exit 0
        fi

        sleep "$CHECK_INTERVAL"
    done

    log "Server stopped, exiting"
    rm -f "$IDLE_FILE" 2>/dev/null || true
}

main "$@"
```

- [ ] **Step 2: Make executable and commit**

```bash
chmod +x bare-metal/stt/scripts/idle-monitor.sh
git add bare-metal/stt/scripts/idle-monitor.sh
git commit -m "feat(stt): add idle monitor for VRAM management"
```

---

## Chunk 4: Configuration and Systemd

**Files:**
- Create: `bare-metal/stt/config/config.yaml`
- Create: `bare-metal/stt/config/logging.yaml`
- Create: `bare-metal/stt/systemd/whisper-server.service`
- Create: `bare-metal/stt/systemd/whisper-idle-monitor.service`
- Modify: `bare-metal/stt/install.sh`

### Task 10: Configuration Files

- [ ] **Step 1: Write `bare-metal/stt/config/config.yaml`**

```yaml
# Whisper STT Configuration
# ~/.config/ai-stack/stt/config.yaml

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
  timeout_seconds: 600
  check_interval: 10

logging:
  level: "INFO"
  format: "json"
  file: ""  # Empty = stdout only
```

- [ ] **Step 2: Commit config**

```bash
git add bare-metal/stt/config/config.yaml
git commit -m "chore(stt): add default configuration file"
```

### Task 11: Systemd Services

- [ ] **Step 1: Write `bare-metal/stt/systemd/whisper-server.service`**

```ini
[Unit]
Description=Whisper STT API Server
After=network.target

[Service]
Type=simple
EnvironmentFile=%h/.env
WorkingDirectory=%h/.local/share/ai-stack/stt
ExecStart=%h/.local/share/ai-stack/stt/venv/bin/python -m whisper_stt \
    --config %h/.config/ai-stack/stt/config.yaml
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=default.target
```

- [ ] **Step 2: Write `bare-metal/stt/systemd/whisper-idle-monitor.service`**

```ini
[Unit]
Description=Whisper Idle Monitor
After=whisper-server.service

[Service]
Type=simple
EnvironmentFile=%h/.env
ExecStart=%h/.local/bin/whisper-idle-monitor.sh

[Install]
WantedBy=default.target
```

- [ ] **Step 3: Commit systemd units**

```bash
git add bare-metal/stt/systemd/*.service
git commit -m "chore(stt): add systemd service units"
```

### Task 12: Update Install Script

- [ ] **Step 1: Modify `bare-metal/stt/install.sh`**

```bash
#!/usr/bin/env bash
set -e

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source ~/.env

echo "Setting up Whisper STT..."

# Create directories
mkdir -p "$AI_STACK_CONFIG_DIR/stt"
mkdir -p "$AI_STACK_DATA_DIR/stt"
mkdir -p "$HOME/.local/bin"

# Copy configuration
cp "$REPO_ROOT/bare-metal/stt/config/config.yaml" "$AI_STACK_CONFIG_DIR/stt/"

# Create virtual environment
python -m venv "$AI_STACK_DATA_DIR/stt/venv"
"$AI_STACK_DATA_DIR/stt/venv/bin/pip" install --upgrade pip

# Install package
cd "$REPO_ROOT/bare-metal/stt"
"$AI_STACK_DATA_DIR/stt/venv/bin/pip" install -e .

# Copy scripts
cp "$REPO_ROOT/bare-metal/stt/scripts/"* "$HOME/.local/bin/"
chmod +x "$HOME/.local/bin/"{whisper-client,whisper-idle-monitor}

# Install systemd units
mkdir -p ~/.config/systemd/user/
cp "$REPO_ROOT/bare-metal/stt/systemd/"*.service ~/.config/systemd/user/
systemctl --user daemon-reload

echo "Whisper STT setup complete."
echo ""
echo "Commands:"
echo "  whisper-client start    - Start the server"
echo "  whisper-client status   - Check server status"
echo "  whisper-client stop     - Stop the server"
```

- [ ] **Step 2: Commit install script**

```bash
git add bare-metal/stt/install.sh
git commit -m "feat(stt): add installation script for new architecture"
```

---

## Chunk 5: Testing

**Files:**
- Create: `bare-metal/stt/tests/test_config.py`
- Create: `bare-metal/stt/tests/test_models.py`
- Create: `bare-metal/stt/tests/test_service.py`

### Task 13: Unit Tests

- [ ] **Step 1: Write `bare-metal/stt/tests/test_config.py`**

```python
"""Tests for configuration management."""

import os
from whisper_stt.config import Config


def test_config_defaults():
    """Test default configuration values."""
    config = Config()
    assert config.server.port == 7861
    assert config.server.host == "127.0.0.1"
    assert config.model.name == "deepdml/faster-whisper-large-v3-turbo-ct2"
    assert config.gpu.min_vram_mb == 1500


def test_config_env_override(monkeypatch):
    """Test environment variable overrides."""
    monkeypatch.setenv("WHISPER_PORT", "9999")
    monkeypatch.setenv("WHISPER_MODEL", "test-model")

    config = Config()
    config._apply_env()

    assert config.server.port == 9999
    assert config.model.name == "test-model"
```

- [ ] **Step 2: Write `bare-metal/stt/tests/test_models.py`**

```python
"""Tests for Pydantic models."""

from whisper_stt.models import (
    HealthResponse,
    StatusResponse,
    Segment,
    DetailedTranscriptionResponse,
)


def test_health_response():
    """Test health response model."""
    response = HealthResponse(status="healthy", model_loaded=True)
    assert response.status == "healthy"
    assert response.model_loaded is True


def test_segment_model():
    """Test segment model."""
    segment = Segment(
        id=0,
        start=0.0,
        end=1.5,
        text="Hello world",
        avg_logprob=-0.5,
        compression_ratio=1.0,
        no_speech_prob=0.1,
    )
    assert segment.text == "Hello world"
    assert segment.duration == 1.5
```

- [ ] **Step 3: Commit tests**

```bash
git add bare-metal/stt/tests/
git commit -m "test(stt): add unit tests for config and models"
```

---

## Chunk 6: Cleanup and Documentation

**Files:**
- Modify: `bare-metal/stt/docs/` (update documentation)

### Task 14: Update Documentation

- [ ] **Step 1: Update STT documentation**

Update `bare-metal/stt/docs/WHISPER-STT-QUICK-REFERENCE.md` with new commands and architecture.

- [ ] **Step 2: Commit documentation**

```bash
git add bare-metal/stt/docs/
git commit -m "docs(stt): update documentation for new architecture"
```

### Task 15: Remove POC Reference (Optional)

- [ ] **Step 1: Move POC to archive**

```bash
mv bare-metal/stt/poc bare-metal/stt/poc-archive
git add bare-metal/stt/poc-archive
git commit -m "chore(stt): archive POC code for reference"
```

---

## Execution Summary

**Total Tasks:** 15  
**Total Commits:** 15 (one per task)  
**Estimated Time:** 60-90 minutes

**After completion:**
1. Run `ai-stack install stt` to install
2. Test with `whisper-client start`
3. Verify with `whisper-client status`
4. Test transcription via API
