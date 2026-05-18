INSERT INTO etl_error_log (source_table, source_id, error_type, error_description)
SELECT 'raw_stores', raw_store_id, 'STAGING_REJECT', error_reason FROM stg_stores WHERE is_valid = 0;
INSERT INTO etl_error_log (source_table, source_id, error_type, error_description)
SELECT 'raw_products', product_id, 'STAGING_REJECT', error_reason FROM stg_products WHERE is_valid = 0;
INSERT INTO etl_error_log (source_table, source_id, error_type, error_description)
SELECT 'raw_customers', customer_id, 'STAGING_REJECT', error_reason FROM stg_customers WHERE is_valid = 0;
INSERT INTO etl_error_log (source_table, source_id, error_type, error_description)
SELECT 'raw_promotions', promotion_id, 'STAGING_REJECT', error_reason FROM stg_promotions WHERE is_valid = 0;
INSERT INTO etl_error_log (source_table, source_id, error_type, error_description)
SELECT 'raw_payment_methods', payment_method_id, 'STAGING_REJECT', error_reason FROM stg_payment_methods WHERE is_valid = 0;
INSERT INTO etl_error_log (source_table, source_id, error_type, error_description)
SELECT 'raw_channels', channel_id, 'STAGING_REJECT', error_reason FROM stg_channels WHERE is_valid = 0;
INSERT INTO etl_error_log (source_table, source_id, error_type, error_description)
SELECT 'raw_suppliers', supplier_id, 'STAGING_REJECT', error_reason FROM stg_suppliers WHERE is_valid = 0;
INSERT INTO etl_error_log (source_table, source_id, error_type, error_description)
SELECT 'raw_fulfilment_centers', fulfilment_center_id, 'STAGING_REJECT', error_reason FROM stg_fulfilment_centers WHERE is_valid = 0;
INSERT INTO etl_error_log (source_table, source_id, error_type, error_description)
SELECT 'raw_distribution_centers', distribution_center_id, 'STAGING_REJECT', error_reason FROM stg_distribution_centers WHERE is_valid = 0;

INSERT INTO dim_date (date_key, full_date, year, quarter, month, month_name, day, day_of_week)
SELECT DISTINCT
    CAST(strftime('%Y%m%d', full_date) AS INTEGER) AS date_key,
    full_date,
    CAST(strftime('%Y', full_date) AS INTEGER) AS year,
    ((CAST(strftime('%m', full_date) AS INTEGER) - 1) / 3) + 1 AS quarter,
    CAST(strftime('%m', full_date) AS INTEGER) AS month,
    CASE strftime('%m', full_date)
        WHEN '01' THEN 'January' WHEN '02' THEN 'February' WHEN '03' THEN 'March'
        WHEN '04' THEN 'April' WHEN '05' THEN 'May' WHEN '06' THEN 'June'
        WHEN '07' THEN 'July' WHEN '08' THEN 'August' WHEN '09' THEN 'September'
        WHEN '10' THEN 'October' WHEN '11' THEN 'November' WHEN '12' THEN 'December'
    END AS month_name,
    CAST(strftime('%d', full_date) AS INTEGER) AS day,
    CASE strftime('%w', full_date)
        WHEN '0' THEN 'Sunday' WHEN '1' THEN 'Monday' WHEN '2' THEN 'Tuesday'
        WHEN '3' THEN 'Wednesday' WHEN '4' THEN 'Thursday' WHEN '5' THEN 'Friday'
        WHEN '6' THEN 'Saturday'
    END AS day_of_week
FROM (
    SELECT open_date AS full_date FROM stg_stores WHERE open_date IS NOT NULL
    UNION SELECT join_date FROM stg_customers WHERE join_date IS NOT NULL
    UNION SELECT start_date FROM stg_promotions WHERE start_date IS NOT NULL
    UNION SELECT end_date FROM stg_promotions WHERE end_date IS NOT NULL
    UNION SELECT transaction_date FROM stg_sales WHERE transaction_date IS NOT NULL
    UNION SELECT order_date FROM stg_online_orders WHERE order_date IS NOT NULL
    UNION SELECT snapshot_date FROM stg_inventory WHERE snapshot_date IS NOT NULL
    UNION SELECT promised_delivery_date FROM stg_delivery WHERE promised_delivery_date IS NOT NULL
    UNION SELECT actual_delivery_date FROM stg_delivery WHERE actual_delivery_date IS NOT NULL
    UNION SELECT purchase_order_date FROM stg_procurement WHERE purchase_order_date IS NOT NULL
    UNION SELECT expected_receipt_date FROM stg_procurement WHERE expected_receipt_date IS NOT NULL
    UNION SELECT actual_receipt_date FROM stg_procurement WHERE actual_receipt_date IS NOT NULL
);

