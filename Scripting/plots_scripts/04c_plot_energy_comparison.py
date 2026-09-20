import matplotlib.pyplot as plt
import os
import json

OUTPUT_DIR = "plots"
os.makedirs(OUTPUT_DIR, exist_ok=True)

def load_json(filepath):
    if not os.path.exists(filepath):
        print(f"Warning: File {filepath} not found.")
        return {}
    with open(filepath, 'r') as f:
        return json.load(f)

def plot_energy_comparison():
    base_path = "Scripting/metrics_baseline.json"
    cordic_path = "Scripting/metrics_cordic.json"
    
    data_base = load_json(base_path)
    data_cordic = load_json(cordic_path)
    
    if not data_base or not data_cordic:
        print("Error: Could not load JSON metrics for energy comparison.")
        return

    # Extract required values
    cycles_base = data_cordic.get('benchmarks', {}).get('cycles', {}).get('SW', 0)
    pow_tot_base = data_base.get('power', {}).get('vcd', {}).get('total_power', 0)
    
    e_cordic_sw = data_cordic.get('energy', {}).get('SW', 0)
    pow_tot_cordic = data_cordic.get('power', {}).get('vcd', {}).get('total_power', 0)
    e_cordic_hw = data_cordic.get('energy', {}).get('HW', 0)
    
    # Calculate baseline energy
    e_base = 0
    if cycles_base > 0 and pow_tot_base > 0 and pow_tot_cordic > 0:
        T_clk = e_cordic_sw / (pow_tot_cordic * cycles_base)
        e_base = pow_tot_base * cycles_base * T_clk

    if e_base == 0 or e_cordic_hw == 0:
        print("Error: Could not calculate valid energy values.")
        return

    # Convert to nJ
    e_base_nj = e_base * 1e9
    e_cordic_hw_nj = e_cordic_hw * 1e9

    labels = ['Baseline\n(SW CORDIC)', 'Our Implementation\n(HW CORDIC)']
    energies = [e_base_nj, e_cordic_hw_nj]
    
    fig, ax = plt.subplots(figsize=(7, 6))
    width = 0.5
    bars = ax.bar(labels, energies, width, color=['goldenrod', 'royalblue'])
    
    ax.set_ylabel('Energy per Task (nJ)')
    ax.set_title('Energy Consumption Comparison')
    
    # Add text labels on the bars
    ax.bar_label(bars, fmt='%.2f', padding=3)

    plt.tight_layout()
    plt.savefig(os.path.join(OUTPUT_DIR, "04c_energy_comparison.pdf"))
    plt.savefig(os.path.join(OUTPUT_DIR, "04c_energy_comparison.png"))
    plt.show()
    print("Generated 04c_energy_comparison.pdf and .png")

if __name__ == "__main__":
    plot_energy_comparison()
