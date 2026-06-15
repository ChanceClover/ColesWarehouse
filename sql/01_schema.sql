-- File ini menyiapkan struktur utama data warehouse.
-- Isinya mencakup tabel audit ETL, tabel data quality, mapping nilai standar,
-- tabel dimensi, tabel fakta, serta baris default untuk nilai Unknown.

-- Mengaktifkan pengecekan foreign key di SQLite agar relasi antar tabel lebih aman.
PRAGMA foreign_keys = ON;

-- Menyimpan informasi setiap proses ETL, seperti batch id, mode load, waktu mulai,
-- waktu selesai, dan status proses.
CREATE TABLE IF NOT EXISTS etl_load_batch (
    batch_id TEXT PRIMARY KEY,
    run_mode TEXT NOT NULL,
    source_database TEXT,
    started_at TEXT DEFAULT CURRENT_TIMESTAMP,
    completed_at TEXT,
    status TEXT NOT NULL DEFAULT 'RUNNING'
);

-- Menyimpan error teknis atau data bermasalah yang ditemukan selama proses ETL.
CREATE TABLE IF NOT EXISTS etl_error_log (
    error_id INTEGER PRIMARY KEY AUTOINCREMENT,
    batch_id TEXT NOT NULL,
    source_table TEXT NOT NULL,
    source_id TEXT,
    error_type TEXT NOT NULL,
    error_description TEXT NOT NULL,
    raw_payload TEXT,
    error_date TEXT DEFAULT CURRENT_TIMESTAMP
);

-- Menyimpan isu kualitas data secara lebih terstruktur, misalnya missing key,
-- duplikasi business key, invalid date, atau lookup yang tidak ditemukan.
CREATE TABLE IF NOT EXISTS data_quality_issue (
    issue_id INTEGER PRIMARY KEY AUTOINCREMENT,
    batch_id TEXT NOT NULL,
    layer_name TEXT NOT NULL,
    source_table TEXT NOT NULL,
    source_id TEXT,
    issue_code TEXT NOT NULL,
    issue_message TEXT NOT NULL,
    severity TEXT NOT NULL,
    created_at TEXT DEFAULT CURRENT_TIMESTAMP
);

-- Menyimpan ringkasan audit per proses ETL, termasuk jumlah row yang diekstrak,
-- berhasil dimuat, ditolak, dan status prosesnya.
CREATE TABLE IF NOT EXISTS etl_audit_log (
    audit_id INTEGER PRIMARY KEY AUTOINCREMENT,
    batch_id TEXT NOT NULL,
    process_name TEXT NOT NULL,
    source_table TEXT,
    target_table TEXT,
    rows_extracted INTEGER DEFAULT 0,
    rows_loaded INTEGER DEFAULT 0,
    rows_rejected INTEGER DEFAULT 0,
    status TEXT NOT NULL,
    created_at TEXT DEFAULT CURRENT_TIMESTAMP
);

-- Tabel mapping untuk menyeragamkan nilai teks yang berbeda penulisannya,
-- contohnya "super market" menjadi "Supermarket".
CREATE TABLE IF NOT EXISTS map_standard_value (
    map_group TEXT NOT NULL,
    raw_value TEXT NOT NULL,
    standard_value TEXT NOT NULL,
    PRIMARY KEY (map_group, raw_value)
);

