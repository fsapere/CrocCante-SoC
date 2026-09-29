#!/bin/bash
# Unified backend flow orchestrator for Croc Cante
#
# Runs the whole backend sequentially and unattended:
#   benchmarks -> synthesis -> floorplan -> placement -> cts -> routing -> finishing -> power -> summary

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)
CROC_FILES_DIR="$REPO_ROOT/Croc_Files"
YOSYS_DIR="$CROC_FILES_DIR/yosys"
OPENROAD_DIR="$CROC_FILES_DIR/openroad"
LOG_DIR="$SCRIPT_DIR/logs"

OSEDA_VERSION="${OSEDA_VERSION:-2026.04}"
OSEDA_MARKER="CROC_BACKEND_IN_OSEDA"

if [[ "${BASH_SOURCE[0]}" != "$0" ]]; then
    echo "[ERROR] This script must be executed, not sourced."
    echo "[ERROR] Use: ./run_full_flow.sh"
    return 1 2>/dev/null || exit 1
fi

stage_banner() {
    echo "###############################################################################"
    echo "# [$(date '+%Y-%m-%d %H:%M:%S')] $1"
    echo "###############################################################################"
}

# --- OUTSIDE OSEDA ---
if [[ -z "${!OSEDA_MARKER:-}" ]]; then
    stage_banner "FUNCTIONAL VERIFICATION AND BENCHMARKS (Outside OSEDA)"
    
    cd "$SCRIPT_DIR"
    
    ./run_all_benchmarks.sh

    if ! command -v oseda >/dev/null 2>&1; then
        echo "[ERROR] oseda command not found in PATH" >&2
        exit 1
    fi

    mkdir -p "$LOG_DIR"
    LOG_FILE="$LOG_DIR/full_flow_$(date '+%Y%m%d_%H%M%S').log"

    echo "[INFO] Launching OSEDA $OSEDA_VERSION and re-running this script inside it"
    echo "[INFO] Logging full output to: $LOG_FILE"

    oseda -"$OSEDA_VERSION" bash <<EOF 2>&1 | tee "$LOG_FILE"
export $OSEDA_MARKER=1
bash "$SCRIPT_DIR/run_full_flow.sh"
EOF
    
    # Store the result of OSEDA run
    backend_status=${PIPESTATUS[0]}
    if [ $backend_status -ne 0 ]; then
        echo "[ERROR] Backend execution inside OSEDA failed."
        exit $backend_status
    fi

    # Back outside OSEDA: QuestaSim and the summary scripts run on the host
    stage_banner "POST-LAYOUT POWER ANALYSIS (Outside OSEDA)"
    cd "$SCRIPT_DIR"
    ./postlayout_powersim.sh 2>&1 | tee -a "$LOG_FILE"

    stage_banner "GENERATE SUMMARY REPORT"
    cd "$SCRIPT_DIR"
    python3 ./generate_summary_report.py 2>&1 | tee -a "$LOG_FILE"
    if [ -f "metrics_summary.json" ]; then
        mv metrics_summary.json metrics_cordic.json
        echo "[INFO] Summary renamed to metrics_cordic.json" 2>&1 | tee -a "$LOG_FILE"
    fi

    stage_banner "FULL FLOW COMPLETE"
    exit 0
fi

# --- INSIDE OSEDA ---
run_flow_inside_oseda() {
    stage_banner "SYNTHESIS (yosys)"
    cd "$YOSYS_DIR"
    ./run_synthesis.sh --synth -v

    stage_banner "BACKEND (floorplan -> placement -> cts -> routing -> finishing)"
    cd "$OPENROAD_DIR"
    ./run_backend.sh --all
}

run_flow_inside_oseda
