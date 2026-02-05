import os
import sys
import shutil
import subprocess
from pathlib import Path

# ==========================================
# CONFIGURATION
# ==========================================
PROJECT_ROOT = Path.cwd()
MEASURES_DIR = PROJECT_ROOT / "measures"
IMAGE = "nrel/openstudio:latest"

def docker_mount_path(host_path: Path) -> str:
    """
    Return a Docker-friendly mount path.
    - On Linux/macOS: use the absolute path as-is.
    - On Windows: convert 'C:\\Users\\me\\proj' -> '/c/Users/me/proj' (Docker Desktop convention).
      This is the most portable approach without relying on external tools.
    """
    p = host_path.resolve()
    if os.name != "nt":
        return str(p)

    drive = p.drive.rstrip(":").lower()  # 'C:' -> 'c'
    rest = p.as_posix().split(":", 1)[-1]  # ':\\Users\\..' -> '/Users/...'
    return f"/{drive}{rest}"

def run(cmd: list[str]) -> subprocess.CompletedProcess:
    return subprocess.run(cmd, capture_output=True, text=True)

def main() -> int:
    print(f"Scanning for measures in: {MEASURES_DIR}\n")

    if not MEASURES_DIR.exists():
        print("Error: 'measures' folder not found!")
        return 1

    if shutil.which("docker") is None:
        print("Error: Docker executable not found in PATH.")
        return 1

    measure_folders = sorted([p for p in MEASURES_DIR.iterdir() if p.is_dir()])
    if not measure_folders:
        print("No measures found.")
        return 0

    mount_src = docker_mount_path(PROJECT_ROOT)
    volume_mount = f"{mount_src}:/work"

    print(f"Found {len(measure_folders)} measures. Starting update process...\n")

    failures = 0
    for mdir in measure_folders:
        measure_name = mdir.name
        print(f"Updating: {measure_name}...", end=" ", flush=True)

        cmd = [
            "docker", "run", "--rm",
            "-v", volume_mount,
            IMAGE,
            "openstudio", "measure", "-u", f"/work/measures/{measure_name}"
        ]

        try:
            result = run(cmd)

            if result.returncode == 0:
                print("[SUCCESS]")
            else:
                failures += 1
                print("[FAILED]")
                stderr = (result.stderr or "").strip()
                stdout = (result.stdout or "").strip()
                if stderr:
                    print(f"  STDERR:\n{stderr}\n")
                if stdout:
                    print(f"  STDOUT:\n{stdout}\n")

        except Exception as e:
            failures += 1
            print(f"[ERROR] {e}")

    print("\nAll measures processed.")
    if failures:
        print(f"Failures: {failures}")
        return 2

    return 0

if __name__ == "__main__":
    raise SystemExit(main())
