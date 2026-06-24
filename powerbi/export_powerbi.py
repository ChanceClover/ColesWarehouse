import csv
import sqlite3
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DB_PATH = ROOT / "output" / "coles_warehouse_dw.sqlite"
EXPORT_DIR = ROOT / "output" / "powerbi"

TABLES = [
    "dim_date",
    "dim_store",
    "dim_product",
    "dim_customer",
    "dim_channel",
    "dim_fulfilment_center",
    "fact_sales",
    "fact_online_orders",
    "fact_inventory_daily",
    "fact_delivery_performance",
]


def export_query(conn, table_name):
    path = EXPORT_DIR / f"{table_name}.csv"
    cursor = conn.execute(f"SELECT * FROM {table_name}")
    headers = [description[0] for description in cursor.description]

    with path.open("w", newline="", encoding="utf-8-sig") as file:
        writer = csv.writer(file)
        writer.writerow(headers)
        writer.writerows(cursor.fetchall())

    return path


def main():
    if not DB_PATH.exists():
        raise FileNotFoundError(f"Warehouse database not found: {DB_PATH}. Run python .\\run_etl.py first.")

    conn = sqlite3.connect(DB_PATH)
    try:
        existing = {
            row[0]
            for row in conn.execute(
                "SELECT name FROM sqlite_master WHERE type IN ('table', 'view')"
            )
        }
        missing = [table for table in TABLES if table not in existing]
        if missing:
            raise RuntimeError(f"Required Power BI tables are missing: {', '.join(missing)}")

        EXPORT_DIR.mkdir(parents=True, exist_ok=True)

        # Hapus export lama agar folder hanya berisi tabel yang dipakai dashboard final.
        for old_export in EXPORT_DIR.glob("*.csv"):
            old_export.unlink()

        exported = [export_query(conn, table) for table in TABLES]
    finally:
        conn.close()

    print(f"Exported {len(exported)} CSV files to {EXPORT_DIR}")
    for path in exported:
        print(path.name)


if __name__ == "__main__":
    main()
