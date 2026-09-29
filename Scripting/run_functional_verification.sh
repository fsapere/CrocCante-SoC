#!/bin/bash
# Unified functional verification flow for Croc Cante
#
# This script:
#   1) enters the requested OSEDA environment if needed
#   2) sources Croc_Files/env.sh once
#   3) builds the selected software image
#   4) runs the Verilator flow with that image
#
# Default use-case:
#   ./run_functional_verification.sh
#
# Default program:
#   helloworld

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)
CROC_FILES_DIR="$REPO_ROOT/Croc_Files"
ENV_SH="$CROC_FILES_DIR/env.sh"
SW_DIR="$CROC_FILES_DIR/sw"
VERILATOR_DIR="$CROC_FILES_DIR/verilator"
OSEDA_VERSION="${OSEDA_VERSION:-2026.02}"
PROGRAM_NAME="${PROGRAM_NAME:-helloworld}"
OSEDA_MARKER="CROC_RUNNING_IN_OSEDA"

if [[ "${BASH_SOURCE[0]}" != "$0" ]]; then
    echo "[ERROR] This script must be executed, not sourced."
    echo "[ERROR] Use: ./run_functional_verification.sh"
    return 1 2>/dev/null || exit 1
fi

show_help() {
    cat << EOF
Functional verification coordinator

Usage:
    ./run_functional_verification.sh [OPTIONS]

Options:
    --help, -h                Show this help message
    --program NAME            Build and run sw/NAME.c or sw/test/NAME.c
                              Default: helloworld
    --oseda-version VERSION   OSEDA container version to use
                              Default: 2026.02
    --inside-oseda            Internal marker used by the wrapper

Examples:
    ./run_functional_verification.sh
    ./run_functional_verification.sh --program helloworld
    OSEDA_VERSION=2026.02 ./run_functional_verification.sh
EOF
}

normalize_program_name() {
    local raw_name="$1"

    if [[ "$raw_name" == *.hex ]]; then
        raw_name="${raw_name%.hex}"
    fi

    echo "$raw_name"
}

run_flow() {
    if [[ ! -f "$ENV_SH" ]]; then
        echo "[ERROR] Cannot find env.sh at: $ENV_SH" >&2
        exit 1
    fi

    source "$ENV_SH"

    # The Makefile mirrors the source tree: sw/test/NAME.c is built as bin/test/NAME.hex
    local hex_path="bin/${PROGRAM_NAME}.hex"
    if [[ ! -f "$SW_DIR/${PROGRAM_NAME}.c" && -f "$SW_DIR/test/${PROGRAM_NAME}.c" ]]; then
        hex_path="bin/test/${PROGRAM_NAME}.hex"
    fi

    echo "[INFO][FLOW] Repository root : $REPO_ROOT"
    echo "[INFO][FLOW] Croc files dir  : $CROC_FILES_DIR"
    echo "[INFO][FLOW] Program         : $PROGRAM_NAME"
    echo "[INFO][FLOW] Software image  : $hex_path"
    echo "[INFO][FLOW] OSEDA version   : $OSEDA_VERSION"

    cd "$SW_DIR"
    echo "[INFO][SW] Cleaning previous build artifacts"
    # make clean

    echo "[INFO][SW] Building $hex_path"
    # Use custom linker script for programs that need extra SRAM
    local make_args=""
    if [[ ("$PROGRAM_NAME" == "test_cordic_HWSW_compare" || "$PROGRAM_NAME" == "test_cordic_HWSW_sweep") && -f "link_hwsw.ld" ]]; then
        make_args="LINK=link_hwsw.ld"
        echo "[INFO][SW] Using custom linker script: link_hwsw.ld"
    fi
    make $make_args "$hex_path"

    if [[ ! -f "$hex_path" ]]; then
        echo "[ERROR][SW] Expected output missing: $SW_DIR/$hex_path" >&2
        exit 1
    fi

    cd "$VERILATOR_DIR"
    echo "[INFO][VERILATOR] Cleaning previous Verilator build artifacts"
    rm -rf obj_dir
    echo "[INFO][VERILATOR] Building and running with $hex_path"
    ./run_verilator.sh --build --run "../sw/$hex_path"
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    show_help
    exit 0
fi

while [[ $# -gt 0 ]]; do
    case "$1" in
        --program)
            if [[ $# -lt 2 ]]; then
                echo "[ERROR] --program requires a value" >&2
                exit 1
            fi
            PROGRAM_NAME=$(normalize_program_name "$2")
            shift 2
            ;;
        --oseda-version)
            if [[ $# -lt 2 ]]; then
                echo "[ERROR] --oseda-version requires a value" >&2
                exit 1
            fi
            OSEDA_VERSION="$2"
            shift 2
            ;;
        --inside-oseda)
            export "$OSEDA_MARKER"=1
            shift
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        *)
            echo "[ERROR] Unknown option: $1" >&2
            exit 1
            ;;
    esac
done

if [[ -z "${!OSEDA_MARKER:-}" ]]; then
    if ! command -v oseda >/dev/null 2>&1; then
        echo "[ERROR] oseda command not found in PATH" >&2
        exit 1
    fi

    echo "[INFO] Launching OSEDA $OSEDA_VERSION and re-running this script inside it"
    exec oseda -"$OSEDA_VERSION" bash <<EOF
bash "$SCRIPT_DIR/run_functional_verification.sh" --inside-oseda --program "$PROGRAM_NAME" --oseda-version "$OSEDA_VERSION"
EOF
fi

run_flow