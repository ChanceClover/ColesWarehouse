-- File ini membuat transform layer dari data staging yang valid.
-- Di tahap ini data-quality issue dicatat, nilai standar diterapkan,
-- dan beberapa atribut turunan seperti date key serta business measure dihitung.

-- Menghapus transform table lama agar hasil transformasi run terbaru tidak bercampur.
DROP TABLE IF EXISTS trf_stores;
DROP TABLE IF EXISTS trf_products;
DROP TABLE IF EXISTS trf_customers;
DROP TABLE IF EXISTS trf_promotions;
DROP TABLE IF EXISTS trf_payment_methods;
DROP TABLE IF EXISTS trf_channels;
DROP TABLE IF EXISTS trf_suppliers;
DROP TABLE IF EXISTS trf_fulfilment_centers;
DROP TABLE IF EXISTS trf_distribution_centers;
DROP TABLE IF EXISTS trf_sales;
DROP TABLE IF EXISTS trf_online_orders;
DROP TABLE IF EXISTS trf_inventory;
DROP TABLE IF EXISTS trf_delivery;
DROP TABLE IF EXISTS trf_procurement;

-- Mencatat semua row staging yang tidak valid ke tabel data_quality_issue.
-- Issue diklasifikasikan agar mudah dijelaskan: missing key, duplicate key,
-- invalid date, invalid measure, atau staging reject umum.
INSERT INTO data_quality_issue (batch_id, layer_name, source_table, source_id, issue_code, issue_message, severity)
SELECT BATCH_ID(), 'staging', source_table, source_id,
       CASE
           WHEN error_reason LIKE '%missing%' THEN 'MISSING_REQUIRED_KEY'
           WHEN error_reason LIKE '%duplicate%' THEN 'DUPLICATE_BUSINESS_KEY'
           WHEN error_reason LIKE '%date%' THEN 'INVALID_DATE'
           WHEN error_reason LIKE '%negative%' OR error_reason LIKE '%invalid%' THEN 'INVALID_MEASURE'
           ELSE 'STAGING_REJECT'
       END,
       error_reason,
       'ERROR'
FROM (
    SELECT 'raw_stores' AS source_table, store_id AS source_id, error_reason FROM stg_stores WHERE is_valid = 0
    UNION ALL SELECT 'raw_products', product_id, error_reason FROM stg_products WHERE is_valid = 0
    UNION ALL SELECT 'raw_customers', customer_id, error_reason FROM stg_customers WHERE is_valid = 0
    UNION ALL SELECT 'raw_promotions', promotion_id, error_reason FROM stg_promotions WHERE is_valid = 0
    UNION ALL SELECT 'raw_payment_methods', payment_method_id, error_reason FROM stg_payment_methods WHERE is_valid = 0
    UNION ALL SELECT 'raw_channels', channel_id, error_reason FROM stg_channels WHERE is_valid = 0
    UNION ALL SELECT 'raw_suppliers', supplier_id, error_reason FROM stg_suppliers WHERE is_valid = 0
    UNION ALL SELECT 'raw_fulfilment_centers', fulfilment_center_id, error_reason FROM stg_fulfilment_centers WHERE is_valid = 0
    UNION ALL SELECT 'raw_distribution_centers', distribution_center_id, error_reason FROM stg_distribution_centers WHERE is_valid = 0
    UNION ALL SELECT 'raw_sales_transactions', transaction_id, error_reason FROM stg_sales WHERE is_valid = 0
    UNION ALL SELECT 'raw_online_orders', online_order_id, error_reason FROM stg_online_orders WHERE is_valid = 0
    UNION ALL SELECT 'raw_inventory_movements', inventory_record_id, error_reason FROM stg_inventory WHERE is_valid = 0
    UNION ALL SELECT 'raw_delivery_logs', delivery_id, error_reason FROM stg_delivery WHERE is_valid = 0
    UNION ALL SELECT 'raw_purchase_orders', purchase_order_id, error_reason FROM stg_procurement WHERE is_valid = 0
);

-- Menyalin data-quality issue staging ke etl_error_log untuk kebutuhan audit error.
INSERT INTO etl_error_log (batch_id, source_table, source_id, error_type, error_description)
SELECT batch_id, source_table, source_id, issue_code, issue_message
FROM data_quality_issue
WHERE batch_id = BATCH_ID()
  AND layer_name = 'staging';

