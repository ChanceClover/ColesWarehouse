import sqlite3
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DB_PATH = ROOT / "output" / "coles_warehouse_dw.sqlite"
SQL_PATH = Path(__file__).resolve().parent / "olap_cube_views.sql"


def main():
    if not DB_PATH.exists():
        raise FileNotFoundError(f"Warehouse database not found: {DB_PATH}. Run python .\\run_etl.py first.")

    conn = sqlite3.connect(DB_PATH)
    try:
        conn.executescript(SQL_PATH.read_text(encoding="utf-8"))
        conn.commit()
    finally:
        conn.close()

    print(f"Cube views created in {DB_PATH}")


if __name__ == "__main__":
    main()
