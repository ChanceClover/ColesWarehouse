import sqlite3
from datetime import date
from pathlib import Path

import pandas as pd
import streamlit as st


ROOT = Path(__file__).resolve().parent
DEFAULT_DB_PATH = ROOT / "output" / "coles_warehouse_dw.sqlite"

st.set_page_config(
    page_title="Coles Omnichannel Warehouse Dashboard",
    layout="wide",
    initial_sidebar_state="expanded",
)


@st.cache_data
def load_query(db_path: str, query: str) -> pd.DataFrame:
    conn = sqlite3.connect(db_path)
    try:
        return pd.read_sql_query(query, conn)
    finally:
        conn.close()


@st.cache_data
def load_sales(db_path: str) -> pd.DataFrame:
    query = """
    SELECT
        fs.transaction_id,
        fs.net_sales,
        fs.gross_profit,
        fs.discount_amount,
        fs.quantity_sold,
        dd.full_date,
        dd.year,
        dd.month,
        dd.month_name,
        dd.year_month,
        ds.region,
        ds.store_name,
        ds.store_type,
        dp.category,
        dp.subcategory,
        dp.product_name,
        dcust.customer_id,
        dcust.membership_type,
        dcust.age_group,
        dch.channel_name,
        dch.channel_group
    FROM fact_sales fs
    JOIN dim_date dd ON dd.date_key = fs.date_key
    JOIN dim_store ds ON ds.store_key = fs.store_key
    JOIN dim_product dp ON dp.product_key = fs.product_key
    JOIN dim_customer dcust ON dcust.customer_key = fs.customer_key
    JOIN dim_channel dch ON dch.channel_key = fs.channel_key
    """
    df = load_query(db_path, query)
    df["full_date"] = pd.to_datetime(df["full_date"]).dt.date
    df["channel_type"] = df.apply(channel_type, axis=1)
    return df


@st.cache_data
def load_online_orders(db_path: str) -> pd.DataFrame:
    query = """
    SELECT
        foo.online_order_id,
        foo.total_order_value,
        foo.order_value,
        foo.delivery_fee,
        foo.order_status,
        foo.fulfilled_flag,
        dd.full_date,
        dd.year_month,
        dcust.membership_type,
        dcust.age_group,
        dch.channel_name,
        dch.channel_group,
        dfc.fulfilment_center_name,
        dfc.city AS fulfilment_city,
        dfc.state AS fulfilment_state
    FROM fact_online_orders foo
    JOIN dim_date dd ON dd.date_key = foo.order_date_key
    JOIN dim_customer dcust ON dcust.customer_key = foo.customer_key
    JOIN dim_channel dch ON dch.channel_key = foo.channel_key
    JOIN dim_fulfilment_center dfc ON dfc.fulfilment_center_key = foo.fulfilment_center_key
    """
    df = load_query(db_path, query)
    df["full_date"] = pd.to_datetime(df["full_date"]).dt.date
    df["channel_type"] = df.apply(channel_type, axis=1)
    return df


@st.cache_data
def load_delivery(db_path: str) -> pd.DataFrame:
    query = """
    SELECT
        fdp.delivery_id,
        fdp.delivery_partner,
        fdp.delivery_status,
        fdp.delivery_time_minutes,
        fdp.delay_minutes,
        fdp.delay_hours,
        fdp.on_time_flag,
        fdp.order_accuracy_flag,
        actual.full_date AS actual_date,
        dch.channel_name,
        dch.channel_group,
        dfc.fulfilment_center_name,
        dfc.city AS fulfilment_city,
        dfc.state AS fulfilment_state
    FROM fact_delivery_performance fdp
    JOIN fact_online_orders foo ON foo.online_order_key = fdp.online_order_key
    JOIN dim_date actual ON actual.date_key = fdp.actual_date_key
    JOIN dim_channel dch ON dch.channel_key = foo.channel_key
    JOIN dim_fulfilment_center dfc ON dfc.fulfilment_center_key = foo.fulfilment_center_key
    """
    df = load_query(db_path, query)
    df["actual_date"] = pd.to_datetime(df["actual_date"]).dt.date
    df["channel_type"] = df.apply(channel_type, axis=1)
    return df


@st.cache_data
def load_inventory(db_path: str) -> pd.DataFrame:
    query = """
    SELECT
        fid.inventory_record_id,
        fid.closing_stock,
        fid.stock_variance,
        fid.stock_variance_abs,
        fid.shrinkage_rate,
        dd.full_date,
        dd.year_month,
        ds.region,
        ds.store_name,
        dp.category,
        dp.subcategory,
        dp.product_name
    FROM fact_inventory_daily fid
    JOIN dim_date dd ON dd.date_key = fid.snapshot_date_key
    JOIN dim_store ds ON ds.store_key = fid.store_key
    JOIN dim_product dp ON dp.product_key = fid.product_key
    """
    df = load_query(db_path, query)
    df["full_date"] = pd.to_datetime(df["full_date"]).dt.date
    return df


