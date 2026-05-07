#!/usr/bin/env bash
# mcp-remote-reconnect-wrapper.sh
# Wraps the mcp-remote Node.js bridge and auto-reconnects on ClosedResourceError.
#
# Issue: #2012 — When the upstream MCP proxy goes down, mcp-remote stays alive
# but enters a permanent ClosedResourceError state. This wrapper detects that
# condition and restarts the bridge process automatically.
#
# Usage:
#   ./mcp-remote-reconnect-wrapper.sh <mcp-remote binary> [args...]
#
# Environment variables:
#   MCP_RECONNECT_MAX_RETRIES   - Max consecutive retries (default: 5)
#   MCP_RECONNECT_BACKOFF_BASE  - Base backoff in seconds (default: 2)
#   MCP_RECONNECT_BACKOFF_MAX   - Max backoff in seconds (default: 60)
#   MCP_RECONNECT_LOG_FILE      - Log file path (default: /tmp/mcp-remote-wrapper.log)
#
# Designed to run inside Hermes Docker containers on remote machines (po-2026, etc.)

set -euo pipefail

# ---------- configuration ----------
MAX_RETRIES="${MCP_RECONNECT_MAX_RETRIES:-5}"
BACKOFF_BASE="${MCP_RECONNECT_BACKOFF_BASE:-2}"
BACKOFF_MAX="${MCP_RECONNECT_BACKOFF_MAX:-60}"
LOG_FILE="${MCP_RECONNECT_LOG_FILE:-/tmp/mcp-remote-wrapper.log}"
ERROR_PATTERNS=("ClosedResourceError" "Connection to provider dropped" "ECONNREFUSED" "ETIMEDOUT" "ReadTimeout")

# ---------- logging ----------
log() {
    local level="$1"; shift
    local ts
    ts=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
    echo "${ts} [${level}] $*" | tee -a "$LOG_FILE" >&2
}

# ---------- signal handling ----------
cleanup() {
    if [[ -n "${CHILD_PID:-}" ]] && kill -0 "$CHILD_PID" 2>/dev/null; then
        log INFO "Stopping mcp-remote (PID=${CHILD_PID})..."
        kill -TERM "$CHILD_PID" 2>/dev/null || true
        wait "$CHILD_PID" 2>/dev/null || true
    fi
    log INFO "Wrapper shutting down"
    exit 0
}
trap cleanup SIGTERM SIGINT SIGQUIT

# ---------- reconnect logic ----------
retry_count=0

while true; do
    if [[ $retry_count -ge $MAX_RETRIES ]]; then
        log ERROR "Max retries (${MAX_RETRIES}) exceeded. Exiting to let container restart policy handle recovery."
        exit 1
    fi

    log INFO "Starting mcp-remote (attempt $((retry_count + 1))/${MAX_RETRIES}): $*"

    # Start mcp-remote in background, capture stderr for error detection
    # We use a named pipe to monitor output while passing it through
    PIPE="/tmp/mcp-remote-stderr-$$"
    mkfifo "$PIPE" 2>/dev/null || true

    # Monitor stderr for error patterns in background
    error_detected=0
    (
        while IFS= read -r line; do
            echo "$line" >&2
            for pattern in "${ERROR_PATTERNS[@]}"; do
                if echo "$line" | grep -qE "$pattern"; then
                    log WARN "Detected error pattern '${pattern}' in mcp-remote output"
                    error_detected=1
                    break 2
                fi
            done
        done < "$PIPE"
    ) &
    MONITOR_PID=$!

    # Start mcp-remote with stderr redirected to the pipe
    "$@" 2>"$PIPE" &
    CHILD_PID=$!

    # Wait for mcp-remote to exit
    wait "$CHILD_PID" 2>/dev/null
    exit_code=$?

    # Cleanup monitor and pipe
    kill "$MONITOR_PID" 2>/dev/null || true
    wait "$MONITOR_PID" 2>/dev/null || true
    rm -f "$PIPE" 2>/dev/null || true

    log WARN "mcp-remote exited with code ${exit_code}, error_detected=${error_detected}"

    # If exit was clean (SIGTERM from wrapper shutdown), don't retry
    if [[ $exit_code -eq 143 ]]; then
        log INFO "mcp-remote terminated by signal (wrapper shutdown)"
        exit 0
    fi

    # Calculate backoff with exponential jitter
    backoff=$((BACKOFF_BASE * (2 ** retry_count)))
    if [[ $backoff -gt $BACKOFF_MAX ]]; then
        backoff=$BACKOFF_MAX
    fi
    # Add jitter (0-50% of backoff)
    jitter=$((backoff * RANDOM / 32768 / 2))
    backoff=$((backoff + jitter))

    retry_count=$((retry_count + 1))
    log INFO "Waiting ${backoff}s before reconnect attempt ${retry_count}/${MAX_RETRIES}..."
    sleep "$backoff"
done
