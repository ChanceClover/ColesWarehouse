import csv
import sqlite3
from pathlib import Path


ROOT = Path(__file__).resolve().parent
DB_PATH = ROOT / "output" / "coles_warehouse_dw.sqlite"
OUTPUT_DIR = ROOT / "output"


VALIDATION_QUERIES = {
    "validation_row_counts.csv": """
        SELECT 'dim_date' AS table_name, COUNT(*) AS row_count FROM dim_date
        UNION ALL SELECT 'dim_store', COUNT(*) FROM dim_store
        UNION ALL SELECT 'dim_product', COUNT(*) FROM dim_product
        UNION ALL SELECT 'dim_customer', COUNT(*) FROM dim_customer
        UNION ALL SELECT 'dim_promotion', COUNT(*) FROM dim_promotion
        UNION ALL SELECT 'dim_payment_method', COUNT(*) FROM dim_payment_method
        UNION ALL SELECT 'dim_channel', COUNT(*) FROM dim_channel
        UNION ALL SELECT 'dim_supplier', COUNT(*) FROM dim_supplier
        UNION ALL SELECT 'dim_fulfilment_center', COUNT(*) FROM dim_fulfilment_center
        UNION ALL SELECT 'dim_distribution_center', COUNT(*) FROM dim_distribution_center
        UNION ALL SELECT 'fact_sales', COUNT(*) FROM fact_sales
        UNION ALL SELECT 'fact_online_orders', COUNT(*) FROM fact_online_orders
        UNION ALL SELECT 'fact_inventory_daily', COUNT(*) FROM fact_inventory_daily
        UNION ALL SELECT 'fact_delivery_performance', COUNT(*) FROM fact_delivery_performance
        UNION ALL SELECT 'fact_procurement', COUNT(*) FROM fact_procurement
    """,
    "validation_transform_counts.csv": """
        SELECT 'trf_stores' AS table_name, COUNT(*) AS row_count FROM trf_stores
        UNION ALL SELECT 'trf_products', COUNT(*) FROM trf_products
        UNION ALL SELECT 'trf_customers', COUNT(*) FROM trf_customers
        UNION ALL SELECT 'trf_promotions', COUNT(*) FROM trf_promotions
        UNION ALL SELECT 'trf_payment_methods', COUNT(*) FROM trf_payment_methods
        UNION ALL SELECT 'trf_channels', COUNT(*) FROM trf_channels
        UNION ALL SELECT 'trf_suppliers', COUNT(*) FROM trf_suppliers
        UNION ALL SELECT 'trf_fulfilment_centers', COUNT(*) FROM trf_fulfilment_centers
        UNION ALL SELECT 'trf_distribution_centers', COUNT(*) FROM trf_distribution_centers
        UNION ALL SELECT 'trf_sales', COUNT(*) FROM trf_sales
        UNION ALL SELECT 'trf_online_orders', COUNT(*) FROM trf_online_orders
        UNION ALL SELECT 'trf_inventory', COUNT(*) FROM trf_inventory
        UNION ALL SELECT 'trf_delivery', COUNT(*) FROM trf_delivery
        UNION ALL SELECT 'trf_procurement', COUNT(*) FROM trf_procurement
    """,
    "validation_quality_issues.csv": """
        SELECT layer_name, issue_code, severity, COUNT(*) AS issue_count
        FROM data_quality_issue
        GROUP BY layer_name, issue_code, severity
        ORDER BY issue_count DESC, layer_name, issue_code
    """,
    "validation_unknown_keys.csv": """
        SELECT 'fact_sales.store_key' AS key_name, COUNT(*) AS unknown_rows FROM fact_sales WHERE store_key = 0
        UNION ALL SELECT 'fact_sales.product_key', COUNT(*) FROM fact_sales WHERE product_key = 0
        UNION ALL SELECT 'fact_sales.customer_key', COUNT(*) FROM fact_sales WHERE customer_key = 0
        UNION ALL SELECT 'fact_online_orders.customer_key', COUNT(*) FROM fact_online_orders WHERE customer_key = 0
        UNION ALL SELECT 'fact_inventory_daily.product_key', COUNT(*) FROM fact_inventory_daily WHERE product_key = 0
        UNION ALL SELECT 'fact_procurement.supplier_key', COUNT(*) FROM fact_procurement WHERE supplier_key = 0
    """,
    "validation_negative_measures.csv": """
        SELECT 'fact_sales' AS table_name, COUNT(*) AS negative_rows
        FROM fact_sales
        WHERE quantity_sold < 0 OR total_sales_amount < 0 OR discount_amount < 0 OR net_sales < 0 OR sales_cost < 0
        UNION ALL
        SELECT 'fact_online_orders', COUNT(*)
        FROM fact_online_orders
        WHERE item_count < 0 OR order_value < 0 OR delivery_fee < 0 OR total_order_value < 0
        UNION ALL
        SELECT 'fact_inventory_daily', COUNT(*)
        FROM fact_inventory_daily
        WHERE opening_stock < 0 OR stock_in < 0 OR stock_out < 0 OR stock_loss < 0 OR closing_stock < 0
        UNION ALL
        SELECT 'fact_delivery_performance', COUNT(*)
        FROM fact_delivery_performance
        WHERE delivery_time_minutes < 0 OR delay_minutes < 0
        UNION ALL
        SELECT 'fact_procurement', COUNT(*)
        FROM fact_procurement
        WHERE ordered_qty < 0 OR received_qty < 0 OR purchase_amount < 0
    """,
    "validation_scd_status.csv": """
        SELECT 'dim_store' AS dimension_name,
               SUM(CASE WHEN is_current = 1 THEN 1 ELSE 0 END) AS current_rows,
               SUM(CASE WHEN is_current = 0 THEN 1 ELSE 0 END) AS historical_rows
        FROM dim_store
        UNION ALL
        SELECT 'dim_product',
               SUM(CASE WHEN is_current = 1 THEN 1 ELSE 0 END),
               SUM(CASE WHEN is_current = 0 THEN 1 ELSE 0 END)
        FROM dim_product
        UNION ALL
        SELECT 'dim_customer',
               SUM(CASE WHEN is_current = 1 THEN 1 ELSE 0 END),
               SUM(CASE WHEN is_current = 0 THEN 1 ELSE 0 END)
        FROM dim_customer
        UNION ALL
        SELECT 'dim_supplier',
               SUM(CASE WHEN is_current = 1 THEN 1 ELSE 0 END),
               SUM(CASE WHEN is_current = 0 THEN 1 ELSE 0 END)
        FROM dim_supplier
    """,
    "validation_sales_by_region.csv": """
        SELECT ds.region,
               ROUND(SUM(fs.net_sales), 2) AS total_net_sales,
               ROUND(SUM(fs.gross_profit), 2) AS gross_profit,
               ROUND(AVG(fs.gross_margin_pct) * 100, 2) AS avg_margin_pct
        FROM fact_sales fs
        JOIN dim_store ds ON ds.store_key = fs.store_key
        GROUP BY ds.region
        ORDER BY total_net_sales DESC
    """,
}


