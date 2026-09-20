#!/bin/bash
# Wrapper script to run the baseline flow using the exact reference flow structure
# but injecting the user's custom power simulation and extracting only the final metrics.

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)
CROC_FILES_DIR="$REPO_ROOT/Croc_Files"

# The user requested to run the full flow EXACTLY like the reference, inside Solutions/reference_flow
REF_FLOW_ROOT="$REPO_ROOT/Solutions/reference_flow"
STAGING_CROC_FILES="$REF_FLOW_ROOT/Croc_Files"
STAGING_SCRIPTING="$REF_FLOW_ROOT/Scripting"

echo "[INFO] Creating reference flow staging directory at $REF_FLOW_ROOT"
rm -rf "$REF_FLOW_ROOT"
mkdir -p "$STAGING_CROC_FILES"
mkdir -p "$STAGING_SCRIPTING"

echo "[INFO] Copying sol11 into reference_flow/Croc_Files..."
# sol11 IS the reference flow (it has rtl, openroad, yosys etc. at the root level).
# We place it inside Croc_Files to match the structure that run_full_flow.sh expects.
cp -r /scratch/vlsi2_01fs26/ExSolutions/sol11/* "$STAGING_CROC_FILES/"

echo "[INFO] Copying user's Scripting folder into reference_flow..."
cp -r "$SCRIPT_DIR/"* "$STAGING_SCRIPTING/"

echo "[INFO] Copying user's power sim files into reference flow..."
# The user wants to use their own power simulation and performance benchmarking.
cp "$CROC_FILES_DIR/sw/test_baseline_power.c" "$STAGING_CROC_FILES/sw/"
cp "$CROC_FILES_DIR/sw/test_baseline_performance.c" "$STAGING_CROC_FILES/sw/"
cp -r "$CROC_FILES_DIR/vsim" "$STAGING_CROC_FILES/"
cp "$CROC_FILES_DIR/openroad/scripts/06_power.tcl" "$STAGING_CROC_FILES/openroad/scripts/"
cp "$CROC_FILES_DIR/openroad/scripts/07_IRdrop.tcl" "$STAGING_CROC_FILES/openroad/scripts/"
cp "$CROC_FILES_DIR/openroad/scripts/extractspef.tcl" "$STAGING_CROC_FILES/openroad/scripts/"

# The post-layout power sim requires the updated testbench to dump the VCD properly
cp "$CROC_FILES_DIR/rtl/test/tb_croc_soc.sv" "$STAGING_CROC_FILES/rtl/test/"

echo "[INFO] Patching postlayout_powersim.sh for reference flow..."
cd "$STAGING_SCRIPTING"
# Patch test_cordic_power to test_baseline_power since we're running baseline
sed -i 's/test_cordic_power/test_baseline_power/g' postlayout_powersim.sh
# Patch hardcoded absolute paths to point to the reference flow instead of the main repo
sed -i "s|/scratch/vlsi2_01fs26/CrocCante/Croc_Files|$STAGING_CROC_FILES|g" postlayout_powersim.sh

# Disable original run_all_benchmarks.sh and replace it with a baseline-specific one
cat << 'EOF' > "$STAGING_SCRIPTING/run_all_benchmarks.sh"
#!/bin/bash
set -euo pipefail
SUMMARY_FILE="summary.txt"
echo "========================================" > $SUMMARY_FILE
echo "    Baseline Benchmark Summary          " >> $SUMMARY_FILE
echo "========================================" >> $SUMMARY_FILE

run_and_extract() {
    local prog=$1
    local title=$2
    echo "Running $title ($prog)..."
    echo "" >> $SUMMARY_FILE
    echo "--- $title ---" >> $SUMMARY_FILE
    ./run_functional_verification.sh --program $prog > tmp_${prog}.log 2>&1 || true
    cat tmp_${prog}.log | grep "\[SUMMARY\]" | sed 's/.*\[SUMMARY\] //g' >> $SUMMARY_FILE || true
    rm -f tmp_${prog}.log
}

run_and_extract "test_baseline_performance" "Baseline SW Performance"

echo ""
echo "==== SUMMARY REPORT ===="
cat $SUMMARY_FILE
echo "========================"
EOF
chmod +x "$STAGING_SCRIPTING/run_all_benchmarks.sh"

echo "[INFO] Baseline shadow workspace ready."
echo "[INFO] Executing full flow on baseline chip..."

# Start the full flow in the staging environment
./run_full_flow.sh

echo "[INFO] Exporting final metrics to main directory..."

# Move the resulting metrics out to the main directory
if [ -f "$STAGING_SCRIPTING/metrics_baseline.json" ]; then
    cp "$STAGING_SCRIPTING/metrics_baseline.json" "$SCRIPT_DIR/metrics_baseline.json"
    echo "[INFO] Successfully exported metrics_baseline.json to main Scripting directory."
elif [ -f "$STAGING_SCRIPTING/metrics_cordic.json" ]; then
    cp "$STAGING_SCRIPTING/metrics_cordic.json" "$SCRIPT_DIR/metrics_baseline.json"
    echo "[INFO] Successfully exported metrics_baseline.json to main Scripting directory."
elif [ -f "$STAGING_SCRIPTING/metrics_summary.json" ]; then
    cp "$STAGING_SCRIPTING/metrics_summary.json" "$SCRIPT_DIR/metrics_baseline.json"
    echo "[INFO] Successfully exported metrics_baseline.json to main Scripting directory."
else
    echo "[WARNING] Could not find generated metrics file in staging!"
fi

# Export the power report for the plots
if [ -f "$STAGING_CROC_FILES/openroad/reports/power_statistical_tt.rpt" ]; then
    mkdir -p "$CROC_FILES_DIR/openroad/reports"
    cp "$STAGING_CROC_FILES/openroad/reports/power_statistical_tt.rpt" "$CROC_FILES_DIR/openroad/reports/power_baseline.rpt"
    echo "[INFO] Successfully exported power_baseline.rpt to main Croc_Files/openroad/reports directory."
else
    echo "[WARNING] Could not find generated power_statistical_tt.rpt in staging!"
fi

echo "[INFO] Baseline flow complete."
