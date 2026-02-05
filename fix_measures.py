import os
import subprocess

# Fix path for Docker
project_root = os.getcwd()
docker_root_path = project_root.replace(":\\", "/").replace("\\", "/").lower()
if not docker_root_path.startswith("/"):
    docker_root_path = "/" + docker_root_path

volume_mount = f"{docker_root_path}:/work"

print("Fixing 'SetWallInsulation' measure...")

# This command tells OpenStudio to update the XML file for your new measure
cmd = [
    "docker", "run", "--rm",
    "-v", volume_mount,
    "nrel/openstudio:latest",
    "openstudio", "measure", "-u", "/work/measures/SetWallInsulation"
]

try:
    result = subprocess.run(cmd, capture_output=True, text=True)
    print(result.stdout)
    if "Success" in result.stdout or result.returncode == 0:
        print("[SUCCESS] measure.xml updated successfully!")
    else:
        print("[FAILED] Could not update XML.")
        print(result.stderr)
except Exception as e:
    print(f"Error: {e}")