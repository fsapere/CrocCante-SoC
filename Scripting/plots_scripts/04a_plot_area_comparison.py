import matplotlib.pyplot as plt
import os
import sys
import numpy as np

# Import the existing area parser
sys.path.append(os.path.dirname(os.path.abspath(__file__)))
from area import extract_areas, get_path
from plot import PULP_COLORS_BASE

OUTPUT_DIR = "plots"
os.makedirs(OUTPUT_DIR, exist_ok=True)
AREA_PER_GE = 7.25

def extract_area_breakdown(report_path):
    area_tree = extract_areas(report_path)
    if area_tree is None:
        return None
    
    node_i_croc = get_path(area_tree, ["<top>", "i_croc_soc", "i_croc"])
    node_i_user = get_path(area_tree, ["<top>", "i_croc_soc", "i_user"])
    
    nodes_to_process = []
    if node_i_croc: nodes_to_process.extend(node_i_croc.children)
    if node_i_user: nodes_to_process.extend(node_i_user.children)
    
    breakdown = {}
    for node in nodes_to_process:
        area_kge = node.area / (AREA_PER_GE * 1e3)
        breakdown[node.name] = area_kge
        
    return breakdown

pretty_names = {
    "gen_sram_bank\[0\].i_sram": "SRAM 1",
    "gen_sram_bank\[1\].i_sram": "SRAM 2",
    "gen_sram_bank\[2\].i_sram": "SRAM 3",
    "gen_sram_bank\[3\].i_sram": "SRAM 4",
    "gen_sram_bank[0].i_sram": "SRAM 1",
    "gen_sram_bank[1].i_sram": "SRAM 2",
    "gen_sram_bank[2].i_sram": "SRAM 3",
    "gen_sram_bank[3].i_sram": "SRAM 4",
    "i_bootrom": "Bootrom",
    "i_clint": "CLINT",
    "i_core_wrap": "Core",
    "i_dm_top.i_dm_top": "Debug\nModule",
    "i_dmi_jtag": "JTAG\nTAP",
    "i_gpio": "GPIO",
    "i_obi_timer": "Timer",
    "i_soc_ctrl": "SoC\nControl",
    "i_uart": "UART",
    "i_cordic_wrapper": "CORDIC"
}

def plot_area_comparison(our_report, baseline_report=None):
    our_breakdown = extract_area_breakdown(our_report)
    if not our_breakdown:
        print("Failed to parse our area report")
        return
        
    # Standardize names
    our_data = {pretty_names.get(k, k): v for k, v in our_breakdown.items()}
    
    baseline_data = {}
    if baseline_report and os.path.exists(baseline_report):
        base_bd = extract_area_breakdown(baseline_report)
        if base_bd:
            baseline_data = {pretty_names.get(k, k): v for k, v in base_bd.items()}
    else:
        # Baseline flow not run yet: plot our design only
        print(f"Warning: Baseline area report not found at {baseline_report}. Baseline will be empty.")
        baseline_data = {}
        
    all_keys = list(set(list(our_data.keys()) + list(baseline_data.keys())))
    all_keys.sort(key=lambda k: our_data.get(k, 0), reverse=True)
    
    # Fill missing with 0
    for k in all_keys:
        if k not in our_data:
            our_data[k] = 0.0
        if k not in baseline_data:
            baseline_data[k] = 0.0
            
    # Prepare stacked bar chart
    fig, ax = plt.subplots(figsize=(10, 4))
    
    colors = [PULP_COLORS_BASE[i % len(PULP_COLORS_BASE)] for i in range(len(all_keys))]
    
    bottom_base = 0
    bottom_our = 0
    
    for i, k in enumerate(all_keys):
        # Plot Baseline
        if baseline_data[k] > 0:
            ax.barh("Original Croc", baseline_data[k], left=bottom_base, color=colors[i], label=k)
            bottom_base += baseline_data[k]
        
        # Plot Our Design
        if our_data[k] > 0:
            ax.barh("Our Implementation", our_data[k], left=bottom_our, color=colors[i], label=k)
            bottom_our += our_data[k]
            
    ax.set_xlabel('Area (kGE)')
    ax.set_title('Area Breakdown Comparison')
    
    # Deduplicate legend
    handles, labels = ax.get_legend_handles_labels()
    by_label = dict(zip(labels, handles))
    ax.legend(by_label.values(), by_label.keys(), loc='upper center', bbox_to_anchor=(0.5, -0.15), ncol=5)
    
    plt.tight_layout()
    plt.savefig(os.path.join(OUTPUT_DIR, "04a_area_comparison.pdf"))
    plt.savefig(os.path.join(OUTPUT_DIR, "04a_area_comparison.png"))
    plt.show()
    print("Generated 04a_area_comparison.pdf and .png")

if __name__ == "__main__":
    our_report = "Croc_Files/openroad/reports/04_croc.routed.rpt"
    baseline_report = "tmp/baseline_run/Croc_Files/openroad/reports/04_croc.routed.rpt"
    plot_area_comparison(our_report, baseline_report)
