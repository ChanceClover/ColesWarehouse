import argparse
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parent


def run_step(label, command):
    print()
    print(f"=== {label} ===", flush=True)
    subprocess.run(command, cwd=ROOT, check=True)


def main():
    parser = argparse.ArgumentParser(
        description="Run the full Coles data warehouse final-project pipeline."
    )
    parser.add_argument(
        "--incremental",
        action="store_true",
        help="Run ETL in incremental mode instead of rebuilding the warehouse.",
    )
    parser.add_argument(
        "--skip-powerbi",
        action="store_true",
        help="Skip Power BI CSV export.",
    )
    args = parser.parse_args()

    python = sys.executable
    etl_command = [python, "run_etl.py"]
    if args.incremental:
        etl_command.append("--incremental")

    run_step("1. Build warehouse", etl_command)
    run_step("2. Run validation reports", [python, "run_validation.py"])
    run_step("3. Create cube views", [python, "cube/run_cube.py"])
    run_step("4. Generate HTML dashboard", [python, "run_dashboard.py"])

    if not args.skip_powerbi:
        run_step("5. Export Power BI-ready files", [python, "powerbi/export_powerbi.py"])

    print()
    print("Final project pipeline complete.")
    print(f"Warehouse database: {ROOT / 'output' / 'coles_warehouse_dw.sqlite'}")
    print(f"Validation summary: {ROOT / 'output' / 'validation_summary.md'}")
    print(f"HTML dashboard: {ROOT / 'output' / 'dashboard.html'}")
    if not args.skip_powerbi:
        print(f"Power BI CSV folder: {ROOT / 'output' / 'powerbi'}")


if __name__ == "__main__":
    main()
