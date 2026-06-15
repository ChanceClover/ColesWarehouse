-- File ini memuat data transform ke tabel dimensi warehouse.
-- Beberapa dimensi memakai SCD Type 2, sehingga perubahan atribut disimpan
-- sebagai versi histori dan row terbaru ditandai dengan is_current = 1.

-- Mengisi dim_date dari semua tanggal yang muncul di transform layer.
-- Ini membuat kalender warehouse otomatis mengikuti data yang tersedia.
INSERT OR IGNORE INTO dim_date (
    date_key, full_date, year, quarter, quarter_name, month, month_name, year_month,
    week_number, day, day_of_week, day_of_week_number, is_weekend,
    month_start_date, month_end_date, fiscal_year, fiscal_quarter, load_batch_id
)
SELECT DISTINCT
    CAST(strftime('%Y%m%d', full_date) AS INTEGER) AS date_key,
    full_date,
    CAST(strftime('%Y', full_date) AS INTEGER) AS year,
    ((CAST(strftime('%m', full_date) AS INTEGER) - 1) / 3) + 1 AS quarter,
    'Q' || (((CAST(strftime('%m', full_date) AS INTEGER) - 1) / 3) + 1) AS quarter_name,
    CAST(strftime('%m', full_date) AS INTEGER) AS month,
    CASE strftime('%m', full_date)
        WHEN '01' THEN 'January' WHEN '02' THEN 'February' WHEN '03' THEN 'March'
        WHEN '04' THEN 'April' WHEN '05' THEN 'May' WHEN '06' THEN 'June'
        WHEN '07' THEN 'July' WHEN '08' THEN 'August' WHEN '09' THEN 'September'
        WHEN '10' THEN 'October' WHEN '11' THEN 'November' WHEN '12' THEN 'December'
    END AS month_name,
    strftime('%Y-%m', full_date) AS year_month,
    CAST(strftime('%W', full_date) AS INTEGER) AS week_number,
    CAST(strftime('%d', full_date) AS INTEGER) AS day,
    CASE strftime('%w', full_date)
        WHEN '0' THEN 'Sunday' WHEN '1' THEN 'Monday' WHEN '2' THEN 'Tuesday'
        WHEN '3' THEN 'Wednesday' WHEN '4' THEN 'Thursday' WHEN '5' THEN 'Friday'
        WHEN '6' THEN 'Saturday'
    END AS day_of_week,
    CAST(strftime('%w', full_date) AS INTEGER) AS day_of_week_number,
    CASE WHEN strftime('%w', full_date) IN ('0', '6') THEN 1 ELSE 0 END AS is_weekend,
    date(full_date, 'start of month') AS month_start_date,
    date(full_date, 'start of month', '+1 month', '-1 day') AS month_end_date,
    CASE
        WHEN CAST(strftime('%m', full_date) AS INTEGER) >= 7 THEN CAST(strftime('%Y', full_date) AS INTEGER) + 1
        ELSE CAST(strftime('%Y', full_date) AS INTEGER)
    END AS fiscal_year,
    ((CAST(strftime('%m', date(full_date, '-6 months')) AS INTEGER) - 1) / 3) + 1 AS fiscal_quarter,
    BATCH_ID()
FROM (
    SELECT open_date AS full_date FROM trf_stores WHERE open_date IS NOT NULL
    UNION SELECT join_date FROM trf_customers WHERE join_date IS NOT NULL
    UNION SELECT start_date FROM trf_promotions WHERE start_date IS NOT NULL
    UNION SELECT end_date FROM trf_promotions WHERE end_date IS NOT NULL
    UNION SELECT transaction_date FROM trf_sales WHERE transaction_date IS NOT NULL
    UNION SELECT order_date FROM trf_online_orders WHERE order_date IS NOT NULL
    UNION SELECT snapshot_date FROM trf_inventory WHERE snapshot_date IS NOT NULL
    UNION SELECT promised_delivery_date FROM trf_delivery WHERE promised_delivery_date IS NOT NULL
    UNION SELECT actual_delivery_date FROM trf_delivery WHERE actual_delivery_date IS NOT NULL
    UNION SELECT purchase_order_date FROM trf_procurement WHERE purchase_order_date IS NOT NULL
    UNION SELECT expected_receipt_date FROM trf_procurement WHERE expected_receipt_date IS NOT NULL
    UNION SELECT actual_receipt_date FROM trf_procurement WHERE actual_receipt_date IS NOT NULL
)
WHERE full_date IS NOT NULL;