@st.cache_data
def load_batch_info(db_path: str) -> pd.DataFrame:
    query = """
    SELECT batch_id, run_mode, status, started_at, completed_at
    FROM etl_load_batch
    ORDER BY started_at DESC
    LIMIT 1
    """
    return load_query(db_path, query)


def channel_type(row: pd.Series) -> str:
    channel_group = str(row.get("channel_group", "")).lower()
    channel_name = str(row.get("channel_name", "")).lower()
    if (
        "online" in channel_group
        or "ecommerce" in channel_name
        or "mobile" in channel_name
        or "delivery" in channel_name
        or "click" in channel_name
    ):
        return "Digital / Online"
    return "Store / Offline"


def format_currency(value) -> str:
    return f"AUD {float(value):,.0f}" if pd.notna(value) else "AUD 0"


def format_percent(value) -> str:
    return f"{float(value):.1f}%" if pd.notna(value) else "0.0%"


def apply_common_filters(
    sales: pd.DataFrame,
    online: pd.DataFrame,
    delivery: pd.DataFrame,
    inventory: pd.DataFrame,
    start_date: date,
    end_date: date,
    channels: list[str],
    regions: list[str],
    categories: list[str],
    memberships: list[str],
):
    sales_f = sales[(sales["full_date"] >= start_date) & (sales["full_date"] <= end_date)]
    online_f = online[(online["full_date"] >= start_date) & (online["full_date"] <= end_date)]
    delivery_f = delivery[(delivery["actual_date"] >= start_date) & (delivery["actual_date"] <= end_date)]
    inventory_f = inventory[(inventory["full_date"] >= start_date) & (inventory["full_date"] <= end_date)]

    if channels:
        sales_f = sales_f[sales_f["channel_name"].isin(channels)]
        online_f = online_f[online_f["channel_name"].isin(channels)]
        delivery_f = delivery_f[delivery_f["channel_name"].isin(channels)]
    if regions:
        sales_f = sales_f[sales_f["region"].isin(regions)]
        inventory_f = inventory_f[inventory_f["region"].isin(regions)]
    if categories:
        sales_f = sales_f[sales_f["category"].isin(categories)]
        inventory_f = inventory_f[inventory_f["category"].isin(categories)]
    if memberships:
        sales_f = sales_f[sales_f["membership_type"].isin(memberships)]
        online_f = online_f[online_f["membership_type"].isin(memberships)]

    return sales_f, online_f, delivery_f, inventory_f


def metric_row(sales: pd.DataFrame, online: pd.DataFrame, delivery: pd.DataFrame, inventory: pd.DataFrame):
    net_sales = sales["net_sales"].sum()
    gross_profit = sales["gross_profit"].sum()
    gross_margin = gross_profit / net_sales * 100 if net_sales else 0
    online_value = online["total_order_value"].sum()
    fulfilment_rate = online["fulfilled_flag"].mean() * 100 if not online.empty else 0
    on_time = delivery["on_time_flag"].mean() * 100 if not delivery.empty else 0
    shrinkage = inventory["shrinkage_rate"].mean() * 100 if not inventory.empty else 0

    cols = st.columns(7)
    cols[0].metric("Net Sales", format_currency(net_sales))
    cols[1].metric("Gross Margin", format_percent(gross_margin))
    cols[2].metric("Transactions", f"{sales['transaction_id'].nunique():,}")
    cols[3].metric("Online Order Value", format_currency(online_value))
    cols[4].metric("Fulfilment Rate", format_percent(fulfilment_rate))
    cols[5].metric("On-Time Delivery", format_percent(on_time))
    cols[6].metric("Inventory Shrinkage", format_percent(shrinkage))


def chart_bar(df: pd.DataFrame, index_col: str, value_col: str):
    if df.empty:
        st.info("Tidak ada data untuk filter yang dipilih.")
    else:
        st.bar_chart(df.set_index(index_col)[value_col])


