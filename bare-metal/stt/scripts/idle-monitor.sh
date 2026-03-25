#!/usr/bin/env bash
#
# whisper-idle-monitor - Auto-unload model after idle timeout
#

set -euo pipefail

readonly IDLE_TIMEOUT=600  # 10 minutes
readonly CHECK_INTERVAL=10
readonly PORT="${WHISPER_PORT:-7861}"
readonly API_URL="http://localhost:$PORT"
readonly IDLE_FILE="/run/user/$(id -u)/whisper-api-idle"

log() {
    echo "[$(date '+%H:%M:%S')] [idle-monitor] $*" >&2
}

record_activity() {
    date +%s > "$IDLE_FILE" 2>/dev/null || true
}

get_last_activity() {
    if [[ -f "$IDLE_FILE" ]]; then
        cat "$IDLE_FILE" 2>/dev/null || date +%s
    else
        date +%s
    fi
}

is_server_running() {
    curl -sf "$API_URL/health" >/dev/null 2>&1
}

stop_server() {
    log "Stopping server (idle for ${IDLE_TIMEOUT}s)"
    notify-send "Whisper STT" "Server stopped (idle timeout - VRAM freed)" -u low 2>/dev/null || true
    systemctl --user stop whisper-server.service 2>/dev/null || true
    rm -f "$IDLE_FILE" 2>/dev/null || true
}

main() {
    log "Starting idle monitor (timeout: ${IDLE_TIMEOUT}s)"

    # Wait for server
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

    record_activity
    log "Activity tracking started"

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

    log "Server stopped, exiting"
    rm -f "$IDLE_FILE" 2>/dev/null || true
}

main "$@"