-- File ini membuat view OLAP/reporting untuk Power BI atau analisis SQL langsung.
-- Jalankan script ini ke output/coles_warehouse_dw.sqlite setelah ETL selesai.

-- Menghapus view lama agar definisi view selalu mengikuti versi terbaru script ini.
DROP VIEW IF EXISTS vw_cube_sales;
DROP VIEW IF EXISTS vw_cube_online_orders;
DROP VIEW IF EXISTS vw_cube_inventory;
DROP VIEW IF EXISTS vw_cube_delivery;
DROP VIEW IF EXISTS vw_cube_procurement;

-- View sales: menggabungkan fact_sales dengan dimensi tanggal, toko, produk,
-- customer, promosi, payment method, dan channel untuk analisis penjualan.
CREATE VIEW vw_cube_sales AS
SELECT
    fs.sales_key,
    fs.transaction_id,
    dd.full_date,
    dd.year,
    dd.quarter,
    dd.quarter_name,
    dd.month,
    dd.month_name,
    dd.year_month,
    dd.week_number,
    dd.is_weekend,
    dd.fiscal_year,
    dd.fiscal_quarter,
    ds.store_id,
    ds.store_name,
    ds.store_type,
    ds.city AS store_city,
    ds.state AS store_state,
    ds.region,
    dp.product_id,
    dp.product_name,
    dp.brand,
    dp.category,
    dp.subcategory,
    dc.customer_id,
    dc.gender,
    dc.age_group,
    dc.membership_type,
    dpr.promotion_type,
    dpm.payment_type,
    dch.channel_name,
    dch.channel_group,
    fs.quantity_sold,
    fs.total_sales_amount,
    fs.discount_amount,
    fs.net_sales,
    fs.sales_cost,
    fs.gross_profit,
    fs.gross_margin_pct,
    fs.discount_pct,
    fs.currency
FROM fact_sales fs
JOIN dim_date dd ON dd.date_key = fs.date_key
JOIN dim_store ds ON ds.store_key = fs.store_key
JOIN dim_product dp ON dp.product_key = fs.product_key
JOIN dim_customer dc ON dc.customer_key = fs.customer_key
LEFT JOIN dim_promotion dpr ON dpr.promotion_key = fs.promotion_key
JOIN dim_payment_method dpm ON dpm.payment_method_key = fs.payment_method_key
JOIN dim_channel dch ON dch.channel_key = fs.channel_key;

-- View online orders: menggabungkan order online dengan customer,
-- fulfilment center, channel, dan tanggal order.
CREATE VIEW vw_cube_online_orders AS
SELECT
    foo.online_order_key,
    foo.online_order_id,
    dd.full_date,
    dd.year,
    dd.quarter,
    dd.quarter_name,
    dd.month,
    dd.month_name,
    dd.year_month,
    dd.week_number,
    dd.is_weekend,
    dc.customer_id,
    dc.gender,
    dc.age_group,
    dc.membership_type,
    dfc.fulfilment_center_id,
    dfc.fulfilment_center_name,
    dfc.city AS fulfilment_city,
    dfc.state AS fulfilment_state,
    dch.channel_name,
    dch.channel_group,
    foo.item_count,
    foo.order_value,
    foo.delivery_fee,
    foo.total_order_value,
    foo.order_status,
    foo.fulfilled_flag
FROM fact_online_orders foo
JOIN dim_date dd ON dd.date_key = foo.order_date_key
JOIN dim_customer dc ON dc.customer_key = foo.customer_key
JOIN dim_fulfilment_center dfc ON dfc.fulfilment_center_key = foo.fulfilment_center_key
JOIN dim_channel dch ON dch.channel_key = foo.channel_key;

-- View inventory: menggabungkan stok harian dengan tanggal, toko, dan produk.
-- Cocok untuk analisis stock movement, variance, dan shrinkage.
CREATE VIEW vw_cube_inventory AS
SELECT
    fid.inventory_key,
    fid.inventory_record_id,
    dd.full_date,
    dd.year,
    dd.quarter,
    dd.quarter_name,
    dd.month,
    dd.month_name,
    dd.year_month,
    dd.week_number,
    ds.store_id,
    ds.store_name,
    ds.city AS store_city,
    ds.state AS store_state,
    ds.region,
    dp.product_id,
    dp.product_name,
    dp.category,
    dp.subcategory,
    fid.opening_stock,
    fid.stock_in,
    fid.stock_out,
    fid.stock_loss,
    fid.closing_stock,
    fid.calculated_closing_stock,
    fid.stock_variance,
    fid.stock_variance_abs,
    fid.shrinkage_rate
FROM fact_inventory_daily fid
JOIN dim_date dd ON dd.date_key = fid.snapshot_date_key
JOIN dim_store ds ON ds.store_key = fid.store_key
JOIN dim_product dp ON dp.product_key = fid.product_key;

-- View delivery: menggabungkan performa pengiriman dengan online order,
-- tanggal promised/actual, channel, dan fulfilment center.
CREATE VIEW vw_cube_delivery AS
SELECT
    fdp.delivery_key,
    fdp.delivery_id,
    foo.online_order_id,
    promised.full_date AS promised_delivery_date,
    actual.full_date AS actual_delivery_date,
    actual.year,
    actual.quarter,
    actual.quarter_name,
    actual.month,
    actual.month_name,
    actual.year_month,
    fdp.delivery_partner,
    fdp.delivery_status,
    fdp.delivery_time_minutes,
    fdp.delay_minutes,
    fdp.delay_hours,
    fdp.on_time_flag,
    fdp.order_accuracy_flag,
    dch.channel_name,
    dfc.fulfilment_center_name,
    dfc.state AS fulfilment_state
FROM fact_delivery_performance fdp
JOIN fact_online_orders foo ON foo.online_order_key = fdp.online_order_key
JOIN dim_date promised ON promised.date_key = fdp.promised_date_key
JOIN dim_date actual ON actual.date_key = fdp.actual_date_key
JOIN dim_channel dch ON dch.channel_key = foo.channel_key
JOIN dim_fulfilment_center dfc ON dfc.fulfilment_center_key = foo.fulfilment_center_key;

-- View procurement: menggabungkan purchase order dengan tanggal,
-- supplier, distribution center, dan produk.
CREATE VIEW vw_cube_procurement AS
SELECT
    fp.procurement_key,
    fp.purchase_order_id,
    dd.full_date AS purchase_order_date,
    dd.year,
    dd.quarter,
    dd.quarter_name,
    dd.month,
    dd.month_name,
    dd.year_month,
    ds.supplier_id,
    ds.supplier_name,
    ds.supplier_type,
    ddc.distribution_center_id,
    ddc.distribution_center_name,
    ddc.state AS distribution_state,
    dp.product_id,
    dp.product_name,
    dp.category,
    fp.ordered_qty,
    fp.received_qty,
    fp.fill_rate,
    fp.purchase_amount,
    fp.late_delivery_flag,
    fp.receipt_delay_days,
    fp.po_status
FROM fact_procurement fp
JOIN dim_date dd ON dd.date_key = fp.purchase_order_date_key
JOIN dim_supplier ds ON ds.supplier_key = fp.supplier_key
JOIN dim_distribution_center ddc ON ddc.distribution_center_key = fp.distribution_center_key
JOIN dim_product dp ON dp.product_key = fp.product_key;
