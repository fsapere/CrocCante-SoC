# Init tech
source scripts/init_tech.tcl

# Load layout
read_def out/croc.def

# SPEF generation
set extRules ../ihp13/IHP_rcx_patterns.rules
define_process_corner -ext_model_index 0 tt
extract_parasitics -ext_model_file $extRules
write_spef out/croc.spef
exit