INSERT INTO data_quality_issue (batch_id, layer_name, source_table, source_id, issue_code, issue_message, severity)
SELECT BATCH_ID(), 'lookup', 'trf_sales', s.transaction_id, 'LOOKUP_NOT_FOUND',
       TRIM(
           CASE WHEN ds.store_key IS NULL THEN 'store_id not found; ' ELSE '' END ||
           CASE WHEN dp.product_key IS NULL THEN 'product_id not found; ' ELSE '' END ||
           CASE WHEN dc.customer_key IS NULL THEN 'customer_id not found; ' ELSE '' END ||
           CASE WHEN s.promotion_id IS NOT NULL AND dpr.promotion_key IS NULL THEN 'promotion_id not found; ' ELSE '' END ||
           CASE WHEN dpm.payment_method_key IS NULL THEN 'payment_method_id not found; ' ELSE '' END ||
           CASE WHEN dch.channel_key IS NULL THEN 'channel_id not found; ' ELSE '' END
       ),
       'WARNING'
FROM trf_sales s
LEFT JOIN dim_store ds ON ds.store_id = s.store_id AND ds.is_current = 1
LEFT JOIN dim_product dp ON dp.product_id = s.product_id AND dp.is_current = 1
LEFT JOIN dim_customer dc ON dc.customer_id = s.customer_id AND dc.is_current = 1
LEFT JOIN dim_promotion dpr ON dpr.promotion_id = s.promotion_id
LEFT JOIN dim_payment_method dpm ON dpm.payment_method_id = s.payment_method_id
LEFT JOIN dim_channel dch ON dch.channel_id = s.channel_id
WHERE ds.store_key IS NULL OR dp.product_key IS NULL OR dc.customer_key IS NULL
   OR (s.promotion_id IS NOT NULL AND dpr.promotion_key IS NULL)
   OR dpm.payment_method_key IS NULL OR dch.channel_key IS NULL;

INSERT INTO etl_error_log (batch_id, source_table, source_id, error_type, error_description)
SELECT batch_id, source_table, source_id, issue_code, issue_message
FROM data_quality_issue
WHERE batch_id = BATCH_ID()
  AND layer_name = 'lookup'
  AND source_table = 'trf_sales';

INSERT INTO fact_sales (
    transaction_id, date_key, store_key, product_key, customer_key, promotion_key,
    payment_method_key, channel_key, quantity_sold, unit_price, total_sales_amount,
    discount_amount, net_sales, sales_cost, gross_profit, gross_margin_pct, discount_pct,
    currency, load_batch_id
)
SELECT s.transaction_id, s.date_key,
       COALESCE(ds.store_key, 0), COALESCE(dp.product_key, 0), COALESCE(dc.customer_key, 0),
       COALESCE(dpr.promotion_key, 0), COALESCE(dpm.payment_method_key, 0), COALESCE(dch.channel_key, 0),
       s.quantity_sold, s.unit_price, s.total_sales_amount, s.discount_amount, s.net_sales,
       s.sales_cost, s.gross_profit, s.gross_margin_pct, s.discount_pct, s.currency, s.load_batch_id
FROM trf_sales s
LEFT JOIN dim_store ds ON ds.store_id = s.store_id AND ds.is_current = 1
LEFT JOIN dim_product dp ON dp.product_id = s.product_id AND dp.is_current = 1
LEFT JOIN dim_customer dc ON dc.customer_id = s.customer_id AND dc.is_current = 1
LEFT JOIN dim_promotion dpr ON dpr.promotion_id = COALESCE(s.promotion_id, 'NONE')
LEFT JOIN dim_payment_method dpm ON dpm.payment_method_id = s.payment_method_id
LEFT JOIN dim_channel dch ON dch.channel_id = s.channel_id
WHERE NOT EXISTS (
    SELECT 1 FROM fact_sales f WHERE f.transaction_id = s.transaction_id
);

INSERT INTO data_quality_issue (batch_id, layer_name, source_table, source_id, issue_code, issue_message, severity)
SELECT BATCH_ID(), 'lookup', 'trf_online_orders', o.online_order_id, 'LOOKUP_NOT_FOUND',
       TRIM(
           CASE WHEN dc.customer_key IS NULL THEN 'customer_id not found; ' ELSE '' END ||
           CASE WHEN dfc.fulfilment_center_key IS NULL THEN 'fulfilment_center_id not found; ' ELSE '' END ||
           CASE WHEN dch.channel_key IS NULL THEN 'channel_id not found; ' ELSE '' END
       ),
       'WARNING'
FROM trf_online_orders o
LEFT JOIN dim_customer dc ON dc.customer_id = o.customer_id AND dc.is_current = 1
LEFT JOIN dim_fulfilment_center dfc ON dfc.fulfilment_center_id = o.fulfilment_center_id
LEFT JOIN dim_channel dch ON dch.channel_id = o.channel_id
WHERE dc.customer_key IS NULL OR dfc.fulfilment_center_key IS NULL OR dch.channel_key IS NULL;

