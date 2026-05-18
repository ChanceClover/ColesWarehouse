DROP TABLE IF EXISTS stg_stores;
DROP TABLE IF EXISTS stg_products;
DROP TABLE IF EXISTS stg_customers;
DROP TABLE IF EXISTS stg_promotions;
DROP TABLE IF EXISTS stg_payment_methods;
DROP TABLE IF EXISTS stg_channels;
DROP TABLE IF EXISTS stg_suppliers;
DROP TABLE IF EXISTS stg_fulfilment_centers;
DROP TABLE IF EXISTS stg_distribution_centers;
DROP TABLE IF EXISTS stg_sales;
DROP TABLE IF EXISTS stg_online_orders;
DROP TABLE IF EXISTS stg_inventory;
DROP TABLE IF EXISTS stg_delivery;
DROP TABLE IF EXISTS stg_procurement;

CREATE TABLE stg_stores AS
WITH base AS (
    SELECT
        ROW_NUMBER() OVER () AS source_row_id,
        CLEAN_ID(store_id) AS store_id,
        CLEAN_TEXT(store_name) AS store_name,
        CASE LOWER(CLEAN_TEXT(store_type))
            WHEN 'super market' THEN 'Supermarket'
            WHEN 'supermarket' THEN 'Supermarket'
            WHEN 'liquor' THEN 'Liquor'
            WHEN 'express' THEN 'Express'
            WHEN 'online hub' THEN 'Online Hub'
            ELSE COALESCE(CLEAN_TEXT(store_type), 'Unknown')
        END AS store_type,
        CLEAN_TEXT(city) AS city,
        CLEAN_ID(state) AS state,
        CLEAN_TEXT(region) AS region,
        CASE WHEN NUM(store_area_sqm) >= 0 THEN NUM(store_area_sqm) END AS store_area_sqm,
        CASE WHEN INT_NUM(staff_count) >= 0 THEN INT_NUM(staff_count) END AS staff_count,
        PARSE_DATE(open_date) AS open_date,
        store_id AS raw_store_id
    FROM raw.raw_stores
),
ranked AS (
    SELECT base.*, ROW_NUMBER() OVER (PARTITION BY store_id ORDER BY source_row_id) AS rn
    FROM base
)
SELECT *,
    CASE WHEN store_id IS NOT NULL AND rn = 1 THEN 1 ELSE 0 END AS is_valid,
    TRIM(
        CASE WHEN store_id IS NULL THEN 'missing store_id; ' ELSE '' END ||
        CASE WHEN rn > 1 THEN 'duplicate store_id; ' ELSE '' END
    ) AS error_reason
FROM ranked;

CREATE TABLE stg_products AS
WITH base AS (
    SELECT
        ROW_NUMBER() OVER () AS source_row_id,
        CLEAN_ID(product_id) AS product_id,
        CLEAN_TEXT(product_name) AS product_name,
        COALESCE(CLEAN_TEXT(brand), 'Unknown') AS brand,
        CASE LOWER(CLEAN_TEXT(category))
            WHEN 'dairy' THEN 'Dairy'
            WHEN 'bakery' THEN 'Bakery'
            WHEN 'frozen' THEN 'Frozen'
            WHEN 'fresh produce' THEN 'Fresh Produce'
            WHEN 'meat & seafood' THEN 'Meat & Seafood'
            WHEN 'beverages' THEN 'Beverages'
            WHEN 'household' THEN 'Household'
            WHEN 'pantry' THEN 'Pantry'
            WHEN 'misc' THEN 'Misc'
            ELSE COALESCE(CLEAN_TEXT(category), 'Unknown')
        END AS category,
        COALESCE(CLEAN_TEXT(subcategory), 'Unknown') AS subcategory,
        NUM(unit_price) AS unit_price,
        NUM(unit_cost) AS unit_cost,
        CLEAN_BOOL(is_active) AS is_active
    FROM raw.raw_products
),
ranked AS (
    SELECT base.*, ROW_NUMBER() OVER (PARTITION BY product_id ORDER BY source_row_id) AS rn
    FROM base
)
SELECT *,
    CASE
        WHEN product_id IS NULL OR rn > 1 OR unit_price IS NULL OR unit_price < 0 OR unit_cost IS NULL OR unit_cost < 0 THEN 0
        ELSE 1
    END AS is_valid,
    TRIM(
        CASE WHEN product_id IS NULL THEN 'missing product_id; ' ELSE '' END ||
        CASE WHEN rn > 1 THEN 'duplicate product_id; ' ELSE '' END ||
        CASE WHEN unit_price IS NULL OR unit_price < 0 THEN 'invalid unit_price; ' ELSE '' END ||
        CASE WHEN unit_cost IS NULL OR unit_cost < 0 THEN 'invalid unit_cost; ' ELSE '' END
    ) AS error_reason
