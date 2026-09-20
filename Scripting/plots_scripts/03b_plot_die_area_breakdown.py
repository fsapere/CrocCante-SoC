import matplotlib.pyplot as plt
import os
import sys

# Import the existing area parser
sys.path.append(os.path.dirname(os.path.abspath(__file__)))
from area import extract_areas, get_path

# Define output directory
OUTPUT_DIR = "plots"
os.makedirs(OUTPUT_DIR, exist_ok=True)

# IHP-130 dimensions
# According to report: die area = 2235 * 2235
# Core area = 2017 * 2017
# Pad area = 2235^2 - 2017^2 = 926936 um^2

TOTAL_DIE_AREA = 2235 * 2235
CORE_AREA = 2017 * 2017
PAD_AREA = TOTAL_DIE_AREA - CORE_AREA

def plot_die_area(area_report):
    area_tree = extract_areas(area_report)
    if area_tree is None:
        print("Failed to read area tree!")
        return
    
    # Get total SoC Area
    node_soc = get_path(area_tree, ["<top>", "i_croc_soc"])
    if node_soc is None:
        print("Failed to find i_croc_soc node")
        return
        
    soc_area = node_soc.area
    free_area = CORE_AREA - soc_area
    
    # Plotting
    labels = ['SoC Logic & Macros', 'Pad Ring', 'Free Core Area']
    sizes = [soc_area, PAD_AREA, free_area]
    colors = ['#ff9999', '#66b3ff', '#c2c2f0']
    explode = (0.1, 0, 0)
    
    fig, ax = plt.subplots(figsize=(8, 8))
    ax.pie(sizes, explode=explode, labels=labels, colors=colors, autopct='%1.1f%%',
           shadow=True, startangle=140)
    ax.axis('equal')
    
    plt.title('Total Die Area Breakdown')
    plt.tight_layout()
    plt.savefig(os.path.join(OUTPUT_DIR, "03b_die_area_breakdown.pdf"))
    plt.savefig(os.path.join(OUTPUT_DIR, "03b_die_area_breakdown.png"))
    plt.close()
    print("Generated 03b_die_area_breakdown.pdf and .png")

if __name__ == "__main__":
    report_path = "Croc_Files/openroad/reports/04_croc.routed.rpt"
    if len(sys.argv) > 1:
        report_path = sys.argv[1]
    plot_die_area(report_path)