INSERT INTO dim_store (store_id, store_name, store_type, city, state, region, store_area_sqm, staff_count, open_date_key)
SELECT store_id, store_name, store_type, city, state, region, store_area_sqm, staff_count, DATE_KEY(open_date)
FROM stg_stores WHERE is_valid = 1;

INSERT INTO dim_product (product_id, product_name, brand, category, subcategory, unit_price, unit_cost, is_active)
SELECT product_id, product_name, brand, category, subcategory, unit_price, unit_cost, is_active
FROM stg_products WHERE is_valid = 1;

INSERT INTO dim_customer (customer_id, gender, birth_year, age_group, membership_type, city, email, join_date_key)
SELECT customer_id, gender, birth_year, age_group, membership_type, city, email, DATE_KEY(join_date)
FROM stg_customers WHERE is_valid = 1;

INSERT INTO dim_promotion (promotion_id, promotion_name, promotion_type, discount_rate, start_date_key, end_date_key)
SELECT promotion_id, promotion_name, promotion_type, discount_rate, DATE_KEY(start_date), DATE_KEY(end_date)
FROM stg_promotions WHERE is_valid = 1;

INSERT INTO dim_payment_method (payment_method_id, payment_type, provider, is_online_supported)
SELECT payment_method_id, payment_type, provider, is_online_supported
FROM stg_payment_methods WHERE is_valid = 1;

INSERT INTO dim_channel (channel_id, channel_name, channel_group, description)
SELECT channel_id, channel_name, channel_group, description
FROM stg_channels WHERE is_valid = 1;

INSERT INTO dim_supplier (supplier_id, supplier_name, supplier_type, city, state, lead_time_days)
SELECT supplier_id, supplier_name, supplier_type, city, state, lead_time_days
FROM stg_suppliers WHERE is_valid = 1;

INSERT INTO dim_fulfilment_center (fulfilment_center_id, fulfilment_center_name, city, state, capacity_orders_per_day)
SELECT fulfilment_center_id, fulfilment_center_name, city, state, capacity_orders_per_day
FROM stg_fulfilment_centers WHERE is_valid = 1;

INSERT INTO dim_distribution_center (distribution_center_id, distribution_center_name, city, state, warehouse_area_sqm)
SELECT distribution_center_id, distribution_center_name, city, state, warehouse_area_sqm
FROM stg_distribution_centers WHERE is_valid = 1;

INSERT INTO etl_audit_log (batch_id, process_name, source_table, target_table, rows_extracted, rows_loaded, rows_rejected, status)
SELECT 'BATCH_001', 'load_dim_store', 'raw_stores', 'dim_store', (SELECT COUNT(*) FROM stg_stores), (SELECT COUNT(*) FROM dim_store), (SELECT COUNT(*) FROM stg_stores WHERE is_valid = 0), 'SUCCESS';
INSERT INTO etl_audit_log (batch_id, process_name, source_table, target_table, rows_extracted, rows_loaded, rows_rejected, status)
SELECT 'BATCH_001', 'load_dim_product', 'raw_products', 'dim_product', (SELECT COUNT(*) FROM stg_products), (SELECT COUNT(*) FROM dim_product), (SELECT COUNT(*) FROM stg_products WHERE is_valid = 0), 'SUCCESS';
INSERT INTO etl_audit_log (batch_id, process_name, source_table, target_table, rows_extracted, rows_loaded, rows_rejected, status)
SELECT 'BATCH_001', 'load_dim_customer', 'raw_customers', 'dim_customer', (SELECT COUNT(*) FROM stg_customers), (SELECT COUNT(*) FROM dim_customer), (SELECT COUNT(*) FROM stg_customers WHERE is_valid = 0), 'SUCCESS';
INSERT INTO etl_audit_log (batch_id, process_name, source_table, target_table, rows_extracted, rows_loaded, rows_rejected, status)
SELECT 'BATCH_001', 'load_dimensions_supporting', NULL, 'supporting_dimensions', 300,
       (SELECT COUNT(*) FROM dim_promotion) + (SELECT COUNT(*) FROM dim_payment_method) + (SELECT COUNT(*) FROM dim_channel) + (SELECT COUNT(*) FROM dim_supplier) + (SELECT COUNT(*) FROM dim_fulfilment_center) + (SELECT COUNT(*) FROM dim_distribution_center),
       (SELECT COUNT(*) FROM stg_promotions WHERE is_valid = 0) + (SELECT COUNT(*) FROM stg_payment_methods WHERE is_valid = 0) + (SELECT COUNT(*) FROM stg_channels WHERE is_valid = 0) + (SELECT COUNT(*) FROM stg_suppliers WHERE is_valid = 0) + (SELECT COUNT(*) FROM stg_fulfilment_centers WHERE is_valid = 0) + (SELECT COUNT(*) FROM stg_distribution_centers WHERE is_valid = 0),
       'SUCCESS';
