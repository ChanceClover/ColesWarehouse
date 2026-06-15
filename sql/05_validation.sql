-- File ini berisi query validasi setelah proses ETL selesai.
-- Query di sini dipakai untuk mengecek jumlah row, isu kualitas data,
-- penggunaan unknown key, kesiapan SCD Type 2, dan metrik bisnis utama.

-- Mengecek jumlah row akhir pada semua tabel dimensi dan fakta.
-- Bagian ini membantu memastikan data benar-benar termuat ke warehouse.
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

-- Mengecek jumlah row pada transform layer.
-- Hasilnya bisa dibandingkan dengan staging untuk melihat berapa data valid yang lolos.
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
UNION ALL SELECT 'trf_procurement', COUNT(*) FROM trf_procurement;

-- Merangkum isu kualitas data berdasarkan layer, jenis issue, dan severity.
-- Ini memudahkan penjelasan error mana yang paling sering terjadi.
SELECT layer_name, issue_code, severity, COUNT(*) AS issue_count
FROM data_quality_issue
GROUP BY layer_name, issue_code, severity
ORDER BY layer_name, issue_code;

-- Mengecek penggunaan unknown surrogate key pada fact table.
-- Jika nilainya besar, berarti banyak foreign key bisnis yang gagal lookup ke dimensi.
SELECT 'fact_sales.store_key' AS key_name, COUNT(*) AS unknown_rows FROM fact_sales WHERE store_key = 0
UNION ALL SELECT 'fact_sales.product_key', COUNT(*) FROM fact_sales WHERE product_key = 0
UNION ALL SELECT 'fact_sales.customer_key', COUNT(*) FROM fact_sales WHERE customer_key = 0
UNION ALL SELECT 'fact_online_orders.customer_key', COUNT(*) FROM fact_online_orders WHERE customer_key = 0
UNION ALL SELECT 'fact_inventory_daily.product_key', COUNT(*) FROM fact_inventory_daily WHERE product_key = 0
UNION ALL SELECT 'fact_procurement.supplier_key', COUNT(*) FROM fact_procurement WHERE supplier_key = 0;

-- Mengecek kesiapan SCD Type 2 dengan menghitung current row dan historical row.
-- Historical row muncul jika ada perubahan atribut pada dimensi yang dilacak.
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
FROM dim_supplier;

-- Melihat histori batch ETL, mode run, waktu mulai, waktu selesai, dan status.
SELECT batch_id, run_mode, started_at, completed_at, status
FROM etl_load_batch
ORDER BY started_at DESC;

-- Mengecek nilai bisnis negatif yang seharusnya tidak ada setelah proses cleansing.
-- Contohnya quantity, sales amount, stock, delivery time, atau purchase amount.
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
WHERE ordered_qty < 0 OR received_qty < 0 OR purchase_amount < 0;

-- Analisis sales per region: total net sales, gross profit, dan rata-rata margin.
SELECT ds.region,
       ROUND(SUM(fs.net_sales), 2) AS total_net_sales,
       ROUND(SUM(fs.gross_profit), 2) AS gross_profit,
       ROUND(AVG(fs.gross_margin_pct) * 100, 2) AS avg_margin_pct
FROM fact_sales fs
JOIN dim_store ds ON ds.store_key = fs.store_key
GROUP BY ds.region
ORDER BY total_net_sales DESC;

-- Analisis inventory per kategori produk: total variance stok dan rata-rata shrinkage.
SELECT dp.category,
       ROUND(SUM(fid.stock_variance), 2) AS total_stock_variance,
       ROUND(AVG(fid.shrinkage_rate) * 100, 2) AS avg_shrinkage_pct
FROM fact_inventory_daily fid
JOIN dim_product dp ON dp.product_key = fid.product_key
GROUP BY dp.category
ORDER BY ABS(total_stock_variance) DESC;

-- Analisis performa delivery berdasarkan status pengiriman.
-- Menghasilkan jumlah delivery, rata-rata delay, dan persentase on-time.
SELECT delivery_status,
       COUNT(*) AS deliveries,
       ROUND(AVG(delay_hours), 2) AS avg_delay_hours,
       ROUND(AVG(on_time_flag) * 100, 2) AS on_time_percentage
FROM fact_delivery_performance
GROUP BY delivery_status;

-- Analisis performa supplier: jumlah PO, total purchase amount,
-- rata-rata fill rate, dan persentase keterlambatan delivery.
SELECT ds.supplier_name,
       COUNT(*) AS purchase_orders,
       ROUND(SUM(fp.purchase_amount), 2) AS total_purchase_amount,
       ROUND(AVG(fp.fill_rate) * 100, 2) AS avg_fill_rate_pct,
       ROUND(AVG(fp.late_delivery_flag) * 100, 2) AS late_delivery_percentage
FROM fact_procurement fp
JOIN dim_supplier ds ON ds.supplier_key = fp.supplier_key
GROUP BY ds.supplier_name
ORDER BY total_purchase_amount DESC;
