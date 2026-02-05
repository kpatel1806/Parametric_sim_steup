import os
import json
import subprocess
import shutil
import sqlite3
import time
import itertools
from multiprocessing import Pool

# ==========================================
# 0. UNIT CONVERSION HELPERS
# ==========================================
# 1 m²·K/W = 5.678263 ft²·°F·hr/Btu
# Conversely, factor is ~0.1761
RSI_TO_IP_FACTOR = 5.678263

def rsi_to_rip(rsi_val):
    """Converts SI R-Value (m2-K/W) to IP R-Value (ft2-F-hr/Btu) for OpenStudio Measures"""
    return float(rsi_val) * RSI_TO_IP_FACTOR

# ==========================================
# 1. SETUP & DISCOVERY
# ==========================================
project_root = os.getcwd() 
output_dir = os.path.join(project_root, "dataset_runs_sweep")
weather_dir = os.path.join(project_root, "weather")
seeds_dir = os.path.join(project_root, "seeds")
num_workers = 15  # Adjust based on RAM

# Auto-Discovery
weather_files = [f for f in os.listdir(weather_dir) if f.endswith(".epw")] if os.path.exists(weather_dir) else []
seed_files = [f for f in os.listdir(seeds_dir) if f.endswith(".osm")] if os.path.exists(seeds_dir) else []

if not weather_files or not seed_files:
    print("ERROR: Missing weather (.epw) or seed (.osm) files.")
    exit()

# ==========================================
# 2. THE GRID (DEFINED IN SI UNITS)
# ==========================================
sweep_config = {
    # --- GEOMETRY ---
    "scale_x":      [1.0, 1.5],        
    "scale_y":      [1.0, 1.5],             
    "scale_z":      [1.0, 1.2],             
    "wwr":          [0.3, 0.5],        
    
    # --- ENVELOPE (SI UNITS: m²·K/W) ---
    # R-10 SI is approx R-57 IP (Super insulated)
    # R-2 SI is approx R-11 IP (Standard old wall)
    "wall_r":       [2.0, 5.0],       # Adjusted to realistic SI ranges
    "roof_r":       [4.0, 8.0],             # Roofs usually higher R
    "floor_r":      [5.0, 10.0],                  # Fixed
    
    # --- PHYSICS ---
    "infil":        [0.0003, 0.0010],       
    
    # --- CONTEXT ---
    "weather":      weather_files,          
    "seed":         seed_files              
}

# ==========================================
# 3. JOB GENERATOR
# ==========================================
def generate_job_list():
    keys = list(sweep_config.keys())
    values = list(sweep_config.values())
    raw_jobs = list(itertools.product(*values))
    
    formatted_jobs = []
    for i, combination in enumerate(raw_jobs):
        job = dict(zip(keys, combination))
        job['run_id'] = f"run_{i:04d}"
        formatted_jobs.append(job)
    return formatted_jobs

