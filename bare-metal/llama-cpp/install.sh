#!/usr/bin/env bash
set -e

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source ~/.env

echo "Installing llama.cpp with optimizations..."

# Ensure HF CLI is installed
if ! command -v hf &>/dev/null; then
    echo "Installing HuggingFace CLI..."
    pip install -U "huggingface_hub[cli]" --quiet
fi

# Authenticate with HF if token is set
if [ -n "$HF_TOKEN" ] && [ "$HF_TOKEN" != "your_token_here" ]; then
    echo "Authenticating with HuggingFace..."
    hf auth login --token "$HF_TOKEN" || true
    
    echo "Downloading default LLM model to HF cache..."
    hf download unsloth/Qwen3.5-4B-GGUF Q4_K_M.gguf || true
fi

# Create dirs
mkdir -p "$AI_STACK_CONFIG_DIR/llama-cpp"
mkdir -p "$AI_STACK_DATA_DIR/llama-cpp"

# Build from source
cd "$AI_STACK_DATA_DIR/llama-cpp"
if [ ! -d "llama.cpp" ]; then
    git clone https://github.com/ggerganov/llama.cpp
fi
cd llama.cpp && git pull

# Export CUDA paths
export CUDA_HOME=/opt/cuda
export PATH=$CUDA_HOME/bin:$PATH
export LD_LIBRARY_PATH=$CUDA_HOME/lib64:$LD_LIBRARY_PATH

# Build with CUDA + LTO + RTX 3050 architecture (sm_86)
echo "Building with CUDA, LTO, and RTX 3050 optimization..."
cmake -B build \
    -DGGML_CUDA=ON \
    -DCMAKE_CUDA_ARCHITECTURES="86" \
    -DGGML_LTO=ON \
    -DGGML_NATIVE=ON \
    -DBUILD_SHARED_LIBS=ON

cmake --build build --config Release -j$(nproc)

# Install configs and systemd units
cd "$REPO_ROOT"
cp bare-metal/llama-cpp/config/presets.ini "$AI_STACK_CONFIG_DIR/llama-cpp/"
mkdir -p ~/.config/systemd/user/
cp bare-metal/llama-cpp/config/llama-cpp.service ~/.config/systemd/user/
systemctl --user daemon-reload

echo ""
echo "llama.cpp installed successfully!"
echo ""
echo "Model loading:"
echo "  - First start: auto-downloads from HuggingFace"
echo "  - Subsequent starts: uses cached model"
echo "  - HF repo: unsloth/Qwen3.5-4B-GGUF:Q4_K_M"
echo ""
echo "To start the server:"
echo "  systemctl --user start llama-cpp"
echo ""
echo "To check status:"
echo "  systemctl --user status llama-cpp"
echo "  curl http://localhost:8080/v1/models"