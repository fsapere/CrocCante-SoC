#!/usr/bin/env python3
import json
import os
import sys

def load_json(filepath):
    if not os.path.exists(filepath):
        print(f"Warning: File {filepath} not found.")
        return {}
    with open(filepath, 'r') as f:
        return json.load(f)

def safe_get(d, *keys, default="N/A"):
    curr = d
    for k in keys:
        if isinstance(curr, dict) and k in curr:
            curr = curr[k]
        else:
            return default
    return curr

def format_val(val, unit=""):
    if val == "N/A":
        return val
    if isinstance(val, float):
        if "W" in unit or "J" in unit:
            return f"{val:.2e} {unit}"
        return f"{val:.4f} {unit}"
    return f"{val} {unit}"

def main():
    base_dir = os.path.join(os.path.dirname(__file__), '..')
    baseline_path = os.path.join(base_dir, 'Scripting', 'metrics_baseline.json')
    cordic_path = os.path.join(base_dir, 'Scripting', 'metrics_cordic.json')

    print("================================================================")
    print("                ARCHITECTURAL COMPARISON                     ")
    print("================================================================")

    data_base = load_json(baseline_path)
    data_cordic = load_json(cordic_path)

    if not data_base or not data_cordic:
        print("Error: both JSON metrics files are needed for the comparison.")
        print("Run both run_full_flow.sh and run_baseline_flow.sh first.")
        sys.exit(1)

    print(f"{'Metric':<30} | {'Baseline':<15} | {'CORDIC':<15} | {'Difference':<15}")
    print("-" * 85)

    # 1. Area
    area_base = safe_get(data_base, 'area', 'core_area')
    area_cordic = safe_get(data_cordic, 'area', 'core_area')
    area_diff = "N/A"
    if area_base != "N/A" and area_cordic != "N/A":
        area_diff = f"{((area_cordic - area_base) / area_base) * 100:+.2f}%"
    print(f"{'Area (Total) [um^2]':<30} | {format_val(area_base):<15} | {format_val(area_cordic):<15} | {area_diff:<15}")

    cell_base = safe_get(data_base, 'area', 'cell_count')
    cell_cordic = safe_get(data_cordic, 'area', 'cell_count')
    cell_diff = "N/A"
    if cell_base != "N/A" and cell_cordic != "N/A":
        cell_diff = f"{cell_cordic - cell_base:+} cells"
    print(f"{'Cell Count':<30} | {format_val(cell_base):<15} | {format_val(cell_cordic):<15} | {cell_diff:<15}")

    # 2. Timing
    wns_base = safe_get(data_base, 'timing', 'wns')
    wns_cordic = safe_get(data_cordic, 'timing', 'wns')
    wns_diff = "N/A"
    if wns_base != "N/A" and wns_cordic != "N/A":
        wns_diff = f"{wns_cordic - wns_base:+.3f} ns"
    print(f"{'Timing WNS [ns]':<30} | {format_val(wns_base):<15} | {format_val(wns_cordic):<15} | {wns_diff:<15}")

    # 3. Power
    # We compare VCD power. 
    pow_tot_base = safe_get(data_base, 'power', 'vcd', 'total_power')
    pow_tot_cordic = safe_get(data_cordic, 'power', 'vcd', 'total_power')
    pow_diff = "N/A"
    if pow_tot_base != "N/A" and pow_tot_cordic != "N/A":
        pow_diff = f"{((pow_tot_cordic - pow_tot_base) / pow_tot_base) * 100:+.2f}%"
    print(f"{'Total Power (VCD) [W]':<30} | {format_val(pow_tot_base, 'W'):<15} | {format_val(pow_tot_cordic, 'W'):<15} | {pow_diff:<15}")

    # 3.1 Leakage Power
    leakage_base = safe_get(data_base, 'power', 'vcd', 'leakage_power')
    leakage_cordic = safe_get(data_cordic, 'power', 'vcd', 'leakage_power')
    leakage_diff = "N/A"
    if leakage_base != "N/A" and leakage_cordic != "N/A":
        if leakage_base > 0:
            leakage_diff = f"{((leakage_cordic - leakage_base) / leakage_base) * 100:+.2f}%"
        else:
            leakage_diff = f"{leakage_cordic - leakage_base:+.2e} W"
    print(f"{'Leakage Power [W]':<30} | {format_val(leakage_base, 'W'):<15} | {format_val(leakage_cordic, 'W'):<15} | {leakage_diff:<15}")

    # 4. Performance & Energy
    # CORDIC runs the HW benchmark
    cycles_cordic = safe_get(data_cordic, 'benchmarks', 'cycles', 'HW')
    e_cordic = safe_get(data_cordic, 'energy', 'HW')

    # Baseline performance is the SW benchmark from the CORDIC run
    cycles_base = safe_get(data_cordic, 'benchmarks', 'cycles', 'SW')
    e_base = "N/A"
    
    # Compute baseline energy using baseline power and SW cycles
    pow_tot_base = safe_get(data_base, 'power', 'vcd', 'total_power')
    if cycles_base != "N/A" and pow_tot_base != "N/A":
        # Recover the T_clk used by generate_summary_report.py from the CORDIC SW energy;
        # fall back to 10 ns if that energy is missing
        e_cordic_sw = safe_get(data_cordic, 'energy', 'SW')
        pow_tot_cordic = safe_get(data_cordic, 'power', 'vcd', 'total_power')
        if e_cordic_sw != "N/A" and pow_tot_cordic != "N/A" and pow_tot_cordic > 0:
            T_clk = e_cordic_sw / (pow_tot_cordic * cycles_base)
            e_base = pow_tot_base * cycles_base * T_clk
        else:
            e_base = pow_tot_base * cycles_base * 10e-9

    print("-" * 85)
    
    cycles_diff = "N/A"
    if cycles_base != "N/A" and cycles_cordic != "N/A":
        cycles_diff = f"{cycles_cordic - cycles_base:+} cycles"
    print(f"{'Performance (Cycles)':<30} | {format_val(cycles_base):<15} | {format_val(cycles_cordic):<15} | {cycles_diff:<15}")
    
    e_savings = "N/A"
    if e_base != "N/A" and e_cordic != "N/A":
        e_savings = f"{((e_base - e_cordic) / e_base) * 100:.2f}%"
    print(f"{'Energy per Task [J]':<30} | {format_val(e_base, 'J'):<15} | {format_val(e_cordic, 'J'):<15} | {('SAVINGS: ' + e_savings) if e_savings != 'N/A' else 'N/A'}")

    print("================================================================")

if __name__ == '__main__':
    main()
