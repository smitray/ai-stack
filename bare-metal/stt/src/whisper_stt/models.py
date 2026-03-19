"""Pydantic models for API request/response validation."""

from pydantic import BaseModel, Field
from typing import Optional, List


class TranscriptionRequest(BaseModel):
    """Request model for transcription endpoint."""

    file: bytes  # Handled via Form in FastAPI
    model: Optional[str] = Field(default=None, description="Model to use")
    language: Optional[str] = Field(default=None, description="Language code")
    response_format: Optional[str] = Field(
        default="json", description="Response format"
    )
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
