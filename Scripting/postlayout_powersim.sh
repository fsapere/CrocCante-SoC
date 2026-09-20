#!/bin/bash

# Stop script immediately if QuestaSim or OpenROAD fails
set -e

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CROC_FILES_DIR="$SCRIPT_DIR/../Croc_Files"
POWER_PROGRAM="${POWER_PROGRAM:-test_cordic_power}"
RISCV_TOOLCHAIN_BIN="${RISCV_TOOLCHAIN_BIN:-/usr/pack/riscv-1.0-kgf/riscv64-gcc-13.2.0/bin}"

source "$CROC_FILES_DIR/env.sh"

# 0. Compile .c file
cd "$CROC_FILES_DIR/sw"
make clean
export PATH="$RISCV_TOOLCHAIN_BIN:$PATH"
make "bin/test/$POWER_PROGRAM.hex"

# 1. VCD Generation (Explicit +acc to prevent signal optimization)
cd "$CROC_FILES_DIR/vsim"

# POST-LAYOUT netlist being built
./run_vsim.sh --build-postlayout

# Simulation (kept +acc to ensure internal signals are traced in VCD)
questa-2023.4 vsim +binary="../sw/bin/test/$POWER_PROGRAM.hex" +power_sim -c tb_croc_soc -t 1ns -voptargs=+acc \
  -suppress vsim-3009 -suppress vsim-8683 -suppress vsim-8386 \
  -suppress vsim-2685 -suppress vsim-3722 \
  -do "run -all; exit"

# Fix VCD timestamps
python3 fixvcd.py croc.vcd croc_fixed.vcd

cd ../openroad/

# Post Layout Power Analysis
oseda -2026.04 openroad scripts/extractspef.tcl
oseda -2026.04 openroad scripts/06_power.tcl
oseda -2026.04 openroad scripts/07_IRdrop.tcl
