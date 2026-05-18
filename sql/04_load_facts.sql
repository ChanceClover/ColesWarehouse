INSERT INTO etl_error_log (source_table, source_id, error_type, error_description)
SELECT 'raw_sales_transactions', transaction_id, 'STAGING_REJECT', error_reason FROM stg_sales WHERE is_valid = 0;
INSERT INTO etl_error_log (source_table, source_id, error_type, error_description)
SELECT 'raw_online_orders', online_order_id, 'STAGING_REJECT', error_reason FROM stg_online_orders WHERE is_valid = 0;
INSERT INTO etl_error_log (source_table, source_id, error_type, error_description)
SELECT 'raw_inventory_movements', inventory_record_id, 'STAGING_REJECT', error_reason FROM stg_inventory WHERE is_valid = 0;
INSERT INTO etl_error_log (source_table, source_id, error_type, error_description)
SELECT 'raw_delivery_logs', delivery_id, 'STAGING_REJECT', error_reason FROM stg_delivery WHERE is_valid = 0;
INSERT INTO etl_error_log (source_table, source_id, error_type, error_description)
SELECT 'raw_purchase_orders', purchase_order_id, 'STAGING_REJECT', error_reason FROM stg_procurement WHERE is_valid = 0;

INSERT INTO etl_error_log (source_table, source_id, error_type, error_description)
SELECT 'raw_sales_transactions', s.transaction_id, 'LOOKUP_REJECT',
       TRIM(
           CASE WHEN ds.store_key IS NULL THEN 'store_id not found; ' ELSE '' END ||
           CASE WHEN dp.product_key IS NULL THEN 'product_id not found; ' ELSE '' END ||
           CASE WHEN dc.customer_key IS NULL THEN 'customer_id not found; ' ELSE '' END ||
           CASE WHEN s.promotion_id IS NOT NULL AND dpr.promotion_key IS NULL THEN 'promotion_id not found; ' ELSE '' END ||
           CASE WHEN dpm.payment_method_key IS NULL THEN 'payment_method_id not found; ' ELSE '' END ||
           CASE WHEN dch.channel_key IS NULL THEN 'channel_id not found; ' ELSE '' END
       )
FROM stg_sales s
LEFT JOIN dim_store ds ON ds.store_id = s.store_id
LEFT JOIN dim_product dp ON dp.product_id = s.product_id
LEFT JOIN dim_customer dc ON dc.customer_id = s.customer_id
LEFT JOIN dim_promotion dpr ON dpr.promotion_id = s.promotion_id
LEFT JOIN dim_payment_method dpm ON dpm.payment_method_id = s.payment_method_id
LEFT JOIN dim_channel dch ON dch.channel_id = s.channel_id
WHERE s.is_valid = 1
  AND (ds.store_key IS NULL OR dp.product_key IS NULL OR dc.customer_key IS NULL
       OR (s.promotion_id IS NOT NULL AND dpr.promotion_key IS NULL)
       OR dpm.payment_method_key IS NULL OR dch.channel_key IS NULL);

INSERT INTO fact_sales (
    transaction_id, date_key, store_key, product_key, customer_key, promotion_key,
    payment_method_key, channel_key, quantity_sold, unit_price, total_sales_amount,
    discount_amount, net_sales, sales_cost, gross_profit, currency
)
SELECT s.transaction_id, s.date_key, ds.store_key, dp.product_key, dc.customer_key, dpr.promotion_key,
       dpm.payment_method_key, dch.channel_key, s.quantity, s.unit_price, s.gross_sale,
       s.discount_amount, s.net_sales, s.sales_cost, s.gross_profit, s.currency
FROM stg_sales s
JOIN dim_store ds ON ds.store_id = s.store_id
JOIN dim_product dp ON dp.product_id = s.product_id
JOIN dim_customer dc ON dc.customer_id = s.customer_id
LEFT JOIN dim_promotion dpr ON dpr.promotion_id = s.promotion_id
JOIN dim_payment_method dpm ON dpm.payment_method_id = s.payment_method_id
JOIN dim_channel dch ON dch.channel_id = s.channel_id
WHERE s.is_valid = 1
  AND (s.promotion_id IS NULL OR dpr.promotion_key IS NOT NULL);

