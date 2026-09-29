// Empty Verilog stubs for physical-only cells (filler / well-tap / bondpad). Self added based on ex 10
// These cells have LEF/GDS but no behavioural Verilog because they carry no
// signals — their job is purely physical (DRC, density, well biasing, pad
// landing). Functional simulation just needs the module name to resolve.

`celldefine
module FILLER1  (); endmodule
module FILLER2  (); endmodule
module FILLER4  (); endmodule
module FILLER8  (); endmodule
module FILLER16 (); endmodule
module WELLTAP  (); endmodule
module bondpad5l_70x70 (pad); inout pad; endmodule
`endcelldefine