-- SCD Type 2 untuk dim_store: jika atribut toko berubah,
-- row lama ditutup dengan is_current = 0 dan effective_end_date_key diisi.
UPDATE dim_store
SET is_current = 0,
    effective_end_date_key = CAST(strftime('%Y%m%d', 'now') AS INTEGER)
WHERE is_current = 1
  AND store_id <> 'UNKNOWN'
  AND EXISTS (
      SELECT 1
      FROM trf_stores s
      WHERE s.store_id = dim_store.store_id
        AND (
            COALESCE(s.store_name, '') <> COALESCE(dim_store.store_name, '') OR
            COALESCE(s.store_type, '') <> COALESCE(dim_store.store_type, '') OR
            COALESCE(s.city, '') <> COALESCE(dim_store.city, '') OR
            COALESCE(s.state, '') <> COALESCE(dim_store.state, '') OR
            COALESCE(s.region, '') <> COALESCE(dim_store.region, '') OR
            COALESCE(s.store_area_sqm, -1) <> COALESCE(dim_store.store_area_sqm, -1) OR
            COALESCE(s.staff_count, -1) <> COALESCE(dim_store.staff_count, -1)
        )
  );

-- Menambahkan row toko baru atau versi toko terbaru yang belum ada sebagai current row.
INSERT INTO dim_store (
    store_id, store_name, store_type, city, state, region, store_area_sqm, staff_count,
    open_date_key, effective_start_date_key, effective_end_date_key, is_current, load_batch_id
)
SELECT store_id, store_name, store_type, city, state, region, store_area_sqm, staff_count,
       open_date_key, CAST(strftime('%Y%m%d', 'now') AS INTEGER), NULL, 1, load_batch_id
FROM trf_stores s
WHERE NOT EXISTS (
    SELECT 1 FROM dim_store d WHERE d.store_id = s.store_id AND d.is_current = 1
);

-- SCD Type 2 untuk dim_product: menutup versi produk lama jika detail produk berubah.
UPDATE dim_product
SET is_current = 0,
    effective_end_date_key = CAST(strftime('%Y%m%d', 'now') AS INTEGER)
WHERE is_current = 1
  AND product_id <> 'UNKNOWN'
  AND EXISTS (
      SELECT 1
      FROM trf_products p
      WHERE p.product_id = dim_product.product_id
        AND (
            COALESCE(p.product_name, '') <> COALESCE(dim_product.product_name, '') OR
            COALESCE(p.brand, '') <> COALESCE(dim_product.brand, '') OR
            COALESCE(p.category, '') <> COALESCE(dim_product.category, '') OR
            COALESCE(p.subcategory, '') <> COALESCE(dim_product.subcategory, '') OR
            COALESCE(p.unit_price, -1) <> COALESCE(dim_product.unit_price, -1) OR
            COALESCE(p.unit_cost, -1) <> COALESCE(dim_product.unit_cost, -1) OR
            COALESCE(p.is_active, -1) <> COALESCE(dim_product.is_active, -1)
        )
  );

-- Menambahkan produk baru atau versi produk terbaru ke dim_product.
INSERT INTO dim_product (
    product_id, product_name, brand, category, subcategory, unit_price, unit_cost, is_active,
    effective_start_date_key, effective_end_date_key, is_current, load_batch_id
)
SELECT product_id, product_name, brand, category, subcategory, unit_price, unit_cost, is_active,
       CAST(strftime('%Y%m%d', 'now') AS INTEGER), NULL, 1, load_batch_id
FROM trf_products p
WHERE NOT EXISTS (
    SELECT 1 FROM dim_product d WHERE d.product_id = p.product_id AND d.is_current = 1
);

-- SCD Type 2 untuk dim_customer: menutup versi customer lama jika atribut profil berubah.
UPDATE dim_customer
SET is_current = 0,
    effective_end_date_key = CAST(strftime('%Y%m%d', 'now') AS INTEGER)
