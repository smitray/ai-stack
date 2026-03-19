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