-- Mengisi mapping standar yang dipakai saat proses cleansing dan transformasi data.
INSERT OR IGNORE INTO map_standard_value VALUES
('store_type', 'super market', 'Supermarket'),
('store_type', 'supermarket', 'Supermarket'),
('store_type', 'liquor', 'Liquor'),
('store_type', 'express', 'Express'),
('store_type', 'online hub', 'Online Hub'),
('product_category', 'dairy', 'Dairy'),
('product_category', 'bakery', 'Bakery'),
('product_category', 'frozen', 'Frozen'),
('product_category', 'fresh produce', 'Fresh Produce'),
('product_category', 'meat & seafood', 'Meat & Seafood'),
('product_category', 'beverages', 'Beverages'),
('product_category', 'household', 'Household'),
('product_category', 'pantry', 'Pantry'),
('product_category', 'misc', 'Misc'),
('promotion_type', 'discountt', 'Percentage Discount'),
('promotion_type', 'percentage discount', 'Percentage Discount'),
('promotion_type', 'clearance', 'Clearance'),
('promotion_type', 'seasonal', 'Seasonal'),
('promotion_type', 'free delivery', 'Free Delivery'),
('promotion_type', 'loyalty points', 'Loyalty Points'),
('channel_name', 'store', 'Store'),
('channel_name', 'ecommerce', 'eCommerce'),
('channel_name', 'e-commerce', 'eCommerce'),
('channel_name', 'click & collect', 'Click & Collect'),
('channel_name', 'home delivery', 'Home Delivery'),
('channel_name', 'mobile app', 'Mobile App'),
('order_status', 'recieved', 'received'),
('order_status', 'received', 'received'),
('order_status', 'processing', 'processing'),
('order_status', 'fulfilled', 'fulfilled'),
('order_status', 'cancelled', 'cancelled'),
('delivery_status', 'delivred', 'delivered'),
('delivery_status', 'delivered', 'delivered'),
('delivery_status', 'in transit', 'in transit'),
('delivery_status', 'failed', 'failed'),
('po_status', 'recieved', 'received'),
('po_status', 'received', 'received'),
('po_status', 'ordered', 'ordered'),
('po_status', 'cancelled', 'cancelled');

-- Dimensi tanggal untuk analisis berdasarkan hari, bulan, kuartal, tahun,
-- weekend, dan periode fiskal.
CREATE TABLE IF NOT EXISTS dim_date (
    date_key INTEGER PRIMARY KEY,
    full_date TEXT NOT NULL UNIQUE,
    year INTEGER NOT NULL,
    quarter INTEGER NOT NULL,
    quarter_name TEXT NOT NULL,
    month INTEGER NOT NULL,
    month_name TEXT NOT NULL,
    year_month TEXT NOT NULL,
    week_number INTEGER NOT NULL,
    day INTEGER NOT NULL,
    day_of_week TEXT NOT NULL,
    day_of_week_number INTEGER NOT NULL,
    is_weekend INTEGER NOT NULL,
    month_start_date TEXT NOT NULL,
    month_end_date TEXT NOT NULL,
    fiscal_year INTEGER NOT NULL,
    fiscal_quarter INTEGER NOT NULL,
    load_batch_id TEXT
);

-- Dimensi toko. Tabel ini memakai SCD Type 2 agar perubahan atribut toko
-- bisa disimpan sebagai histori, bukan menimpa data lama.
CREATE TABLE IF NOT EXISTS dim_store (
    store_key INTEGER PRIMARY KEY AUTOINCREMENT,
    store_id TEXT NOT NULL,
    store_name TEXT,
    store_type TEXT,
    city TEXT,
    state TEXT,
    region TEXT,
    store_area_sqm REAL,
    staff_count INTEGER,
    open_date_key INTEGER,
    effective_start_date_key INTEGER NOT NULL,
    effective_end_date_key INTEGER,
    is_current INTEGER NOT NULL DEFAULT 1,
    load_batch_id TEXT,
    loaded_at TEXT DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (store_id, effective_start_date_key),
    FOREIGN KEY (open_date_key) REFERENCES dim_date(date_key)
);