-- Transform toko: hanya mengambil row valid, memberi default value,
-- dan membuat open_date_key untuk relasi ke dim_date.
CREATE TABLE trf_stores AS
SELECT
    source_row_id,
    store_id,
    COALESCE(store_name, 'Unknown Store') AS store_name,
    COALESCE(m.standard_value, store_type, 'Unknown') AS store_type,
    COALESCE(city, 'Unknown') AS city,
    COALESCE(state, 'Unknown') AS state,
    COALESCE(region, 'Unknown') AS region,
    COALESCE(store_area_sqm, 0) AS store_area_sqm,
    COALESCE(staff_count, 0) AS staff_count,
    open_date,
    COALESCE(DATE_KEY(open_date), 0) AS open_date_key,
    BATCH_ID() AS load_batch_id
FROM stg_stores s
LEFT JOIN map_standard_value m
    ON m.map_group = 'store_type'
   AND m.raw_value = LOWER(s.store_type)
WHERE s.is_valid = 1;

-- Transform produk: menerapkan standar kategori dan menghitung margin standar produk.
CREATE TABLE trf_products AS
SELECT
    source_row_id,
    product_id,
    COALESCE(product_name, 'Unknown Product') AS product_name,
    COALESCE(brand, 'Unknown') AS brand,
    COALESCE(m.standard_value, category, 'Unknown') AS category,
    COALESCE(subcategory, 'Unknown') AS subcategory,
    unit_price,
    unit_cost,
    COALESCE(is_active, 0) AS is_active,
    CASE WHEN unit_price > 0 THEN ROUND((unit_price - unit_cost) / unit_price, 4) END AS standard_margin_pct,
    BATCH_ID() AS load_batch_id
FROM stg_products p
LEFT JOIN map_standard_value m
    ON m.map_group = 'product_category'
   AND m.raw_value = LOWER(p.category)
WHERE p.is_valid = 1;

-- Transform customer: menjaga atribut customer valid dan membuat join_date_key.
CREATE TABLE trf_customers AS
SELECT
    source_row_id,
    customer_id,
    gender,
    birth_year,
    age_group,
    membership_type,
    COALESCE(city, 'Unknown') AS city,
    COALESCE(email, 'Unknown') AS email,
    join_date,
    COALESCE(DATE_KEY(join_date), 0) AS join_date_key,
    BATCH_ID() AS load_batch_id
FROM stg_customers
WHERE is_valid = 1;

-- Transform promosi: menerapkan standar tipe promosi dan membuat start/end date key.
CREATE TABLE trf_promotions AS
SELECT
    source_row_id,
    promotion_id,
    promotion_name,
    COALESCE(m.standard_value, promotion_type, 'Unknown') AS promotion_type,
    discount_rate,
    start_date,
    end_date,
    DATE_KEY(start_date) AS start_date_key,
    DATE_KEY(end_date) AS end_date_key,
    BATCH_ID() AS load_batch_id
FROM stg_promotions p
LEFT JOIN map_standard_value m
    ON m.map_group = 'promotion_type'
   AND m.raw_value = LOWER(p.promotion_type)
WHERE p.is_valid = 1;

-- Transform metode pembayaran: menyimpan payment type, provider,
-- dan flag apakah bisa dipakai untuk transaksi online.
CREATE TABLE trf_payment_methods AS
SELECT
    source_row_id,
    payment_method_id,
    payment_type,
    provider,
    COALESCE(is_online_supported, 0) AS is_online_supported,
    BATCH_ID() AS load_batch_id
FROM stg_payment_methods
WHERE is_valid = 1;

-- Transform channel: menerapkan standar nama channel untuk analisis channel penjualan.
CREATE TABLE trf_channels AS
SELECT
    source_row_id,
    channel_id,
    COALESCE(m.standard_value, channel_name, 'Unknown') AS channel_name,
    channel_group,
    description,
    BATCH_ID() AS load_batch_id
FROM stg_channels c
LEFT JOIN map_standard_value m
    ON m.map_group = 'channel_name'
   AND m.raw_value = LOWER(c.channel_name)
WHERE c.is_valid = 1;

