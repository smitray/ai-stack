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
    assert segment.end == 1.5
