#!/usr/bin/env bash
set -e

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Load shared constants
_COMMON="${XDG_CONFIG_HOME:-$HOME/.config}/ai-stack/lib/common.sh"
if [ -f "$_COMMON" ]; then
    # shellcheck source=/dev/null
    source "$_COMMON"
    load_env
else
    echo "WARNING: common.sh not found. Run: bash lib/install-base.sh first."
    AI_STACK_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/ai-stack"
    AI_STACK_DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/ai-stack"
fi

echo "Setting up Whisper STT..."
# Note: STT model download is handled by: bash lib/install-base.sh

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
chmod +x "$HOME/.local/bin/"{whisper-client,hypr-stt,whisper-activity,idle-monitor.sh}

# Install systemd units
mkdir -p "$HOME/.config/systemd/user"
cp "$REPO_ROOT/bare-metal/stt/systemd/"*.service "$HOME/.config/systemd/user/"
systemctl --user daemon-reload

echo "Whisper STT setup complete."
echo ""
echo "Commands:"
echo "  whisper-client start    - Start the server"
echo "  whisper-client status   - Check server status"
echo "  whisper-client stop     - Stop the server"