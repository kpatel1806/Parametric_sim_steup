import os
import subprocess

print("=== DIAGNOSTIC MODE ===")
root = os.getcwd()
measures_path = os.path.join(root, "measures")

# 1. CHECK LOCAL FOLDER STRUCTURE
print(f"\n1. Checking Local Folders in: {measures_path}")
if not os.path.exists(measures_path):
    print("   [CRITICAL FAIL] 'measures' folder does not exist!")
    exit()

found_measures = []
for item in os.listdir(measures_path):
    item_path = os.path.join(measures_path, item)
    if os.path.isdir(item_path):
        # Check for Double Nesting (The #1 Cause of Failure)
        nested_files = os.listdir(item_path)
        if item in nested_files: 
            print(f"   [WARNING] DOUBLE NESTING DETECTED in: {item}")
            print(f"      You have: measures/{item}/{item}/measure.rb")
            print(f"      You need: measures/{item}/measure.rb")
            print("      FIX: Move the files up one level.")
        
        # Check for measure.xml
        if "measure.xml" in nested_files:
            print(f"   [OK] Found valid measure: {item}")
            found_measures.append(item)
        else:
            print(f"   [ERROR] No measure.xml found in: {item}")

# 2. CHECK DOCKER VISIBILITY
print("\n2. Asking Docker what it sees...")
# We mount C:\ML to /work and ask it to list the files
# This proves if the mount is working or broken
docker_root = root.replace(":\\", "/").replace("\\", "/").lower()
if not docker_root.startswith("/"): docker_root = "/" + docker_root

cmd = [
    "docker", "run", "--rm",
    "-v", f"{docker_root}:/work",
    "nrel/openstudio:latest",
    "ls", "-R", "/work/measures"
]

try:
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode == 0:
        print("\n   [DOCKER OUTPUT START]")
        print(result.stdout)
        print("   [DOCKER OUTPUT END]")
        
        # Check if Docker sees the exact name required
        required_name = "create_typical_building_from_model"
        if required_name in result.stdout:
            print(f"\n   [SUCCESS] Docker sees '{required_name}'")
        else:
            print(f"\n   [FAIL] Docker CANNOT see '{required_name}'")
            print("   Compare the names in 'DOCKER OUTPUT' above vs what your script needs.")
    else:
        print("   [CRITICAL FAIL] Docker mount failed completely.")
        print(result.stderr)
except Exception as e:
    print(f"   Docker failed to run: {e}")