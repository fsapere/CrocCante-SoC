# CrocCante System-on-Chip

---

## Project Context

This chip was designed as a part of the “VLSI 2: From Netlist to Complete System on Chip” course at ETH Zurich. The scope of the project consists of enhancing the performance and functionalities of the baseline Croc SoC. 

---

## Description

The main goal of the project is to implement a dedicated **CORDIC** (Coordinate Rotation Digital Computer) accelerator for trigonometric function computation. 

Contributions include:

- integration of a memory-mapped CORDIC accelerator in the user domain of the Croc SoC through an IRQ-based wrapper to handle backpressure for the computational datapath part, as well as the memory transfer/arbitration;
- enhancement of the existing CORDIC design and explored different design solutions, aiming at the sweet spot between throughput, latency, and area footprint;
- increase of the memory capacity (from 4 kB to 8 kB) and bandwidth by adding two additional SRAM banks to the baseline design;
- increase of the clock frequency from 72.46 MHz to fCLK = 75.9 MHz (post-parasitics estimation with IHP_rcx_patterns.rules) through architectural modifications and synthesis overconstraining;
- exploration of software solutions for handling banking conflicts efficiently through modifications of the linker (link.ld).

---

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

---

<aside>
📖

Extensive documentation of the design and backend choices can be found at “.\CrocCante - report”.

</aside>

---