def page_overview(sales: pd.DataFrame, online: pd.DataFrame, delivery: pd.DataFrame, inventory: pd.DataFrame):
    st.header("Omnichannel Executive Overview")
    metric_row(sales, online, delivery, inventory)

    st.divider()
    left, right = st.columns([1.2, 1])

    with left:
        st.subheader("Monthly Sales Trend")
        monthly = (
            sales.groupby("year_month", as_index=False)
            .agg(net_sales=("net_sales", "sum"), gross_profit=("gross_profit", "sum"))
            .sort_values("year_month")
        )
        if monthly.empty:
            st.info("Tidak ada data sales.")
        else:
            st.line_chart(monthly.set_index("year_month")[["net_sales", "gross_profit"]])

    with right:
        st.subheader("Online vs Store Contribution")
        contribution = (
            sales.groupby("channel_type", as_index=False)
            .agg(net_sales=("net_sales", "sum"), transactions=("transaction_id", "nunique"))
            .sort_values("net_sales", ascending=False)
        )
        chart_bar(contribution, "channel_type", "net_sales")
        st.dataframe(contribution, hide_index=True, use_container_width=True)

    col1, col2 = st.columns(2)
    with col1:
        st.subheader("Sales by Channel")
        by_channel = (
            sales.groupby("channel_name", as_index=False)
            .agg(net_sales=("net_sales", "sum"), gross_profit=("gross_profit", "sum"))
            .sort_values("net_sales", ascending=False)
        )
        chart_bar(by_channel, "channel_name", "net_sales")
    with col2:
        st.subheader("Channel x Product Category")
        channel_category = (
            sales.groupby(["channel_name", "category"], as_index=False)
            .agg(net_sales=("net_sales", "sum"))
            .sort_values("net_sales", ascending=False)
            .head(15)
        )
        st.dataframe(channel_category, hide_index=True, use_container_width=True)


def page_customer_channel(sales: pd.DataFrame):
    st.header("Customer & Channel Behavior")

    net_sales = sales["net_sales"].sum()
    avg_transaction = sales["net_sales"].mean() if not sales.empty else 0
    top_channel = (
        sales.groupby("channel_name")["net_sales"].sum().sort_values(ascending=False).index[0]
        if not sales.empty
        else "-"
    )
    top_segment = (
        sales.groupby("membership_type")["net_sales"].sum().sort_values(ascending=False).index[0]
        if not sales.empty
        else "-"
    )

    cols = st.columns(4)
    cols[0].metric("Customer Count", f"{sales['customer_id'].nunique():,}")
    cols[1].metric("Avg Transaction Value", format_currency(avg_transaction))
    cols[2].metric("Top Channel", top_channel)
    cols[3].metric("Top Membership", top_segment)

    st.divider()
    col1, col2 = st.columns(2)
    with col1:
        st.subheader("Customer Segment by Channel")
        segment = (
            sales.groupby(["channel_name", "membership_type", "age_group"], as_index=False)
            .agg(customers=("customer_id", "nunique"), net_sales=("net_sales", "sum"))
            .sort_values(["channel_name", "net_sales"], ascending=[True, False])
        )
        st.dataframe(segment, hide_index=True, use_container_width=True)
    with col2:
        st.subheader("Net Sales by Membership")
        by_membership = (
            sales.groupby("membership_type", as_index=False)
            .agg(net_sales=("net_sales", "sum"))
            .sort_values("net_sales", ascending=False)
        )
        chart_bar(by_membership, "membership_type", "net_sales")

    col3, col4 = st.columns(2)
    with col3:
        st.subheader("Transactions by Age Group")
        by_age = (
            sales.groupby("age_group", as_index=False)
            .agg(transactions=("transaction_id", "nunique"))
            .sort_values("transactions", ascending=False)
        )
        chart_bar(by_age, "age_group", "transactions")
    with col4:
        st.subheader("Channel by Membership")
        pivot = pd.pivot_table(
            sales,
            values="net_sales",
            index="channel_name",
            columns="membership_type",
            aggfunc="sum",
            fill_value=0,
        )
        if pivot.empty:
            st.info("Tidak ada data customer/channel.")
        else:
            st.bar_chart(pivot)