-- Dimensi produk. Memuat atribut produk dan disiapkan untuk histori perubahan
-- harga, kategori, brand, dan status aktif.
CREATE TABLE IF NOT EXISTS dim_product (
    product_key INTEGER PRIMARY KEY AUTOINCREMENT,
    product_id TEXT NOT NULL,
    product_name TEXT,
    brand TEXT,
    category TEXT,
    subcategory TEXT,
    unit_price REAL,
    unit_cost REAL,
    is_active INTEGER,
    effective_start_date_key INTEGER NOT NULL,
    effective_end_date_key INTEGER,
    is_current INTEGER NOT NULL DEFAULT 1,
    load_batch_id TEXT,
    loaded_at TEXT DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (product_id, effective_start_date_key)
);

-- Dimensi customer. Menyimpan profil customer dan mendukung histori perubahan
-- atribut seperti membership, kota, atau email.
CREATE TABLE IF NOT EXISTS dim_customer (
    customer_key INTEGER PRIMARY KEY AUTOINCREMENT,
    customer_id TEXT NOT NULL,
    gender TEXT,
    birth_year INTEGER,
    age_group TEXT,
    membership_type TEXT,
    city TEXT,
    email TEXT,
    join_date_key INTEGER,
    effective_start_date_key INTEGER NOT NULL,
    effective_end_date_key INTEGER,
    is_current INTEGER NOT NULL DEFAULT 1,
    load_batch_id TEXT,
    loaded_at TEXT DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (customer_id, effective_start_date_key),
    FOREIGN KEY (join_date_key) REFERENCES dim_date(date_key)
);

-- Dimensi promosi untuk menghubungkan transaksi penjualan dengan jenis diskon
-- atau campaign tertentu.
CREATE TABLE IF NOT EXISTS dim_promotion (
    promotion_key INTEGER PRIMARY KEY AUTOINCREMENT,
    promotion_id TEXT NOT NULL UNIQUE,
    promotion_name TEXT,
    promotion_type TEXT,
    discount_rate REAL,
    start_date_key INTEGER,
    end_date_key INTEGER,
    load_batch_id TEXT,
    loaded_at TEXT DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (start_date_key) REFERENCES dim_date(date_key),
    FOREIGN KEY (end_date_key) REFERENCES dim_date(date_key)
);

-- Dimensi metode pembayaran untuk mengelompokkan transaksi berdasarkan tipe
-- pembayaran dan provider.
CREATE TABLE IF NOT EXISTS dim_payment_method (
    payment_method_key INTEGER PRIMARY KEY AUTOINCREMENT,
    payment_method_id TEXT NOT NULL UNIQUE,
    payment_type TEXT,
    provider TEXT,
    is_online_supported INTEGER,
    load_batch_id TEXT,
    loaded_at TEXT DEFAULT CURRENT_TIMESTAMP
);

-- Dimensi channel untuk membedakan sumber transaksi, misalnya store,
-- eCommerce, mobile app, click and collect, atau home delivery.
CREATE TABLE IF NOT EXISTS dim_channel (
    channel_key INTEGER PRIMARY KEY AUTOINCREMENT,
    channel_id TEXT NOT NULL UNIQUE,
    channel_name TEXT,
    channel_group TEXT,
    description TEXT,
    load_batch_id TEXT,
    loaded_at TEXT DEFAULT CURRENT_TIMESTAMP
);

-- Dimensi supplier. Tabel ini juga memakai SCD Type 2 agar perubahan informasi
-- supplier bisa dilacak.
CREATE TABLE IF NOT EXISTS dim_supplier (
    supplier_key INTEGER PRIMARY KEY AUTOINCREMENT,
    supplier_id TEXT NOT NULL,
    supplier_name TEXT,
    supplier_type TEXT,
    city TEXT,
    state TEXT,
    lead_time_days INTEGER,
    effective_start_date_key INTEGER NOT NULL,
    effective_end_date_key INTEGER,
    is_current INTEGER NOT NULL DEFAULT 1,
    load_batch_id TEXT,
    loaded_at TEXT DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (supplier_id, effective_start_date_key)
);

