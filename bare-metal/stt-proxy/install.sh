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

echo "Setting up STT Proxy..."

# Create directories
mkdir -p "$AI_STACK_DATA_DIR/stt-proxy"
mkdir -p "$HOME/.local/bin"

# Create virtual environment
python -m venv "$AI_STACK_DATA_DIR/stt-proxy/venv"
"$AI_STACK_DATA_DIR/stt-proxy/venv/bin/pip" install --upgrade pip

# Install dependencies
cd "$REPO_ROOT/bare-metal/stt-proxy"
"$AI_STACK_DATA_DIR/stt-proxy/venv/bin/pip" install -r requirements.txt

# Copy proxy script
mkdir -p "$AI_STACK_DATA_DIR/stt-proxy/"
cp "$REPO_ROOT/bare-metal/stt-proxy/stt_proxy.py" "$AI_STACK_DATA_DIR/stt-proxy/"

# Copy test script
cp "$REPO_ROOT/bare-metal/stt-proxy/test-router-mode.sh" "$HOME/.local/bin/"
chmod +x "$HOME/.local/bin/test-router-mode.sh"

# Install systemd units
mkdir -p "$HOME/.config/systemd/user"
cp "$REPO_ROOT/bare-metal/stt-proxy/systemd/"*.service "$HOME/.config/systemd/user/"
systemctl --user daemon-reload

echo ""
echo "STT Proxy setup complete."
echo ""
echo "Configuration:"
echo "  - Proxy listens on: http://localhost:7866"
echo "  - Forwards to Whisper: http://localhost:7861"
echo "  - Unloads llama.cpp: http://localhost:7865"
echo ""
echo "To start:"
echo "  systemctl --user start stt-proxy"
echo ""
echo "To configure Open WebUI:"
echo "  1. Go to Admin Settings → Audio"
echo "  2. Set API Base URL to: http://localhost:7866/v1"
echo "  3. Save settings"
echo ""
