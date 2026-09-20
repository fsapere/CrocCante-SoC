import matplotlib.pyplot as plt
import numpy as np
import os

# Define output directory
OUTPUT_DIR = "plots"
os.makedirs(OUTPUT_DIR, exist_ok=True)

def parse_power_report(filepath):
    data = {"groups": {}}
    if not os.path.exists(filepath):
        print(f"Warning: File {filepath} not found!")
        return data
    with open(filepath, "r") as f:
        lines = f.readlines()
    
    in_table = False
    for line in lines:
        if line.startswith("---------"):
            in_table = not in_table
            continue
        if in_table and not line.startswith("Group") and not line.startswith("Total"):
            parts = line.split()
            if len(parts) >= 5:
                group = parts[0]
                internal = float(parts[1])
                switching = float(parts[2])
                leakage = float(parts[3])
                total = float(parts[4])
                data["groups"][group] = {
                    "Internal": internal,
                    "Switching": switching,
                    "Leakage": leakage,
                    "Total": total
                }
    return data

baseline_file = "Croc_Files/openroad/reports/power_baseline.rpt"
our_file = "Croc_Files/openroad/reports/power_statistical_tt.rpt"

baseline_data = parse_power_report(baseline_file)
our_data = parse_power_report(our_file)

groups = ["Sequential", "Combinational", "Clock", "Macro", "Pad"]

# Plot 1: By groups (Total power)
baseline_totals = [baseline_data["groups"].get(g, {}).get("Total", 0) * 1000 for g in groups] # Convert to mW
our_totals = [our_data["groups"].get(g, {}).get("Total", 0) * 1000 for g in groups]

x = np.arange(len(groups))
width = 0.35

fig, ax = plt.subplots(figsize=(10, 6))
rects1 = ax.bar(x - width/2, baseline_totals, width, label='Original Croc', color='skyblue')
rects2 = ax.bar(x + width/2, our_totals, width, label='Our Implementation', color='salmon')

ax.set_ylabel('Total Power (mW)')
ax.set_title('Power Consumption by Group for Both Implementations')
ax.set_xticks(x)
ax.set_xticklabels(groups)
ax.legend()
plt.grid(axis='y', linestyle='--', alpha=0.7)
plt.savefig(os.path.join(OUTPUT_DIR, "03a_power_by_groups.pdf"))
plt.savefig(os.path.join(OUTPUT_DIR, "03a_power_by_groups.png"))
plt.show()
plt.close()

# Plot 2: By category (Internal, Switching, Leakage)
categories = ["Internal", "Switching", "Leakage"]
baseline_cat = [sum(baseline_data["groups"].get(g, {}).get(c, 0) for g in groups) * 1000 for c in categories]
our_cat = [sum(our_data["groups"].get(g, {}).get(c, 0) for g in groups) * 1000 for c in categories]

x_cat = np.arange(len(categories))
fig, ax = plt.subplots(figsize=(8, 6))
rects1 = ax.bar(x_cat - width/2, baseline_cat, width, label='Original Croc', color='lightgreen')
rects2 = ax.bar(x_cat + width/2, our_cat, width, label='Our Implementation', color='plum')

ax.set_ylabel('Total Power (mW)')
ax.set_title('Total Power by Component Category')
ax.set_xticks(x_cat)
ax.set_xticklabels(categories)
ax.legend()
plt.grid(axis='y', linestyle='--', alpha=0.7)
plt.savefig(os.path.join(OUTPUT_DIR, "03a_power_by_category.pdf"))
plt.savefig(os.path.join(OUTPUT_DIR, "03a_power_by_category.png"))
plt.show()
plt.close()

print("Generated 03a_power_by_groups.pdf/png and 03a_power_by_category.pdf/png")
