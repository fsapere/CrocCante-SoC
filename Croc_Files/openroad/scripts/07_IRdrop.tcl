# Loading the design
source scripts/init_tech.tcl
read_def out/croc.def
read_sdc out/croc.sdc

# Setting voltages and analyzing IO_BOND_pad_vdd0
set_pdnsim_net_voltage -net VDD -voltage 1.2
analyze_power_grid -vsrc src/Vsrc_croc_vdd.loc -net VDD -corner tt

set_pdnsim_net_voltage -net VSS -voltage 0
analyze_power_grid -vsrc src/Vsrc_croc_vss.loc -net VSS -corner tt -error_file reports/vss_connectivity_errors.rpt
exit