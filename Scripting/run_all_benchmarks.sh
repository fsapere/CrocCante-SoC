#!/bin/bash
set -euo pipefail

SUMMARY_FILE="summary.txt"

echo "========================================" > $SUMMARY_FILE
echo "        CrocCante Benchmark Summary     " >> $SUMMARY_FILE
echo "========================================" >> $SUMMARY_FILE

run_and_extract() {
    local prog=$1
    local title=$2
    
    echo "Running $title ($prog)..."
    echo "" >> $SUMMARY_FILE
    echo "--- $title ---" >> $SUMMARY_FILE
    
    # Run the program and capture output
    # Grep for lines with [SUMMARY] and strip the VCD/Time prefix to keep it clean
    ./run_functional_verification.sh --program $prog > tmp_$prog.log 2>&1 || true
    
    cat tmp_$prog.log | grep "\[SUMMARY\]" | sed 's/.*\[SUMMARY\] //g' >> $SUMMARY_FILE || true
    rm -f tmp_$prog.log
}

echo "========================================"
echo "    Running Functional Verification     "
echo "========================================"
run_and_extract "test_cordic_correctness" "Functional Verification"

echo "========================================"
echo " Running SW vs HW Speedup Analysis      "
echo "========================================"
run_and_extract "test_cordic_HWSW_compare" "HW vs. SW  Speedup Analysis"

echo "========================================"
echo " Running Edge Cases for Handshaking          "
echo "========================================"
run_and_extract "test_cordic_handshaking" "Edge Cases for handshaking logic"

echo "========================================"
echo " Running Bank Contention Profiling      "
echo "========================================"
run_and_extract "test_cordic_contention" "SRAM Bank Contention Penalty"

echo "========================================"
echo "          All Benchmarks Done!          "
echo "========================================"

echo ""
echo "==== SUMMARY REPORT ===="
cat $SUMMARY_FILE
echo "========================"
