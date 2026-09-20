#!/bin/bash
# DRC with KLayout, LVS with Calibre.
# The Calibre LVS setup (Croc_Files/calibre/) comes from the course environment
# and is not distributed with this repository.

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
cd "$SCRIPT_DIR/../Croc_Files"

# 1. DRC
cd klayout
# Generate GDS from DEF
oseda -2026.04 ./def2gds-croc
# Run DRC
oseda -2026.04 ./run_drc-croc
cd ..

if [ ! -d calibre/lvs ]; then
    echo "[WARNING] Croc_Files/calibre/lvs not found: skipping LVS"
    exit 0
fi

# 2. Generate SPICE netlist
cd calibre/lvs
./verilog2spice ../../openroad/out/croc_lvs.v croc_chip.spice
cd ..

# 3. LVS
./start_calibre
