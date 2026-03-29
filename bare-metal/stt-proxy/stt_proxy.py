#!/usr/bin/env python3
"""
STT Proxy for Open WebUI

Intercepts speech-to-text requests from Open WebUI, unloads llama.cpp model,
forwards to Whisper STT, and returns transcription.

This ensures VRAM is properly managed when STT is activated.
"""

import asyncio
import json
import logging
import os
import sys
from pathlib import Path

from fastapi import FastAPI, File, Form, HTTPException, UploadFile
from fastapi.responses import JSONResponse
import httpx

# Configuration — read from environment (set via systemd EnvironmentFile=~/.zshenv
# or common.sh). Fallback values match defaults in lib/common.sh.
_WHISPER_BASE = os.environ.get("WHISPER_URL", "http://localhost:7861")
WHISPER_URL = f"{_WHISPER_BASE}/v1/audio/transcriptions"
LLAMA_CPP_URL = os.environ.get("LLAMA_CPP_URL", "http://localhost:7865")
PROXY_PORT = int(os.environ.get("STT_PROXY_PORT", "7866"))

logging.basicConfig(
    level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s"
)
logger = logging.getLogger("stt-proxy")

app = FastAPI(title="STT Proxy", version="1.0.0")

http_client = httpx.AsyncClient(timeout=120.0)


@app.on_event("shutdown")
async def shutdown_event():
    await http_client.aclose()


async def unload_llama_model() -> dict:
    """
    Unload llama.cpp model from VRAM using native API.
    Falls back to systemd if API unavailable.
    """
    logger.info("Unloading llama.cpp model via API...")

    # Method 1: Native llama.cpp router API (preferred)
    # Empty body = unload whatever model is currently loaded (model-agnostic)
    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            response = await client.post(f"{LLAMA_CPP_URL}/models/unload", json={})
            if response.status_code == 200:
                logger.info("Model unloaded via llama.cpp API")
                # Write state file
                await write_state("stt")
                return {"success": True, "method": "api"}
            elif response.status_code == 404:
                logger.debug("/models/unload endpoint not found, trying systemd")
            else:
                logger.warning(f"API returned {response.status_code}: {response.text}")
    except httpx.ConnectError:
        logger.debug("llama.cpp not running, nothing to unload")
        return {"success": True, "method": "not_running"}
    except Exception as e:
        logger.debug(f"API unload failed: {e}")

    # Method 2: systemd stop (fallback)
    try:
        process = await asyncio.create_subprocess_exec(
            "systemctl",
            "--user",
            "stop",
            "llama-cpp",
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
        )
        stdout, stderr = await process.communicate()

        if process.returncode == 0:
            logger.info("Model unloaded via systemd")
            await write_state("stt")
            return {"success": True, "method": "systemd"}
        else:
            logger.warning(f"systemctl failed: {stderr.decode()}")
    except Exception as e:
        logger.warning(f"systemctl exception: {e}")

    # Already unloaded or not running
    logger.info("llama.cpp not running or already unloaded")
    return {"success": True, "method": "not_running"}


async def write_state(active: str) -> None:
    """Write VRAM state file."""
    import os

    state_file = f"/run/user/{os.getuid()}/ai-stack-vram-state"
    state = {"active": active, "timestamp": int(asyncio.get_event_loop().time())}

    try:
        run_dir = os.path.dirname(state_file)
        os.makedirs(run_dir, exist_ok=True)
        with open(state_file, "w") as f:
            json.dump(state, f)
        logger.debug(f"State written: {active}")
    except Exception as e:
        logger.debug(f"Failed to write state: {e}")


async def wait_for_whisper_ready(max_wait: int = 30) -> bool:
    """Start whisper-server if stopped, then wait for readiness."""
    # Start whisper-server if not running
    try:
        proc = await asyncio.create_subprocess_exec(
            "systemctl",
            "--user",
            "start",
            "whisper-server.service",
            stdout=asyncio.subprocess.DEVNULL,
            stderr=asyncio.subprocess.DEVNULL,
        )
        await proc.wait()
        logger.info("whisper-server.service start attempted")
    except Exception as e:
        logger.warning(f"Failed to start whisper-server: {e}")

    # Wait for /ready endpoint
    async with httpx.AsyncClient(timeout=5.0) as client:
        for i in range(max_wait):
            try:
                response = await client.get(f"{_WHISPER_BASE}/ready")
                if response.status_code == 200:
                    logger.info("Whisper STT is ready")
                    return True
            except Exception:
                pass
            await asyncio.sleep(1)

        logger.error("Whisper STT not ready after waiting")
        return False


@app.post("/v1/audio/transcriptions")
async def transcribe_audio(
    file: UploadFile = File(...),
    model: str | None = Form(None),
    language: str | None = Form(None),
    response_format: str | None = Form("json"),
):
    """
    Transcribe audio with automatic llama.cpp unloading.

    Flow:
    1. Unload llama.cpp model (free VRAM)
    2. Wait for Whisper STT to be ready
    3. Forward audio to Whisper STT
    4. Return transcription
    """
    logger.info("STT request received from Open WebUI")

    # Step 1: Unload llama.cpp to free VRAM
    await unload_llama_model()

    # Small delay to ensure VRAM is freed
    await asyncio.sleep(1)

    # Step 2: Ensure Whisper STT is ready
    if not await wait_for_whisper_ready():
        raise HTTPException(status_code=503, detail="Whisper STT not ready")

    # Step 3: Forward to Whisper STT
    logger.info("Forwarding audio to Whisper STT")

    # Prepare multipart form data
    form_data = httpx.FormData()
    form_data.add_field(
        "file", await file.read(), filename=file.filename or "audio.wav"
    )
    if model:
        form_data.add_field("model", model)
    if language:
        form_data.add_field("language", language)
    form_data.add_field("response_format", response_format or "json")

    try:
        async with httpx.AsyncClient(timeout=120.0) as client:
            response = await client.post(WHISPER_URL, data=form_data)

            if response.status_code != 200:
                logger.error(
                    f"Whisper STT returned {response.status_code}: {response.text}"
                )
                raise HTTPException(status_code=500, detail="Transcription failed")

            logger.info("Transcription successful")
            return JSONResponse(content=response.json())

    except httpx.TimeoutException:
        logger.error("Whisper STT timeout")
        raise HTTPException(status_code=504, detail="Transcription timeout")
    except Exception as e:
        logger.error(f"Transcription error: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/health")
async def health_check():
    """Health check endpoint."""
    return {"status": "healthy", "service": "stt-proxy"}


@app.get("/status")
async def get_status():
    """Get proxy and service status."""
    status = {"proxy": "running", "whisper_stt": "unknown", "llama_cpp": "unknown"}

    async with httpx.AsyncClient(timeout=5.0) as client:
        # Check Whisper
        try:
            response = await client.get("http://localhost:7861/health")
            status["whisper_stt"] = (
                "healthy" if response.status_code == 200 else "unhealthy"
            )
        except Exception:
            status["whisper_stt"] = "not_running"

        # Check llama.cpp
        try:
            response = await client.get(f"{LLAMA_CPP_URL}/health")
            status["llama_cpp"] = (
                "healthy" if response.status_code == 200 else "unhealthy"
            )
        except Exception:
            status["llama_cpp"] = "not_running"

    return status


if __name__ == "__main__":
    import uvicorn

    logger.info(f"Starting STT Proxy on port {PROXY_PORT}")
    uvicorn.run(app, host="0.0.0.0", port=PROXY_PORT)