FROM ranked;

CREATE TABLE stg_customers AS
WITH base AS (
    SELECT
        ROW_NUMBER() OVER () AS source_row_id,
        CLEAN_ID(customer_id) AS customer_id,
        CASE LOWER(CLEAN_TEXT(gender))
            WHEN 'm' THEN 'Male'
            WHEN 'male' THEN 'Male'
            WHEN 'f' THEN 'Female'
            WHEN 'female' THEN 'Female'
            WHEN 'other' THEN 'Other'
            ELSE 'Unknown'
        END AS gender,
        INT_NUM(birth_year) AS birth_year,
        CASE
            WHEN INT_NUM(birth_year) BETWEEN 2011 AND 2026 THEN 'Under 18'
            WHEN INT_NUM(birth_year) BETWEEN 1997 AND 2010 THEN '18-29'
            WHEN INT_NUM(birth_year) BETWEEN 1981 AND 1996 THEN '30-45'
            WHEN INT_NUM(birth_year) BETWEEN 1961 AND 1980 THEN '46-65'
            WHEN INT_NUM(birth_year) BETWEEN 1900 AND 1960 THEN '65+'
            ELSE 'Unknown'
        END AS age_group,
        CASE LOWER(CLEAN_TEXT(membership_type))
            WHEN 'bronze' THEN 'Bronze'
            WHEN 'silver' THEN 'Silver'
            WHEN 'gold' THEN 'Gold'
            WHEN 'platinum' THEN 'Platinum'
            WHEN 'none' THEN 'None'
            ELSE 'None'
        END AS membership_type,
        CLEAN_TEXT(city) AS city,
        CASE WHEN CLEAN_TEXT(email) LIKE '%_@_%._%' THEN CLEAN_TEXT(email) END AS email,
        PARSE_DATE(join_date) AS join_date
    FROM raw.raw_customers
),
ranked AS (
    SELECT base.*, ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY source_row_id) AS rn
    FROM base
)
SELECT *,
    CASE WHEN customer_id IS NOT NULL AND rn = 1 AND birth_year BETWEEN 1900 AND 2026 THEN 1 ELSE 0 END AS is_valid,
    TRIM(
        CASE WHEN customer_id IS NULL THEN 'missing customer_id; ' ELSE '' END ||
        CASE WHEN rn > 1 THEN 'duplicate customer_id; ' ELSE '' END ||
        CASE WHEN birth_year IS NULL OR birth_year NOT BETWEEN 1900 AND 2026 THEN 'invalid birth_year; ' ELSE '' END
    ) AS error_reason
FROM ranked;

