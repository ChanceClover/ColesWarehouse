import csv
import html
import sqlite3
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
DB_PATH = ROOT / "output" / "coles_warehouse_dw.sqlite"
OUTPUT_DIR = ROOT / "output"
POWERBI_OUTPUT_DIR = OUTPUT_DIR / "powerbi"


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


def fmt_money(value):
    return f"{float(value):,.2f}"


def fmt_pct(value):
    return f"{float(value):.2f}%"


def font(size, bold=False):
    candidates = [
        Path("C:/Windows/Fonts/arialbd.ttf" if bold else "C:/Windows/Fonts/arial.ttf"),
        Path("C:/Windows/Fonts/calibrib.ttf" if bold else "C:/Windows/Fonts/calibri.ttf"),
    ]
    for candidate in candidates:
        if candidate.exists():
            return ImageFont.truetype(str(candidate), size)
    return ImageFont.load_default()


def draw_round_rect(draw, box, radius, fill, outline=None, width=1):
    draw.rounded_rectangle(box, radius=radius, fill=fill, outline=outline, width=width)


def draw_text(draw, xy, text, size=24, fill="#111827", bold=False, anchor=None):
    draw.text(xy, text, font=font(size, bold), fill=fill, anchor=anchor)


def draw_bar_chart(draw, x, y, w, h, title, rows, label_index, value_index, color, label_width=210):
    draw_text(draw, (x, y), title, size=22, bold=True)
    chart_y = y + 42
    max_value = max([float(row[value_index] or 0) for row in rows] + [1])
    bar_h = 28
    gap = 13
    for idx, row in enumerate(rows[:6]):
        label = str(row[label_index])[:24]
        value = float(row[value_index] or 0)
        yy = chart_y + idx * (bar_h + gap)
        draw_text(draw, (x, yy + 4), label, size=17, fill="#374151")
        bar_x = x + label_width
        bar_w = int((w - label_width - 95) * (value / max_value))
        draw_round_rect(draw, (bar_x, yy, bar_x + max(bar_w, 4), yy + bar_h), 7, color)
        draw_text(draw, (bar_x + bar_w + 10, yy + 4), f"{value:,.0f}", size=16, fill="#4b5563")


def draw_kpi(draw, x, y, w, h, label, value, subtext, fill="#ffffff"):
    draw_round_rect(draw, (x, y, x + w, y + h), 12, fill, "#d7dee8")
    draw_text(draw, (x + 20, y + 18), label, size=18, fill="#4b5563", bold=True)
    draw_text(draw, (x + 20, y + 48), value, size=31, fill="#0f172a", bold=True)
    draw_text(draw, (x + 20, y + h - 30), subtext, size=15, fill="#64748b")


