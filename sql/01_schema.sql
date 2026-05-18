PRAGMA foreign_keys = ON;

DROP TABLE IF EXISTS fact_procurement;
DROP TABLE IF EXISTS fact_delivery_performance;
DROP TABLE IF EXISTS fact_inventory_daily;
DROP TABLE IF EXISTS fact_online_orders;
DROP TABLE IF EXISTS fact_sales;
DROP TABLE IF EXISTS dim_distribution_center;
DROP TABLE IF EXISTS dim_fulfilment_center;
DROP TABLE IF EXISTS dim_supplier;
DROP TABLE IF EXISTS dim_channel;
DROP TABLE IF EXISTS dim_payment_method;
DROP TABLE IF EXISTS dim_promotion;
DROP TABLE IF EXISTS dim_customer;
DROP TABLE IF EXISTS dim_product;
DROP TABLE IF EXISTS dim_store;
DROP TABLE IF EXISTS dim_date;
DROP TABLE IF EXISTS etl_error_log;
DROP TABLE IF EXISTS etl_audit_log;

CREATE TABLE etl_error_log (
    error_id INTEGER PRIMARY KEY AUTOINCREMENT,
    source_table TEXT NOT NULL,
    source_id TEXT,
    error_type TEXT NOT NULL,
    error_description TEXT NOT NULL,
    raw_payload TEXT,
    error_date TEXT DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE etl_audit_log (
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

CREATE TABLE dim_date (
    date_key INTEGER PRIMARY KEY,
    full_date TEXT NOT NULL UNIQUE,
    year INTEGER NOT NULL,
    quarter INTEGER NOT NULL,
    month INTEGER NOT NULL,
    month_name TEXT NOT NULL,
    day INTEGER NOT NULL,
    day_of_week TEXT NOT NULL
);

CREATE TABLE dim_store (
    store_key INTEGER PRIMARY KEY AUTOINCREMENT,
    store_id TEXT NOT NULL UNIQUE,
    store_name TEXT,
    store_type TEXT,
    city TEXT,
    state TEXT,
    region TEXT,
    store_area_sqm REAL,
    staff_count INTEGER,
    open_date_key INTEGER,
    FOREIGN KEY (open_date_key) REFERENCES dim_date(date_key)
);

CREATE TABLE dim_product (
    product_key INTEGER PRIMARY KEY AUTOINCREMENT,
    product_id TEXT NOT NULL UNIQUE,
    product_name TEXT,
    brand TEXT,
    category TEXT,
    subcategory TEXT,
    unit_price REAL,
    unit_cost REAL,
    is_active INTEGER
);

CREATE TABLE dim_customer (
    customer_key INTEGER PRIMARY KEY AUTOINCREMENT,
    customer_id TEXT NOT NULL UNIQUE,
    gender TEXT,
    birth_year INTEGER,
    age_group TEXT,
    membership_type TEXT,
    city TEXT,
    email TEXT,
    join_date_key INTEGER,
    FOREIGN KEY (join_date_key) REFERENCES dim_date(date_key)
);

CREATE TABLE dim_promotion (
    promotion_key INTEGER PRIMARY KEY AUTOINCREMENT,
    promotion_id TEXT NOT NULL UNIQUE,
    promotion_name TEXT,
    promotion_type TEXT,
    discount_rate REAL,
    start_date_key INTEGER,
    end_date_key INTEGER,
    FOREIGN KEY (start_date_key) REFERENCES dim_date(date_key),
    FOREIGN KEY (end_date_key) REFERENCES dim_date(date_key)
);

CREATE TABLE dim_payment_method (
    payment_method_key INTEGER PRIMARY KEY AUTOINCREMENT,
    payment_method_id TEXT NOT NULL UNIQUE,
    payment_type TEXT,
    provider TEXT,
    is_online_supported INTEGER
);

CREATE TABLE dim_channel (
    channel_key INTEGER PRIMARY KEY AUTOINCREMENT,
    channel_id TEXT NOT NULL UNIQUE,
    channel_name TEXT,
    channel_group TEXT,
    description TEXT
);

CREATE TABLE dim_supplier (
    supplier_key INTEGER PRIMARY KEY AUTOINCREMENT,
    supplier_id TEXT NOT NULL UNIQUE,
    supplier_name TEXT,
    supplier_type TEXT,
    city TEXT,
    state TEXT,
    lead_time_days INTEGER
);

CREATE TABLE dim_fulfilment_center (
    fulfilment_center_key INTEGER PRIMARY KEY AUTOINCREMENT,
    fulfilment_center_id TEXT NOT NULL UNIQUE,
    fulfilment_center_name TEXT,
    city TEXT,
    state TEXT,
    capacity_orders_per_day INTEGER
);

CREATE TABLE dim_distribution_center (
    distribution_center_key INTEGER PRIMARY KEY AUTOINCREMENT,
    distribution_center_id TEXT NOT NULL UNIQUE,
    distribution_center_name TEXT,
    city TEXT,
    state TEXT,
    warehouse_area_sqm REAL
);

CREATE TABLE fact_sales (
    sales_key INTEGER PRIMARY KEY AUTOINCREMENT,
    transaction_id TEXT NOT NULL,
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
    currency TEXT,
    FOREIGN KEY (date_key) REFERENCES dim_date(date_key),
    FOREIGN KEY (store_key) REFERENCES dim_store(store_key),
    FOREIGN KEY (product_key) REFERENCES dim_product(product_key),
    FOREIGN KEY (customer_key) REFERENCES dim_customer(customer_key),
    FOREIGN KEY (promotion_key) REFERENCES dim_promotion(promotion_key),
    FOREIGN KEY (payment_method_key) REFERENCES dim_payment_method(payment_method_key),
    FOREIGN KEY (channel_key) REFERENCES dim_channel(channel_key)
);

CREATE TABLE fact_online_orders (
    online_order_key INTEGER PRIMARY KEY AUTOINCREMENT,
    online_order_id TEXT NOT NULL UNIQUE,
    order_date_key INTEGER NOT NULL,
    customer_key INTEGER NOT NULL,
    fulfilment_center_key INTEGER NOT NULL,
    channel_key INTEGER NOT NULL,
    item_count INTEGER NOT NULL,
    order_value REAL NOT NULL,
    delivery_fee REAL,
    order_status TEXT,
    fulfilled_flag INTEGER,
    FOREIGN KEY (order_date_key) REFERENCES dim_date(date_key),
    FOREIGN KEY (customer_key) REFERENCES dim_customer(customer_key),
    FOREIGN KEY (fulfilment_center_key) REFERENCES dim_fulfilment_center(fulfilment_center_key),
    FOREIGN KEY (channel_key) REFERENCES dim_channel(channel_key)
);

CREATE TABLE fact_inventory_daily (
    inventory_key INTEGER PRIMARY KEY AUTOINCREMENT,
    inventory_record_id TEXT NOT NULL,
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
    FOREIGN KEY (snapshot_date_key) REFERENCES dim_date(date_key),
    FOREIGN KEY (store_key) REFERENCES dim_store(store_key),
    FOREIGN KEY (product_key) REFERENCES dim_product(product_key)
);

CREATE TABLE fact_delivery_performance (
    delivery_key INTEGER PRIMARY KEY AUTOINCREMENT,
    delivery_id TEXT NOT NULL,
    online_order_key INTEGER NOT NULL,
    promised_date_key INTEGER NOT NULL,
    actual_date_key INTEGER NOT NULL,
    delivery_partner TEXT,
    delivery_status TEXT,
    delivery_time_minutes INTEGER,
    delay_minutes INTEGER NOT NULL,
    on_time_flag INTEGER NOT NULL,
    order_accuracy_flag INTEGER,
    FOREIGN KEY (online_order_key) REFERENCES fact_online_orders(online_order_key),
    FOREIGN KEY (promised_date_key) REFERENCES dim_date(date_key),
    FOREIGN KEY (actual_date_key) REFERENCES dim_date(date_key)
);

CREATE TABLE fact_procurement (
    procurement_key INTEGER PRIMARY KEY AUTOINCREMENT,
    purchase_order_id TEXT NOT NULL,
    purchase_order_date_key INTEGER NOT NULL,
    supplier_key INTEGER NOT NULL,
    distribution_center_key INTEGER NOT NULL,
    product_key INTEGER NOT NULL,
    ordered_qty REAL NOT NULL,
    received_qty REAL NOT NULL,
    purchase_amount REAL NOT NULL,
    expected_receipt_date_key INTEGER,
    actual_receipt_date_key INTEGER,
    late_delivery_flag INTEGER,
    po_status TEXT,
    FOREIGN KEY (purchase_order_date_key) REFERENCES dim_date(date_key),
    FOREIGN KEY (supplier_key) REFERENCES dim_supplier(supplier_key),
    FOREIGN KEY (distribution_center_key) REFERENCES dim_distribution_center(distribution_center_key),
    FOREIGN KEY (product_key) REFERENCES dim_product(product_key),
    FOREIGN KEY (expected_receipt_date_key) REFERENCES dim_date(date_key),
    FOREIGN KEY (actual_receipt_date_key) REFERENCES dim_date(date_key)
);
