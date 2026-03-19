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
