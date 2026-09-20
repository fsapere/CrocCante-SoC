#!/bin/bash
# Runs the full flow on the baseline Croc SoC (reference flow from the course exercises),
# injecting our power simulation setup, and exports only the final metrics.
#
# Usage:
#   BASELINE_SRC=/path/to/reference/croc ./run_baseline_flow.sh

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)
CROC_FILES_DIR="$REPO_ROOT/Croc_Files"

# Reference Croc flow (course exercise solution); not distributed with this repository
BASELINE_SRC="${BASELINE_SRC:?Set BASELINE_SRC to the reference Croc flow directory (rtl/, openroad/, yosys/, ...)}"

# Staged under tmp/ (git-ignored); 04a_plot_area_comparison.py reads the baseline area report from here
REF_FLOW_ROOT="$REPO_ROOT/tmp/baseline_run"
STAGING_CROC_FILES="$REF_FLOW_ROOT/Croc_Files"
STAGING_SCRIPTING="$REF_FLOW_ROOT/Scripting"

echo "[INFO] Creating reference flow staging directory at $REF_FLOW_ROOT"
rm -rf "$REF_FLOW_ROOT"
mkdir -p "$STAGING_CROC_FILES"
mkdir -p "$STAGING_SCRIPTING"

echo "[INFO] Copying the reference flow from $BASELINE_SRC into the staging Croc_Files..."
# The reference flow has rtl, openroad, yosys etc. at the root level:
# we place it inside Croc_Files to match the structure that run_full_flow.sh expects.
cp -r "$BASELINE_SRC"/* "$STAGING_CROC_FILES/"

echo "[INFO] Copying the Scripting folder into the staging area..."
cp -r "$SCRIPT_DIR/"* "$STAGING_SCRIPTING/"

echo "[INFO] Copying our power simulation files into the staging area..."
mkdir -p "$STAGING_CROC_FILES/sw/test"
cp "$CROC_FILES_DIR/sw/test/test_baseline_power.c" "$STAGING_CROC_FILES/sw/test/"
cp -r "$CROC_FILES_DIR/vsim" "$STAGING_CROC_FILES/"
cp "$CROC_FILES_DIR/ihp13/empty_cells.v" "$STAGING_CROC_FILES/ihp13/"
cp "$CROC_FILES_DIR/openroad/scripts/06_power.tcl" "$STAGING_CROC_FILES/openroad/scripts/"
cp "$CROC_FILES_DIR/openroad/scripts/07_IRdrop.tcl" "$STAGING_CROC_FILES/openroad/scripts/"
cp "$CROC_FILES_DIR/openroad/scripts/extractspef.tcl" "$STAGING_CROC_FILES/openroad/scripts/"

# The post-layout power sim requires the updated testbench to dump the VCD properly
cp "$CROC_FILES_DIR/rtl/test/tb_croc_soc.sv" "$STAGING_CROC_FILES/rtl/test/"

# postlayout_powersim.sh (called by run_full_flow.sh) simulates this program instead of test_cordic_power
export POWER_PROGRAM="test_baseline_power"

# The baseline has no accelerator to benchmark: compare_summaries.py takes the baseline
# cycle count from the SW CORDIC run of the main flow, so no benchmark is run here.
cat << 'EOF2' > "$STAGING_SCRIPTING/run_all_benchmarks.sh"
#!/bin/bash
set -euo pipefail
echo "Baseline flow: no benchmarks to run" > summary.txt
EOF2
chmod +x "$STAGING_SCRIPTING/run_all_benchmarks.sh"

cd "$STAGING_SCRIPTING"
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