INSERT INTO etl_error_log (source_table, source_id, error_type, error_description)
SELECT 'raw_online_orders', o.online_order_id, 'LOOKUP_REJECT',
       TRIM(
           CASE WHEN dc.customer_key IS NULL THEN 'customer_id not found; ' ELSE '' END ||
           CASE WHEN dfc.fulfilment_center_key IS NULL THEN 'fulfilment_center_id not found; ' ELSE '' END ||
           CASE WHEN dch.channel_key IS NULL THEN 'channel_id not found; ' ELSE '' END
       )
FROM stg_online_orders o
LEFT JOIN dim_customer dc ON dc.customer_id = o.customer_id
LEFT JOIN dim_fulfilment_center dfc ON dfc.fulfilment_center_id = o.fulfilment_center_id
LEFT JOIN dim_channel dch ON dch.channel_id = o.channel_id
WHERE o.is_valid = 1
  AND (dc.customer_key IS NULL OR dfc.fulfilment_center_key IS NULL OR dch.channel_key IS NULL);

INSERT INTO fact_online_orders (
    online_order_id, order_date_key, customer_key, fulfilment_center_key, channel_key,
    item_count, order_value, delivery_fee, order_status, fulfilled_flag
)
SELECT o.online_order_id, o.order_date_key, dc.customer_key, dfc.fulfilment_center_key, dch.channel_key,
       o.item_count, o.order_value, o.delivery_fee, o.order_status, o.fulfilled_flag
FROM stg_online_orders o
JOIN dim_customer dc ON dc.customer_id = o.customer_id
JOIN dim_fulfilment_center dfc ON dfc.fulfilment_center_id = o.fulfilment_center_id
JOIN dim_channel dch ON dch.channel_id = o.channel_id
WHERE o.is_valid = 1;

INSERT INTO etl_error_log (source_table, source_id, error_type, error_description)
SELECT 'raw_inventory_movements', i.inventory_record_id, 'LOOKUP_REJECT',
       TRIM(
           CASE WHEN ds.store_key IS NULL THEN 'store_id not found; ' ELSE '' END ||
           CASE WHEN dp.product_key IS NULL THEN 'product_id not found; ' ELSE '' END
       )
FROM stg_inventory i
LEFT JOIN dim_store ds ON ds.store_id = i.store_id
LEFT JOIN dim_product dp ON dp.product_id = i.product_id
WHERE i.is_valid = 1 AND (ds.store_key IS NULL OR dp.product_key IS NULL);

INSERT INTO fact_inventory_daily (
    inventory_record_id, snapshot_date_key, store_key, product_key,
    opening_stock, stock_in, stock_out, stock_loss, closing_stock,
    calculated_closing_stock, stock_variance
)
SELECT i.inventory_record_id, i.snapshot_date_key, ds.store_key, dp.product_key,
       i.opening_stock, i.stock_in, i.stock_out, i.stock_loss, i.closing_stock,
       i.calculated_closing_stock, i.closing_stock - i.calculated_closing_stock
FROM stg_inventory i
JOIN dim_store ds ON ds.store_id = i.store_id
JOIN dim_product dp ON dp.product_id = i.product_id
WHERE i.is_valid = 1;

INSERT INTO etl_error_log (source_table, source_id, error_type, error_description)
SELECT 'raw_delivery_logs', d.delivery_id, 'LOOKUP_REJECT', 'online_order_id not found in loaded online order fact'
FROM stg_delivery d
LEFT JOIN fact_online_orders foo ON foo.online_order_id = d.online_order_id
WHERE d.is_valid = 1 AND foo.online_order_key IS NULL;

INSERT INTO fact_delivery_performance (
    delivery_id, online_order_key, promised_date_key, actual_date_key, delivery_partner,
    delivery_status, delivery_time_minutes, delay_minutes, on_time_flag, order_accuracy_flag
)
SELECT d.delivery_id, foo.online_order_key, d.promised_date_key, d.actual_date_key, d.delivery_partner,
       d.delivery_status, d.delivery_time_minutes, COALESCE(d.delay_minutes, 0), d.on_time_flag, d.order_accuracy_flag
FROM stg_delivery d
JOIN fact_online_orders foo ON foo.online_order_id = d.online_order_id
WHERE d.is_valid = 1;