-- Transform supplier: menyimpan data supplier valid untuk dimensi supplier.
CREATE TABLE trf_suppliers AS
SELECT
    source_row_id,
    supplier_id,
    supplier_name,
    supplier_type,
    COALESCE(city, 'Unknown') AS city,
    COALESCE(state, 'Unknown') AS state,
    lead_time_days,
    BATCH_ID() AS load_batch_id
FROM stg_suppliers
WHERE is_valid = 1;

-- Transform fulfilment center: menyimpan pusat fulfilment valid untuk order online.
CREATE TABLE trf_fulfilment_centers AS
SELECT
    source_row_id,
    fulfilment_center_id,
    fulfilment_center_name,
    COALESCE(city, 'Unknown') AS city,
    COALESCE(state, 'Unknown') AS state,
    capacity_orders_per_day,
    BATCH_ID() AS load_batch_id
FROM stg_fulfilment_centers
WHERE is_valid = 1;

-- Transform distribution center: menyimpan distribution center valid untuk procurement.
CREATE TABLE trf_distribution_centers AS
SELECT
    source_row_id,
    distribution_center_id,
    distribution_center_name,
    COALESCE(city, 'Unknown') AS city,
    COALESCE(state, 'Unknown') AS state,
    warehouse_area_sqm,
    BATCH_ID() AS load_batch_id
FROM stg_distribution_centers
WHERE is_valid = 1;

-- Transform sales: menghitung total sales, net sales, gross profit,
-- margin, dan discount percentage dari transaksi penjualan.
CREATE TABLE trf_sales AS
SELECT
    source_row_id,
    transaction_id,
    transaction_date,
    date_key,
    store_id,
    product_id,
    customer_id,
    NULLIF(promotion_id, '') AS promotion_id,
    payment_method_id,
    channel_id,
    quantity AS quantity_sold,
    unit_price,
    gross_sale AS total_sales_amount,
    discount_amount,
    net_sales,
    sales_cost,
    gross_profit,
    CASE WHEN net_sales > 0 THEN ROUND(gross_profit / net_sales, 4) END AS gross_margin_pct,
    CASE WHEN gross_sale > 0 THEN ROUND(discount_amount / gross_sale, 4) ELSE 0 END AS discount_pct,
    currency,
    BATCH_ID() AS load_batch_id
FROM stg_sales
WHERE is_valid = 1;

-- Transform online orders: menghitung total order value dan menjaga status fulfilment.
CREATE TABLE trf_online_orders AS
SELECT
    source_row_id,
    online_order_id,
    order_date,
    order_date_key,
    customer_id,
    fulfilment_center_id,
    channel_id,
    item_count,
    order_value,
    delivery_fee,
    order_value + COALESCE(delivery_fee, 0) AS total_order_value,
    COALESCE(m.standard_value, order_status, 'unknown') AS order_status,
    COALESCE(fulfilled_flag, 0) AS fulfilled_flag,
    BATCH_ID() AS load_batch_id
FROM stg_online_orders o
LEFT JOIN map_standard_value m
    ON m.map_group = 'order_status'
   AND m.raw_value = LOWER(o.order_status)
WHERE o.is_valid = 1;

-- Transform inventory: menghitung variance stok, nilai absolut variance,
-- dan shrinkage rate sebagai indikator kualitas stok.
CREATE TABLE trf_inventory AS
SELECT
    source_row_id,
    inventory_record_id,
    snapshot_date,
    snapshot_date_key,
    store_id,
    product_id,
    opening_stock,
    stock_in,
    stock_out,
    stock_loss,
    closing_stock,
    calculated_closing_stock,
    closing_stock - calculated_closing_stock AS stock_variance,
    ABS(closing_stock - calculated_closing_stock) AS stock_variance_abs,
    CASE WHEN opening_stock + stock_in > 0 THEN ROUND(stock_loss / (opening_stock + stock_in), 4) ELSE 0 END AS shrinkage_rate,
    BATCH_ID() AS load_batch_id
FROM stg_inventory
WHERE is_valid = 1;