CREATE TABLE stg_promotions AS
WITH base AS (
    SELECT
        ROW_NUMBER() OVER () AS source_row_id,
        CLEAN_ID(promotion_id) AS promotion_id,
        COALESCE(CLEAN_TEXT(promotion_name), 'Unknown Promotion') AS promotion_name,
        CASE LOWER(CLEAN_TEXT(promotion_type))
            WHEN 'discountt' THEN 'Percentage Discount'
            WHEN 'percentage discount' THEN 'Percentage Discount'
            WHEN 'clearance' THEN 'Clearance'
            WHEN 'seasonal' THEN 'Seasonal'
            WHEN 'free delivery' THEN 'Free Delivery'
            WHEN 'loyalty points' THEN 'Loyalty Points'
            ELSE COALESCE(CLEAN_TEXT(promotion_type), 'Unknown')
        END AS promotion_type,
        NUM(discount_rate) AS discount_rate,
        PARSE_DATE(start_date) AS start_date,
        PARSE_DATE(end_date) AS end_date
    FROM raw.raw_promotions
),
ranked AS (
    SELECT base.*, ROW_NUMBER() OVER (PARTITION BY promotion_id ORDER BY source_row_id) AS rn
    FROM base
)
SELECT *,
    CASE
        WHEN promotion_id IS NULL OR rn > 1 OR discount_rate IS NULL OR discount_rate < 0 OR start_date IS NULL OR end_date IS NULL OR end_date < start_date THEN 0
        ELSE 1
    END AS is_valid,
    TRIM(
        CASE WHEN promotion_id IS NULL THEN 'missing promotion_id; ' ELSE '' END ||
        CASE WHEN rn > 1 THEN 'duplicate promotion_id; ' ELSE '' END ||
        CASE WHEN discount_rate IS NULL OR discount_rate < 0 THEN 'invalid discount_rate; ' ELSE '' END ||
        CASE WHEN start_date IS NULL THEN 'invalid start_date; ' ELSE '' END ||
        CASE WHEN end_date IS NULL THEN 'invalid end_date; ' ELSE '' END ||
        CASE WHEN start_date IS NOT NULL AND end_date IS NOT NULL AND end_date < start_date THEN 'end_date before start_date; ' ELSE '' END
    ) AS error_reason
FROM ranked;

CREATE TABLE stg_payment_methods AS
WITH base AS (
    SELECT
        ROW_NUMBER() OVER () AS source_row_id,
        CLEAN_ID(payment_method_id) AS payment_method_id,
        COALESCE(CLEAN_TEXT(payment_type), 'Unknown') AS payment_type,
        COALESCE(CLEAN_TEXT(provider), 'Unknown') AS provider,
        CLEAN_BOOL(is_online_supported) AS is_online_supported
    FROM raw.raw_payment_methods
),
ranked AS (
    SELECT base.*, ROW_NUMBER() OVER (PARTITION BY payment_method_id ORDER BY source_row_id) AS rn
    FROM base
)
SELECT *,
    CASE WHEN payment_method_id IS NOT NULL AND rn = 1 THEN 1 ELSE 0 END AS is_valid,
    TRIM(
        CASE WHEN payment_method_id IS NULL THEN 'missing payment_method_id; ' ELSE '' END ||
        CASE WHEN rn > 1 THEN 'duplicate payment_method_id; ' ELSE '' END
    ) AS error_reason
FROM ranked;

CREATE TABLE stg_channels AS
WITH base AS (
    SELECT
        ROW_NUMBER() OVER () AS source_row_id,
        CLEAN_ID(channel_id) AS channel_id,
        CASE LOWER(CLEAN_TEXT(channel_name))
            WHEN 'store' THEN 'Store'
            WHEN 'ecommerce' THEN 'eCommerce'
            WHEN 'e-commerce' THEN 'eCommerce'
            WHEN 'click & collect' THEN 'Click & Collect'
            WHEN 'home delivery' THEN 'Home Delivery'
            WHEN 'mobile app' THEN 'Mobile App'
            ELSE COALESCE(CLEAN_TEXT(channel_name), 'Unknown')
        END AS channel_name,
        COALESCE(CLEAN_TEXT(channel_group), 'Unknown') AS channel_group,
        CLEAN_TEXT(description) AS description
    FROM raw.raw_channels
),
ranked AS (
    SELECT base.*, ROW_NUMBER() OVER (PARTITION BY channel_id ORDER BY source_row_id) AS rn
    FROM base
)
SELECT *,
    CASE WHEN channel_id IS NOT NULL AND rn = 1 THEN 1 ELSE 0 END AS is_valid,
    TRIM(
        CASE WHEN channel_id IS NULL THEN 'missing channel_id; ' ELSE '' END ||
        CASE WHEN rn > 1 THEN 'duplicate channel_id; ' ELSE '' END
    ) AS error_reason
FROM ranked;