INSERT INTO fact_online_orders (
    online_order_id, order_date_key, customer_key, fulfilment_center_key, channel_key,
    item_count, order_value, delivery_fee, total_order_value, order_status, fulfilled_flag, load_batch_id
)
SELECT o.online_order_id, o.order_date_key, COALESCE(dc.customer_key, 0),
       COALESCE(dfc.fulfilment_center_key, 0), COALESCE(dch.channel_key, 0),
       o.item_count, o.order_value, o.delivery_fee, o.total_order_value, o.order_status,
       o.fulfilled_flag, o.load_batch_id
FROM trf_online_orders o
LEFT JOIN dim_customer dc ON dc.customer_id = o.customer_id AND dc.is_current = 1
LEFT JOIN dim_fulfilment_center dfc ON dfc.fulfilment_center_id = o.fulfilment_center_id
LEFT JOIN dim_channel dch ON dch.channel_id = o.channel_id
WHERE NOT EXISTS (
    SELECT 1 FROM fact_online_orders f WHERE f.online_order_id = o.online_order_id
);

INSERT INTO data_quality_issue (batch_id, layer_name, source_table, source_id, issue_code, issue_message, severity)
SELECT BATCH_ID(), 'lookup', 'trf_inventory', i.inventory_record_id, 'LOOKUP_NOT_FOUND',
       TRIM(
           CASE WHEN ds.store_key IS NULL THEN 'store_id not found; ' ELSE '' END ||
           CASE WHEN dp.product_key IS NULL THEN 'product_id not found; ' ELSE '' END
       ),
       'WARNING'
FROM trf_inventory i
LEFT JOIN dim_store ds ON ds.store_id = i.store_id AND ds.is_current = 1
LEFT JOIN dim_product dp ON dp.product_id = i.product_id AND dp.is_current = 1
WHERE ds.store_key IS NULL OR dp.product_key IS NULL;

INSERT INTO fact_inventory_daily (
    inventory_record_id, snapshot_date_key, store_key, product_key,
    opening_stock, stock_in, stock_out, stock_loss, closing_stock,
    calculated_closing_stock, stock_variance, stock_variance_abs, shrinkage_rate, load_batch_id
)
SELECT i.inventory_record_id, i.snapshot_date_key, COALESCE(ds.store_key, 0), COALESCE(dp.product_key, 0),
       i.opening_stock, i.stock_in, i.stock_out, i.stock_loss, i.closing_stock,
       i.calculated_closing_stock, i.stock_variance, i.stock_variance_abs, i.shrinkage_rate, i.load_batch_id
FROM trf_inventory i
LEFT JOIN dim_store ds ON ds.store_id = i.store_id AND ds.is_current = 1
LEFT JOIN dim_product dp ON dp.product_id = i.product_id AND dp.is_current = 1
WHERE NOT EXISTS (
    SELECT 1 FROM fact_inventory_daily f WHERE f.inventory_record_id = i.inventory_record_id
);

INSERT INTO data_quality_issue (batch_id, layer_name, source_table, source_id, issue_code, issue_message, severity)
SELECT BATCH_ID(), 'lookup', 'trf_delivery', d.delivery_id, 'LOOKUP_NOT_FOUND',
       'online_order_id not found in loaded online order fact',
       'WARNING'
FROM trf_delivery d
LEFT JOIN fact_online_orders foo ON foo.online_order_id = d.online_order_id
WHERE foo.online_order_key IS NULL;

INSERT INTO fact_delivery_performance (
    delivery_id, online_order_key, promised_date_key, actual_date_key, delivery_partner,
    delivery_status, delivery_time_minutes, delay_minutes, delay_hours, on_time_flag,
    order_accuracy_flag, load_batch_id
)
SELECT d.delivery_id, COALESCE(foo.online_order_key, 0), d.promised_date_key, d.actual_date_key,
       d.delivery_partner, d.delivery_status, d.delivery_time_minutes, d.delay_minutes,
       d.delay_hours, d.on_time_flag, d.order_accuracy_flag, d.load_batch_id
FROM trf_delivery d
LEFT JOIN fact_online_orders foo ON foo.online_order_id = d.online_order_id
WHERE foo.online_order_key IS NOT NULL
  AND NOT EXISTS (
      SELECT 1 FROM fact_delivery_performance f WHERE f.delivery_id = d.delivery_id
  );

INSERT INTO data_quality_issue (batch_id, layer_name, source_table, source_id, issue_code, issue_message, severity)
SELECT BATCH_ID(), 'lookup', 'trf_procurement', p.purchase_order_id, 'LOOKUP_NOT_FOUND',
       TRIM(
           CASE WHEN ds.supplier_key IS NULL THEN 'supplier_id not found; ' ELSE '' END ||
           CASE WHEN ddc.distribution_center_key IS NULL THEN 'distribution_center_id not found; ' ELSE '' END ||
           CASE WHEN dp.product_key IS NULL THEN 'product_id not found; ' ELSE '' END
       ),
       'WARNING'
