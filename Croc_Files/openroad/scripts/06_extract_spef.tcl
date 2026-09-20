# Copyright 2023 ETH Zurich and University of Bologna.
# Solderpad Hardware License, Version 0.51, see LICENSE for details.
# SPDX-License-Identifier: SHL-0.51

# Stage 06: Extract SPEF Only
#
# This script ONLY loads the preexisting .odb database and extracts the SPEF.
# It does NOT overwrite DEF, GDS, Verilog or any other layout files.

source scripts/startup.tcl

utl::report "###############################################################################"
utl::report "# SPEF EXTRACTION (Read-Only Mode)"
utl::report "###############################################################################"

utl::report "Loading pre-existing final database AND constraints..."
# load_checkpoint properly loads both the database and the SDC
load_checkpoint 05_${proj_name}.final

utl::report "Extracting parasitics..."
define_process_corner -ext_model_index 0 X
extract_parasitics -ext_model_file ../technology/rcx/IHP_rcx_patterns.rules

utl::report "Writing SPEF..."
write_spef ${out_dir}/${proj_name}.spef

utl::report "Reading back SPEF for reporting..."
read_spef  ${out_dir}/${proj_name}.spef; # readback parasitics for OpenSTA

# Report metrics for SPEF extraction
report_metrics "05_${proj_name}.extract"

utl::report "###############################################################################"
utl::report "# SPEF Extraction Complete!"
utl::report "# File saved: ${out_dir}/${proj_name}.spef"
utl::report "# Report saved: reports/05_${proj_name}.extract.rpt"
utl::report "###############################################################################"