CREATE TABLE stg_suppliers AS
WITH base AS (
    SELECT
        ROW_NUMBER() OVER () AS source_row_id,
        CLEAN_ID(supplier_id) AS supplier_id,
        COALESCE(CLEAN_TEXT(supplier_name), 'Unknown Supplier') AS supplier_name,
        COALESCE(CLEAN_TEXT(supplier_type), 'Unknown') AS supplier_type,
        CLEAN_TEXT(city) AS city,
        CLEAN_ID(state) AS state,
        INT_NUM(lead_time_days) AS lead_time_days
    FROM raw.raw_suppliers
),
ranked AS (
    SELECT base.*, ROW_NUMBER() OVER (PARTITION BY supplier_id ORDER BY source_row_id) AS rn
    FROM base
)
SELECT *,
    CASE WHEN supplier_id IS NOT NULL AND rn = 1 AND lead_time_days >= 0 THEN 1 ELSE 0 END AS is_valid,
    TRIM(
        CASE WHEN supplier_id IS NULL THEN 'missing supplier_id; ' ELSE '' END ||
        CASE WHEN rn > 1 THEN 'duplicate supplier_id; ' ELSE '' END ||
        CASE WHEN lead_time_days IS NULL OR lead_time_days < 0 THEN 'invalid lead_time_days; ' ELSE '' END
    ) AS error_reason
FROM ranked;

CREATE TABLE stg_fulfilment_centers AS
WITH base AS (
    SELECT
        ROW_NUMBER() OVER () AS source_row_id,
        CLEAN_ID(fulfilment_center_id) AS fulfilment_center_id,
        COALESCE(CLEAN_TEXT(fulfilment_center_name), 'Unknown Fulfilment Center') AS fulfilment_center_name,
        CLEAN_TEXT(city) AS city,
        CLEAN_ID(state) AS state,
        INT_NUM(capacity_orders_per_day) AS capacity_orders_per_day
    FROM raw.raw_fulfilment_centers
),
ranked AS (
    SELECT base.*, ROW_NUMBER() OVER (PARTITION BY fulfilment_center_id ORDER BY source_row_id) AS rn
    FROM base
)
SELECT *,
    CASE WHEN fulfilment_center_id IS NOT NULL AND rn = 1 AND capacity_orders_per_day >= 0 THEN 1 ELSE 0 END AS is_valid,
    TRIM(
        CASE WHEN fulfilment_center_id IS NULL THEN 'missing fulfilment_center_id; ' ELSE '' END ||
        CASE WHEN rn > 1 THEN 'duplicate fulfilment_center_id; ' ELSE '' END ||
        CASE WHEN capacity_orders_per_day IS NULL OR capacity_orders_per_day < 0 THEN 'invalid capacity; ' ELSE '' END
    ) AS error_reason
FROM ranked;

CREATE TABLE stg_distribution_centers AS
WITH base AS (
    SELECT
        ROW_NUMBER() OVER () AS source_row_id,
        CLEAN_ID(distribution_center_id) AS distribution_center_id,
        COALESCE(CLEAN_TEXT(distribution_center_name), 'Unknown Distribution Center') AS distribution_center_name,
        CLEAN_TEXT(city) AS city,
        CLEAN_ID(state) AS state,
        NUM(warehouse_area_sqm) AS warehouse_area_sqm
    FROM raw.raw_distribution_centers
),
ranked AS (
    SELECT base.*, ROW_NUMBER() OVER (PARTITION BY distribution_center_id ORDER BY source_row_id) AS rn
    FROM base
)
SELECT *,
    CASE WHEN distribution_center_id IS NOT NULL AND rn = 1 AND warehouse_area_sqm >= 0 THEN 1 ELSE 0 END AS is_valid,
    TRIM(
        CASE WHEN distribution_center_id IS NULL THEN 'missing distribution_center_id; ' ELSE '' END ||
        CASE WHEN rn > 1 THEN 'duplicate distribution_center_id; ' ELSE '' END ||
        CASE WHEN warehouse_area_sqm IS NULL OR warehouse_area_sqm < 0 THEN 'invalid warehouse_area_sqm; ' ELSE '' END
    ) AS error_reason
FROM ranked;