-- Dimensi fulfilment center untuk pesanan online dan operasional fulfilment.
CREATE TABLE IF NOT EXISTS dim_fulfilment_center (
    fulfilment_center_key INTEGER PRIMARY KEY AUTOINCREMENT,
    fulfilment_center_id TEXT NOT NULL UNIQUE,
    fulfilment_center_name TEXT,
    city TEXT,
    state TEXT,
    capacity_orders_per_day INTEGER,
    load_batch_id TEXT,
    loaded_at TEXT DEFAULT CURRENT_TIMESTAMP
);

-- Dimensi distribution center untuk proses procurement dan distribusi barang.
CREATE TABLE IF NOT EXISTS dim_distribution_center (
    distribution_center_key INTEGER PRIMARY KEY AUTOINCREMENT,
    distribution_center_id TEXT NOT NULL UNIQUE,
    distribution_center_name TEXT,
    city TEXT,
    state TEXT,
    warehouse_area_sqm REAL,
    load_batch_id TEXT,
    loaded_at TEXT DEFAULT CURRENT_TIMESTAMP
);

-- Fact sales menyimpan transaksi penjualan toko maupun channel terkait.
-- Tabel ini berisi measure utama seperti quantity, net sales, cost, profit, dan margin.
CREATE TABLE IF NOT EXISTS fact_sales (
    sales_key INTEGER PRIMARY KEY AUTOINCREMENT,
    transaction_id TEXT NOT NULL UNIQUE,
    date_key INTEGER NOT NULL,
    store_key INTEGER NOT NULL,
    product_key INTEGER NOT NULL,
    customer_key INTEGER NOT NULL,
    promotion_key INTEGER,
    payment_method_key INTEGER NOT NULL,
    channel_key INTEGER NOT NULL,
    quantity_sold REAL NOT NULL,
    unit_price REAL,
    total_sales_amount REAL NOT NULL,
    discount_amount REAL NOT NULL,
    net_sales REAL NOT NULL,
    sales_cost REAL NOT NULL,
    gross_profit REAL NOT NULL,
    gross_margin_pct REAL,
    discount_pct REAL,
    currency TEXT,
    load_batch_id TEXT,
    loaded_at TEXT DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (date_key) REFERENCES dim_date(date_key),
    FOREIGN KEY (store_key) REFERENCES dim_store(store_key),
    FOREIGN KEY (product_key) REFERENCES dim_product(product_key),
    FOREIGN KEY (customer_key) REFERENCES dim_customer(customer_key),
    FOREIGN KEY (promotion_key) REFERENCES dim_promotion(promotion_key),
    FOREIGN KEY (payment_method_key) REFERENCES dim_payment_method(payment_method_key),
    FOREIGN KEY (channel_key) REFERENCES dim_channel(channel_key)
);

-- Fact online orders menyimpan transaksi order online dan status fulfilment-nya.
CREATE TABLE IF NOT EXISTS fact_online_orders (
    online_order_key INTEGER PRIMARY KEY AUTOINCREMENT,
    online_order_id TEXT NOT NULL UNIQUE,
    order_date_key INTEGER NOT NULL,
    customer_key INTEGER NOT NULL,
    fulfilment_center_key INTEGER NOT NULL,
    channel_key INTEGER NOT NULL,
    item_count INTEGER NOT NULL,
    order_value REAL NOT NULL,
    delivery_fee REAL,
    total_order_value REAL NOT NULL,
    order_status TEXT,
    fulfilled_flag INTEGER,
    load_batch_id TEXT,
    loaded_at TEXT DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (order_date_key) REFERENCES dim_date(date_key),
    FOREIGN KEY (customer_key) REFERENCES dim_customer(customer_key),
    FOREIGN KEY (fulfilment_center_key) REFERENCES dim_fulfilment_center(fulfilment_center_key),
    FOREIGN KEY (channel_key) REFERENCES dim_channel(channel_key)
);

