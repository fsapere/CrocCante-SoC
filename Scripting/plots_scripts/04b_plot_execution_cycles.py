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

def plot_execution_cycles():
    metrics_path = "Scripting/metrics_cordic.json"
    data = load_json(metrics_path)
    
    if not data or 'benchmarks' not in data or 'cycles' not in data['benchmarks']:
        print("Error: Could not find cycle data in metrics_cordic.json!")
        return

    sw_cycles = data['benchmarks']['cycles'].get('SW', 0)
    hw_cycles = data['benchmarks']['cycles'].get('HW', 0)
    
    labels = ['Baseline\n(SW CORDIC)', 'Our Implementation\n(HW CORDIC)']
    cycles = [sw_cycles, hw_cycles]
    
    fig, ax = plt.subplots(figsize=(7, 6))
    width = 0.5
    bars = ax.bar(labels, cycles, width, color=['lightcoral', 'mediumseagreen'])
    
    ax.set_ylabel('Total Execution Cycles')
    ax.set_title('CORDIC Execution Time Comparison')
    
    # Add text labels on the bars
    ax.bar_label(bars, fmt='%d', padding=3)

    plt.tight_layout()
    plt.savefig(os.path.join(OUTPUT_DIR, "04b_execution_cycles.pdf"))
    plt.savefig(os.path.join(OUTPUT_DIR, "04b_execution_cycles.png"))
    plt.show()
    print("Generated 04b_execution_cycles.pdf and .png")

if __name__ == "__main__":
    plot_execution_cycles()
