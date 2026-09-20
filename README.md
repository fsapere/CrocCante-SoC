# CrocCante System-on-Chip

This chip was designed as part of the [VLSI 2: From Netlist to Complete System on Chip](https://vlsi.ethz.ch/) course at ETH Zurich. The project enhances the performance and functionality of the baseline [Croc SoC](https://github.com/pulp-platform/croc).

## Description

The main goal of the project is a dedicated **CORDIC** (Coordinate Rotation Digital Computer) accelerator for trigonometric function computation.

Main features:

- integration of a memory-mapped CORDIC accelerator in the user domain of the Croc SoC through an IRQ-based wrapper, which handles backpressure on the computational datapath as well as memory transfers and arbitration;
- enhancement of the existing CORDIC design, exploring different design solutions to find the sweet spot between throughput, latency and area;
- memory capacity increased from 4 kB to 8 kB, with higher bandwidth, by adding two SRAM banks to the baseline design;
- clock frequency increased from 72.46 MHz to 75.93 MHz (post-parasitics estimation with IHP_rcx_patterns.rules) through architectural changes and synthesis overconstraining;
- exploration of software solutions to handle banking conflicts through linker script changes (`link.ld`, `link_hwsw.ld`).

## Performance Summary

| Metric | Baseline | Our design | Comparison |
| --- | --- | --- | --- |
| Total Power (mW) | 14.6 | 29.0 | +98.63 % |
| Area (Core) (µm²) | $5.368 \times 10^5$ | $8.190 \times 10^5$ | +52.57 % |
| Energy per Task (µJ) | 14.58 | 2.51 | -82.76 % |
| Absolute Speedup | - | - | 11.52x |
| Clock Frequency ($f_{CLK}$) (MHz) | 72.46 | 75.93 | +3.47 MHz |
| Memory Capacity (kB) | 4 | 8 | +100 % |
| Numerical Accuracy | - | $\pm 10$ LSB | - |

Design and backend choices are documented in detail in the [report](CrocCante%20-%20report.pdf).

## Repository Structure

- `Croc_Files/`: the Croc SoC extended with the accelerator
  - `rtl/cordic/`: CORDIC core, OBI wrapper, manager and subordinate ports
  - `sw/`: drivers, linker scripts and test programs (`sw/test/`)
  - `yosys/`, `openroad/`, `klayout/`: synthesis, place and route, DRC
  - `vsim/`, `verilator/`: RTL and post-layout simulation
- `Scripting/`: flow automation, metrics extraction and plots

## Running the Flow

The flow targets the ETH Zurich course environment: OSEDA containers (Yosys, OpenROAD, KLayout), QuestaSim, the RISC-V GCC toolchain and the IHP 130 nm PDK set up through the DZ cockpit. It does not run as-is outside of it.

From `Scripting/`:

```bash
./run_functional_verification.sh --program test_cordic_correctness  # single test in Verilator
./run_all_benchmarks.sh                                              # correctness, speedup, handshaking, bank contention
./run_full_flow.sh                                                   # benchmarks, synthesis, P&R, post-layout power, metrics
BASELINE_SRC=/path/to/reference/croc ./run_baseline_flow.sh          # same flow on the baseline Croc SoC
./run_post_processing.sh                                             # plots and baseline comparison
./signoff.sh                                                         # DRC (KLayout) and LVS (Calibre setup not included)
```

## Authors

- Francesco Maria Sapere ([@fsapere](https://github.com/fsapere))
- Luca Antonio Battaglia ([@luca-battaglia](https://github.com/luca-battaglia))

## Credits

- [Croc](https://github.com/pulp-platform/croc) by the PULP Platform (ETH Zurich and University of Bologna): baseline SoC, RTL IPs and physical design flow.
- The CORDIC core in `Croc_Files/rtl/cordic/` (all files except `cordic_wrapper.sv`, `cordic_mgr.sv` and `cordic_sbr.sv`) is derived from [Manashwinijoshi/CORDIC](https://github.com/Manashwinijoshi/CORDIC), adapted with per-stage pipeline registers and an active-low asynchronous reset.
- Parts of the flow scripts derive from the exercises of the [VLSI 2](https://vlsi.ethz.ch/) course at ETH Zurich.

## License

Our own work is released under the Apache License 2.0 (see [LICENSE](LICENSE)). Files derived from third-party projects keep their original authorship and license terms: most of the Croc RTL is licensed under the Solderpad Hardware License v0.51 (SHL-0.51), as stated in the file headers.
