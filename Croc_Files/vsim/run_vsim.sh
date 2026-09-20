#!/bin/bash
# Copyright (c) 2026 ETH Zurich and University of Bologna.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#
# Published with permission from Siemens. 
# Siemens QuestaSim is available through EDA Higher Education Software Program
# https://www.sw.siemens.com/en-US/academic/educators/eda-higher-education-software/
#
# Authors:
# - Thomas Benz     <tbenz@iis.ee.ethz.ch>


set -e  # Exit on error
set -u  # Error on undefined vars


################
# Setup
################
# Source environment
source "../env.sh"

VSIM=${VSIM:-questa-2023.4 vsim}


mkdir -p reports

################
# Helpers
################

show_help() {
    cat << EOF
VSIM Coordinator

Usage:
    ./run_vsim.sh [OPTIONS]

Options:
    --help, -h          Show this help message
    --dry-run, -n       Only print commands instead of executing
    --verbose, -v       Print commands while executing
    --build             Compile Croc RTL in VSIM
    --build-netlist     Compile Croc post-synthesis netlist in VSIM
    --build-postlayout  Compile Croc post-layout netlist in VSIM
    --run BINARY        Run binary in VSIM
    --run-gui BINARY    Prepare running binary in VSIM, open GUI

Example:
    # Build and run RTL simulation with given binary (CLI mode)
    ./run_vsim.sh --build --run ../sw/bin/helloworld.hex

EOF
    exit 0
}


run_cmd() {
    if [ "$DRYRUN" = 1 ]; then
        echo $1
    else
        eval $1
    fi
}


compile_rtl() {
    run_cmd "echo [INFO][VSIM] Compile"
    run_cmd "${VSIM} \
        -c \
        -do \"source compile_rtl.tcl; exit\" \
        > reports/compile_rtl.log"

    # Collect errors and warnings from compilation log and print summary
    run_cmd "echo [INFO][VSIM] Check reports/compile_rtl.log"
    run_cmd "echo --- QuestaSim compilation report ---  > reports/compile_rtl.rpt"
    run_cmd "echo Errors:                              >> reports/compile_rtl.rpt"
    run_cmd "grep Error: reports/compile_rtl.log       >> reports/compile_rtl.rpt || true"
    run_cmd "echo                                      >> reports/compile_rtl.rpt"
    run_cmd "echo Warnings:                            >> reports/compile_rtl.rpt"
    run_cmd "grep Warning: reports/compile_rtl.log     >> reports/compile_rtl.rpt || true"

    NUM_ERRORS=$(grep "Error:" reports/compile_rtl.rpt | wc -l || echo 0)
    NUM_WARNINGS=$(grep "Warning:" reports/compile_rtl.rpt | wc -l || echo 0)
    run_cmd "echo \"#######################################################\""
    run_cmd "echo \"############### Compilation report ####################\""
    run_cmd "echo \"#######################################################\""
    run_cmd "echo  Errors   : ${NUM_ERRORS}"
    run_cmd "echo  Warnings : ${NUM_WARNINGS}"
    run_cmd "echo See 'reports/compile_rtl.rpt' for more info"
    run_cmd "echo \"#######################################################\""

    # Make the error fatal
    if [ "$NUM_ERRORS" -gt 0 ]; then
        echo "[FATAL] RTL Compilation failed with $NUM_ERRORS errors. Exiting to prevent stale simulation."
        exit 1
    fi
}


compile_netlist() {
    run_cmd "echo [INFO][VSIM] Compile post-synthesis netlist"
    run_cmd "${VSIM} \
        -c \
        -do \"source compile_netlist.tcl; exit\" \
        > reports/compile_netlist.log"

    # Collect errors and warnings from compilation log and print summary
    run_cmd "echo [INFO][VSIM] Check reports/compile_netlist.log"
    run_cmd "echo --- QuestaSim compilation report ---  > reports/compile_netlist.rpt"
    run_cmd "echo Errors:                              >> reports/compile_netlist.rpt"
    run_cmd "grep Error: reports/compile_netlist.log       >> reports/compile_netlist.rpt || true"
    run_cmd "echo                                      >> reports/compile_netlist.rpt"
    run_cmd "echo Warnings:                            >> reports/compile_netlist.rpt"
    run_cmd "grep Warning: reports/compile_netlist.log     >> reports/compile_netlist.rpt || true"

    NUM_ERRORS=$(grep "Error:" reports/compile_netlist.rpt | wc -l || echo 0)
    NUM_WARNINGS=$(grep "Warning:" reports/compile_netlist.rpt | wc -l || echo 0)
    run_cmd "echo \"#######################################################\""
    run_cmd "echo \"############### Compilation report ####################\""
    run_cmd "echo \"#######################################################\""
    run_cmd "echo  Errors   : ${NUM_ERRORS}"
    run_cmd "echo  Warnings : ${NUM_WARNINGS}"
    run_cmd "echo See 'reports/compile_netlist.rpt' for more info"
    run_cmd "echo \"#######################################################\""

    # Make the error fatal
    if [ "$NUM_ERRORS" -gt 0 ]; then
        echo "[FATAL] Netlist Compilation failed with $NUM_ERRORS errors. Exiting to prevent stale simulation."
        exit 1
    fi
}


