#!/usr/bin/env bash
set -e

echo "Starting AI Stack Bootstrap..."

# 1. Dependency Check & Auto-Install
DEPENDENCIES=("podman" "podman-compose" "nvidia-container-toolkit" "base-devel" "cmake" "git" "cuda")
MISSING=()

for pkg in "${DEPENDENCIES[@]}"; do
    if ! pacman -Qi "$pkg" &>/dev/null; then
        MISSING+=("$pkg")
    fi
done

if [ ${#MISSING[@]} -gt 0 ]; then
    echo "Installing missing dependencies: ${MISSING[*]}"
    sudo pacman -S --needed --noconfirm "${MISSING[@]}"
fi

# 2. Configure NVIDIA Container Toolkit for Podman
if ! grep -q "nvidia-container-runtime" /etc/containers/containers.conf 2>/dev/null; then
    echo "Configuring NVIDIA Container Toolkit for Podman..."
    sudo nvidia-ctk runtime configure --runtime=podman
    systemctl --user restart podman.socket || true
fi

# 3. Install HuggingFace CLI (for model management)
echo "Installing HuggingFace CLI..."
if command -v pip &>/dev/null; then
    pip install -U "huggingface_hub[cli]" --quiet
elif command -v pipx &>/dev/null; then
    pipx install huggingface_hub
fi

# 4. Setup environment from template
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ZSHENV="$HOME/.zshenv"
TEMPLATE="$REPO_ROOT/templates/zshenv.template"

if [ ! -f "$ZSHENV" ] || ! grep -q "AI_STACK_DATA_DIR" "$ZSHENV"; then
    echo "Setting up environment configuration..."
    if [ -f "$TEMPLATE" ]; then
        echo "" >> "$ZSHENV"
        echo "# AI Stack Environment (added by ai-stack install)" >> "$ZSHENV"
        cat "$TEMPLATE" >> "$ZSHENV"
        echo "" >> "$ZSHENV"
        echo "Environment configuration added to $ZSHENV"
        echo "Please edit $ZSHENV and fill in your API keys."
    else
        echo "WARNING: Template not found at $TEMPLATE"
        echo "Please manually configure environment variables in $ZSHENV"
    fi
else
    echo "Environment already configured in $ZSHENV"
fi

# Source environment for subsequent steps
if [ -f "$ZSHENV" ]; then
    source "$ZSHENV"
fi

# 5. Download Models to HF Cache
if [ -n "$HF_TOKEN" ] && [ "$HF_TOKEN" != "" ]; then
    echo "Authenticating with HuggingFace..."
    hf auth login --token "$HF_TOKEN" || true

    echo "Downloading STT model to HF cache..."
    hf download deepdml/faster-whisper-large-v3-turbo-ct2 || true

    echo "Downloading LLM model to HF cache..."
    hf download unsloth/Qwen3.5-4B-GGUF --include Q4_K_M.gguf || true

    echo "Downloading reasoning model to HF cache..."
    hf download Jackrong/Qwen3.5-4B-Claude-4.6-Opus-Reasoning-Distilled-v2-GGUF --include Q4_K_M.gguf || true

    echo "Verifying cache..."
    hf cache ls
else
    echo "WARNING: HF_TOKEN not set. Models will be downloaded on first use."
    echo "Set HF_TOKEN in $ZSHENV to download models now."
fi

# 6. Inject CUDA paths into ~/.zshrc (if not already present)
ZSHRC="$HOME/.zshrc"
if [ -f "$ZSHRC" ]; then
    if ! grep -q "export CUDA_HOME=/opt/cuda" "$ZSHRC"; then
        echo -e "\n# CUDA Paths (AI Stack)\nexport CUDA_HOME=/opt/cuda\nexport PATH=\$CUDA_HOME/bin:\$PATH\nexport LD_LIBRARY_PATH=\$CUDA_HOME/lib64:\$LD_LIBRARY_PATH" >> "$ZSHRC"
    fi
fi

echo ""
echo "Bootstrap complete!"
echo ""
echo "Next steps:"
echo "  1. Edit $ZSHENV and add your API keys"
echo "  2. Run: source $ZSHENV"
echo "  3. Run: ai-stack install all"
echo ""