-- Row counts for final warehouse tables.
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
UNION ALL SELECT 'fact_procurement', COUNT(*) FROM fact_procurement;

-- Rejected records by table and reason type.
SELECT source_table, error_type, COUNT(*) AS rejected_rows
FROM etl_error_log
GROUP BY source_table, error_type
ORDER BY source_table, error_type;

-- Fact tables should have no negative business measures after ETL.
SELECT 'fact_sales' AS table_name, COUNT(*) AS negative_rows
FROM fact_sales
WHERE quantity_sold < 0 OR total_sales_amount < 0 OR discount_amount < 0 OR net_sales < 0 OR sales_cost < 0
UNION ALL
SELECT 'fact_online_orders', COUNT(*)
FROM fact_online_orders
WHERE item_count < 0 OR order_value < 0 OR delivery_fee < 0
UNION ALL
SELECT 'fact_inventory_daily', COUNT(*)
FROM fact_inventory_daily
WHERE opening_stock < 0 OR stock_in < 0 OR stock_out < 0 OR stock_loss < 0 OR closing_stock < 0
UNION ALL
SELECT 'fact_delivery_performance', COUNT(*)
FROM fact_delivery_performance
WHERE delivery_time_minutes < 0
UNION ALL
SELECT 'fact_procurement', COUNT(*)
FROM fact_procurement
WHERE ordered_qty < 0 OR received_qty < 0 OR purchase_amount < 0;

-- Sales analysis: total net sales and gross profit by region.
SELECT ds.region, ROUND(SUM(fs.net_sales), 2) AS total_net_sales, ROUND(SUM(fs.gross_profit), 2) AS gross_profit
FROM fact_sales fs
JOIN dim_store ds ON ds.store_key = fs.store_key
GROUP BY ds.region
ORDER BY total_net_sales DESC;

-- Product performance by category.
SELECT dp.category, SUM(fs.quantity_sold) AS units_sold, ROUND(SUM(fs.net_sales), 2) AS total_net_sales
FROM fact_sales fs
JOIN dim_product dp ON dp.product_key = fs.product_key
GROUP BY dp.category
ORDER BY total_net_sales DESC;

-- Online order performance by channel.
SELECT dc.channel_name, COUNT(*) AS orders, ROUND(SUM(foo.order_value), 2) AS order_value
FROM fact_online_orders foo
JOIN dim_channel dc ON dc.channel_key = foo.channel_key
GROUP BY dc.channel_name
ORDER BY order_value DESC;

-- Delivery performance.
SELECT delivery_status, COUNT(*) AS deliveries, ROUND(AVG(delay_minutes), 2) AS avg_delay_minutes,
       ROUND(AVG(on_time_flag) * 100, 2) AS on_time_percentage
FROM fact_delivery_performance
GROUP BY delivery_status;

-- Procurement by supplier.
SELECT ds.supplier_name, COUNT(*) AS purchase_orders, ROUND(SUM(fp.purchase_amount), 2) AS total_purchase_amount,
       ROUND(AVG(fp.late_delivery_flag) * 100, 2) AS late_delivery_percentage
FROM fact_procurement fp
JOIN dim_supplier ds ON ds.supplier_key = fp.supplier_key
GROUP BY ds.supplier_name
ORDER BY total_purchase_amount DESC;
