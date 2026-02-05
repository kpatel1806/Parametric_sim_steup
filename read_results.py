import os
import sqlite3

# ==========================================
# CONFIGURATION
# ==========================================
project_root = os.getcwd() 
output_dir = os.path.join(project_root, "output_runs")

# We assume these match the order you ran them in
# run_000 = R-5, run_001 = R-15, run_002 = R-40
r_values_map = {
    "run_000": 5.0,
    "run_001": 15.0,
    "run_002": 40.0
}

# ==========================================
# ANALYZE RESULTS
# ==========================================
print("\nReading existing simulation results...")
print(f"{'Run ID':<10} | {'R-Value':<10} | {'EUI':<15} | {'Units':<10}")
print("-" * 55)

# Sort folders so they appear in order (run_000, run_001, etc.)
runs = sorted([d for d in os.listdir(output_dir) if d.startswith("run_")])

for run_id in runs:
    # 1. Get the SQL file path
    sql_path = os.path.join(output_dir, run_id, "run", "eplusout.sql")
    r_val = r_values_map.get(run_id, "???")
    
    if os.path.exists(sql_path):
        try:
            # 2. Connect to the database
            conn = sqlite3.connect(sql_path)
            c = conn.cursor()
            
            # 3. Query the Total Energy (EUI)
            # This is the standard "Total Site Energy" per area number
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
                print(f"{run_id:<10} | {r_val:<10} | {round(eui, 2):<15} | {units:<10}")
            else:
                print(f"{run_id:<10} | {r_val:<10} | DATA NOT FOUND   | -")
                
        except Exception as e:
            print(f"{run_id:<10} | {r_val:<10} | SQL ERROR        | {e}")
    else:
        print(f"{run_id:<10} | {r_val:<10} | NO DB FILE       | -")