-- Fact inventory daily menyimpan posisi stok harian dan perhitungan selisih stok.
CREATE TABLE IF NOT EXISTS fact_inventory_daily (
    inventory_key INTEGER PRIMARY KEY AUTOINCREMENT,
    inventory_record_id TEXT NOT NULL UNIQUE,
    snapshot_date_key INTEGER NOT NULL,
    store_key INTEGER NOT NULL,
    product_key INTEGER NOT NULL,
    opening_stock REAL NOT NULL,
    stock_in REAL NOT NULL,
    stock_out REAL NOT NULL,
    stock_loss REAL NOT NULL,
    closing_stock REAL NOT NULL,
    calculated_closing_stock REAL NOT NULL,
    stock_variance REAL NOT NULL,
    stock_variance_abs REAL NOT NULL,
    shrinkage_rate REAL,
    load_batch_id TEXT,
    loaded_at TEXT DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (snapshot_date_key) REFERENCES dim_date(date_key),
    FOREIGN KEY (store_key) REFERENCES dim_store(store_key),
    FOREIGN KEY (product_key) REFERENCES dim_product(product_key)
);

-- Fact delivery performance menyimpan performa pengiriman, keterlambatan,
-- status delivery, dan akurasi order.
CREATE TABLE IF NOT EXISTS fact_delivery_performance (
    delivery_key INTEGER PRIMARY KEY AUTOINCREMENT,
    delivery_id TEXT NOT NULL UNIQUE,
    online_order_key INTEGER NOT NULL,
    promised_date_key INTEGER NOT NULL,
    actual_date_key INTEGER NOT NULL,
    delivery_partner TEXT,
    delivery_status TEXT,
    delivery_time_minutes INTEGER,
    delay_minutes INTEGER NOT NULL,
    delay_hours REAL NOT NULL,
    on_time_flag INTEGER NOT NULL,
    order_accuracy_flag INTEGER,
    load_batch_id TEXT,
    loaded_at TEXT DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (online_order_key) REFERENCES fact_online_orders(online_order_key),
    FOREIGN KEY (promised_date_key) REFERENCES dim_date(date_key),
    FOREIGN KEY (actual_date_key) REFERENCES dim_date(date_key)
);

-- Fact procurement menyimpan pembelian dari supplier, penerimaan barang,
-- fill rate, nilai pembelian, dan keterlambatan receipt.
CREATE TABLE IF NOT EXISTS fact_procurement (
    procurement_key INTEGER PRIMARY KEY AUTOINCREMENT,
    purchase_order_id TEXT NOT NULL UNIQUE,
    purchase_order_date_key INTEGER NOT NULL,
    supplier_key INTEGER NOT NULL,
    distribution_center_key INTEGER NOT NULL,
    product_key INTEGER NOT NULL,
    ordered_qty REAL NOT NULL,
    received_qty REAL NOT NULL,
    fill_rate REAL,
    purchase_amount REAL NOT NULL,
    expected_receipt_date_key INTEGER,
    actual_receipt_date_key INTEGER,
    late_delivery_flag INTEGER,
    receipt_delay_days INTEGER,
    po_status TEXT,
    load_batch_id TEXT,
    loaded_at TEXT DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (purchase_order_date_key) REFERENCES dim_date(date_key),
    FOREIGN KEY (supplier_key) REFERENCES dim_supplier(supplier_key),
    FOREIGN KEY (distribution_center_key) REFERENCES dim_distribution_center(distribution_center_key),
    FOREIGN KEY (product_key) REFERENCES dim_product(product_key),
    FOREIGN KEY (expected_receipt_date_key) REFERENCES dim_date(date_key),
    FOREIGN KEY (actual_receipt_date_key) REFERENCES dim_date(date_key)
);

-- Membuat catatan batch ETL yang sedang berjalan.
INSERT OR IGNORE INTO etl_load_batch (batch_id, run_mode, source_database, status)
VALUES (BATCH_ID(), RUN_MODE(), 'raw attached database', 'RUNNING');

