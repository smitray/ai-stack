#!/usr/bin/env bash
#
# lib/install-base.sh — AI Stack bootstrap installer
#
# Installs all components to XDG locations.
# This is the entry point: ai-stack install base
#
set -e

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "=== AI Stack Bootstrap ==="
echo ""

# ---------------------------------------------------------------------------
# 1. System dependencies
# ---------------------------------------------------------------------------
echo "[1/8] Checking system dependencies..."
DEPENDENCIES=(podman podman-compose nvidia-container-toolkit base-devel cmake git cuda jq)
MISSING=()

for pkg in "${DEPENDENCIES[@]}"; do
    if ! pacman -Qi "$pkg" &>/dev/null; then
        MISSING+=("$pkg")
    fi
done

if [ ${#MISSING[@]} -gt 0 ]; then
    echo "  Installing: ${MISSING[*]}"
    sudo pacman -S --needed --noconfirm "${MISSING[@]}"
else
    echo "  All dependencies present."
fi

# ---------------------------------------------------------------------------
# 2. NVIDIA Container Toolkit for Podman
# ---------------------------------------------------------------------------
echo "[2/8] Configuring NVIDIA Container Toolkit..."
if ! grep -q "nvidia-container-runtime" /etc/containers/containers.conf 2>/dev/null; then
    sudo nvidia-ctk runtime configure --runtime=podman
    systemctl --user restart podman.socket || true
else
    echo "  Already configured."
fi

# ---------------------------------------------------------------------------
# 3. Environment setup (~/.zshenv)
# ---------------------------------------------------------------------------
echo "[3/8] Setting up environment (~/.zshenv)..."
ZSHENV="$HOME/.zshenv"
TEMPLATE="$REPO_ROOT/templates/zshenv.template"

if [ ! -f "$ZSHENV" ] || ! grep -q "AI_STACK_DATA_DIR" "$ZSHENV"; then
    if [ -f "$TEMPLATE" ]; then
        {
            echo ""
            echo "# AI Stack Environment (added by ai-stack install base)"
            cat "$TEMPLATE"
            echo ""
        } >> "$ZSHENV"
        echo "  Added to $ZSHENV — please fill in your API keys."
    else
        echo "  WARNING: Template not found at $TEMPLATE"
    fi
else
    echo "  Already configured in $ZSHENV"
fi

# Load environment for subsequent steps
# shellcheck source=/dev/null
[ -f "$ZSHENV" ] && { set -a; source "$ZSHENV"; set +a; }

# ---------------------------------------------------------------------------
# 4. Install lib/common.sh to XDG config dir
# ---------------------------------------------------------------------------
echo "[4/8] Installing lib/common.sh..."
AI_STACK_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/ai-stack"
mkdir -p "$AI_STACK_CONFIG_DIR/lib"
cp "$REPO_ROOT/lib/common.sh" "$AI_STACK_CONFIG_DIR/lib/common.sh"
echo "  Installed to $AI_STACK_CONFIG_DIR/lib/common.sh"

# ---------------------------------------------------------------------------
# 5. Install ai-stack CLI to ~/.local/bin
# ---------------------------------------------------------------------------
echo "[5/8] Installing ai-stack CLI..."
mkdir -p "$HOME/.local/bin"
cp "$REPO_ROOT/bin/ai-stack" "$HOME/.local/bin/ai-stack"
chmod +x "$HOME/.local/bin/ai-stack"
cp "$REPO_ROOT/bin/ai-stack-smoke-test" "$HOME/.local/bin/"
chmod +x "$HOME/.local/bin/ai-stack-smoke-test"
echo "  Installed to $HOME/.local/bin/ai-stack"

# ---------------------------------------------------------------------------
# 6. Install compose.yaml to XDG config dir
# ---------------------------------------------------------------------------
echo "[6/8] Installing compose.yaml..."
cp "$REPO_ROOT/containers/compose.yaml" "$AI_STACK_CONFIG_DIR/compose.yaml"

# Copy container service configs (bind-mounted by compose)
mkdir -p "$AI_STACK_CONFIG_DIR/searxng"
cp -r "$REPO_ROOT/containers/searxng/config/." "$AI_STACK_CONFIG_DIR/searxng/"
mkdir -p "$AI_STACK_CONFIG_DIR/qdrant"
cp "$REPO_ROOT/containers/qdrant/config/production.yaml" "$AI_STACK_CONFIG_DIR/qdrant/production.yaml"
echo "  Installed to $AI_STACK_CONFIG_DIR/compose.yaml"

# ---------------------------------------------------------------------------
# Configure journald retention (7 days)
# ---------------------------------------------------------------------------
echo "[6.5/8] Configuring journald retention..."
JOURNALD_DIR="$HOME/.config/systemd/journald.conf.d"
mkdir -p "$JOURNALD_DIR"
cp "$REPO_ROOT/lib/journald-ai-stack.conf" "$JOURNALD_DIR/ai-stack.conf"
echo "  Configured 7-day log retention"

# ---------------------------------------------------------------------------
# 7. Create XDG data directories (volume mounts)
# ---------------------------------------------------------------------------
echo "[7/8] Creating data directories..."
AI_STACK_DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/ai-stack"
for vol in postgres valkey qdrant/storage qdrant/snapshots open-webui n8n; do
    mkdir -p "$AI_STACK_DATA_DIR/volumes/$vol"
done
echo "  Created under $AI_STACK_DATA_DIR/volumes/"

# ---------------------------------------------------------------------------
# 8. HuggingFace CLI + models
# ---------------------------------------------------------------------------
echo "[8/8] Setting up HuggingFace..."
HF_HOME="${XDG_CACHE_HOME:-$HOME/.cache}/huggingface"
export HF_HOME

if ! command -v hf &>/dev/null; then
    echo "  Installing HuggingFace CLI..."
    if command -v pip &>/dev/null; then
        pip install -U "huggingface_hub[cli]" --quiet
    elif command -v pipx &>/dev/null; then
        pipx install huggingface_hub
    fi
fi

if [ -n "$HF_TOKEN" ]; then
    hf auth login --token "$HF_TOKEN" || true

    echo "  Downloading STT model..."
    hf download deepdml/faster-whisper-large-v3-turbo-ct2 || true

    echo "  Downloading LLM model..."
    hf download unsloth/Qwen3.5-4B-GGUF --include Q4_K_M.gguf || true

    echo "  Downloading reasoning model..."
    hf download Jackrong/Qwen3.5-4B-Claude-4.6-Opus-Reasoning-Distilled-v2-GGUF \
        --include Q4_K_M.gguf || true

    echo "  Cache contents:"
    hf cache ls
else
    echo "  WARNING: HF_TOKEN not set — models will download on first use."
fi

# ---------------------------------------------------------------------------
# CUDA paths in ~/.zshrc
# ---------------------------------------------------------------------------
ZSHRC="$HOME/.zshrc"
if [ -f "$ZSHRC" ] && ! grep -q "CUDA_HOME=/opt/cuda" "$ZSHRC"; then
    {
        echo ""
        echo "# CUDA Paths (AI Stack)"
        echo "export CUDA_HOME=/opt/cuda"
        echo 'export PATH="$CUDA_HOME/bin:$PATH"'
        echo 'export LD_LIBRARY_PATH="$CUDA_HOME/lib64:$LD_LIBRARY_PATH"'
    } >> "$ZSHRC"
fi

# ---------------------------------------------------------------------------
echo ""
echo "=== Bootstrap complete! ==="
echo ""
echo "Next steps:"
echo "  1. Fill in API keys: $ZSHENV"
echo "  2. source $ZSHENV"
echo "  3. bash $REPO_ROOT/bare-metal/llama-cpp/install.sh"
echo "  4. bash $REPO_ROOT/bare-metal/stt/install.sh"
echo "  5. ai-stack up"
echo ""