FROM trf_procurement p
LEFT JOIN dim_supplier ds ON ds.supplier_id = p.supplier_id AND ds.is_current = 1
LEFT JOIN dim_distribution_center ddc ON ddc.distribution_center_id = p.distribution_center_id
LEFT JOIN dim_product dp ON dp.product_id = p.product_id AND dp.is_current = 1
WHERE ds.supplier_key IS NULL OR ddc.distribution_center_key IS NULL OR dp.product_key IS NULL;

INSERT INTO fact_procurement (
    purchase_order_id, purchase_order_date_key, supplier_key, distribution_center_key, product_key,
    ordered_qty, received_qty, fill_rate, purchase_amount, expected_receipt_date_key,
    actual_receipt_date_key, late_delivery_flag, receipt_delay_days, po_status, load_batch_id
)
SELECT p.purchase_order_id, p.purchase_order_date_key, COALESCE(ds.supplier_key, 0),
       COALESCE(ddc.distribution_center_key, 0), COALESCE(dp.product_key, 0),
       p.ordered_qty, p.received_qty, p.fill_rate, p.purchase_amount,
       p.expected_receipt_date_key, p.actual_receipt_date_key, p.late_delivery_flag,
       p.receipt_delay_days, p.po_status, p.load_batch_id
FROM trf_procurement p
LEFT JOIN dim_supplier ds ON ds.supplier_id = p.supplier_id AND ds.is_current = 1
LEFT JOIN dim_distribution_center ddc ON ddc.distribution_center_id = p.distribution_center_id
LEFT JOIN dim_product dp ON dp.product_id = p.product_id AND dp.is_current = 1
WHERE NOT EXISTS (
    SELECT 1 FROM fact_procurement f WHERE f.purchase_order_id = p.purchase_order_id
);

INSERT INTO etl_error_log (batch_id, source_table, source_id, error_type, error_description)
SELECT batch_id, source_table, source_id, issue_code, issue_message
FROM data_quality_issue
WHERE batch_id = BATCH_ID()
  AND layer_name = 'lookup'
  AND source_table <> 'trf_sales';

INSERT INTO etl_audit_log (batch_id, process_name, source_table, target_table, rows_extracted, rows_loaded, rows_rejected, status)
SELECT BATCH_ID(), 'load_fact_sales', 'trf_sales', 'fact_sales',
       (SELECT COUNT(*) FROM trf_sales),
       (SELECT COUNT(*) FROM fact_sales WHERE load_batch_id = BATCH_ID()),
       (SELECT COUNT(*) FROM data_quality_issue WHERE batch_id = BATCH_ID() AND source_table = 'trf_sales'),
       'SUCCESS';

INSERT INTO etl_audit_log (batch_id, process_name, source_table, target_table, rows_extracted, rows_loaded, rows_rejected, status)
SELECT BATCH_ID(), 'load_fact_online_orders', 'trf_online_orders', 'fact_online_orders',
       (SELECT COUNT(*) FROM trf_online_orders),
       (SELECT COUNT(*) FROM fact_online_orders WHERE load_batch_id = BATCH_ID()),
       (SELECT COUNT(*) FROM data_quality_issue WHERE batch_id = BATCH_ID() AND source_table = 'trf_online_orders'),
       'SUCCESS';

INSERT INTO etl_audit_log (batch_id, process_name, source_table, target_table, rows_extracted, rows_loaded, rows_rejected, status)
SELECT BATCH_ID(), 'load_fact_inventory_daily', 'trf_inventory', 'fact_inventory_daily',
       (SELECT COUNT(*) FROM trf_inventory),
       (SELECT COUNT(*) FROM fact_inventory_daily WHERE load_batch_id = BATCH_ID()),
       (SELECT COUNT(*) FROM data_quality_issue WHERE batch_id = BATCH_ID() AND source_table = 'trf_inventory'),
       'SUCCESS';

INSERT INTO etl_audit_log (batch_id, process_name, source_table, target_table, rows_extracted, rows_loaded, rows_rejected, status)
SELECT BATCH_ID(), 'load_fact_delivery_performance', 'trf_delivery', 'fact_delivery_performance',
       (SELECT COUNT(*) FROM trf_delivery),
       (SELECT COUNT(*) FROM fact_delivery_performance WHERE load_batch_id = BATCH_ID()),
       (SELECT COUNT(*) FROM data_quality_issue WHERE batch_id = BATCH_ID() AND source_table = 'trf_delivery'),
       'SUCCESS';

INSERT INTO etl_audit_log (batch_id, process_name, source_table, target_table, rows_extracted, rows_loaded, rows_rejected, status)
SELECT BATCH_ID(), 'load_fact_procurement', 'trf_procurement', 'fact_procurement',
       (SELECT COUNT(*) FROM trf_procurement),
       (SELECT COUNT(*) FROM fact_procurement WHERE load_batch_id = BATCH_ID()),
       (SELECT COUNT(*) FROM data_quality_issue WHERE batch_id = BATCH_ID() AND source_table = 'trf_procurement'),
       'SUCCESS';

UPDATE etl_load_batch
SET completed_at = CURRENT_TIMESTAMP,
    status = 'SUCCESS'
WHERE batch_id = BATCH_ID();
