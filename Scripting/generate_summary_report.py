#!/usr/bin/env python3
import json
import os
import re

def parse_power_report(filepath):
    power_data = {}
    if not os.path.exists(filepath):
        return power_data
    with open(filepath, 'r') as f:
        lines = f.readlines()
        for line in lines:
            if line.strip().startswith('Total'):
                parts = line.split()
                try:
                    # Usually: Total <internal> <switching> <leakage> <total> <%>
                    total_idx = -1
                    if '%' in parts[-1]:
                        total_idx = -2
                        
                    power_data['total_power'] = float(parts[total_idx])
                    if len(parts) >= abs(total_idx) + 3:
                        power_data['leakage_power'] = float(parts[total_idx-1])
                        power_data['switching_power'] = float(parts[total_idx-2])
                        power_data['internal_power'] = float(parts[total_idx-3])
                except ValueError:
                    pass
    return power_data

def parse_summary_txt(filepath):
    summary_data = {'cycles': {}, 'contention_dips': {}}
    if not os.path.exists(filepath):
        return summary_data
    with open(filepath, 'r') as f:
        content = f.read()
        
        cycle_match = re.search(r'S=([0-9a-fA-F]+)\s+H=([0-9a-fA-F]+)\s+cfg=([0-9a-fA-F]+)\s+crn=([0-9a-fA-F]+)\s+irq=([0-9a-fA-F]+)', content)
        if cycle_match:
            summary_data['cycles']['SW'] = int(cycle_match.group(1), 16)
            summary_data['cycles']['HW'] = int(cycle_match.group(2), 16)
            summary_data['cycles']['cfg'] = int(cycle_match.group(3), 16)
            summary_data['cycles']['crn'] = int(cycle_match.group(4), 16)
            summary_data['cycles']['irq'] = int(cycle_match.group(5), 16)
            
        contention_matches = re.finditer(r'BankSweep N=([0-9a-fA-F]+)\s+.*?dip=[\+\-]([0-9a-fA-F]+)', content)
        for match in contention_matches:
            n_val = str(int(match.group(1), 16))
            dip_val = int(match.group(2), 16)
            summary_data['contention_dips'][n_val] = dip_val
            
    return summary_data

def parse_routed_report(filepath):
    data = {'area': {}, 'timing': {}}
    if not os.path.exists(filepath):
        return data
    with open(filepath, 'r') as f:
        content = f.read()
        
        # WNS
        wns_match = re.search(r'wns max\s+([-\.\d]+)', content)
        if wns_match:
            data['timing']['wns'] = float(wns_match.group(1))
            
        # Core Area (actually parsing Total Active Area)
        area_match = re.search(r'Total Active Area:\s+([\d\.]+)', content)
        if area_match:
            data['area']['core_area'] = float(area_match.group(1))
            
        # Cell Count
        # Search for the <top> line
        top_match = re.search(r'^<top>\s+([\d\.]+)\s+([\d\.]+)\s+([\d\.]+)\s+([\d\.]+)\s+([\d\.]+)\s+(\d+)', content, re.MULTILINE)
        if top_match:
            data['area']['cell_count'] = int(top_match.group(6))
            
    return data

def main():
    base_dir = os.path.join(os.path.dirname(__file__), '..')
    reports_dir = os.path.join(base_dir, 'Croc_Files', 'openroad', 'reports')
    
    vcd_power_path = os.path.join(reports_dir, 'power_vcd_tt.rpt')
    stat_power_path = os.path.join(reports_dir, 'power_statistical_tt.rpt')
    summary_path = os.path.join(base_dir, 'Scripting', 'summary.txt')
    routed_rpt_path = os.path.join(reports_dir, '04_croc.routed.rpt')
    
    routed_data = parse_routed_report(routed_rpt_path)
    
    metrics = {
        'area': routed_data.get('area', {}),
        'timing': routed_data.get('timing', {}),
        'power': {
            'vcd': parse_power_report(vcd_power_path),
            'statistical': parse_power_report(stat_power_path)
        },
        'benchmarks': parse_summary_txt(summary_path),
        'energy': {}
    }
    
    # Calculate Energy = P_avg * cycles * T_clk
    # Extract T_clk dynamically from SDC and adjust with WNS for true Max Freq energy
    T_clk = 10e-9 
    sdc_path = os.path.join(base_dir, 'Croc_Files', 'openroad', 'src', 'constraints.sdc')
    if os.path.exists(sdc_path):
        with open(sdc_path, 'r') as f:
            for line in f:
                match = re.search(r'set TCK_SYS\s+([\d\.]+)', line)
                if match:
                    T_clk = float(match.group(1)) * 1e-9
                    break
                    
    # Adjust for WNS if negative to find the true minimum achievable clock period
    wns = metrics['timing'].get('wns', 0)
    if wns and wns < 0:
        T_clk += abs(wns) * 1e-9
    
    vcd_power = metrics['power']['vcd'].get('total_power', 0)
    if vcd_power > 0 and metrics['benchmarks']['cycles']:
        for test, cycles in metrics['benchmarks']['cycles'].items():
            metrics['energy'][test] = vcd_power * cycles * T_clk
            
    with open(os.path.join(base_dir, 'Scripting', 'metrics_summary.json'), 'w') as f:
        json.dump(metrics, f, indent=4)
        
    print(f"Summary generated at metrics_summary.json")

if __name__ == '__main__':
    main()
