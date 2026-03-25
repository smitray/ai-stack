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
        "--config",
        "-c",
        type=Path,
        help="Path to config file",
    )
    parser.add_argument(
        "--port",
        "-p",
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
