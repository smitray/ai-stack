#!/usr/bin/env bash
set -e

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source ~/.env

echo "Setting up Whisper STT..."

# Copy python dependencies and POC scripts
mkdir -p "$AI_STACK_CONFIG_DIR/whisper-api"
mkdir -p "$HOME/.local/bin"

cp bare-metal/stt/poc/config/config.yaml "$AI_STACK_CONFIG_DIR/whisper-api/"
cp bare-metal/stt/poc/bin/* "$HOME/.local/bin/"
chmod +x "$HOME/.local/bin/hypr-stt" "$HOME/.local/bin/whisper-api-server" "$HOME/.local/bin/whisper-ctl"

# Install python deps via venv (Arch PEP 668 compliance)
python -m venv "$AI_STACK_DATA_DIR/whisper-venv"
"$AI_STACK_DATA_DIR/whisper-venv/bin/pip" install --upgrade pip
"$AI_STACK_DATA_DIR/whisper-venv/bin/pip" install faster-whisper fastapi uvicorn

# Install systemd units
mkdir -p ~/.config/systemd/user/
cp bare-metal/stt/config/*.service ~/.config/systemd/user/
systemctl --user daemon-reload

echo "Whisper STT setup complete."
