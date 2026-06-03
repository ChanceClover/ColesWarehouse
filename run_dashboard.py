import html
import sqlite3
from pathlib import Path


ROOT = Path(__file__).resolve().parent
DB_PATH = ROOT / "output" / "coles_warehouse_dw.sqlite"
OUTPUT_DIR = ROOT / "output"
DASHBOARD_PATH = OUTPUT_DIR / "dashboard.html"


def fetch_all(conn, sql):
    return conn.execute(sql).fetchall()


def fetch_one(conn, sql):
    return conn.execute(sql).fetchone()


def money(value):
    return f"{float(value or 0):,.2f}"


def pct(value):
    return f"{float(value or 0):.2f}%"


def bar_rows(rows, label_index, value_index, value_formatter=None):
    max_value = max([float(row[value_index] or 0) for row in rows] + [1])
    parts = []
    for row in rows:
        label = html.escape(str(row[label_index]))
        value = float(row[value_index] or 0)
        width = max(2, value / max_value * 100)
        shown_value = value_formatter(value) if value_formatter else f"{value:,.0f}"
        parts.append(
            f"""
            <div class="bar-row">
              <span class="bar-label">{label}</span>
              <div class="bar-track"><div class="bar-fill" style="width: {width:.2f}%"></div></div>
              <strong>{shown_value}</strong>
            </div>
            """
        )
    return "\n".join(parts)


def issue_table(rows):
    if not rows:
        return "<tr><td colspan='4'>No data quality issues recorded.</td></tr>"
    return "\n".join(
        f"""
        <tr>
          <td>{html.escape(str(row[0]))}</td>
          <td>{html.escape(str(row[1]))}</td>
          <td><span class="badge">{html.escape(str(row[2]))}</span></td>
          <td class="num">{row[3]}</td>
        </tr>
        """
        for row in rows
    )


