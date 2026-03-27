#!/usr/bin/env bash
set -e

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Source environment from ~/.zshenv
if [ -f "$HOME/.zshenv" ]; then
    source "$HOME/.zshenv"
else
    echo "WARNING: ~/.zshenv not found. Please run: ai-stack install base"
    echo "Continuing with default values..."
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
mkdir -p ~/.config/systemd/user/
cp "$REPO_ROOT/bare-metal/stt-proxy/systemd/"*.service ~/.config/systemd/user/
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
