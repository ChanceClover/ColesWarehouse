-- File ini berisi query analitik final yang benar-benar dipakai untuk dashboard omnichannel.
-- Fokus dashboard: performa channel, kontribusi online vs store, customer segment,
-- fulfilment/delivery, dan dukungan inventory.

-- 1. Executive KPI summary.
-- Ringkasan angka utama untuk halaman pembuka dashboard.
SELECT
    ROUND(SUM(fs.net_sales), 2) AS total_net_sales,
    ROUND(SUM(fs.gross_profit), 2) AS total_gross_profit,
    ROUND(SUM(fs.gross_profit) / NULLIF(SUM(fs.net_sales), 0) * 100, 2) AS gross_margin_pct,
    COUNT(DISTINCT fs.transaction_id) AS total_sales_transactions,
    (SELECT COUNT(*) FROM fact_online_orders) AS total_online_orders,
    (SELECT ROUND(SUM(total_order_value), 2) FROM fact_online_orders) AS total_online_order_value,
    (SELECT ROUND(AVG(fulfilled_flag) * 100, 2) FROM fact_online_orders) AS fulfilment_rate_pct,
    (SELECT ROUND(AVG(on_time_flag) * 100, 2) FROM fact_delivery_performance) AS on_time_delivery_pct,
    (SELECT ROUND(AVG(shrinkage_rate) * 100, 2) FROM fact_inventory_daily) AS avg_inventory_shrinkage_pct
FROM fact_sales fs;

-- 2. Monthly sales trend.
-- Dipakai untuk line chart tren net sales dan gross margin dari waktu ke waktu.
SELECT
    dd.year,
    dd.month,
    dd.month_name,
    dd.year_month,
    ROUND(SUM(fs.net_sales), 2) AS net_sales,
    ROUND(SUM(fs.gross_profit), 2) AS gross_profit,
    ROUND(SUM(fs.gross_profit) / NULLIF(SUM(fs.net_sales), 0) * 100, 2) AS gross_margin_pct,
    COUNT(DISTINCT fs.transaction_id) AS transactions
FROM fact_sales fs
JOIN dim_date dd ON dd.date_key = fs.date_key
GROUP BY dd.year, dd.month, dd.month_name, dd.year_month
ORDER BY dd.year, dd.month;

-- 3. Sales by channel.
-- Dipakai untuk melihat kontribusi penjualan dari store, eCommerce, mobile app, dan channel lain.
SELECT
    dc.channel_name,
    dc.channel_group,
    COUNT(DISTINCT fs.transaction_id) AS transactions,
    ROUND(SUM(fs.net_sales), 2) AS net_sales,
    ROUND(SUM(fs.gross_profit), 2) AS gross_profit,
    ROUND(SUM(fs.discount_amount), 2) AS discount_amount
FROM fact_sales fs
JOIN dim_channel dc ON dc.channel_key = fs.channel_key
GROUP BY dc.channel_name, dc.channel_group
ORDER BY net_sales DESC;

-- 4. Online vs store contribution.
-- Dipakai untuk membandingkan kontribusi channel fisik dan digital/online.
SELECT
    CASE
        WHEN LOWER(dc.channel_group) LIKE '%online%'
          OR LOWER(dc.channel_name) LIKE '%ecommerce%'
          OR LOWER(dc.channel_name) LIKE '%mobile%'
          OR LOWER(dc.channel_name) LIKE '%delivery%'
          OR LOWER(dc.channel_name) LIKE '%click%'
        THEN 'Digital / Online'
        ELSE 'Store / Offline'
    END AS channel_type,
    COUNT(DISTINCT fs.transaction_id) AS transactions,
    ROUND(SUM(fs.net_sales), 2) AS net_sales,
    ROUND(SUM(fs.gross_profit), 2) AS gross_profit,
    ROUND(SUM(fs.net_sales) * 100.0 / NULLIF((SELECT SUM(net_sales) FROM fact_sales), 0), 2) AS sales_contribution_pct
FROM fact_sales fs
JOIN dim_channel dc ON dc.channel_key = fs.channel_key
GROUP BY
    CASE
        WHEN LOWER(dc.channel_group) LIKE '%online%'
          OR LOWER(dc.channel_name) LIKE '%ecommerce%'
          OR LOWER(dc.channel_name) LIKE '%mobile%'
          OR LOWER(dc.channel_name) LIKE '%delivery%'
          OR LOWER(dc.channel_name) LIKE '%click%'
        THEN 'Digital / Online'
        ELSE 'Store / Offline'
    END
ORDER BY net_sales DESC;

