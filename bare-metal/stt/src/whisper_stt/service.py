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
            # download_root handled automatically via Hugging Face cache
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
            segment_list.append(
                Segment(
                    id=i,
                    start=segment.start,
                    end=segment.end,
                    text=segment.text,
                    avg_logprob=segment.avg_logprob,
                    compression_ratio=segment.compression_ratio,
                    no_speech_prob=segment.no_speech_prob,
                )
            )
            full_text.append(segment.text)

        return DetailedTranscriptionResponse(
            text="".join(full_text),
            segments=segment_list,
            language=info.language,
            duration=info.duration,
        )
