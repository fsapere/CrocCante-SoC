#!/bin/bash

# Generates the area, power, performance and energy comparison plots
# from the backend reports and the JSON metrics of both flows.

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)
PYTHON_SCRIPTS_DIR="$SCRIPT_DIR/plots_scripts"

echo "Starting plot generation for CrocCante..."

# The plotting scripts use paths relative to the repository root and save to plots/
cd "$REPO_ROOT"
mkdir -p plots

# We use the final routed report which contains the Hierarchical Area Report
AREA_REPORT="Croc_Files/openroad/reports/04_croc.routed.rpt"

if [ ! -f "$AREA_REPORT" ]; then
    echo "Error: Area report $AREA_REPORT not found!"
    exit 1
fi

export PYTHONPATH="$PYTHON_SCRIPTS_DIR:${PYTHONPATH:-}"

# Run python using the Apptainer environment provided by oseda -2026.04
# to make sure matplotlib and other dependencies are available!
echo "Running 03a_plot_power_comparison.py..."
oseda -2026.04 python3 "$PYTHON_SCRIPTS_DIR/03a_plot_power_comparison.py"
echo "Running 03b_plot_die_area_breakdown.py..."
oseda -2026.04 python3 "$PYTHON_SCRIPTS_DIR/03b_plot_die_area_breakdown.py"
echo "Running 04a_plot_area_comparison.py..."
oseda -2026.04 python3 "$PYTHON_SCRIPTS_DIR/04a_plot_area_comparison.py"
echo "Running 04b_plot_execution_cycles.py..."
oseda -2026.04 python3 "$PYTHON_SCRIPTS_DIR/04b_plot_execution_cycles.py"
echo "Running 04c_plot_energy_comparison.py..."
oseda -2026.04 python3 "$PYTHON_SCRIPTS_DIR/04c_plot_energy_comparison.py"

echo ""
echo "Done! All plots have been generated in: $REPO_ROOT/plots/"
