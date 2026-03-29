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

MAX_UPLOAD_SIZE = 50 * 1024 * 1024  # 50 MB


def create_app(config: Config) -> FastAPI:
    """Create and configure FastAPI application."""

    app = FastAPI(
        title="Whisper STT",
        description="Local speech-to-text API using Whisper",
        version="1.0.0",
    )

    # Initialize service
    service = TranscriptionService(config)
    model_loaded = False

    @app.on_event("startup")
    async def startup_event() -> None:
        """Load model on startup if configured."""
        nonlocal model_loaded
        if config.model.load_on_startup:
            service.load_model()
            model_loaded = True
            logger.info("Model loaded on startup")
        else:
            logger.info("Server started (model will load on first request)")

    @app.on_event("shutdown")
    async def shutdown_event() -> None:
        """Unload model on shutdown."""
        service.unload_model()

    @app.get("/health", response_model=HealthResponse)
    async def health_check() -> HealthResponse:
        """Simple health check."""
        return HealthResponse(status="healthy", model_loaded=service.is_model_loaded())

    @app.get("/ready", response_model=HealthResponse)
    async def readiness_check() -> HealthResponse:
        """Check if model is loaded and ready."""
        if not service.is_model_loaded():
            # Try to load model if not loaded (lazy loading)
            if not config.model.load_on_startup:
                try:
                    service.load_model()
                    return HealthResponse(status="ready", model_loaded=True)
                except Exception as e:
                    logger.error(f"Failed to load model: {e}")
                    raise HTTPException(
                        status_code=503, detail=f"Model load failed: {str(e)}"
                    )
            raise HTTPException(status_code=503, detail="Model not loaded")
        return HealthResponse(status="ready", model_loaded=True)

    @app.get("/status", response_model=StatusResponse)
    async def get_status() -> StatusResponse:
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
    async def get_vram() -> VRAMResponse:
        """Get GPU VRAM usage."""
        vram = _get_vram_info()
        return VRAMResponse(**vram)

    @app.post("/v1/audio/transcriptions", response_model=DetailedTranscriptionResponse)
    async def transcribe_audio(
        file: UploadFile = File(...),
        model: Optional[str] = Form(None),
        language: Optional[str] = Form(None),
        response_format: Optional[str] = Form("json"),
    ) -> DetailedTranscriptionResponse | JSONResponse:
        """Transcribe audio file (OpenAI-compatible endpoint)."""
        # Lazy load model if not loaded
        if not service.is_model_loaded():
            try:
                service.load_model()
            except Exception as e:
                raise HTTPException(
                    status_code=503, detail=f"Model load failed: {str(e)}"
                )

        # Validate file type
        if not file.content_type or not file.content_type.startswith("audio/"):
            raise HTTPException(status_code=400, detail="Invalid audio file")

        # Save uploaded file temporarily
        with tempfile.NamedTemporaryFile(delete=False, suffix=".wav") as tmp:
            content = await file.read()
            if len(content) > MAX_UPLOAD_SIZE:
                raise HTTPException(
                    status_code=413,
                    detail=f"File too large. Maximum size is {MAX_UPLOAD_SIZE // (1024 * 1024)} MB.",
                )
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

    def _get_vram_info() -> dict[str, int | float]:
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
