import os
import json
import subprocess
import shutil
import pandas as pd

# ==========================================
# CONFIGURATION
# ==========================================
project_root = os.getcwd() 
docker_root_path = project_root.replace(":\\", "/").replace("\\", "/").lower()
if not docker_root_path.startswith("/"):
    docker_root_path = "/" + docker_root_path

output_dir = os.path.join(project_root, "output_runs")

# DEFINING OUR EXPERIMENT
# We want to test these 3 specific values
r_values_to_test = [5.0, 15.0, 40.0] 
n_simulations = len(r_values_to_test)

# ==========================================
# GENERATE
# ==========================================
if os.path.exists(output_dir):
    shutil.rmtree(output_dir)
os.makedirs(output_dir)

print(f"Generating inputs for {n_simulations} scenarios...")

for i, r_val in enumerate(r_values_to_test):
    run_id = f"run_{i:03d}"
    run_folder = os.path.join(output_dir, run_id)
    os.makedirs(run_folder)

    osw_content = {
        "seed_file": None,
        "weather_file": "/work/weather.epw", 
        "measure_paths": ["/work/measures"], 
        "steps": [
            {
                "measure_dir_name": "CreateDOEPrototypeBuilding",
                "arguments": {
                    "building_type": "MediumOffice",
                    "template": "90.1-2010",
                    "climate_zone": "ASHRAE 169-2013-4A"
                }
            },
            {
                "measure_dir_name": "SetWallInsulation",
                "arguments": {
                    # HERE IS THE MAGIC:
                    # We inject a different value for every run
                    "r_value": r_val 
                }
            },
            { "measure_dir_name": "openstudio_results", "arguments": {} }
        ]
    }
    
    with open(os.path.join(run_folder, "workflow.osw"), 'w') as f:
        json.dump(osw_content, f, indent=4)

# ==========================================
# RUN
# ==========================================
print("\nStarting Docker simulations...")
volume_mount = f"{docker_root_path}:/work"

for i in range(n_simulations):
    run_id = f"run_{i:03d}"
    container_osw_path = f"/work/output_runs/{run_id}/workflow.osw"
    
    docker_cmd = [
        "docker", "run", "--rm",
        "-v", volume_mount,
        "nrel/openstudio:latest",
        "openstudio", "run",
        "-w", container_osw_path
    ]
    
    print(f"Running {run_id} (R-Value: {r_values_to_test[i]})...")
    subprocess.run(docker_cmd, capture_output=True)
    print(f"  [SUCCESS] {run_id}")

# ==========================================
# ANALYZE (New!)
# ==========================================
print("\nResults Analysis:")
print(f"{'Run ID':<10} | {'R-Value':<10} | {'EUI (kBtu/ft2)':<15}")
print("-" * 45)

for i, r_val in enumerate(r_values_to_test):
    run_id = f"run_{i:03d}"
    csv_path = os.path.join(output_dir, run_id, "results.csv")
    
    if os.path.exists(csv_path):
        df = pd.read_csv(csv_path)
        # We grab the Total EUI (Energy Use Intensity)
        eui = df.loc[0, 'eui']
        print(f"{run_id:<10} | {r_val:<10} | {round(eui, 2):<15}")
    else:
        print(f"{run_id:<10} | {r_val:<10} | FAILED")