-- Transform delivery: menghitung delay dalam menit/jam dan flag on-time delivery.
CREATE TABLE trf_delivery AS
SELECT
    source_row_id,
    delivery_id,
    online_order_id,
    delivery_partner,
    promised_delivery_date,
    promised_date_key,
    actual_delivery_date,
    actual_date_key,
    COALESCE(m.standard_value, delivery_status, 'unknown') AS delivery_status,
    delivery_time_minutes,
    MAX(COALESCE(delay_minutes, 0), 0) AS delay_minutes,
    ROUND(MAX(COALESCE(delay_minutes, 0), 0) / 60.0, 2) AS delay_hours,
    on_time_flag,
    COALESCE(order_accuracy_flag, 0) AS order_accuracy_flag,
    BATCH_ID() AS load_batch_id
FROM stg_delivery d
LEFT JOIN map_standard_value m
    ON m.map_group = 'delivery_status'
   AND m.raw_value = LOWER(d.delivery_status)
WHERE d.is_valid = 1;

-- Transform procurement: menghitung fill rate, delay receipt,
-- dan flag keterlambatan penerimaan barang.
CREATE TABLE trf_procurement AS
SELECT
    source_row_id,
    purchase_order_id,
    purchase_order_date,
    purchase_order_date_key,
    supplier_id,
    distribution_center_id,
    product_id,
    ordered_qty,
    received_qty,
    CASE WHEN ordered_qty > 0 THEN ROUND(received_qty / ordered_qty, 4) END AS fill_rate,
    purchase_amount,
    expected_receipt_date,
    expected_receipt_date_key,
    actual_receipt_date,
    actual_receipt_date_key,
    late_delivery_flag,
    CASE
        WHEN actual_receipt_date IS NOT NULL AND expected_receipt_date IS NOT NULL
        THEN MAX(CAST(julianday(actual_receipt_date) - julianday(expected_receipt_date) AS INTEGER), 0)
        ELSE NULL
    END AS receipt_delay_days,
    COALESCE(m.standard_value, po_status, 'unknown') AS po_status,
    BATCH_ID() AS load_batch_id
FROM stg_procurement p
LEFT JOIN map_standard_value m
    ON m.map_group = 'po_status'
   AND m.raw_value = LOWER(p.po_status)
WHERE p.is_valid = 1;

-- Mencatat ringkasan audit transform layer: jumlah row valid yang dimuat
-- dan jumlah row yang ditolak dari staging.
INSERT INTO etl_audit_log (batch_id, process_name, source_table, target_table, rows_extracted, rows_loaded, rows_rejected, status)
SELECT BATCH_ID(), 'transform_layer', NULL, 'trf_*',
       (SELECT COUNT(*) FROM stg_stores) + (SELECT COUNT(*) FROM stg_products) + (SELECT COUNT(*) FROM stg_customers) +
       (SELECT COUNT(*) FROM stg_promotions) + (SELECT COUNT(*) FROM stg_payment_methods) + (SELECT COUNT(*) FROM stg_channels) +
       (SELECT COUNT(*) FROM stg_suppliers) + (SELECT COUNT(*) FROM stg_fulfilment_centers) + (SELECT COUNT(*) FROM stg_distribution_centers) +
       (SELECT COUNT(*) FROM stg_sales) + (SELECT COUNT(*) FROM stg_online_orders) + (SELECT COUNT(*) FROM stg_inventory) +
       (SELECT COUNT(*) FROM stg_delivery) + (SELECT COUNT(*) FROM stg_procurement),
       (SELECT COUNT(*) FROM trf_stores) + (SELECT COUNT(*) FROM trf_products) + (SELECT COUNT(*) FROM trf_customers) +
       (SELECT COUNT(*) FROM trf_promotions) + (SELECT COUNT(*) FROM trf_payment_methods) + (SELECT COUNT(*) FROM trf_channels) +
       (SELECT COUNT(*) FROM trf_suppliers) + (SELECT COUNT(*) FROM trf_fulfilment_centers) + (SELECT COUNT(*) FROM trf_distribution_centers) +
       (SELECT COUNT(*) FROM trf_sales) + (SELECT COUNT(*) FROM trf_online_orders) + (SELECT COUNT(*) FROM trf_inventory) +
       (SELECT COUNT(*) FROM trf_delivery) + (SELECT COUNT(*) FROM trf_procurement),
       (SELECT COUNT(*) FROM data_quality_issue WHERE batch_id = BATCH_ID() AND layer_name = 'staging'),
       'SUCCESS';
