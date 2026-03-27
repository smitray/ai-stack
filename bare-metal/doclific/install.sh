#!/usr/bin/env bash
#
# bare-metal/doclific/install.sh
# Installs Doclific — local documentation tool with AI support
# https://github.com/muellerluke/doclific
#
# Installs to: ~/.local/bin/doclific
# Configured to run on port: 7864
# Service is INACTIVE by default — start manually when needed.
#
set -e

# Load shared constants
_COMMON="${XDG_CONFIG_HOME:-$HOME/.config}/ai-stack/lib/common.sh"
if [ -f "$_COMMON" ]; then
    # shellcheck source=/dev/null
    source "$_COMMON"
    load_env
else
    echo "WARNING: common.sh not found. Run: bash lib/install-base.sh first."
fi

DOCLIFIC_PORT=7864

echo "Installing Doclific (port $DOCLIFIC_PORT)..."

# Install doclific binary via official installer
curl -fsSL https://raw.githubusercontent.com/muellerluke/doclific/main/scripts/install.sh | bash

# Configure port (doclific stores config at ~/.config/doclific/config.json)
if command -v doclific &>/dev/null; then
    doclific set port "$DOCLIFIC_PORT" 2>/dev/null || true
    echo "  Configured port: $DOCLIFIC_PORT"
fi

# Install systemd unit (disabled by default — manual start only)
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
mkdir -p "$HOME/.config/systemd/user"
cp "$REPO_ROOT/bare-metal/doclific/systemd/doclific.service" \
    "$HOME/.config/systemd/user/"
systemctl --user daemon-reload
# Note: NOT enabling — service is on-demand only
echo "  Systemd unit installed (not enabled)"

echo ""
echo "Doclific installed. Port: http://localhost:$DOCLIFIC_PORT"
echo ""
echo "Usage (from any project directory):"
echo "  doclific init              # Initialize docs in current project"
echo "  systemctl --user start doclific  # Start server"
echo "  systemctl --user stop  doclific  # Stop server"
echo ""
echo "Note: Service is deliberately kept inactive."
echo "Start it only when needed to avoid idle resource usage."