WHERE is_current = 1
  AND customer_id <> 'UNKNOWN'
  AND EXISTS (
      SELECT 1
      FROM trf_customers c
      WHERE c.customer_id = dim_customer.customer_id
        AND (
            COALESCE(c.gender, '') <> COALESCE(dim_customer.gender, '') OR
            COALESCE(c.birth_year, -1) <> COALESCE(dim_customer.birth_year, -1) OR
            COALESCE(c.age_group, '') <> COALESCE(dim_customer.age_group, '') OR
            COALESCE(c.membership_type, '') <> COALESCE(dim_customer.membership_type, '') OR
            COALESCE(c.city, '') <> COALESCE(dim_customer.city, '') OR
            COALESCE(c.email, '') <> COALESCE(dim_customer.email, '')
        )
  );

-- Menambahkan customer baru atau versi customer terbaru ke dim_customer.
INSERT INTO dim_customer (
    customer_id, gender, birth_year, age_group, membership_type, city, email, join_date_key,
    effective_start_date_key, effective_end_date_key, is_current, load_batch_id
)
SELECT customer_id, gender, birth_year, age_group, membership_type, city, email, join_date_key,
       CAST(strftime('%Y%m%d', 'now') AS INTEGER), NULL, 1, load_batch_id
FROM trf_customers c
WHERE NOT EXISTS (
    SELECT 1 FROM dim_customer d WHERE d.customer_id = c.customer_id AND d.is_current = 1
);

-- Memuat dimensi promosi. Tabel ini bersifat lookup sederhana,
-- sehingga hanya insert jika promotion_id belum pernah ada.
INSERT INTO dim_promotion (promotion_id, promotion_name, promotion_type, discount_rate, start_date_key, end_date_key, load_batch_id)
SELECT promotion_id, promotion_name, promotion_type, discount_rate, start_date_key, end_date_key, load_batch_id
FROM trf_promotions p
WHERE NOT EXISTS (
    SELECT 1 FROM dim_promotion d WHERE d.promotion_id = p.promotion_id
);

-- Memuat dimensi metode pembayaran dan mencegah duplikasi payment_method_id.
INSERT INTO dim_payment_method (payment_method_id, payment_type, provider, is_online_supported, load_batch_id)
SELECT payment_method_id, payment_type, provider, is_online_supported, load_batch_id
FROM trf_payment_methods p
WHERE NOT EXISTS (
    SELECT 1 FROM dim_payment_method d WHERE d.payment_method_id = p.payment_method_id
);

-- Memuat dimensi channel untuk kebutuhan analisis sumber transaksi.
INSERT INTO dim_channel (channel_id, channel_name, channel_group, description, load_batch_id)
SELECT channel_id, channel_name, channel_group, description, load_batch_id
FROM trf_channels c
WHERE NOT EXISTS (
    SELECT 1 FROM dim_channel d WHERE d.channel_id = c.channel_id
);

-- SCD Type 2 untuk dim_supplier: menutup versi supplier lama jika atribut supplier berubah.
UPDATE dim_supplier
SET is_current = 0,
    effective_end_date_key = CAST(strftime('%Y%m%d', 'now') AS INTEGER)
WHERE is_current = 1
  AND supplier_id <> 'UNKNOWN'
  AND EXISTS (
      SELECT 1
      FROM trf_suppliers s
      WHERE s.supplier_id = dim_supplier.supplier_id
        AND (
            COALESCE(s.supplier_name, '') <> COALESCE(dim_supplier.supplier_name, '') OR
            COALESCE(s.supplier_type, '') <> COALESCE(dim_supplier.supplier_type, '') OR
            COALESCE(s.city, '') <> COALESCE(dim_supplier.city, '') OR
            COALESCE(s.state, '') <> COALESCE(dim_supplier.state, '') OR
            COALESCE(s.lead_time_days, -1) <> COALESCE(dim_supplier.lead_time_days, -1)
        )
  );

-- Menambahkan supplier baru atau versi supplier terbaru ke dim_supplier.
INSERT INTO dim_supplier (
    supplier_id, supplier_name, supplier_type, city, state, lead_time_days,
    effective_start_date_key, effective_end_date_key, is_current, load_batch_id
)
SELECT supplier_id, supplier_name, supplier_type, city, state, lead_time_days,
       CAST(strftime('%Y%m%d', 'now') AS INTEGER), NULL, 1, load_batch_id