compile_postlayout() {
    run_cmd "echo [INFO][VSIM] Compile post-layout netlist"
    run_cmd "${VSIM} \
        -c \
        -do \"source compile_postlayout.tcl; exit\" \
        > reports/compile_postlayout.log"

    # Collect errors and warnings from compilation log and print summary
    run_cmd "echo [INFO][VSIM] Check reports/compile_postlayout.log"
    run_cmd "echo --- QuestaSim compilation report ---  > reports/compile_postlayout.rpt"
    run_cmd "echo Errors:                              >> reports/compile_postlayout.rpt"
    run_cmd "grep Error: reports/compile_postlayout.log       >> reports/compile_postlayout.rpt || true"
    run_cmd "echo                                      >> reports/compile_postlayout.rpt"
    run_cmd "echo Warnings:                            >> reports/compile_postlayout.rpt"
    run_cmd "grep Warning: reports/compile_postlayout.log     >> reports/compile_postlayout.rpt || true"

    NUM_ERRORS=$(grep "Error:" reports/compile_postlayout.rpt | wc -l || echo 0)
    NUM_WARNINGS=$(grep "Warning:" reports/compile_postlayout.rpt | wc -l || echo 0)
    run_cmd "echo \"#######################################################\""
    run_cmd "echo \"############### Compilation report ####################\""
    run_cmd "echo \"#######################################################\""
    run_cmd "echo  Errors   : ${NUM_ERRORS}"
    run_cmd "echo  Warnings : ${NUM_WARNINGS}"
    run_cmd "echo See 'reports/compile_postlayout.rpt' for more info"
    run_cmd "echo \"#######################################################\""

    # Make the error fatal
    if [ "$NUM_ERRORS" -gt 0 ]; then
        echo "[FATAL] Post-layout Compilation failed with $NUM_ERRORS errors. Exiting to prevent stale simulation."
        exit 1
    fi
}


run_vsim() {
    run_cmd "${VSIM} \
        +binary=$1 \
        -c \
        tb_croc_soc \
        -t 1ns \
        -suppress vsim-3009 \
        -suppress vsim-8683 \
        -suppress vsim-8386 \
        -do \"run -a; quit\""
}


run_vsim_gui() {
    run_cmd "${VSIM} \
        +binary=$1 \
        -gui \
        tb_croc_soc \
        -t 1ns \
        -voptargs=+acc \
        -suppress vsim-3009 \
        -suppress vsim-8683 \
        -suppress vsim-8386"
}


####################
# Parse Arguments
####################

DRYRUN=0

# default action if no argument is given
if [ $# -eq 0 ]; then
    show_help
    return 0
fi

# check for global arguments
for arg in "$@"; do
    [[ "$arg" == -v || "$arg" == --verbose ]] && set -x
    [[ "$arg" == -n || "$arg" == --dry-run ]] && DRYRUN=1
done

# parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --help|-h)
            show_help
            ;;
        --verbose|-v)
            shift
            ;;
        --dry-run|-n)
            shift
            ;;
        # script-specific commands
        --build)
            compile_rtl
            shift
            ;;
        --build-netlist)
            compile_netlist
            shift
            ;;

        --build-postlayout)
            compile_postlayout
            shift
            ;;
        --run)
            run_vsim $2
            shift 2
            ;;
        --run-gui)
            run_vsim_gui $2
            shift 2
            ;;
        # Error handling
        *)
            echo "[ERROR] Unknown option: $1 (use --help for usage)" >&2
            exit 1
            ;;
    esac
done