import sqlite3
from datetime import date
from pathlib import Path

import pandas as pd
import streamlit as st

ROOT = Path(__file__).resolve().parent
DEFAULT_DB_PATH = ROOT / "output" / "coles_warehouse_dw.sqlite"

st.set_page_config(
    page_title="Coles Warehouse Streamlit Dashboard",
    layout="wide",
    initial_sidebar_state="expanded",
)


@st.cache_data
def load_query(db_path: str, query: str, params=None) -> pd.DataFrame:
    conn = sqlite3.connect(db_path)
    try:
        return pd.read_sql_query(query, conn, params=params)
    finally:
        conn.close()


@st.cache_data
def load_sales(db_path: str) -> pd.DataFrame:
    query = """
    SELECT
        fs.net_sales,
        fs.gross_profit,
        fs.gross_margin_pct,
        fs.discount_pct,
        fs.quantity_sold,
        fs.total_sales_amount,
        fs.discount_amount,
        d.full_date,
        d.year_month,
        d.year,
        d.quarter_name,
        ds.region,
        ds.store_name,
        ds.store_type,
        dp.category,
        dp.brand,
        dp.product_name,
        dc.channel_name
    FROM fact_sales fs
    JOIN dim_date d ON fs.date_key = d.date_key
    JOIN dim_store ds ON fs.store_key = ds.store_key
    JOIN dim_product dp ON fs.product_key = dp.product_key
    JOIN dim_channel dc ON fs.channel_key = dc.channel_key
    """
    df = load_query(db_path, query)
    df["full_date"] = pd.to_datetime(df["full_date"]).dt.date
    return df


@st.cache_data
def load_delivery_performance(db_path: str) -> pd.DataFrame:
    query = """
    SELECT
        f.delivery_status,
        f.on_time_flag,
        f.delay_minutes,
        d.full_date AS actual_date,
        o.channel_key,
        dc.channel_name
    FROM fact_delivery_performance f
    JOIN fact_online_orders o ON f.online_order_key = o.online_order_key
    JOIN dim_date d ON f.actual_date_key = d.date_key
    JOIN dim_channel dc ON o.channel_key = dc.channel_key
    """
    df = load_query(db_path, query)
    df["actual_date"] = pd.to_datetime(df["actual_date"]).dt.date
    return df


@st.cache_data
def load_quality_issues(db_path: str) -> pd.DataFrame:
    query = """
    SELECT layer_name, issue_code, severity, issue_message, created_at
    FROM data_quality_issue
    ORDER BY created_at DESC
    LIMIT 200
    """
    return load_query(db_path, query)


@st.cache_data
def load_batch_info(db_path: str) -> pd.DataFrame:
    query = """
    SELECT batch_id, run_mode, status, started_at, completed_at
    FROM etl_load_batch
    ORDER BY started_at DESC
    LIMIT 1
    """
    return load_query(db_path, query)


@st.cache_data
def load_fact_counts(db_path: str) -> pd.DataFrame:
    query = """
    SELECT 'fact_sales' AS table_name, COUNT(*) AS row_count FROM fact_sales
    UNION ALL
    SELECT 'fact_online_orders', COUNT(*) FROM fact_online_orders
    UNION ALL
    SELECT 'fact_delivery_performance', COUNT(*) FROM fact_delivery_performance
    UNION ALL
    SELECT 'fact_inventory_daily', COUNT(*) FROM fact_inventory_daily
    UNION ALL
    SELECT 'fact_procurement', COUNT(*) FROM fact_procurement
    """
    return load_query(db_path, query)


def format_currency(value):
    return f"AUD {value:,.0f}" if pd.notna(value) else "AUD 0"


def format_percentage(value):
    return f"{value:.1f}%" if pd.notna(value) else "0.0%"