-- 5. Channel by product category.
-- Dipakai untuk melihat kategori produk mana yang paling kuat di setiap channel.
SELECT
    dc.channel_name,
    dc.channel_group,
    dp.category,
    COUNT(DISTINCT fs.transaction_id) AS transactions,
    SUM(fs.quantity_sold) AS quantity_sold,
    ROUND(SUM(fs.net_sales), 2) AS net_sales,
    ROUND(SUM(fs.gross_profit), 2) AS gross_profit
FROM fact_sales fs
JOIN dim_channel dc ON dc.channel_key = fs.channel_key
JOIN dim_product dp ON dp.product_key = fs.product_key
GROUP BY dc.channel_name, dc.channel_group, dp.category
ORDER BY dc.channel_name, net_sales DESC;

-- 6. Customer segment by channel.
-- Dipakai untuk mengetahui membership dan age group mana yang dominan di tiap channel.
SELECT
    dc.channel_name,
    cust.membership_type,
    cust.age_group,
    COUNT(DISTINCT cust.customer_id) AS customers,
    COUNT(DISTINCT fs.transaction_id) AS transactions,
    ROUND(SUM(fs.net_sales), 2) AS net_sales,
    ROUND(AVG(fs.net_sales), 2) AS avg_transaction_value
FROM fact_sales fs
JOIN dim_channel dc ON dc.channel_key = fs.channel_key
JOIN dim_customer cust ON cust.customer_key = fs.customer_key
GROUP BY dc.channel_name, cust.membership_type, cust.age_group
ORDER BY dc.channel_name, net_sales DESC;

-- 7. Online order fulfilment summary.
-- Dipakai untuk KPI order online, order value, dan fulfilment rate.
SELECT
    foo.order_status,
    COUNT(*) AS orders,
    ROUND(SUM(foo.total_order_value), 2) AS total_order_value,
    ROUND(AVG(foo.total_order_value), 2) AS avg_order_value,
    ROUND(AVG(foo.fulfilled_flag) * 100, 2) AS fulfilment_rate_pct
FROM fact_online_orders foo
GROUP BY foo.order_status
ORDER BY total_order_value DESC;

-- 8. Delivery performance by partner.
-- Dipakai untuk membandingkan partner pengiriman berdasarkan on-time rate dan delay.
SELECT
    fdp.delivery_partner,
    COUNT(*) AS deliveries,
    ROUND(AVG(fdp.on_time_flag) * 100, 2) AS on_time_delivery_pct,
    ROUND(AVG(fdp.delay_minutes), 2) AS avg_delay_minutes,
    ROUND(AVG(fdp.delay_hours), 2) AS avg_delay_hours,
    ROUND(AVG(fdp.order_accuracy_flag) * 100, 2) AS order_accuracy_pct
FROM fact_delivery_performance fdp
GROUP BY fdp.delivery_partner
ORDER BY on_time_delivery_pct DESC, avg_delay_minutes ASC;

-- 9. Delivery performance by fulfilment center.
-- Dipakai untuk mengevaluasi kualitas fulfilment online berdasarkan pusat fulfilment.
SELECT
    dfc.fulfilment_center_name,
    dfc.city,
    dfc.state,
    COUNT(*) AS deliveries,
    ROUND(AVG(fdp.on_time_flag) * 100, 2) AS on_time_delivery_pct,
    ROUND(AVG(fdp.delay_hours), 2) AS avg_delay_hours,
    ROUND(AVG(fdp.order_accuracy_flag) * 100, 2) AS order_accuracy_pct
FROM fact_delivery_performance fdp
JOIN fact_online_orders foo ON foo.online_order_key = fdp.online_order_key
JOIN dim_fulfilment_center dfc ON dfc.fulfilment_center_key = foo.fulfilment_center_key
GROUP BY dfc.fulfilment_center_name, dfc.city, dfc.state
ORDER BY on_time_delivery_pct DESC, avg_delay_hours ASC;

-- 10. Inventory support by category, store, and region.
-- Dipakai untuk melihat kategori dan lokasi yang punya issue stok paling tinggi.
SELECT
    ds.region,
    ds.store_name,
    dp.category,
    COUNT(*) AS inventory_records,
    ROUND(SUM(fid.closing_stock), 2) AS total_closing_stock,
    ROUND(SUM(fid.stock_variance_abs), 2) AS total_abs_stock_variance,
    ROUND(AVG(fid.shrinkage_rate) * 100, 2) AS avg_shrinkage_pct
FROM fact_inventory_daily fid
JOIN dim_store ds ON ds.store_key = fid.store_key
JOIN dim_product dp ON dp.product_key = fid.product_key
GROUP BY ds.region, ds.store_name, dp.category
ORDER BY total_abs_stock_variance DESC;