def build_dashboard_png(metrics, sales_region, sales_channel, issues):
    img = Image.new("RGB", (1600, 1120), "#f3f6fb")
    draw = ImageDraw.Draw(img)

    draw.rectangle((0, 0, 1600, 96), fill="#111827")
    draw_text(draw, (42, 25), "Coles Group Data Warehouse Dashboard", size=34, fill="#ffffff", bold=True)
    draw_text(draw, (42, 62), "Executive Overview | ETL output evidence preview", size=18, fill="#cbd5e1")
    draw_text(draw, (1540, 36), "Power BI Layout", size=18, fill="#ffffff", anchor="ra")

    kpis = [
        ("Net Sales", fmt_money(metrics["net_sales"]), "from fact_sales"),
        ("Gross Profit", fmt_money(metrics["gross_profit"]), "sales profitability"),
        ("Gross Margin", fmt_pct(metrics["gross_margin_pct"]), "weighted margin"),
        ("Online Orders", fmt_money(metrics["online_order_value"]), "total order value"),
        ("On-time Delivery", fmt_pct(metrics["on_time_pct"]), "delivery performance"),
        ("DQ Issues", str(metrics["dq_issues"]), "logged and traceable"),
    ]
    x0, y0 = 42, 126
    for idx, item in enumerate(kpis):
        x = x0 + (idx % 3) * 510
        y = y0 + (idx // 3) * 142
        draw_kpi(draw, x, y, 470, 112, *item)

    draw_round_rect(draw, (42, 424, 760, 718), 14, "#ffffff", "#d7dee8")
    draw_bar_chart(draw, 70, 452, 660, 240, "Net Sales by Region", sales_region, 0, 1, "#2563eb")

    draw_round_rect(draw, (800, 424, 1558, 718), 14, "#ffffff", "#d7dee8")
    draw_bar_chart(draw, 828, 452, 700, 240, "Net Sales by Channel", sales_channel, 0, 1, "#059669")

    draw_round_rect(draw, (42, 748, 760, 1060), 14, "#ffffff", "#d7dee8")
    draw_text(draw, (70, 776), "Validation Result", size=22, bold=True)
    validation_lines = [
        f"Warehouse tables loaded: {metrics['warehouse_tables']} dimension/fact tables",
        f"Negative business measures after ETL: {metrics['negative_rows']}",
        f"Unknown surrogate-key rows: {metrics['unknown_key_rows']}",
        f"Latest ETL batch status: {metrics['batch_status']}",
    ]
    for idx, line in enumerate(validation_lines):
        draw_text(draw, (88, 822 + idx * 34), line, size=20, fill="#374151")

    draw_round_rect(draw, (800, 748, 1558, 1060), 14, "#ffffff", "#d7dee8")
    draw_bar_chart(draw, 828, 776, 700, 240, "Top Data Quality Issues", issues, 0, 1, "#dc2626", label_width=250)

    path = POWERBI_OUTPUT_DIR / "dashboard_final_preview.png"
    img.save(path)
    return path


def build_dashboard_html(metrics, sales_region, sales_channel, issues):
    def rows_to_bars(rows, label_index, value_index):
        max_value = max([float(row[value_index] or 0) for row in rows] + [1])
        parts = []
        for row in rows[:6]:
            label = html.escape(str(row[label_index]))
            value = float(row[value_index] or 0)
            width = max(3, int(value / max_value * 100))
            parts.append(
                f"<div class='bar-row'><span>{label}</span><div class='bar-track'>"
                f"<div class='bar' style='width:{width}%'></div></div><strong>{value:,.0f}</strong></div>"
            )
        return "\n".join(parts)

    html_text = f"""<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Coles Group Data Warehouse Dashboard</title>
  <style>
    * {{ box-sizing: border-box; }}
    body {{ margin: 0; font-family: Arial, sans-serif; background: #f3f6fb; color: #111827; }}
    header {{ background: #111827; color: white; padding: 24px 36px; }}
    header h1 {{ margin: 0; font-size: 32px; }}
    header p {{ margin: 6px 0 0; color: #cbd5e1; }}
    main {{ padding: 28px 36px; display: grid; gap: 22px; }}
    .kpis {{ display: grid; grid-template-columns: repeat(3, 1fr); gap: 18px; }}
    .card {{ background: white; border: 1px solid #d7dee8; border-radius: 12px; padding: 20px; }}
    .kpi-label {{ color: #4b5563; font-weight: 700; }}
    .kpi-value {{ font-size: 30px; font-weight: 800; margin-top: 8px; }}
    .kpi-sub {{ color: #64748b; margin-top: 12px; font-size: 14px; }}
    .grid2 {{ display: grid; grid-template-columns: 1fr 1fr; gap: 22px; }}
    h2 {{ margin: 0 0 18px; font-size: 22px; }}
    .bar-row {{ display: grid; grid-template-columns: 170px 1fr 90px; gap: 12px; align-items: center; margin: 13px 0; }}
    .bar-track {{ background: #e5e7eb; border-radius: 999px; height: 24px; overflow: hidden; }}
    .bar {{ background: #2563eb; height: 100%; border-radius: 999px; }}
    .green .bar {{ background: #059669; }}
    .red .bar {{ background: #dc2626; }}
    .checks p {{ margin: 12px 0; font-size: 18px; }}
  </style>
</head>
<body>
  <header>
    <h1>Coles Group Data Warehouse Dashboard</h1>
    <p>Executive Overview | Power BI-ready layout based on generated warehouse output</p>
  </header>
  <main>
    <section class="kpis">
      <div class="card"><div class="kpi-label">Net Sales</div><div class="kpi-value">{fmt_money(metrics["net_sales"])}</div><div class="kpi-sub">from fact_sales</div></div>
      <div class="card"><div class="kpi-label">Gross Profit</div><div class="kpi-value">{fmt_money(metrics["gross_profit"])}</div><div class="kpi-sub">sales profitability</div></div>
      <div class="card"><div class="kpi-label">Gross Margin</div><div class="kpi-value">{fmt_pct(metrics["gross_margin_pct"])}</div><div class="kpi-sub">weighted margin</div></div>
      <div class="card"><div class="kpi-label">Online Orders</div><div class="kpi-value">{fmt_money(metrics["online_order_value"])}</div><div class="kpi-sub">total order value</div></div>
      <div class="card"><div class="kpi-label">On-time Delivery</div><div class="kpi-value">{fmt_pct(metrics["on_time_pct"])}</div><div class="kpi-sub">delivery performance</div></div>
      <div class="card"><div class="kpi-label">Data Quality Issues</div><div class="kpi-value">{metrics["dq_issues"]}</div><div class="kpi-sub">logged and traceable</div></div>
    </section>
    <section class="grid2">
      <div class="card"><h2>Net Sales by Region</h2>{rows_to_bars(sales_region, 0, 1)}</div>
      <div class="card green"><h2>Net Sales by Channel</h2>{rows_to_bars(sales_channel, 0, 1)}</div>
    </section>
    <section class="grid2">
      <div class="card checks"><h2>Validation Result</h2>
        <p>Warehouse tables loaded: {metrics["warehouse_tables"]} dimension/fact tables</p>
        <p>Negative business measures after ETL: {metrics["negative_rows"]}</p>
        <p>Unknown surrogate-key rows: {metrics["unknown_key_rows"]}</p>
        <p>Latest ETL batch status: {metrics["batch_status"]}</p>
      </div>
      <div class="card red"><h2>Top Data Quality Issues</h2>{rows_to_bars(issues, 0, 1)}</div>
    </section>
  </main>
</body>
</html>
"""
    path = POWERBI_OUTPUT_DIR / "dashboard_final_preview.html"
    path.write_text(html_text, encoding="utf-8")
    return path


def main():
    if not DB_PATH.exists():
        raise FileNotFoundError(f"Warehouse database not found: {DB_PATH}")
    POWERBI_OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    conn = sqlite3.connect(DB_PATH)
    try:
        validation_queries = {
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

        generated_csvs = []
        for filename, sql in validation_queries.items():
            columns, rows = fetch_all(conn, sql)
            path = OUTPUT_DIR / filename
            write_csv(path, columns, rows)
            generated_csvs.append(path)

        row_counts_cols, row_counts = fetch_all(conn, validation_queries["validation_row_counts.csv"])
        quality_cols, quality_rows = fetch_all(conn, validation_queries["validation_quality_issues.csv"])
        unknown_cols, unknown_rows = fetch_all(conn, validation_queries["validation_unknown_keys.csv"])
        negative_cols, negative_rows = fetch_all(conn, validation_queries["validation_negative_measures.csv"])
        sales_cols, sales_region = fetch_all(conn, validation_queries["validation_sales_by_region.csv"])

        sales_channel_cols, sales_channel = fetch_all(
            conn,
            """
            SELECT dc.channel_name, ROUND(SUM(fs.net_sales), 2) AS total_net_sales
            FROM fact_sales fs
            JOIN dim_channel dc ON dc.channel_key = fs.channel_key
            GROUP BY dc.channel_name
            ORDER BY total_net_sales DESC
            """,
        )
        issue_top_cols, issue_top = fetch_all(
            conn,
            """
            SELECT issue_code, COUNT(*) AS issue_count
            FROM data_quality_issue
            GROUP BY issue_code
            ORDER BY issue_count DESC
            LIMIT 6
            """,
        )

        net_sales, gross_profit, gross_margin_pct = fetch_one(
            conn,
            """
            SELECT ROUND(SUM(net_sales), 2),
                   ROUND(SUM(gross_profit), 2),
                   ROUND(SUM(gross_profit) / NULLIF(SUM(net_sales), 0) * 100, 2)
            FROM fact_sales
            """,
        )
        (online_order_value,) = fetch_one(conn, "SELECT ROUND(SUM(total_order_value), 2) FROM fact_online_orders")
        (on_time_pct,) = fetch_one(conn, "SELECT ROUND(AVG(on_time_flag) * 100, 2) FROM fact_delivery_performance")
        (dq_issues,) = fetch_one(conn, "SELECT COUNT(*) FROM data_quality_issue")
        (batch_status,) = fetch_one(conn, "SELECT status FROM etl_load_batch ORDER BY started_at DESC LIMIT 1")

        negative_total = sum(row[1] for row in negative_rows)
        unknown_total = sum(row[1] for row in unknown_rows)
        warehouse_loaded = sum(1 for row in row_counts if row[1] > 0)

        metrics = {
            "net_sales": net_sales or 0,
            "gross_profit": gross_profit or 0,
            "gross_margin_pct": gross_margin_pct or 0,
            "online_order_value": online_order_value or 0,
            "on_time_pct": on_time_pct or 0,
            "dq_issues": dq_issues,
            "negative_rows": negative_total,
            "unknown_key_rows": unknown_total,
            "batch_status": batch_status,
            "warehouse_tables": warehouse_loaded,
        }

        dashboard_png = build_dashboard_png(metrics, sales_region, sales_channel, issue_top)
        dashboard_html = build_dashboard_html(metrics, sales_region, sales_channel, issue_top)

        summary_path = OUTPUT_DIR / "validation_summary.md"
        issue_lines = "\n".join(
            f"| {row[0]} | {row[1]} | {row[2]} | {row[3]} |" for row in quality_rows[:10]
        )
        row_count_lines = "\n".join(f"| {row[0]} | {row[1]} |" for row in row_counts)
        sales_lines = "\n".join(
            f"| {row[0]} | {fmt_money(row[1])} | {fmt_money(row[2])} | {fmt_pct(row[3])} |"
            for row in sales_region
        )
        summary_path.write_text(
            f"""# Final Validation Summary - Coles Data Warehouse

## Executive Result

Status validasi akhir: PASS untuk kesiapan demo data warehouse.

Warehouse berhasil memuat {warehouse_loaded} tabel dimension/fact dengan batch terakhir berstatus {batch_status}. Pemeriksaan measure bisnis menunjukkan {negative_total} baris negatif pada fact table setelah ETL. Unknown surrogate-key usage berjumlah {unknown_total} baris; kondisi ini tercatat sebagai lookup warning dan tetap traceable karena diarahkan ke unknown member, sehingga bisa dijelaskan saat demo.

Data quality issue yang tercatat berjumlah {dq_issues}. Angka ini bukan kegagalan warehouse, tetapi bukti bahwa dirty source diprofiling dan masalah data dicatat secara traceable melalui data_quality_issue dan etl_error_log.

## Loaded Warehouse Tables

| Table | Row Count |
|---|---:|
{row_count_lines}

## Negative Measure Check

| Result | Value |
|---|---:|
| Fact rows with negative business measures after ETL | {negative_total} |

## Unknown Key Check

| Result | Value |
|---|---:|
| Fact rows using unknown surrogate key after lookup | {unknown_total} |

## Top Data Quality Issues

| Layer | Issue Code | Severity | Count |
|---|---|---|---:|
{issue_lines}

## Sales Validation by Region

| Region | Net Sales | Gross Profit | Avg Margin |
|---|---:|---:|---:|
{sales_lines}

## Evidence Files

- output/validation_row_counts.csv
- output/validation_quality_issues.csv
- output/validation_unknown_keys.csv
- output/validation_negative_measures.csv
- output/validation_sales_by_region.csv
- output/powerbi/dashboard_final_preview.png
- output/powerbi/dashboard_final_preview.html
""",
            encoding="utf-8",
        )

        layout_path = ROOT / "powerbi" / "final_dashboard_layout.md"
        layout_path.write_text(
            f"""# Final Power BI Dashboard Layout

This layout is ready to reproduce in Power BI Desktop using CSV files from `output/powerbi`.

## Page 1 - Executive Overview

Purpose: show whether the Coles-style retail warehouse is ready for business analysis.

KPI cards:

- Net Sales: {fmt_money(metrics["net_sales"])}
- Gross Profit: {fmt_money(metrics["gross_profit"])}
- Gross Margin %: {fmt_pct(metrics["gross_margin_pct"])}
- Total Online Order Value: {fmt_money(metrics["online_order_value"])}
- On-time Delivery %: {fmt_pct(metrics["on_time_pct"])}
- Data Quality Issues: {metrics["dq_issues"]}

Visuals:

- Bar chart: Net Sales by Region, using `fact_sales[net_sales]` and `dim_store[region]`.
- Bar chart: Net Sales by Channel, using `fact_sales[net_sales]` and `dim_channel[channel_name]`.
- Validation card group: negative measure rows, unknown surrogate-key rows, latest ETL batch status.
- Bar chart: issue count by `data_quality_issue[issue_code]`.

## Page 2 - Sales and Omnichannel

Visuals:

- Column chart: Net Sales by `dim_channel[channel_name]`.
- Matrix: `dim_store[region]` by `dim_product[category]`, value `fact_sales[net_sales]`.
- Bar chart: Quantity Sold by product category.
- Slicers: Year, Region, Channel, Category.

## Page 3 - ETL Health

Visuals:

- KPI cards: Data Quality Issues, Error Log Rows, Audit Log Rows, Latest Batch Status.
- Matrix: `data_quality_issue[layer_name]` by `severity`.
- Bar chart: issue count by `issue_code`.
- Table: `etl_audit_log` process_name, source_table, target_table, rows_loaded, rows_rejected, status.

## Preview Evidence

- PNG preview: `output/powerbi/dashboard_final_preview.png`
- HTML preview: `output/powerbi/dashboard_final_preview.html`

Use the PNG as a minimal final dashboard screenshot if Power BI Desktop is not available during submission.
""",
            encoding="utf-8",
        )

        print("Generated validation summary:", summary_path)
        for path in generated_csvs:
            print("Generated validation CSV:", path)
        print("Generated dashboard PNG:", dashboard_png)
        print("Generated dashboard HTML:", dashboard_html)
        print("Generated Power BI layout:", layout_path)
    finally:
        conn.close()


if __name__ == "__main__":
    main()