CREATE TABLE stg_sales AS
WITH base AS (
    SELECT
        ROW_NUMBER() OVER () AS source_row_id,
        CLEAN_ID(transaction_id) AS transaction_id,
        PARSE_DATE(transaction_date) AS transaction_date,
        DATE_KEY(transaction_date) AS date_key,
        CLEAN_ID(store_id) AS store_id,
        CLEAN_ID(product_id) AS product_id,
        CLEAN_ID(customer_id) AS customer_id,
        CLEAN_ID(promotion_id) AS promotion_id,
        CLEAN_ID(payment_method_id) AS payment_method_id,
        CLEAN_ID(channel_id) AS channel_id,
        NUM(quantity) AS quantity,
        NUM(unit_price) AS unit_price,
        NUM(gross_sale) AS gross_sale,
        COALESCE(NUM(discount_amount), 0) AS discount_amount,
        NUM(sales_cost) AS sales_cost,
        CASE WHEN CLEAN_ID(currency) IN ('AUD', 'USD') THEN CLEAN_ID(currency) ELSE 'AUD' END AS currency
    FROM raw.raw_sales_transactions
),
ranked AS (
    SELECT base.*, ROW_NUMBER() OVER (PARTITION BY transaction_id ORDER BY source_row_id) AS rn
    FROM base
)
SELECT *,
    gross_sale - discount_amount AS net_sales,
    gross_sale - discount_amount - sales_cost AS gross_profit,
    CASE
        WHEN transaction_id IS NULL OR rn > 1 OR date_key IS NULL
          OR quantity IS NULL OR quantity < 0
          OR gross_sale IS NULL OR gross_sale < 0
          OR discount_amount < 0
          OR gross_sale - discount_amount < 0
          OR sales_cost IS NULL OR sales_cost < 0 THEN 0
        ELSE 1
    END AS is_valid,
    TRIM(
        CASE WHEN transaction_id IS NULL THEN 'missing transaction_id; ' ELSE '' END ||
        CASE WHEN rn > 1 THEN 'duplicate transaction_id; ' ELSE '' END ||
        CASE WHEN date_key IS NULL THEN 'invalid transaction_date; ' ELSE '' END ||
        CASE WHEN quantity IS NULL OR quantity < 0 THEN 'invalid quantity; ' ELSE '' END ||
        CASE WHEN gross_sale IS NULL OR gross_sale < 0 THEN 'invalid gross_sale; ' ELSE '' END ||
        CASE WHEN discount_amount < 0 THEN 'invalid discount_amount; ' ELSE '' END ||
        CASE WHEN gross_sale - discount_amount < 0 THEN 'discount exceeds gross_sale; ' ELSE '' END ||
        CASE WHEN sales_cost IS NULL OR sales_cost < 0 THEN 'invalid sales_cost; ' ELSE '' END
    ) AS error_reason
FROM ranked;

CREATE TABLE stg_online_orders AS
WITH base AS (
    SELECT
        ROW_NUMBER() OVER () AS source_row_id,
        CLEAN_ID(online_order_id) AS online_order_id,
        PARSE_DATE(order_date) AS order_date,
        DATE_KEY(order_date) AS order_date_key,
        CLEAN_ID(customer_id) AS customer_id,
        CLEAN_ID(fulfilment_center_id) AS fulfilment_center_id,
        CLEAN_ID(channel_id) AS channel_id,
        INT_NUM(item_count) AS item_count,
        NUM(order_value) AS order_value,
        NUM(delivery_fee) AS delivery_fee,
        CASE LOWER(CLEAN_TEXT(order_status))
            WHEN 'recieved' THEN 'received'
            ELSE LOWER(COALESCE(CLEAN_TEXT(order_status), 'unknown'))
        END AS order_status,
        CLEAN_BOOL(fulfilled_flag) AS fulfilled_flag
    FROM raw.raw_online_orders
),
ranked AS (
    SELECT base.*, ROW_NUMBER() OVER (PARTITION BY online_order_id ORDER BY source_row_id) AS rn
    FROM base
)
SELECT *,
    CASE
        WHEN online_order_id IS NULL OR rn > 1 OR order_date_key IS NULL
          OR item_count IS NULL OR item_count < 0
          OR order_value IS NULL OR order_value < 0
          OR delivery_fee IS NULL OR delivery_fee < 0 THEN 0
        ELSE 1
    END AS is_valid,
    TRIM(
        CASE WHEN online_order_id IS NULL THEN 'missing online_order_id; ' ELSE '' END ||
        CASE WHEN rn > 1 THEN 'duplicate online_order_id; ' ELSE '' END ||
        CASE WHEN order_date_key IS NULL THEN 'invalid order_date; ' ELSE '' END ||
        CASE WHEN item_count IS NULL OR item_count < 0 THEN 'invalid item_count; ' ELSE '' END ||
        CASE WHEN order_value IS NULL OR order_value < 0 THEN 'invalid order_value; ' ELSE '' END ||
        CASE WHEN delivery_fee IS NULL OR delivery_fee < 0 THEN 'invalid delivery_fee; ' ELSE '' END
    ) AS error_reason
