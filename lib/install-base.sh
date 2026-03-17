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

# 3. Setup ~/.env
if [ ! -f "$HOME/.env" ]; then
    echo "Creating ~/.env from template. Please fill in your API keys."
    cp .env.example "$HOME/.env"
fi

# 4. Inject into ~/.zshrc
ZSHRC="$HOME/.zshrc"
if [ -f "$ZSHRC" ]; then
    if ! grep -q "source ~/.env" "$ZSHRC"; then
        echo -e "\n# AI Stack Environment\nif [ -f ~/.env ]; then\n  source ~/.env\nfi" >> "$ZSHRC"
    fi
    if ! grep -q "export CUDA_HOME=/opt/cuda" "$ZSHRC"; then
        echo -e "\n# CUDA Paths\nexport CUDA_HOME=/opt/cuda\nexport PATH=\$CUDA_HOME/bin:\$PATH\nexport LD_LIBRARY_PATH=\$CUDA_HOME/lib64:\$LD_LIBRARY_PATH" >> "$ZSHRC"
    fi
fi

echo "Bootstrap complete!"