FROM trf_suppliers s
WHERE NOT EXISTS (
    SELECT 1 FROM dim_supplier d WHERE d.supplier_id = s.supplier_id AND d.is_current = 1
);

-- Memuat dimensi fulfilment center untuk order online.
INSERT INTO dim_fulfilment_center (fulfilment_center_id, fulfilment_center_name, city, state, capacity_orders_per_day, load_batch_id)
SELECT fulfilment_center_id, fulfilment_center_name, city, state, capacity_orders_per_day, load_batch_id
FROM trf_fulfilment_centers f
WHERE NOT EXISTS (
    SELECT 1 FROM dim_fulfilment_center d WHERE d.fulfilment_center_id = f.fulfilment_center_id
);

-- Memuat dimensi distribution center untuk proses procurement.
INSERT INTO dim_distribution_center (distribution_center_id, distribution_center_name, city, state, warehouse_area_sqm, load_batch_id)
SELECT distribution_center_id, distribution_center_name, city, state, warehouse_area_sqm, load_batch_id
FROM trf_distribution_centers d
WHERE NOT EXISTS (
    SELECT 1 FROM dim_distribution_center x WHERE x.distribution_center_id = d.distribution_center_id
);

-- Audit load dim_store: mencatat jumlah row sumber, row yang dimuat,
-- dan status proses.
INSERT INTO etl_audit_log (batch_id, process_name, source_table, target_table, rows_extracted, rows_loaded, rows_rejected, status)
SELECT BATCH_ID(), 'load_dim_store', 'trf_stores', 'dim_store',
       (SELECT COUNT(*) FROM trf_stores),
       (SELECT COUNT(*) FROM dim_store WHERE load_batch_id = BATCH_ID()),
       0, 'SUCCESS';

-- Audit load dim_product.
INSERT INTO etl_audit_log (batch_id, process_name, source_table, target_table, rows_extracted, rows_loaded, rows_rejected, status)
SELECT BATCH_ID(), 'load_dim_product', 'trf_products', 'dim_product',
       (SELECT COUNT(*) FROM trf_products),
       (SELECT COUNT(*) FROM dim_product WHERE load_batch_id = BATCH_ID()),
       0, 'SUCCESS';

-- Audit load dim_customer.
INSERT INTO etl_audit_log (batch_id, process_name, source_table, target_table, rows_extracted, rows_loaded, rows_rejected, status)
SELECT BATCH_ID(), 'load_dim_customer', 'trf_customers', 'dim_customer',
       (SELECT COUNT(*) FROM trf_customers),
       (SELECT COUNT(*) FROM dim_customer WHERE load_batch_id = BATCH_ID()),
       0, 'SUCCESS';

-- Audit untuk supporting dimensions seperti promotion, payment method,
-- channel, supplier, fulfilment center, dan distribution center.
INSERT INTO etl_audit_log (batch_id, process_name, source_table, target_table, rows_extracted, rows_loaded, rows_rejected, status)
SELECT BATCH_ID(), 'load_supporting_dimensions', 'trf_supporting', 'supporting_dimensions',
       (SELECT COUNT(*) FROM trf_promotions) + (SELECT COUNT(*) FROM trf_payment_methods) +
       (SELECT COUNT(*) FROM trf_channels) + (SELECT COUNT(*) FROM trf_suppliers) +
       (SELECT COUNT(*) FROM trf_fulfilment_centers) + (SELECT COUNT(*) FROM trf_distribution_centers),
       (SELECT COUNT(*) FROM dim_promotion WHERE load_batch_id = BATCH_ID()) +
       (SELECT COUNT(*) FROM dim_payment_method WHERE load_batch_id = BATCH_ID()) +
       (SELECT COUNT(*) FROM dim_channel WHERE load_batch_id = BATCH_ID()) +
       (SELECT COUNT(*) FROM dim_supplier WHERE load_batch_id = BATCH_ID()) +
       (SELECT COUNT(*) FROM dim_fulfilment_center WHERE load_batch_id = BATCH_ID()) +
       (SELECT COUNT(*) FROM dim_distribution_center WHERE load_batch_id = BATCH_ID()),
       0, 'SUCCESS';
