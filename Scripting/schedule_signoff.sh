#!/bin/bash
# Schedule the full backend flow to start at a given time without requiring 'at'.
#
# Uses a background sleeper (nohup + sleep) that launches run_full_flow.sh when the
# target time is reached. Works on systems where 'at' is disabled for your user.
#
# Usage:
#   ./schedule_backend.sh "02:00"              # next occurrence of 02:00 (today or tomorrow)
#   ./schedule_backend.sh "now + 3 hours"      # relative delay (GNU date syntax)
#   ./schedule_backend.sh "01:00 tomorrow"
#   ./schedule_backend.sh --status             # show pending schedule
#   ./schedule_backend.sh --cancel             # cancel pending schedule
#
# Output from the flow itself is logged by run_full_flow.sh under Scripting/logs/.

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
FLOW_SCRIPT="$SCRIPT_DIR/signoff.sh"
LOG_DIR="$SCRIPT_DIR/logs"
PID_FILE="$LOG_DIR/scheduled_signoff.pid"
INFO_FILE="$LOG_DIR/scheduled_signoff.info"

show_help() {
    cat << EOF
Schedule backend flow without 'at' (uses nohup + sleep)

Usage:
    ./schedule_backend.sh <time-spec>
    ./schedule_backend.sh --status
    ./schedule_backend.sh --cancel

Time examples (GNU date):
    "02:00"              next 02:00 today, or tomorrow if already passed
    "now + 3 hours"
    "now + 30 minutes"
    "01:00 tomorrow"

Cancel / status:
    ./schedule_backend.sh --cancel    kill the pending sleeper (flow not started yet)
    ./schedule_backend.sh --status    show PID and planned start time

Note: If the flow has already started, use normal process tools to stop it.
EOF
}

read_scheduled_info() {
    if [[ -f "$INFO_FILE" ]]; then
        # shellcheck source=/dev/null
        source "$INFO_FILE"
    fi
}

is_pid_alive() {
    local pid="$1"
    kill -0 "$pid" 2>/dev/null
}

cleanup_stale_schedule() {
    if [[ ! -f "$PID_FILE" ]]; then
        return 0
    fi
    local pid
    pid=$(<"$PID_FILE")
    if ! is_pid_alive "$pid"; then
        rm -f "$PID_FILE" "$INFO_FILE"
    fi
}

cmd_status() {
    cleanup_stale_schedule
    if [[ ! -f "$PID_FILE" ]]; then
        echo "[INFO] No backend flow scheduled."
        return 0
    fi
    read_scheduled_info
    local pid
    pid=$(<"$PID_FILE")
    echo "[INFO] Scheduled backend flow"
    echo "  PID (sleeper):  $pid"
    echo "  Planned start:  ${PLANNED_START:-unknown}"
    echo "  Time spec:      ${TIME_SPEC:-unknown}"
    echo "  Scheduled at:   ${SCHEDULED_AT:-unknown}"
    echo ""
    echo "Cancel with: ./schedule_backend.sh --cancel"
}

cmd_cancel() {
    cleanup_stale_schedule
    if [[ ! -f "$PID_FILE" ]]; then
        echo "[INFO] Nothing to cancel (no pending schedule)."
        return 0
    fi
    local pid
    pid=$(<"$PID_FILE")
    if is_pid_alive "$pid"; then
        kill "$pid" 2>/dev/null || true
        # Give it a moment, then force-kill if needed
        sleep 0.5
        if is_pid_alive "$pid"; then
            kill -9 "$pid" 2>/dev/null || true
        fi
        echo "[INFO] Cancelled scheduled job (PID $pid)."
    else
        echo "[INFO] Scheduled PID $pid was not running."
    fi
    rm -f "$PID_FILE" "$INFO_FILE"
}