def page_fulfilment_inventory(online: pd.DataFrame, delivery: pd.DataFrame, inventory: pd.DataFrame):
    st.header("Fulfilment & Inventory Support")

    cols = st.columns(5)
    cols[0].metric("Online Orders", f"{len(online):,}")
    cols[1].metric("Online Order Value", format_currency(online["total_order_value"].sum()))
    cols[2].metric("Fulfilment Rate", format_percent(online["fulfilled_flag"].mean() * 100 if not online.empty else 0))
    cols[3].metric("On-Time Delivery", format_percent(delivery["on_time_flag"].mean() * 100 if not delivery.empty else 0))
    cols[4].metric("Avg Delay Hours", f"{delivery['delay_hours'].mean():.2f}" if not delivery.empty else "0.00")

    st.divider()
    col1, col2 = st.columns(2)
    with col1:
        st.subheader("Online Order Fulfilment")
        by_status = (
            online.groupby("order_status", as_index=False)
            .agg(orders=("online_order_id", "count"), total_order_value=("total_order_value", "sum"))
            .sort_values("total_order_value", ascending=False)
        )
        chart_bar(by_status, "order_status", "total_order_value")
    with col2:
        st.subheader("Delivery Performance by Partner")
        by_partner = (
            delivery.groupby("delivery_partner", as_index=False)
            .agg(
                deliveries=("delivery_id", "count"),
                on_time_delivery_pct=("on_time_flag", lambda x: round(x.mean() * 100, 2)),
                avg_delay_hours=("delay_hours", "mean"),
            )
            .sort_values("on_time_delivery_pct", ascending=False)
        )
        chart_bar(by_partner, "delivery_partner", "on_time_delivery_pct")
        st.dataframe(by_partner, hide_index=True, use_container_width=True)

    col3, col4 = st.columns(2)
    with col3:
        st.subheader("Delivery by Fulfilment Center")
        by_center = (
            delivery.groupby("fulfilment_center_name", as_index=False)
            .agg(
                deliveries=("delivery_id", "count"),
                on_time_delivery_pct=("on_time_flag", lambda x: round(x.mean() * 100, 2)),
                avg_delay_hours=("delay_hours", "mean"),
            )
            .sort_values("on_time_delivery_pct", ascending=False)
        )
        chart_bar(by_center, "fulfilment_center_name", "on_time_delivery_pct")
    with col4:
        st.subheader("Inventory Support by Store & Category")
        inv = (
            inventory.groupby(["region", "store_name", "category"], as_index=False)
            .agg(
                total_closing_stock=("closing_stock", "sum"),
                total_abs_stock_variance=("stock_variance_abs", "sum"),
                avg_shrinkage_pct=("shrinkage_rate", lambda x: round(x.mean() * 100, 2)),
            )
            .sort_values("total_abs_stock_variance", ascending=False)
            .head(20)
        )
        st.dataframe(inv, hide_index=True, use_container_width=True)


def main():
    st.sidebar.title("Omnichannel Dashboard")
    db_path = st.sidebar.text_input("Path database warehouse", str(DEFAULT_DB_PATH))
    if not Path(db_path).exists():
        st.sidebar.error("Database tidak ditemukan. Jalankan ETL terlebih dahulu.")
        st.stop()

    sales = load_sales(db_path)
    online = load_online_orders(db_path)
    delivery = load_delivery(db_path)
    inventory = load_inventory(db_path)
    batch_info = load_batch_info(db_path)

    min_date = min(sales["full_date"].min(), online["full_date"].min(), inventory["full_date"].min())
    max_date = max(sales["full_date"].max(), online["full_date"].max(), inventory["full_date"].max())
    selected_range = st.sidebar.date_input(
        "Rentang tanggal",
        [min_date, max_date],
        min_value=min_date,
        max_value=max_date,
    )
    if isinstance(selected_range, (list, tuple)) and len(selected_range) == 2:
        start_date, end_date = selected_range
        if start_date > end_date:
            start_date, end_date = end_date, start_date
    else:
        st.sidebar.warning("Pilih tanggal awal dan akhir.")
        st.stop()

    channels = sorted(sales["channel_name"].dropna().unique().tolist())
    regions = sorted(sales["region"].dropna().unique().tolist())
    categories = sorted(sales["category"].dropna().unique().tolist())
    memberships = sorted(sales["membership_type"].dropna().unique().tolist())

    selected_channels = st.sidebar.multiselect("Channel", channels, default=channels)
    selected_regions = st.sidebar.multiselect("Region", regions, default=regions)
    selected_categories = st.sidebar.multiselect("Kategori produk", categories, default=categories)
    selected_memberships = st.sidebar.multiselect("Membership", memberships, default=memberships)

    page = st.sidebar.radio(
        "Halaman dashboard",
        [
            "1. Omnichannel Executive Overview",
            "2. Customer & Channel Behavior",
            "3. Fulfilment & Inventory Support",
        ],
    )

    sales_f, online_f, delivery_f, inventory_f = apply_common_filters(
        sales,
        online,
        delivery,
        inventory,
        start_date,
        end_date,
        selected_channels,
        selected_regions,
        selected_categories,
        selected_memberships,
    )

    st.title("Coles Omnichannel Data Warehouse Dashboard")
    if not batch_info.empty:
        batch = batch_info.iloc[0]
        st.caption(
            f"Batch ETL: {batch['batch_id']} | Mode: {batch['run_mode']} | Status: {batch['status']}"
        )

    if page.startswith("1."):
        page_overview(sales_f, online_f, delivery_f, inventory_f)
    elif page.startswith("2."):
        page_customer_channel(sales_f)
    else:
        page_fulfilment_inventory(online_f, delivery_f, inventory_f)


if __name__ == "__main__":
    main()