def main():
    if not DB_PATH.exists():
        raise FileNotFoundError(f"Warehouse database not found: {DB_PATH}. Run python .\\run_project.py first.")

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(DB_PATH)
    try:
        net_sales, gross_profit, gross_margin = fetch_one(
            conn,
            """
            SELECT ROUND(SUM(net_sales), 2),
                   ROUND(SUM(gross_profit), 2),
                   ROUND(SUM(gross_profit) / NULLIF(SUM(net_sales), 0) * 100, 2)
            FROM fact_sales
            """,
        )
        (online_value,) = fetch_one(conn, "SELECT ROUND(SUM(total_order_value), 2) FROM fact_online_orders")
        (on_time_pct,) = fetch_one(conn, "SELECT ROUND(AVG(on_time_flag) * 100, 2) FROM fact_delivery_performance")
        (quality_issue_count,) = fetch_one(conn, "SELECT COUNT(*) FROM data_quality_issue")
        batch_id, run_mode, batch_status = fetch_one(
            conn,
            """
            SELECT batch_id, run_mode, status
            FROM etl_load_batch
            ORDER BY started_at DESC
            LIMIT 1
            """,
        )
        (negative_rows,) = fetch_one(
            conn,
            """
            SELECT SUM(negative_rows)
            FROM (
                SELECT COUNT(*) AS negative_rows
                FROM fact_sales
                WHERE quantity_sold < 0 OR total_sales_amount < 0 OR discount_amount < 0 OR net_sales < 0 OR sales_cost < 0
                UNION ALL
                SELECT COUNT(*)
                FROM fact_online_orders
                WHERE item_count < 0 OR order_value < 0 OR delivery_fee < 0 OR total_order_value < 0
                UNION ALL
                SELECT COUNT(*)
                FROM fact_inventory_daily
                WHERE opening_stock < 0 OR stock_in < 0 OR stock_out < 0 OR stock_loss < 0 OR closing_stock < 0
                UNION ALL
                SELECT COUNT(*)
                FROM fact_delivery_performance
                WHERE delivery_time_minutes < 0 OR delay_minutes < 0
                UNION ALL
                SELECT COUNT(*)
                FROM fact_procurement
                WHERE ordered_qty < 0 OR received_qty < 0 OR purchase_amount < 0
            )
            """,
        )

        sales_by_region = fetch_all(
            conn,
            """
            SELECT ds.region, ROUND(SUM(fs.net_sales), 2) AS total_net_sales
            FROM fact_sales fs
            JOIN dim_store ds ON ds.store_key = fs.store_key
            GROUP BY ds.region
            ORDER BY total_net_sales DESC
            """,
        )
        sales_by_category = fetch_all(
            conn,
            """
            SELECT
                CASE
                    WHEN fs.product_key = 0 THEN 'Unknown / Unmatched Product'
                    WHEN dp.category = 'Unknown' THEN 'Unknown Category'
                    ELSE dp.category
                END AS product_category,
                ROUND(SUM(fs.net_sales), 2) AS total_net_sales
            FROM fact_sales fs
            JOIN dim_product dp ON dp.product_key = fs.product_key
            GROUP BY product_category
            ORDER BY total_net_sales DESC
            LIMIT 8
            """,
        )
        delivery_status = fetch_all(
            conn,
            """
            SELECT delivery_status, COUNT(*) AS deliveries
            FROM fact_delivery_performance
            GROUP BY delivery_status
            ORDER BY deliveries DESC
            """,
        )
        quality_issues = fetch_all(
            conn,
            """
            SELECT layer_name, issue_code, severity, COUNT(*) AS issue_count
            FROM data_quality_issue
            GROUP BY layer_name, issue_code, severity
            ORDER BY issue_count DESC
            LIMIT 10
            """,
        )
    finally:
        conn.close()

    dashboard = f"""<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Coles Data Warehouse Dashboard</title>
  <style>
    * {{ box-sizing: border-box; }}
    body {{
      margin: 0;
      font-family: Arial, Helvetica, sans-serif;
      background: #f5f7fb;
      color: #172033;
    }}
    header {{
      background: #202938;
      color: #fff;
      padding: 24px 34px;
    }}
    h1 {{
      margin: 0;
      font-size: 30px;
      letter-spacing: 0;
    }}
    header p {{
      margin: 7px 0 0;
      color: #c8d2e1;
    }}
    main {{
      padding: 28px 34px 40px;
      display: grid;
      gap: 22px;
    }}
    .kpis {{
      display: grid;
      grid-template-columns: repeat(3, minmax(0, 1fr));
      gap: 16px;
    }}
    .grid {{
      display: grid;
      grid-template-columns: repeat(2, minmax(0, 1fr));
      gap: 22px;
    }}
    section, .kpi {{
      background: #fff;
      border: 1px solid #dce3ee;
      border-radius: 8px;
      padding: 20px;
    }}
    .kpi small {{
      display: block;
      color: #667085;
      font-weight: 700;
      margin-bottom: 8px;
    }}
    .kpi strong {{
      display: block;
      font-size: 28px;
      line-height: 1.2;
    }}
    h2 {{
      margin: 0 0 18px;
      font-size: 20px;
      letter-spacing: 0;
    }}
    .bar-row {{
      display: grid;
      grid-template-columns: 150px minmax(120px, 1fr) 100px;
      gap: 12px;
      align-items: center;
      margin: 12px 0;
    }}
    .bar-label {{
      color: #344054;
      overflow-wrap: anywhere;
    }}
    .bar-track {{
      height: 24px;
      background: #e7ecf3;
      border-radius: 4px;
      overflow: hidden;
    }}
    .bar-fill {{
      height: 100%;
      background: #2e6f9e;
      border-radius: 4px;
    }}
    .green .bar-fill {{ background: #27845f; }}
    .red .bar-fill {{ background: #b94747; }}
    table {{
      width: 100%;
      border-collapse: collapse;
      font-size: 14px;
    }}
    th, td {{
      border-bottom: 1px solid #e5eaf1;
      padding: 10px 8px;
      text-align: left;
    }}
    th {{ color: #526071; }}
    .num {{ text-align: right; }}
    .badge {{
      display: inline-block;
      padding: 4px 8px;
      border-radius: 4px;
      background: #eef2f6;
      font-size: 12px;
      font-weight: 700;
    }}
    .status {{
      display: grid;
      gap: 10px;
      color: #344054;
    }}
    .status strong {{ color: #172033; }}
    @media (max-width: 900px) {{
      .kpis, .grid {{ grid-template-columns: 1fr; }}
      main {{ padding: 18px; }}
      header {{ padding: 22px 18px; }}
      .bar-row {{ grid-template-columns: 1fr; }}
    }}
  </style>
</head>
<body>
  <header>
    <h1>Coles Data Warehouse Dashboard</h1>
    <p>Generated directly from the SQLite warehouse. No Power BI model setup required.</p>
  </header>
  <main>
    <div class="kpis">
      <div class="kpi"><small>Net Sales</small><strong>{money(net_sales)}</strong></div>
      <div class="kpi"><small>Gross Profit</small><strong>{money(gross_profit)}</strong></div>
      <div class="kpi"><small>Gross Margin</small><strong>{pct(gross_margin)}</strong></div>
      <div class="kpi"><small>Online Order Value</small><strong>{money(online_value)}</strong></div>
      <div class="kpi"><small>On-Time Delivery</small><strong>{pct(on_time_pct)}</strong></div>
      <div class="kpi"><small>Data Quality Issues</small><strong>{quality_issue_count}</strong></div>
    </div>

    <div class="grid">
      <section>
        <h2>Net Sales by Region</h2>
        {bar_rows(sales_by_region, 0, 1, money)}
      </section>
      <section class="green">
        <h2>Net Sales by Product Category</h2>
        {bar_rows(sales_by_category, 0, 1, money)}
      </section>
    </div>

    <div class="grid">
      <section>
        <h2>Delivery Status</h2>
        {bar_rows(delivery_status, 0, 1)}
      </section>
      <section>
        <h2>ETL Validation Status</h2>
        <div class="status">
          <div>Latest batch: <strong>{html.escape(str(batch_id))}</strong></div>
          <div>Run mode: <strong>{html.escape(str(run_mode))}</strong></div>
          <div>Batch status: <strong>{html.escape(str(batch_status))}</strong></div>
          <div>Negative fact measures after ETL: <strong>{negative_rows or 0}</strong></div>
        </div>
      </section>
    </div>

    <section class="red">
      <h2>Top Data Quality Issues</h2>
      <table>
        <thead>
          <tr>
            <th>Layer</th>
            <th>Issue Code</th>
            <th>Severity</th>
            <th class="num">Count</th>
          </tr>
        </thead>
        <tbody>
          {issue_table(quality_issues)}
        </tbody>
      </table>
    </section>
  </main>
</body>
</html>
"""
    DASHBOARD_PATH.write_text(dashboard, encoding="utf-8")
    print(f"Dashboard created: {DASHBOARD_PATH}")


if __name__ == "__main__":
    main()
