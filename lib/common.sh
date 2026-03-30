#!/usr/bin/env bash
#
# lib/common.sh — AI Stack shared constants and helpers
#
# This file is installed to: ~/.config/ai-stack/lib/common.sh
# Source it from any installed script:
#   source "${XDG_CONFIG_HOME:-$HOME/.config}/ai-stack/lib/common.sh"
#

# === Terminal Colors ===
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# === XDG Base Directories ===
AI_STACK_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/ai-stack"
AI_STACK_DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/ai-stack"
AI_STACK_CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/ai-stack"

# === Service URLs (override via env vars) ===
WHISPER_URL="${WHISPER_URL:-http://localhost:7861}"
LLAMA_CPP_URL="${LLAMA_CPP_URL:-http://localhost:7865}"
STT_PROXY_PORT="${STT_PROXY_PORT:-7866}"

# === VRAM State File (XDG_RUNTIME_DIR) ===
VRAM_STATE_FILE="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/ai-stack-vram-state"

# === HuggingFace Cache ===
HF_HOME="${XDG_CACHE_HOME:-$HOME/.cache}/huggingface"
AI_STACK_MODELS_DIR="${HF_HOME}/hub"

# =============================================================================
# Helper: load_env
#   Sources ~/.zshenv to inject secrets (API keys, passwords) into the shell.
#   Use set -a / set +a so all variables are exported automatically.
# =============================================================================
load_env() {
    if [ -f "$HOME/.zshenv" ]; then
        set -a
        # shellcheck source=/dev/null
        source "$HOME/.zshenv"
        set +a
    fi
}

# =============================================================================
# Helper: validate_required_secrets
#   Validates that required secrets are set in the environment.
#   Call after load_env to ensure secrets are available.
# =============================================================================
validate_required_secrets() {
    local missing=()
    local required=("POSTGRES_PASSWORD" "OPENWEBUI_DB_PASSWORD" "WEBUI_SECRET_KEY" "SEARXNG_SECRET")
    
    for secret in "${required[@]}"; do
        if [ -z "${!secret:-}" ]; then
            missing+=("$secret")
        fi
    done
    
    if [ ${#missing[@]} -gt 0 ]; then
        echo -e "${RED}ERROR: Missing required secrets:${NC}"
        printf '  - %s\n' "${missing[@]}"
        echo "Please set these in ~/.zshenv"
        return 1
    fi
    return 0
}
