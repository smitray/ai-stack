#!/bin/bash
#
# Whisper STT Cleanup Script
# Cleans up stale processes before systemd service starts
#
# This prevents "address already in use" errors after reboot
#

set -euo pipefail

PORT="${WHISPER_PORT:-7861}"
PID_FILE="/run/user/$(id -u)/whisper-api-server.pid"

log() {
    echo "[$(date '+%H:%M:%S')] $*" >&2
}

# Kill process using the STT port
kill_port_process() {
    local pid
    pid=$(lsof -t -i:"$PORT" 2>/dev/null || echo "")
    
    if [[ -n "$pid" ]]; then
        log "Killing process $pid on port $PORT"
        kill "$pid" 2>/dev/null || true
        
        # Wait for graceful shutdown
        local timeout=10
        while kill -0 "$pid" 2>/dev/null && [[ $timeout -gt 0 ]]; do
            sleep 0.5
            ((timeout--))
        done
        
        # Force kill if still running
        if kill -0 "$pid" 2>/dev/null; then
            log "Force killing process $pid"
            kill -9 "$pid" 2>/dev/null || true
        fi
    fi
}

# Kill whisper-api-server by exact process name
kill_whisper_server() {
    # Use pgrep with exact match on the full path
    local pids
    pids=$(pgrep -f "/home/debasmitr/.local/bin/whisper-api-server" 2>/dev/null || echo "")
    
    if [[ -n "$pids" ]]; then
        log "Killing whisper-api-server processes: $pids"
        for pid in $pids; do
            # Verify it's actually the whisper server, not a child or unrelated process
            local cmdline
            cmdline=$(cat /proc/"$pid"/cmdline 2>/dev/null | tr '\0' ' ' || echo "")
            if [[ "$cmdline" == *"whisper-api-server"* ]]; then
                kill "$pid" 2>/dev/null || true
            fi
        done
        
        sleep 1
        
        # Force kill if still running
        for pid in $pids; do
            if kill -0 "$pid" 2>/dev/null; then
                local cmdline
                cmdline=$(cat /proc/"$pid"/cmdline 2>/dev/null | tr '\0' ' ' || echo "")
                if [[ "$cmdline" == *"whisper-api-server"* ]]; then
                    kill -9 "$pid" 2>/dev/null || true
                fi
            fi
        done
    fi
}

# Remove stale PID files
cleanup_pid_files() {
    for pid_file in "$PID_FILE"; do
        if [[ -f "$pid_file" ]]; then
            local pid
            pid=$(cat "$pid_file" 2>/dev/null || echo "")
            
            if [[ -z "$pid" ]] || ! kill -0 "$pid" 2>/dev/null; then
                log "Removing stale PID file: $pid_file"
                rm -f "$pid_file"
            fi
        fi
    done
}

# Main cleanup
main() {
    log "Starting Whisper STT cleanup..."
    
    # Clean up by port first (most reliable)
    kill_port_process
    
    # Clean up whisper server by exact path
    kill_whisper_server
    
    # Clean up PID files
    cleanup_pid_files
    
    log "Cleanup complete"
}

main "$@"
