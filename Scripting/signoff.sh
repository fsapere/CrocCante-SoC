#!/bin/bash
# set -e

cd ../Croc_Files

# 1. DRC
cd klayout
# Generate GDS from DEF
oseda -2026.04 ./def2gds-croc
# Run DRC
oseda -2026.04 ./run_drc-croc
cd ..

# 2. Generate SPICE netlist
cd calibre/lvs
./verilog2spice ../../openroad/out/croc_lvs.v croc_chip.spice
cd ..

# 3. LVS
./start_calibre

# Return to the main directory
cd ../../Scripting
