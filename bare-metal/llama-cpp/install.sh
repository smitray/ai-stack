#!/usr/bin/env bash
set -e

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source ~/.env

echo "Installing llama.cpp..."

# Create dirs
mkdir -p "$AI_STACK_CONFIG_DIR/llama-cpp"
mkdir -p "$AI_STACK_DATA_DIR/llama-cpp"
sudo mkdir -p "$AI_STACK_MODELS_DIR"
sudo chown -R $USER:$USER "$AI_STACK_MODELS_DIR"

# Build from source
cd "$AI_STACK_DATA_DIR/llama-cpp"
if [ ! -d "llama.cpp" ]; then
    git clone https://github.com/ggerganov/llama.cpp
fi
cd llama.cpp && git pull

# Build with CUDA
export CUDA_HOME=/opt/cuda
export PATH=$CUDA_HOME/bin:$PATH
export LD_LIBRARY_PATH=$CUDA_HOME/lib64:$LD_LIBRARY_PATH
cmake -B build -DGGML_CUDA=ON -DCMAKE_CUDA_ARCHITECTURES="86"
cmake --build build --config Release -j$(nproc)

# Install configs and systemd units
cd "$REPO_ROOT"
cp bare-metal/llama-cpp/config/presets.ini "$AI_STACK_CONFIG_DIR/llama-cpp/"
mkdir -p ~/.config/systemd/user/
cp bare-metal/llama-cpp/config/llama-cpp.service ~/.config/systemd/user/
systemctl --user daemon-reload

echo "llama.cpp installed successfully."