FROM ranked;

CREATE TABLE stg_inventory AS
SELECT
    ROW_NUMBER() OVER () AS source_row_id,
    CLEAN_ID(inventory_record_id) AS inventory_record_id,
    PARSE_DATE(snapshot_date) AS snapshot_date,
    DATE_KEY(snapshot_date) AS snapshot_date_key,
    CLEAN_ID(store_id) AS store_id,
    CLEAN_ID(product_id) AS product_id,
    NUM(opening_stock) AS opening_stock,
    NUM(stock_in) AS stock_in,
    NUM(stock_out) AS stock_out,
    COALESCE(NUM(stock_loss), 0) AS stock_loss,
    NUM(closing_stock) AS closing_stock,
    NUM(opening_stock) + NUM(stock_in) - NUM(stock_out) - COALESCE(NUM(stock_loss), 0) AS calculated_closing_stock,
    CASE
        WHEN CLEAN_ID(inventory_record_id) IS NULL OR DATE_KEY(snapshot_date) IS NULL
          OR NUM(opening_stock) IS NULL OR NUM(opening_stock) < 0
          OR NUM(stock_in) IS NULL OR NUM(stock_in) < 0
          OR NUM(stock_out) IS NULL OR NUM(stock_out) < 0
          OR COALESCE(NUM(stock_loss), 0) < 0
          OR NUM(closing_stock) IS NULL OR NUM(closing_stock) < 0 THEN 0
        ELSE 1
    END AS is_valid,
    TRIM(
        CASE WHEN CLEAN_ID(inventory_record_id) IS NULL THEN 'missing inventory_record_id; ' ELSE '' END ||
        CASE WHEN DATE_KEY(snapshot_date) IS NULL THEN 'invalid snapshot_date; ' ELSE '' END ||
        CASE WHEN NUM(opening_stock) IS NULL OR NUM(opening_stock) < 0 THEN 'invalid opening_stock; ' ELSE '' END ||
        CASE WHEN NUM(stock_in) IS NULL OR NUM(stock_in) < 0 THEN 'invalid stock_in; ' ELSE '' END ||
        CASE WHEN NUM(stock_out) IS NULL OR NUM(stock_out) < 0 THEN 'invalid stock_out; ' ELSE '' END ||
        CASE WHEN COALESCE(NUM(stock_loss), 0) < 0 THEN 'invalid stock_loss; ' ELSE '' END ||
        CASE WHEN NUM(closing_stock) IS NULL OR NUM(closing_stock) < 0 THEN 'invalid closing_stock; ' ELSE '' END
    ) AS error_reason
FROM raw.raw_inventory_movements;