INSERT INTO etl_error_log (source_table, source_id, error_type, error_description)
SELECT 'raw_purchase_orders', p.purchase_order_id, 'LOOKUP_REJECT',
       TRIM(
           CASE WHEN ds.supplier_key IS NULL THEN 'supplier_id not found; ' ELSE '' END ||
           CASE WHEN ddc.distribution_center_key IS NULL THEN 'distribution_center_id not found; ' ELSE '' END ||
           CASE WHEN dp.product_key IS NULL THEN 'product_id not found; ' ELSE '' END
       )
FROM stg_procurement p
LEFT JOIN dim_supplier ds ON ds.supplier_id = p.supplier_id
LEFT JOIN dim_distribution_center ddc ON ddc.distribution_center_id = p.distribution_center_id
LEFT JOIN dim_product dp ON dp.product_id = p.product_id
WHERE p.is_valid = 1
  AND (ds.supplier_key IS NULL OR ddc.distribution_center_key IS NULL OR dp.product_key IS NULL);

INSERT INTO fact_procurement (
    purchase_order_id, purchase_order_date_key, supplier_key, distribution_center_key, product_key,
    ordered_qty, received_qty, purchase_amount, expected_receipt_date_key,
    actual_receipt_date_key, late_delivery_flag, po_status
)
SELECT p.purchase_order_id, p.purchase_order_date_key, ds.supplier_key, ddc.distribution_center_key, dp.product_key,
       p.ordered_qty, p.received_qty, p.purchase_amount, p.expected_receipt_date_key,
       p.actual_receipt_date_key, p.late_delivery_flag, p.po_status
FROM stg_procurement p
JOIN dim_supplier ds ON ds.supplier_id = p.supplier_id
JOIN dim_distribution_center ddc ON ddc.distribution_center_id = p.distribution_center_id
JOIN dim_product dp ON dp.product_id = p.product_id
WHERE p.is_valid = 1;

INSERT INTO etl_audit_log (batch_id, process_name, source_table, target_table, rows_extracted, rows_loaded, rows_rejected, status)
SELECT 'BATCH_001', 'load_fact_sales', 'raw_sales_transactions', 'fact_sales',
       (SELECT COUNT(*) FROM stg_sales), (SELECT COUNT(*) FROM fact_sales),
       (SELECT COUNT(*) FROM etl_error_log WHERE source_table = 'raw_sales_transactions'), 'SUCCESS';
INSERT INTO etl_audit_log (batch_id, process_name, source_table, target_table, rows_extracted, rows_loaded, rows_rejected, status)
SELECT 'BATCH_001', 'load_fact_online_orders', 'raw_online_orders', 'fact_online_orders',
       (SELECT COUNT(*) FROM stg_online_orders), (SELECT COUNT(*) FROM fact_online_orders),
       (SELECT COUNT(*) FROM etl_error_log WHERE source_table = 'raw_online_orders'), 'SUCCESS';
INSERT INTO etl_audit_log (batch_id, process_name, source_table, target_table, rows_extracted, rows_loaded, rows_rejected, status)
SELECT 'BATCH_001', 'load_fact_inventory_daily', 'raw_inventory_movements', 'fact_inventory_daily',
       (SELECT COUNT(*) FROM stg_inventory), (SELECT COUNT(*) FROM fact_inventory_daily),
       (SELECT COUNT(*) FROM etl_error_log WHERE source_table = 'raw_inventory_movements'), 'SUCCESS';
INSERT INTO etl_audit_log (batch_id, process_name, source_table, target_table, rows_extracted, rows_loaded, rows_rejected, status)
SELECT 'BATCH_001', 'load_fact_delivery_performance', 'raw_delivery_logs', 'fact_delivery_performance',
       (SELECT COUNT(*) FROM stg_delivery), (SELECT COUNT(*) FROM fact_delivery_performance),
       (SELECT COUNT(*) FROM etl_error_log WHERE source_table = 'raw_delivery_logs'), 'SUCCESS';
INSERT INTO etl_audit_log (batch_id, process_name, source_table, target_table, rows_extracted, rows_loaded, rows_rejected, status)
SELECT 'BATCH_001', 'load_fact_procurement', 'raw_purchase_orders', 'fact_procurement',
       (SELECT COUNT(*) FROM stg_procurement), (SELECT COUNT(*) FROM fact_procurement),
       (SELECT COUNT(*) FROM etl_error_log WHERE source_table = 'raw_purchase_orders'), 'SUCCESS';