# ==========================================
# 4. WORKER FUNCTION
# ==========================================
def run_simulation(job):
    run_id = job['run_id']
    run_folder = os.path.join(output_dir, run_id)
    
    # Docker Paths
    docker_root = project_root.replace(":\\", "/").replace("\\", "/").lower()
    if not docker_root.startswith("/"): docker_root = "/" + docker_root

    try: os.makedirs(run_folder, exist_ok=True)
    except: pass

    # --- A. BUILD WORKFLOW ---
    steps = [
        # Geometry (Unitless ratios)
        { "measure_dir_name": "SetBuildingScale", "arguments": {"x_scale": job['scale_x'], "y_scale": job['scale_y'], "z_scale": job['scale_z']} },
        { "measure_dir_name": "SetWindowToWallRatio", "arguments": {"wwr": job['wwr']} },
        
        # Envelope (CONVERT SI -> IP HERE)
        # The measures expect IP, but our job dict has SI.
        { "measure_dir_name": "SetWallInsulation", "arguments": {"r_value": rsi_to_rip(job['wall_r'])} },
        { "measure_dir_name": "SetRoofInsulation", "arguments": {"r_value": rsi_to_rip(job['roof_r'])} },
        { "measure_dir_name": "SetFloorInsulation", "arguments": {"r_value": rsi_to_rip(job['floor_r'])} },
        
        # Infiltration (Already correct unit in measure?)
        # Double check your measure.rb. Usually flow/area is standard SI in E+. 
        # Assuming your measure uses the raw value passed.
        {
            "measure_dir_name": "SetInfiltrationWeatherDriven",
            "arguments": {
                "flow_per_area": job['infil'],
                "create_if_missing": True,
                "const_coeff": 0.606, "temp_coeff": 0.03636, "wind_coeff": 0.1177, "wind2_coeff": 0.0
            }
        }
    ]

    osw_content = {
        "seed_file": f"/work/seeds/{job['seed']}",
        "weather_file": f"/work/weather/{job['weather']}", 
        "measure_paths": ["/work/measures"], 
        "steps": steps
    }
    
    with open(os.path.join(run_folder, "workflow.osw"), 'w') as f:
        json.dump(osw_content, f, indent=4)

    # --- B. RUN DOCKER ---
    container_osw = f"/work/dataset_runs_sweep/{run_id}/workflow.osw"
    cmd = [
        "docker", "run", "--rm",
        "-v", f"{docker_root}:/work",
        "-v", f"{docker_root}/weather:/work/weather",
        "-v", f"{docker_root}/seeds:/work/seeds",
        "nrel/openstudio:latest",
        "openstudio", "run",
        "-w", container_osw
    ]
    
    subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

    # --- C. EXTRACT ALL RESULTS ---
    sql_path = os.path.join(run_folder, "run", "eplusout.sql")
    
    # Initialize dictionary with INPUTS PRESERVED AS SI (m2-K/W)
    final_row = {
        "run_id": run_id,
        "seed_file": job['seed'],
        "weather_file": job['weather'],
        "scale_x_factor": job['scale_x'],
        "scale_y_factor": job['scale_y'],
        "scale_z_factor": job['scale_z'],
        "wwr_ratio": job['wwr'],
        # Saving the original SI job values, not the converted IP ones!
        "wall_r_m2K_W": job['wall_r'],
        "roof_r_m2K_W": job['roof_r'],
        "floor_r_m2K_W": job['floor_r'],
        "infil_rate_m3_s_m2": job['infil'],
        "valid_sim": False
    }

    # Default outputs
    full_end_uses = [
        "Heating", "Cooling", "Interior Lighting", "Exterior Lighting",
        "Interior Equipment", "Exterior Equipment", "Fans", "Pumps",
        "Heat Rejection", "Humidification", "Heat Recovery", 
        "Water Systems", "Refrigeration", "Generators"
    ]
    for use in full_end_uses:
        final_row[f"eui_{use.lower().replace(' ', '_')}_MJ_m2"] = 0.0
    
    final_row["eui_total_MJ_m2"] = 0.0
    final_row["total_area_m2"] = 0.0
    final_row["total_volume_m3"] = 0.0

    if os.path.exists(sql_path):
        try:
            conn = sqlite3.connect(sql_path)
            cur = conn.cursor()
            
            # Geometry
            cur.execute("SELECT Value FROM TabularDataWithStrings WHERE TableName='Building Area' AND RowName='Total Building Area' AND ColumnName='Area'")
            res_area = cur.fetchone()
            area = float(res_area[0]) if res_area else 0.0
            
            cur.execute("SELECT Value FROM TabularDataWithStrings WHERE TableName='Building Area' AND RowName='Net Conditioned Building Volume' AND ColumnName='Volume'")
            res_vol = cur.fetchone()
            vol = float(res_vol[0]) if res_vol else 0.0

            if area > 0:
                final_row["valid_sim"] = True
                final_row["total_area_m2"] = area
                final_row["total_volume_m3"] = vol
                
                # End Uses
                total_mj = 0.0
                for cat in full_end_uses:
                    col_name = f"eui_{cat.lower().replace(' ', '_')}_MJ_m2"
                    cur.execute(f"SELECT Value FROM TabularDataWithStrings WHERE TableName='End Uses' AND RowName='{cat}'")
                    rows = cur.fetchall()
                    val_gj = sum([float(r[0]) for r in rows if r[0]])
                    val_mj = (val_gj * 1000.0) / area
                    final_row[col_name] = round(val_mj, 3)
                    total_mj += val_mj
                
                # Total EUI
                cur.execute("SELECT Value FROM TabularDataWithStrings WHERE TableName='Site and Source Energy' AND RowName='Total Site Energy' AND ColumnName='Energy Per Total Building Area'")
                res_eui = cur.fetchone()
                if res_eui:
                    final_row["eui_total_MJ_m2"] = round(float(res_eui[0]), 3)
                else:
                    final_row["eui_total_MJ_m2"] = round(total_mj, 3)
            
            conn.close()
        except: pass
    
    try: shutil.rmtree(run_folder) 
    except: pass

    return final_row

# ==========================================
# 5. EXECUTION
# ==========================================
if __name__ == "__main__":
    import pandas as pd
    
    if os.path.exists(output_dir): shutil.rmtree(output_dir)
    os.makedirs(output_dir)

    # 1. PLAN
    jobs = generate_job_list()
    print(f"Generated Grid: {len(jobs)} simulations.")
    print("="*60)
    
    # 2. RUN
    start_time = time.time()
    valid_data = []
    
    with Pool(num_workers) as p:
        for i, res in enumerate(p.imap_unordered(run_simulation, jobs)):
            if res["valid_sim"]:
                valid_data.append(res)
                status = f"{res['eui_total_MJ_m2']} MJ/m2"
            else:
                status = "FAIL"
            print(f"[{i+1}/{len(jobs)}] {res['run_id']} | {res['weather_file'][:8]}.. | {status}")

    # 3. EXPORT
    if valid_data:
        df = pd.DataFrame(valid_data)
        
        # Sort Columns
        priority = ["run_id", "seed_file", "weather_file", "valid_sim", 
                    "eui_total_MJ_m2", "total_area_m2", "total_volume_m3"]
        rest = [c for c in df.columns if c not in priority]
        rest.sort()
        df = df[priority + rest]
        
        csv_path = os.path.join(project_root, "sweep_results_corrected.csv")
        df.to_csv(csv_path, index=False)
        
        print("\n" + "="*30)
        print(f"DONE in {round(time.time() - start_time)} seconds.")
        print(f"Valid Runs: {len(df)}/{len(jobs)}")
        print(f"Dataset: {csv_path}")
        print("="*30)
    else:
        print("\nFAILURE. No valid runs.")