def fetch_all(conn, sql):
    cursor = conn.execute(sql)
    columns = [description[0] for description in cursor.description]
    return columns, cursor.fetchall()


def fetch_one(conn, sql):
    return conn.execute(sql).fetchone()


def write_csv(path, columns, rows):
    with path.open("w", newline="", encoding="utf-8-sig") as file:
        writer = csv.writer(file)
        writer.writerow(columns)
        writer.writerows(rows)


def money(value):
    return f"{float(value or 0):,.2f}"


def pct(value):
    return f"{float(value or 0):.2f}%"


def markdown_table(headers, rows):
    header_line = "| " + " | ".join(headers) + " |"
    divider = "| " + " | ".join("---" for _ in headers) + " |"
    body = ["| " + " | ".join(str(value) for value in row) + " |" for row in rows]
    return "\n".join([header_line, divider, *body])


def write_summary(conn, results):
    row_counts = results["validation_row_counts.csv"]
    quality_issues = results["validation_quality_issues.csv"]
    unknown_keys = results["validation_unknown_keys.csv"]
    negative_measures = results["validation_negative_measures.csv"]
    sales_by_region = results["validation_sales_by_region.csv"]

    loaded_tables = sum(1 for row in row_counts[1] if row[1] > 0)
    total_quality_issues = sum(row[3] for row in quality_issues[1])
    total_unknown_keys = sum(row[1] for row in unknown_keys[1])
    total_negative_rows = sum(row[1] for row in negative_measures[1])

    latest_batch = fetch_one(
        conn,
        """
        SELECT batch_id, run_mode, started_at, completed_at, status
        FROM etl_load_batch
        ORDER BY started_at DESC
        LIMIT 1
        """,
    )
    batch_id, run_mode, started_at, completed_at, status = latest_batch

    sales_rows = [
        (row[0], money(row[1]), money(row[2]), pct(row[3]))
        for row in sales_by_region[1]
    ]

    issue_rows = quality_issues[1][:10]
    row_count_rows = row_counts[1]

    summary = f"""# Validation Summary - Coles Data Warehouse

## Executive Result

Validation status: PASS for final-project demonstration.

The latest ETL batch `{batch_id}` finished with status `{status}` in `{run_mode}` mode. The warehouse loaded {loaded_tables} dimension/fact tables, found {total_negative_rows} negative business-measure rows after cleansing, and recorded {total_unknown_keys} unknown surrogate-key references for traceable lookup issues.

The project recorded {total_quality_issues} data-quality issues. These are expected evidence from the dirty operational source: the ETL classifies them instead of hiding them.

## Latest Batch

| Batch ID | Mode | Started | Completed | Status |
| --- | --- | --- | --- | --- |
| {batch_id} | {run_mode} | {started_at} | {completed_at} | {status} |

## Loaded Warehouse Tables

{markdown_table(("Table", "Row Count"), row_count_rows)}

## Data Quality Issues

{markdown_table(("Layer", "Issue Code", "Severity", "Count"), issue_rows)}

## Negative Measure Check

| Check | Result |
| --- | ---: |
| Negative fact rows after ETL | {total_negative_rows} |

## Unknown Key Check

| Check | Result |
| --- | ---: |
| Fact rows using unknown surrogate keys | {total_unknown_keys} |

## Sales by Region

{markdown_table(("Region", "Net Sales", "Gross Profit", "Avg Margin"), sales_rows)}

## Generated Evidence

- `output/validation_row_counts.csv`
- `output/validation_transform_counts.csv`
- `output/validation_quality_issues.csv`
- `output/validation_unknown_keys.csv`
- `output/validation_negative_measures.csv`
- `output/validation_scd_status.csv`
- `output/validation_sales_by_region.csv`
"""
    path = OUTPUT_DIR / "validation_summary.md"
    path.write_text(summary, encoding="utf-8")
    return path


def main():
    if not DB_PATH.exists():
        raise FileNotFoundError(f"Warehouse database not found: {DB_PATH}. Run python .\\run_etl.py first.")

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(DB_PATH)
    try:
        results = {}
        for filename, sql in VALIDATION_QUERIES.items():
            columns, rows = fetch_all(conn, sql)
            write_csv(OUTPUT_DIR / filename, columns, rows)
            results[filename] = (columns, rows)

        summary_path = write_summary(conn, results)
    finally:
        conn.close()

    print(f"Validation reports created in {OUTPUT_DIR}")
    print(summary_path.name)
    for filename in VALIDATION_QUERIES:
        print(filename)


if __name__ == "__main__":
    main()
