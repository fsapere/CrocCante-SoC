#!/bin/bash

# Stop script immediately if QuestaSim or OpenROAD fails
set -e

source /scratch/vlsi2_01fs26/CrocCante_fallback_working_finalmente/Croc_Files/env.sh

# 0. Compile .c file
cd /scratch/vlsi2_01fs26/CrocCante_fallback_working_finalmente/Croc_Files/sw
make clean
export PATH="/usr/pack/riscv-1.0-kgf/riscv64-gcc-13.2.0/bin:$PATH"
make bin/test_cordic_power.hex

# 1. VCD Generation (Explicit +acc to prevent signal optimization)
cd /scratch/vlsi2_01fs26/CrocCante_fallback_working_finalmente/Croc_Files/vsim

# POST-LAYOUT netlist being built
./run_vsim.sh --build-postlayout

# Simulation (kept +acc to ensure internal signals are traced in VCD)
questa-2023.4 vsim +binary="../sw/bin/test_cordic_power.hex" +power_sim -c tb_croc_soc -t 1ns -voptargs=+acc \
  -suppress vsim-3009 -suppress vsim-8683 -suppress vsim-8386 \
  -suppress vsim-2685 -suppress vsim-3722 \
  -do "run -all; exit"

# Fix VCD timestamps
python3 fixvcd.py croc.vcd croc_fixed.vcd

# Note: Make sure to start an interactive shell via
# > oseda -2026.02 bash
# first to be able to execute this properly
cd ../openroad/

# Post Layout Power Analysis
oseda -2026.04 openroad scripts/extractspef.tcl
oseda -2026.04 openroad scripts/06_power.tcl
oseda -2026.04 openroad scripts/07_IRdrop.tcl