-- Menambahkan baris default Unknown pada setiap dimensi.
-- Baris ini dipakai ketika lookup dimensi gagal, supaya fact table tetap bisa dimuat.
INSERT OR IGNORE INTO dim_date (
    date_key, full_date, year, quarter, quarter_name, month, month_name, year_month,
    week_number, day, day_of_week, day_of_week_number, is_weekend,
    month_start_date, month_end_date, fiscal_year, fiscal_quarter, load_batch_id
)
VALUES (
    0, '1900-01-01', 1900, 1, 'Q1', 1, 'Unknown', '1900-01',
    0, 1, 'Unknown', 0, 0, '1900-01-01', '1900-01-31', 1900, 1, BATCH_ID()
);

INSERT OR IGNORE INTO dim_store (
    store_key, store_id, store_name, store_type, city, state, region,
    store_area_sqm, staff_count, open_date_key, effective_start_date_key,
    effective_end_date_key, is_current, load_batch_id
) VALUES (0, 'UNKNOWN', 'Unknown Store', 'Unknown', 'Unknown', 'Unknown', 'Unknown', 0, 0, 0, 0, NULL, 1, BATCH_ID());

INSERT OR IGNORE INTO dim_product (
    product_key, product_id, product_name, brand, category, subcategory,
    unit_price, unit_cost, is_active, effective_start_date_key,
    effective_end_date_key, is_current, load_batch_id
) VALUES (0, 'UNKNOWN', 'Unknown Product', 'Unknown', 'Unknown', 'Unknown', 0, 0, 0, 0, NULL, 1, BATCH_ID());

INSERT OR IGNORE INTO dim_customer (
    customer_key, customer_id, gender, birth_year, age_group, membership_type,
    city, email, join_date_key, effective_start_date_key, effective_end_date_key,
    is_current, load_batch_id
) VALUES (0, 'UNKNOWN', 'Unknown', NULL, 'Unknown', 'Unknown', 'Unknown', 'Unknown', 0, 0, NULL, 1, BATCH_ID());

INSERT OR IGNORE INTO dim_promotion (
    promotion_key, promotion_id, promotion_name, promotion_type, discount_rate,
    start_date_key, end_date_key, load_batch_id
) VALUES (0, 'NONE', 'No Promotion', 'None', 0, 0, 0, BATCH_ID());

INSERT OR IGNORE INTO dim_payment_method (
    payment_method_key, payment_method_id, payment_type, provider, is_online_supported, load_batch_id
) VALUES (0, 'UNKNOWN', 'Unknown', 'Unknown', 0, BATCH_ID());

INSERT OR IGNORE INTO dim_channel (
    channel_key, channel_id, channel_name, channel_group, description, load_batch_id
) VALUES (0, 'UNKNOWN', 'Unknown', 'Unknown', 'Unknown channel', BATCH_ID());

INSERT OR IGNORE INTO dim_supplier (
    supplier_key, supplier_id, supplier_name, supplier_type, city, state,
    lead_time_days, effective_start_date_key, effective_end_date_key, is_current, load_batch_id
) VALUES (0, 'UNKNOWN', 'Unknown Supplier', 'Unknown', 'Unknown', 'Unknown', 0, 0, NULL, 1, BATCH_ID());

INSERT OR IGNORE INTO dim_fulfilment_center (
    fulfilment_center_key, fulfilment_center_id, fulfilment_center_name, city, state, capacity_orders_per_day, load_batch_id
) VALUES (0, 'UNKNOWN', 'Unknown Fulfilment Center', 'Unknown', 'Unknown', 0, BATCH_ID());

INSERT OR IGNORE INTO dim_distribution_center (
    distribution_center_key, distribution_center_id, distribution_center_name, city, state, warehouse_area_sqm, load_batch_id
) VALUES (0, 'UNKNOWN', 'Unknown Distribution Center', 'Unknown', 'Unknown', 0, BATCH_ID());
