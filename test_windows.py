import os
import json
import subprocess
import shutil
import sqlite3

# ==========================================
# CONFIGURATION
# ==========================================
project_root = os.getcwd() 
docker_root_path = project_root.replace(":\\", "/").replace("\\", "/").lower()
if not docker_root_path.startswith("/"):
    docker_root_path = "/" + docker_root_path

output_dir = os.path.join(project_root, "output_runs_window_test")

# TEST VALUES: 20% Glass vs 90% Glass
test_values = [0.20, 0.90]

# ==========================================
# GENERATE
# ==========================================
if os.path.exists(output_dir):
    shutil.rmtree(output_dir)
os.makedirs(output_dir)

print(f"Generating inputs for Window Test...")

for i, wwr in enumerate(test_values):
    run_id = f"run_{i:03d}"
    run_folder = os.path.join(output_dir, run_id)
    os.makedirs(run_folder)

    osw_content = {
        "seed_file": None,
        "weather_file": "/work/weather.epw", 
        "measure_paths": ["/work/measures"], 
        "steps": [
            # 1. Base Building
            {
                "measure_dir_name": "CreateDOEPrototypeBuilding",
                "arguments": {
                    "building_type": "MediumOffice",
                    "template": "90.1-2010",
                    "climate_zone": "ASHRAE 169-2013-4A"
                }
            },
            
            # 2. YOUR WINDOW MEASURE
            {
                "measure_dir_name": "SetWindowToWallRatio",
                "arguments": {
                    "wwr": wwr  # <--- The Magic Variable
                }
            }
        ]
    }
    
    with open(os.path.join(run_folder, "workflow.osw"), 'w') as f:
        json.dump(osw_content, f, indent=4)

# ==========================================
# RUN
# ==========================================
print("\nStarting Docker simulations...")
volume_mount = f"{docker_root_path}:/work"

for i in range(len(test_values)):
    run_id = f"run_{i:03d}"
    container_osw_path = f"/work/output_runs_window_test/{run_id}/workflow.osw"
    
    docker_cmd = [
        "docker", "run", "--rm",
        "-v", volume_mount,
        "nrel/openstudio:latest",
        "openstudio", "run",
        "-w", container_osw_path
    ]
    
    print(f"Running {run_id} (WWR: {test_values[i]})...")
    subprocess.run(docker_cmd, capture_output=True)
    print(f"  [SUCCESS] {run_id}")

# ==========================================
# ANALYZE (Physics Check)
# ==========================================
print("\nResults Analysis:")
print(f"{'Run ID':<10} | {'WWR':<10} | {'EUI':<15} | {'Units':<10}")
print("-" * 55)

for i, wwr in enumerate(test_values):
    run_id = f"run_{i:03d}"
    sql_path = os.path.join(output_dir, run_id, "run", "eplusout.sql")
    
    if os.path.exists(sql_path):
        try:
            conn = sqlite3.connect(sql_path)
            c = conn.cursor()
            query = """
                SELECT Value, Units 
                FROM TabularDataWithStrings 
                WHERE ReportName='AnnualBuildingUtilityPerformanceSummary' 
                AND TableName='Site and Source Energy' 
                AND RowName='Total Site Energy' 
                AND ColumnName='Energy Per Total Building Area'
            """
            c.execute(query)
            result = c.fetchone()
            conn.close()
            
            if result:
                eui = float(result[0])
                units = result[1]
                print(f"{run_id:<10} | {wwr:<10} | {round(eui, 2):<15} | {units:<10}")
            else:
                print(f"{run_id:<10} | {wwr:<10} | DATA NOT FOUND   | -")
        except:
            print(f"{run_id:<10} | {wwr:<10} | ERROR READING DB | -")
    else:
        print(f"{run_id:<10} | {wwr:<10} | NO DB FILE       | -")