CREATE TABLE stg_delivery AS
SELECT
    ROW_NUMBER() OVER () AS source_row_id,
    CLEAN_ID(delivery_id) AS delivery_id,
    CLEAN_ID(online_order_id) AS online_order_id,
    COALESCE(CLEAN_TEXT(delivery_partner), 'Unknown') AS delivery_partner,
    PARSE_DATE(promised_delivery_date) AS promised_delivery_date,
    DATE_KEY(promised_delivery_date) AS promised_date_key,
    PARSE_DATE(actual_delivery_date) AS actual_delivery_date,
    DATE_KEY(actual_delivery_date) AS actual_date_key,
    CASE LOWER(CLEAN_TEXT(delivery_status))
        WHEN 'delivred' THEN 'delivered'
        ELSE LOWER(COALESCE(CLEAN_TEXT(delivery_status), 'unknown'))
    END AS delivery_status,
    INT_NUM(delivery_time_minutes) AS delivery_time_minutes,
    CLEAN_BOOL(order_accuracy_flag) AS order_accuracy_flag,
    CAST(julianday(PARSE_DATE(actual_delivery_date)) - julianday(PARSE_DATE(promised_delivery_date)) AS INTEGER) * 1440 AS delay_minutes,
    CASE WHEN PARSE_DATE(actual_delivery_date) <= PARSE_DATE(promised_delivery_date) THEN 1 ELSE 0 END AS on_time_flag,
    CASE
        WHEN CLEAN_ID(delivery_id) IS NULL OR CLEAN_ID(online_order_id) IS NULL
          OR DATE_KEY(promised_delivery_date) IS NULL OR DATE_KEY(actual_delivery_date) IS NULL
          OR INT_NUM(delivery_time_minutes) IS NULL OR INT_NUM(delivery_time_minutes) < 0 THEN 0
        ELSE 1
    END AS is_valid,
    TRIM(
        CASE WHEN CLEAN_ID(delivery_id) IS NULL THEN 'missing delivery_id; ' ELSE '' END ||
        CASE WHEN CLEAN_ID(online_order_id) IS NULL THEN 'missing online_order_id; ' ELSE '' END ||
        CASE WHEN DATE_KEY(promised_delivery_date) IS NULL THEN 'invalid promised_delivery_date; ' ELSE '' END ||
        CASE WHEN DATE_KEY(actual_delivery_date) IS NULL THEN 'invalid actual_delivery_date; ' ELSE '' END ||
        CASE WHEN INT_NUM(delivery_time_minutes) IS NULL OR INT_NUM(delivery_time_minutes) < 0 THEN 'invalid delivery_time_minutes; ' ELSE '' END
    ) AS error_reason
FROM raw.raw_delivery_logs;

CREATE TABLE stg_procurement AS
SELECT
    ROW_NUMBER() OVER () AS source_row_id,
    CLEAN_ID(purchase_order_id) AS purchase_order_id,
    PARSE_DATE(purchase_order_date) AS purchase_order_date,
    DATE_KEY(purchase_order_date) AS purchase_order_date_key,
    CLEAN_ID(supplier_id) AS supplier_id,
    CLEAN_ID(distribution_center_id) AS distribution_center_id,
    CLEAN_ID(product_id) AS product_id,
    NUM(ordered_qty) AS ordered_qty,
    NUM(received_qty) AS received_qty,
    NUM(purchase_amount) AS purchase_amount,
    PARSE_DATE(expected_receipt_date) AS expected_receipt_date,
    DATE_KEY(expected_receipt_date) AS expected_receipt_date_key,
    PARSE_DATE(actual_receipt_date) AS actual_receipt_date,
    DATE_KEY(actual_receipt_date) AS actual_receipt_date_key,
    CASE WHEN PARSE_DATE(actual_receipt_date) > PARSE_DATE(expected_receipt_date) THEN 1 ELSE 0 END AS late_delivery_flag,
    CASE LOWER(CLEAN_TEXT(po_status))
        WHEN 'recieved' THEN 'received'
        ELSE LOWER(COALESCE(CLEAN_TEXT(po_status), 'unknown'))
    END AS po_status,
    CASE
        WHEN CLEAN_ID(purchase_order_id) IS NULL OR DATE_KEY(purchase_order_date) IS NULL
          OR NUM(ordered_qty) IS NULL OR NUM(ordered_qty) < 0
          OR NUM(received_qty) IS NULL OR NUM(received_qty) < 0
          OR NUM(purchase_amount) IS NULL OR NUM(purchase_amount) < 0 THEN 0
        ELSE 1
    END AS is_valid,
    TRIM(
        CASE WHEN CLEAN_ID(purchase_order_id) IS NULL THEN 'missing purchase_order_id; ' ELSE '' END ||
        CASE WHEN DATE_KEY(purchase_order_date) IS NULL THEN 'invalid purchase_order_date; ' ELSE '' END ||
        CASE WHEN NUM(ordered_qty) IS NULL OR NUM(ordered_qty) < 0 THEN 'invalid ordered_qty; ' ELSE '' END ||
        CASE WHEN NUM(received_qty) IS NULL OR NUM(received_qty) < 0 THEN 'invalid received_qty; ' ELSE '' END ||
        CASE WHEN NUM(purchase_amount) IS NULL OR NUM(purchase_amount) < 0 THEN 'invalid purchase_amount; ' ELSE '' END
    ) AS error_reason
FROM raw.raw_purchase_orders;
