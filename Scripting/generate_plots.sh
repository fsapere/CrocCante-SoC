#!/bin/bash

# Wrapper script to run all the area breakdown Python plotting scripts
# using the backend data from CrocCante instead of the reference flow.

echo "Starting plot generation for CrocCante..."

# The scripts will save to "plots/" in the current directory.
# Let's run this from the main CrocCante folder so plots go to CrocCante/plots/
cd /scratch/vlsi2_01fs26/CrocCante || { echo "CrocCante directory not found!"; exit 1; }

# Create plots directory if it doesn't exist
mkdir -p plots

# The path to the python scripts that we locally modified!
PYTHON_SCRIPTS_DIR="/scratch/vlsi2_01fs26/CrocCante/Scripting/plots_scripts"

# We use the final routed report which contains the Hierarchical Area Report
AREA_REPORT="Croc_Files/openroad/reports/04_croc.routed.rpt"

if [ ! -f "$AREA_REPORT" ]; then
    echo "Error: Area report $AREA_REPORT not found!"
    exit 1
fi

export PYTHONPATH="$PYTHON_SCRIPTS_DIR:$PYTHONPATH"

# Run python using the Apptainer environment provided by oseda -2026.04
# to make sure matplotlib and other dependencies are available!
echo "Running 01a_plot_area_bar_sol.py..."
oseda -2026.04 python3 $PYTHON_SCRIPTS_DIR/01a_plot_area_bar_sol.py "$AREA_REPORT"

echo "Running 01b_plot_area_pie_sol.py..."
oseda -2026.04 python3 $PYTHON_SCRIPTS_DIR/01b_plot_area_pie_sol.py "$AREA_REPORT"

echo "Running 02a_plot_area_stacked_bar_sol.py..."
oseda -2026.04 python3 $PYTHON_SCRIPTS_DIR/02a_plot_area_stacked_bar_sol.py "$AREA_REPORT"

echo "Running 02b_plot_area_stacked_bar_sol.py..."
oseda -2026.04 python3 $PYTHON_SCRIPTS_DIR/02b_plot_area_stacked_bar_sol.py "$AREA_REPORT"

echo ""
echo "Done! All plots have been generated."
echo "You can find them in: /scratch/vlsi2_01fs26/CrocCante/plots/"

echo "Running 03a_plot_power_comparison.py..."
oseda -2026.04 python3 $PYTHON_SCRIPTS_DIR/03a_plot_power_comparison.py
echo "Running 03b_plot_die_area_breakdown.py..."
oseda -2026.04 python3 $PYTHON_SCRIPTS_DIR/03b_plot_die_area_breakdown.py
echo "Running 04a_plot_area_comparison.py..."
oseda -2026.04 python3 $PYTHON_SCRIPTS_DIR/04a_plot_area_comparison.py
echo "Running 04b_plot_execution_cycles.py..."
oseda -2026.04 python3 $PYTHON_SCRIPTS_DIR/04b_plot_execution_cycles.py
echo "Running 04c_plot_energy_comparison.py..."
oseda -2026.04 python3 $PYTHON_SCRIPTS_DIR/04c_plot_energy_comparison.py
echo "Done! All extended plots have been generated."
