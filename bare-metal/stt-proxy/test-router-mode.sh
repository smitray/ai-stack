#!/usr/bin/env bash
#
# Test llama.cpp Router Mode and STT Proxy
#

set -e

# Source common.sh if available
COMMON_SH="${XDG_CONFIG_HOME:-$HOME/.config}/ai-stack/lib/common.sh"
if [ -f "$COMMON_SH" ]; then
    source "$COMMON_SH"
fi

# Colors (fallback if common.sh not available)
: "${RED:='\033[0;31m'}"
: "${GREEN:='\033[0;32m'}"
: "${YELLOW:='\033[1;33m'}"
: "${BLUE:='\033[0;34m'}"
: "${NC:='\033[0m'}"

LLAMA_CPP_URL="http://localhost:7865"
WHISPER_URL="http://localhost:7861"
STT_PROXY_URL="http://localhost:7866"

log_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
log_success() { echo -e "${GREEN}[OK]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[FAIL]${NC} $*" >&2; }

test_endpoint() {
    local name="$1"
    local url="$2"
    local method="${3:-GET}"
    local data="${4:-}"
    
    log_info "Testing $name: $method $url"
    
    if [ -n "$data" ]; then
        response=$(curl -sf -X "$method" -H "Content-Type: application/json" -d "$data" "$url" 2>&1)
    else
        response=$(curl -sf -X "$method" "$url" 2>&1)
    fi
    
    if [ $? -eq 0 ]; then
        log_success "$name is responding"
        echo "$response" | head -c 200
        echo ""
        return 0
    else
        log_error "$name is not responding"
        return 1
    fi
}

echo "========================================"
echo "  llama.cpp Router Mode & STT Proxy    "
echo "  Test Suite                            "
echo "========================================"
echo ""

# Test 1: llama.cpp Router Mode API
echo "=== Test 1: llama.cpp Router Mode API ==="
log_info "Testing llama.cpp at $LLAMA_CPP_URL"

test_endpoint "Health" "$LLAMA_CPP_URL/health"
test_endpoint "Models List" "$LLAMA_CPP_URL/models"
test_endpoint "Props" "$LLAMA_CPP_URL/props"

echo ""

# Test 2: Whisper STT
echo "=== Test 2: Whisper STT ==="
log_info "Testing Whisper STT at $WHISPER_URL"

test_endpoint "Health" "$WHISPER_URL/health"
test_endpoint "Ready" "$WHISPER_URL/ready"
test_endpoint "Status" "$WHISPER_URL/status"

echo ""

# Test 3: STT Proxy
echo "=== Test 3: STT Proxy ==="
log_info "Testing STT Proxy at $STT_PROXY_URL"

test_endpoint "Health" "$STT_PROXY_URL/health"
test_endpoint "Status" "$STT_PROXY_URL/status"

echo ""

# Test 4: Model Unload API
echo "=== Test 4: Model Unload API ==="
log_info "Testing /models/unload endpoint"

response=$(curl -sf -X POST "$LLAMA_CPP_URL/models/unload" \
    -H "Content-Type: application/json" \
    -d '{"model": "unsloth/Qwen3.5-4B-GGUF:Q4_K_M"}' 2>&1)

if [ $? -eq 0 ]; then
    log_success "Model unload API works"
    echo "Response: $response"
else
    log_warn "Model unload API not available (may need router mode)"
fi

echo ""

# Test 5: VRAM Status
echo "=== Test 5: VRAM Status ==="
if command -v nvidia-smi &>/dev/null; then
    log_info "Current VRAM usage:"
    nvidia-smi --query-gpu=memory.used,memory.free --format=csv
else
    log_warn "nvidia-smi not available"
fi

echo ""
echo "========================================"
echo "  Test Complete                         "
echo "========================================"
echo ""
echo "Next steps:"
echo "  1. If all tests pass, Open WebUI should work"
echo "  2. Test voice input in Open WebUI"
echo "  3. Monitor VRAM with: watch -n1 nvidia-smi"
echo ""