def filter_sales(df: pd.DataFrame, start_date: date, end_date: date, region, categories, channels):
    filtered = df[(df["full_date"] >= start_date) & (df["full_date"] <= end_date)]
    if region and region != "Semua":
        filtered = filtered[filtered["region"] == region]
    if categories:
        filtered = filtered[filtered["category"].isin(categories)]
    if channels:
        filtered = filtered[filtered["channel_name"].isin(channels)]
    return filtered


def main():
    st.sidebar.title("Filter Visualisasi")
    st.sidebar.markdown(
        "Gunakan filter ini untuk menjelajahi hasil ETL warehouse dan melihat tren penjualan, kinerja pengiriman, dan kualitas data."
    )

    db_path = st.sidebar.text_input("Path database warehouse", str(DEFAULT_DB_PATH))
    if not Path(db_path).exists():
        st.sidebar.error("Database tidak ditemukan. Jalankan `python run_project.py` terlebih dahulu.")
        st.stop()

    sales = load_sales(db_path)
    delivery = load_delivery_performance(db_path)
    quality_issues = load_quality_issues(db_path)
    batch_info = load_batch_info(db_path)
    fact_counts = load_fact_counts(db_path)

    min_date = sales["full_date"].min()
    max_date = sales["full_date"].max()
    date_range = st.sidebar.date_input(
        "Rentang tanggal",
        [min_date, max_date],
        min_value=min_date,
        max_value=max_date,
    )
    if isinstance(date_range, (list, tuple)) and len(date_range) == 2:
        start_date, end_date = date_range
        if start_date > end_date:
            start_date, end_date = end_date, start_date
    elif isinstance(date_range, (list, tuple)) and len(date_range) == 1:
        st.sidebar.warning("Pilih tanggal akhir untuk menerapkan rentang tanggal.")
        st.stop()
    else:
        start_date = min_date
        end_date = max_date

    if start_date < min_date or end_date > max_date:
        st.sidebar.error(
            f"Rentang tanggal harus berada antara {min_date.isoformat()} dan {max_date.isoformat()}."
        )
        st.stop()

    regions = ["Semua"] + sorted(sales["region"].fillna("Unknown").unique().tolist())
    selected_region = st.sidebar.selectbox("Region", regions)

    categories = sorted(sales["category"].fillna("Unknown").unique().tolist())
    selected_categories = st.sidebar.multiselect("Kategori produk", categories, default=categories[:3])

    channels = sorted(sales["channel_name"].fillna("Unknown").unique().tolist())
    selected_channels = st.sidebar.multiselect("Channel", channels, default=channels)

    filtered_sales = filter_sales(sales, start_date, end_date, selected_region, selected_categories, selected_channels)
    filtered_delivery = delivery[(delivery["actual_date"] >= start_date) & (delivery["actual_date"] <= end_date)]
    if selected_channels:
        filtered_delivery = filtered_delivery[filtered_delivery["channel_name"].isin(selected_channels)]

    st.title("Coles Warehouse Streamlit Dashboard")
    st.markdown(
        "Visualisasi ini menggunakan hasil ETL dari `output/coles_warehouse_dw.sqlite` untuk menampilkan metrik penjualan, pengiriman, dan kualitas data."
    )

    if batch_info.empty:
        st.warning("Tidak ada informasi batch ETL. Pastikan `run_project.py` telah dijalankan.")
    else:
        batch = batch_info.iloc[0]
        st.write(
            f"**Batch ETL terakhir:** {batch['batch_id']} | Mode: {batch['run_mode']} | Status: {batch['status']}"
        )
        st.write(
            f"Mulai: {batch['started_at']} | Selesai: {batch['completed_at'] or 'Belum tersedia'}"
        )

    if filtered_sales.empty:
        st.warning("Tidak ada data penjualan untuk filter yang dipilih.")
        st.stop()

    total_net_sales = filtered_sales["net_sales"].sum()
    total_gross_profit = filtered_sales["gross_profit"].sum()
    gross_margin_pct = (
    total_gross_profit / total_net_sales * 100
    if total_net_sales
    else 0
    )
    total_discount = filtered_sales["discount_amount"].sum()
    channel_placeholders = ",".join("?" for _ in selected_channels)
    order_value = load_query(
        db_path,
        f"""
        SELECT ROUND(SUM(foo.total_order_value), 2) AS total_order_value
        FROM fact_online_orders foo
        JOIN dim_date d ON foo.order_date_key = d.date_key
        JOIN dim_channel dc ON foo.channel_key = dc.channel_key
        WHERE d.full_date BETWEEN ? AND ?
          AND dc.channel_name IN ({channel_placeholders})
        """,
        (str(start_date), str(end_date), *selected_channels),
    ).iloc[0, 0]

    col1, col2, col3, col4, col5 = st.columns(5)
    col1.metric("Net Sales", format_currency(total_net_sales))
    col2.metric("Gross Profit", format_currency(total_gross_profit))
    col3.metric("Gross Margin %", f"{gross_margin_pct:.1f}%")
    col4.metric("Online Order Value", format_currency(order_value))
    col5.metric("Total Diskon", format_currency(total_discount))

    st.markdown("---")

    sales_by_month = (
        filtered_sales.groupby("year_month", sort=False)["net_sales"].sum().reset_index()
    )
    top_regions = (
        filtered_sales.groupby("region")["net_sales"].sum().sort_values(ascending=False).reset_index()
    )
    top_categories = (
        filtered_sales.groupby("category")["net_sales"].sum().sort_values(ascending=False).head(10).reset_index()
    )
    top_products = (
        filtered_sales.groupby("product_name")["net_sales"].sum().sort_values(ascending=False).head(10).reset_index()
    )

    st.subheader("Tren Penjualan")
    st.line_chart(sales_by_month.rename(columns={"year_month": "Bulan", "net_sales": "Net Sales"}).set_index("Bulan"))

    st.subheader("Ringkasan Kinerja")
    c1, c2 = st.columns(2)
    with c1:
        st.bar_chart(top_regions.rename(columns={"region": "Region", "net_sales": "Net Sales"}).set_index("Region"))
    with c2:
        st.bar_chart(top_categories.rename(columns={"category": "Kategori", "net_sales": "Net Sales"}).set_index("Kategori"))

    st.subheader("Top 10 Produk berdasarkan Net Sales")
    st.bar_chart(top_products.rename(columns={"product_name": "Produk", "net_sales": "Net Sales"}).set_index("Produk"))

    st.markdown("---")
    st.subheader("Kinerja Pengiriman")
    if filtered_delivery.empty:
        st.info("Tidak ada data pengiriman di rentang tanggal yang dipilih.")
    else:
        delivery_status = (
            filtered_delivery.groupby("delivery_status")["delivery_status"].count().rename("delivery_count").reset_index()
        )
        delivery_performance = (
            filtered_delivery.groupby("delivery_status")["on_time_flag"].mean().mul(100).round(1).reset_index()
        )
        d1, d2 = st.columns(2)
        with d1:
            st.bar_chart(delivery_status.rename(columns={"delivery_status": "Status", "delivery_count": "Jumlah"}).set_index("Status"))
        with d2:
            st.bar_chart(delivery_performance.rename(columns={"delivery_status": "Status", "on_time_flag": "On-Time %"}).set_index("Status"))

    st.subheader("Data Quality / Kualitas Data")
    if quality_issues.empty:
        st.success("Tidak ada masalah kualitas data yang tercatat.")
    else:
        st.write(quality_issues)

    st.markdown("---")
    st.subheader("Jumlah Baris Faktual")
    st.table(fact_counts.set_index("table_name"))

    st.caption("Dashboard ini dibangun dari hasil ETL pada database warehouse lokal dan bisa dikustomisasi lebih lanjut.")


if __name__ == "__main__":
    main()