# Resolve time spec to epoch seconds and human-readable planned start.
resolve_target_epoch() {
    local spec="$1"
    local now_epoch target_epoch

    now_epoch=$(date +%s)

    # Relative: "now + N hours/minutes/..."
    if [[ "$spec" =~ ^now[[:space:]]+\+ ]]; then
        target_epoch=$(date -d "$spec" +%s)
        echo "$target_epoch"
        return 0
    fi

    # Absolute with date keywords (tomorrow, etc.)
    if target_epoch=$(date -d "$spec" +%s 2>/dev/null); then
        if (( target_epoch > now_epoch )); then
            echo "$target_epoch"
            return 0
        fi
    fi

    # Bare clock time HH:MM or HH:MM:SS -> today, else tomorrow
    target_epoch=$(date -d "today $spec" +%s 2>/dev/null) || {
        echo "[ERROR] Cannot parse time spec: $spec" >&2
        echo "[ERROR] Use GNU date syntax, e.g. \"02:00\", \"now + 2 hours\", \"01:00 tomorrow\"" >&2
        return 1
    }
    if (( target_epoch <= now_epoch )); then
        target_epoch=$(date -d "tomorrow $spec" +%s)
    fi
    echo "$target_epoch"
}

cmd_schedule() {
    local time_spec="$1"
    local target_epoch now_epoch delay_secs planned_start scheduled_at wrapper_pid

    if [[ ! -x "$FLOW_SCRIPT" ]]; then
        echo "[ERROR] Cannot find executable orchestrator at: $FLOW_SCRIPT" >&2
        exit 1
    fi

    cleanup_stale_schedule
    if [[ -f "$PID_FILE" ]]; then
        echo "[ERROR] A schedule is already pending. Cancel it first:" >&2
        echo "  ./schedule_backend.sh --cancel" >&2
        cmd_status
        exit 1
    fi

    target_epoch=$(resolve_target_epoch "$time_spec")
    now_epoch=$(date +%s)
    delay_secs=$(( target_epoch - now_epoch ))

    if (( delay_secs < 1 )); then
        echo "[ERROR] Target time is in the past or too soon: $time_spec" >&2
        exit 1
    fi

    planned_start=$(date -d "@$target_epoch" '+%Y-%m-%d %H:%M:%S %Z')
    scheduled_at=$(date '+%Y-%m-%d %H:%M:%S %Z')

    mkdir -p "$LOG_DIR"
    SCHEDULE_LOG="$LOG_DIR/scheduled_signoff_$(date '+%Y%m%d_%H%M%S').log"

    cat > "$INFO_FILE" <<EOF
TIME_SPEC='$time_spec'
PLANNED_START='$planned_start'
SCHEDULED_AT='$scheduled_at'
DELAY_SECS=$delay_secs
SCHEDULE_LOG='$SCHEDULE_LOG'
EOF

    nohup bash -c "
        set -euo pipefail
        echo \"[INFO][SCHEDULE] Waiting ${delay_secs}s until ${planned_start}\"
        sleep ${delay_secs}
        echo \"[INFO][SCHEDULE] Starting run_full_flow.sh at \$(date '+%Y-%m-%d %H:%M:%S %Z')\"
        exec bash \"${FLOW_SCRIPT}\"
    " >> "$SCHEDULE_LOG" 2>&1 &

    wrapper_pid=$!
    echo "$wrapper_pid" > "$PID_FILE"

    echo "[INFO] Backend flow scheduled (no 'at' required)"
    echo "  Time spec:      $time_spec"
    echo "  Planned start:  $planned_start"
    echo "  Delay:          ${delay_secs}s (~$(( delay_secs / 3600 ))h $(( (delay_secs % 3600) / 60 ))m)"
    echo "  Sleeper PID:    $wrapper_pid"
    echo "  Schedule log:   $SCHEDULE_LOG"
    echo "  Flow log:       $LOG_DIR/full_flow_<timestamp>.log (created when flow starts)"
    echo ""
    echo "  ./schedule_backend.sh --status"
    echo "  ./schedule_backend.sh --cancel"
}

# --- main ---

if [[ $# -lt 1 ]]; then
    show_help
    exit 1
fi

case "${1:-}" in
    -h|--help)
        show_help
        exit 0
        ;;
    --status|-s)
        cmd_status
        ;;
    --cancel|-c)
        cmd_cancel
        ;;
    *)
        cmd_schedule "$1"
        ;;
esac
