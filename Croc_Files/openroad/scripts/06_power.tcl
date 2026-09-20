# Initialize technology
source scripts/init_tech.tcl

# Load netlist and link design
read_verilog out/croc.v
link_design croc_chip

# Load constraints and parasitics
read_sdc out/croc.sdc
read_spef out/croc.spef

# STIMULI-BASED (VCD-BASED) POWER SIMULATION
set_power_activity -input_port rst_ni -activity 0

# Load the VCD file (overwrites a ctivity for traced signals)
read_vcd -scope tb_croc_soc/i_croc_soc ../vsim/croc_fixed.vcd

# Report activity annotation coverage
report_activity_annotation

# Print VCD-based report to screen and save to file
puts "=========================================================================="
puts "VCD-Based Power Report (Corner: tt)"
puts "=========================================================================="
report_power -corner tt
report_power -corner tt > reports/power_vcd_tt.rpt

# Save pin transitions that were observed
report_activity_annotation -report_annotated > reports/activity_details.rpt

# STATISTICAL POWER SIMULATION
# Set statistical switching activity (using 0.01 to match VCD average activity)
set_power_activity -global -activity 0.01
set_power_activity -input_port rst_ni -activity 0

# Print statistical report to screen and save to file
puts "=========================================================================="
puts "Purely Statistical Power Report (Corner: tt, Activity: 0.01)"
puts "=========================================================================="
report_power -corner tt
report_power -corner tt > reports/power_statistical_tt.rpt

exit 	