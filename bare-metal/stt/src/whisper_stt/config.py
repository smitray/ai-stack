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
    load_on_startup: bool = True  # If False, server starts but model loads on first request


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
        if load_on_startup := os.environ.get("WHISPER_LOAD_ON_STARTUP"):
            self.model.load_on_startup = load_on_startup.lower() in ("true", "1", "yes")
        if idle_timeout := os.environ.get("WHISPER_IDLE_TIMEOUT"):
            self.idle.timeout_seconds = int(idle_timeout)
        if min_vram := os.environ.get("WHISPER_MIN_VRAM"):
            self.gpu.min_vram_mb = int(min_vram)
