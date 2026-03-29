#!/usr/bin/env bash
#
# AI Stack one-liner installer
# Usage: curl -fsSL https://raw.githubusercontent.com/smitray/ai-stack/main/install.sh | bash
#

set -e

REPO_URL="https://github.com/smitray/ai-stack.git"
DEST_DIR="${AI_STACK_DIR:-$HOME/ai-stack}"

echo "🚀 Installing AI Stack..."

# Install basic dependencies if missing (git, curl)
if ! command -v git &> /dev/null || ! command -v curl &> /dev/null; then
    echo "📦 Installing git and curl..."
    sudo pacman -Sy --noconfirm git curl
fi

if [ ! -d "$DEST_DIR" ]; then
    echo "📦 Cloning repository to $DEST_DIR..."
    mkdir -p "$(dirname "$DEST_DIR")"
    git clone "$REPO_URL" "$DEST_DIR"
else
    echo "📦 Repository already exists at $DEST_DIR. Pulling latest..."
    cd "$DEST_DIR" && git pull
fi

cd "$DEST_DIR"

echo "🔧 Running base installation..."
bash lib/install-base.sh

echo ""
echo "✨ AI Stack base components installed."
echo ""
echo "Next steps:"
echo "1. Configure your environment variables in ~/.zshenv"
echo "   (Add API keys, HF_TOKEN, etc.)"
echo "2. Run: source ~/.zshenv"
echo "3. Run: bash $DEST_DIR/bare-metal/llama-cpp/install.sh"
echo "4. Run: bash $DEST_DIR/bare-metal/stt/install.sh"
echo "5. Run: ai-stack up"
