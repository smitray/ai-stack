#!/bin/bash
#
# Whisper STT Idle Monitor
# Stops the server after 10 minutes of NO API usage to free VRAM
#

set -euo pipefail

readonly IDLE_TIMEOUT=600  # 10 minutes in seconds
readonly CHECK_INTERVAL=10  # Check every 10 seconds
readonly PORT="${WHISPER_PORT:-7861}"
readonly API_URL="http://localhost:$PORT"
readonly IDLE_FILE="/run/user/$(id -u)/whisper-api-idle"

log() {
    echo "[$(date '+%H:%M:%S')] [idle-monitor] $*" >&2
}

# Record activity timestamp
record_activity() {
    date +%s > "$IDLE_FILE" 2>/dev/null || true
}

# Get last activity timestamp
get_last_activity() {
    if [[ -f "$IDLE_FILE" ]]; then
        cat "$IDLE_FILE" 2>/dev/null || date +%s
    else
        date +%s
    fi
}

# Check if server is running
is_server_running() {
    curl -sf "$API_URL/health" >/dev/null 2>&1
}

# Stop the server
stop_server() {
    log "Stopping Whisper API server (idle for ${IDLE_TIMEOUT}s)"
    notify-send "Whisper STT" "Server stopped (idle timeout - VRAM freed)" -u low 2>/dev/null || true
    
    # Stop via systemctl (clean shutdown)
    systemctl --user stop whisper-api.service 2>/dev/null || \
        pkill -f "whisper-api-server" 2>/dev/null || true
    
    sleep 2
    rm -f "$IDLE_FILE" 2>/dev/null || true
}

# Main monitoring logic
main() {
    log "Starting idle monitor (timeout: ${IDLE_TIMEOUT}s)"
    
    # Wait for server to be ready (up to 60 seconds)
    local wait_count=0
    while [[ $wait_count -lt 12 ]]; do
        if is_server_running; then
            log "Server detected"
            break
        fi
        sleep 5
        ((wait_count++))
    done
    
    if ! is_server_running; then
        log "Server not running, exiting"
        exit 0
    fi
    
    # Initialize activity tracking
    record_activity
    log "Activity tracking started"
    
    # Monitor until server stops or idle timeout
    while is_server_running; do
        local last_activity current_time idle_time
        last_activity=$(get_last_activity)
        current_time=$(date +%s)
        idle_time=$((current_time - last_activity))
        
        log "Idle for ${idle_time}s"
        
        if [[ $idle_time -ge $IDLE_TIMEOUT ]]; then
            stop_server
            exit 0
        fi
        
        sleep "$CHECK_INTERVAL"
    done
    
    # Server stopped externally
    log "Server stopped, exiting"
    rm -f "$IDLE_FILE" 2>/dev/null || true
}

main "$@"
