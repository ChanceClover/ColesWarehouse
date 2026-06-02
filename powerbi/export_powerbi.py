import csv
import sqlite3
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DB_PATH = ROOT / "output" / "coles_warehouse_dw.sqlite"
EXPORT_DIR = ROOT / "output" / "powerbi"
CUBE_SQL_PATH = ROOT / "cube" / "olap_cube_views.sql"

TABLES = [
    "etl_load_batch",
    "etl_audit_log",
    "etl_error_log",
    "data_quality_issue",
    "map_standard_value",
    "dim_date",
    "dim_store",
    "dim_product",
    "dim_customer",
    "dim_promotion",
    "dim_payment_method",
    "dim_channel",
    "dim_supplier",
    "dim_fulfilment_center",
    "dim_distribution_center",
    "fact_sales",
    "fact_online_orders",
    "fact_inventory_daily",
    "fact_delivery_performance",
    "fact_procurement",
    "trf_stores",
    "trf_products",
    "trf_customers",
    "trf_promotions",
    "trf_payment_methods",
    "trf_channels",
    "trf_suppliers",
    "trf_fulfilment_centers",
    "trf_distribution_centers",
    "trf_sales",
    "trf_online_orders",
    "trf_inventory",
    "trf_delivery",
    "trf_procurement",
    "vw_cube_sales",
    "vw_cube_online_orders",
    "vw_cube_inventory",
    "vw_cube_delivery",
    "vw_cube_procurement",
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

    EXPORT_DIR.mkdir(parents=True, exist_ok=True)

    conn = sqlite3.connect(DB_PATH)
    try:
        if CUBE_SQL_PATH.exists():
            conn.executescript(CUBE_SQL_PATH.read_text(encoding="utf-8"))
            conn.commit()

        existing = {
            row[0]
            for row in conn.execute(
                "SELECT name FROM sqlite_master WHERE type IN ('table', 'view')"
            )
        }
        exported = []
        for table in TABLES:
            if table in existing:
                exported.append(export_query(conn, table))
    finally:
        conn.close()

    print(f"Exported {len(exported)} CSV files to {EXPORT_DIR}")
    for path in exported:
        print(path.name)


if __name__ == "__main__":
    main()
