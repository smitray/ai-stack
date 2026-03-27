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

echo "Setting up Whisper STT..."

# Ensure HF CLI is installed
if ! command -v hf &>/dev/null; then
    echo "Installing HuggingFace CLI..."
    pip install -U "huggingface_hub[cli]" --quiet
fi

# Authenticate with HF if token is set
if [ -n "$HF_TOKEN" ] && [ "$HF_TOKEN" != "" ]; then
    echo "Authenticating with HuggingFace..."
    hf auth login --token "$HF_TOKEN" || true

    echo "Downloading STT model to HF cache..."
    hf download deepdml/faster-whisper-large-v3-turbo-ct2 || true
fi

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
chmod +x "$HOME/.local/bin/"{whisper-client,whisper-idle-monitor,whisper-activity}

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