
# Coles Omnichannel Data Warehouse

  

## 1. Project Overview

  

This project is a local data warehouse and ETL pipeline for a Coles-style retail business. It takes dirty operational data, cleans and validates it, loads it into a star-schema warehouse, and exposes the result through Streamlit, a static HTML dashboard, validation files, cube views, and Power BI-ready exports.

  

The project is built with:

  

- SQLite for the source database and final warehouse.

- SQL for schema creation, staging, transformation, dimension loading, fact loading, and validation logic.

- Python for orchestration, helper functions, validation exports, dashboard generation, and Power BI export.

- Streamlit for the interactive dashboard.

  

## 2. Final Goal: Omnichannel Analytics

  

The final goal is to build a warehouse foundation for **omnichannel retail analytics**.

  

In this project, omnichannel means combining different retail and operational channels into one analytical model. Instead of looking at store sales, online orders, delivery, inventory, and procurement separately, the warehouse connects them through shared dimensions such as date, product, customer, store, and channel.

  

This allows the business to answer questions such as:

  

- Which regions, products, and channels generate the most sales?

- How do store, online, mobile app, click-and-collect, and home delivery channels compare?

- Are delivery delays affecting online order performance?

- Are inventory issues connected to sales or procurement problems?

- Which suppliers or product categories create operational risk?

- What data-quality issues exist in the source system?

  

The current project is a foundation for omnichannel reporting. It already connects sales, online orders, delivery, inventory, procurement, products, customers, stores, channels, and data-quality evidence.

  

## 3. Data Sources

  

The main source database is:

  

```text

data\raw\coles_dirty_source_50_records.sqlite

```

  

The raw CSV extracts are also available for inspection:

  

```text

data\raw\csv\

```

  

The ETL uses the SQLite database as the official source system.

  

### Source Tables

  


| Source Table                       | Business Area                  |
|------------------------------------|--------------------------------|
| `raw_stores`                       | Store operations               |
| `raw_products`                     | Product management             |
| `raw_customers`                    | Customer and membership data   |
| `raw_promotions`                   | Promotions and discounts       |
| `raw_payment_methods`              | Payment method data            |
| `raw_channels`                     | Sales and fulfilment channels  |
| `raw_suppliers`                    | Supplier data                  |
| `raw_fulfilment_centers`           | Online fulfilment centers      |
| `raw_distribution_centers`         | Distribution centers           |
| `raw_sales_transactions`           | Sales transactions             |
| `raw_online_orders`                | Online orders                  |
| `raw_inventory_movements`          | Inventory movement             |
| `raw_delivery_logs`                | Delivery performance           |
| `raw_purchase_orders`              | Procurement                    |
  

The source data intentionally includes dirty data such as inconsistent text, duplicate IDs, invalid dates, missing lookup keys, invalid measures, status typos, and mixed boolean formats.

  

## 4. ETL Pipeline

  

The pipeline flow is:

  

```text

Dirty SQLite Source

-> Staging Tables

-> Transform Tables

-> Dimension Tables

-> Fact Tables

-> Cube Views

-> Validation and Reporting Outputs

```

  

### 4.1 Extract

  

The ETL starts by attaching the raw SQLite source database and reading the `raw_*` tables.

  

`run_etl.py` also registers helper functions into SQLite so the SQL scripts can clean data consistently:

  


| Helper Function | Purpose                                                                       |
|-----------------|-------------------------------------------------------------------------------|
| `CLEAN_TEXT()`  | Trims text and treats blank strings as missing.                               |
| `CLEAN_ID()`    | Trims and uppercases business keys.                                           |
| `PARSE_DATE()`  | Converts multiple date formats into a standard date.                          |
| `DATE_KEY()`    | Converts dates into integer keys like `20250104`.                             |
| `NUM()`         | Converts text into numeric values.                                            |
| `INT_NUM()`     | Converts text into integers.                                                  |
| `CLEAN_BOOL()`  | Converts values like `yes`, `no`, `1`, `0`, `true`, and `false`.              |

  

This step prepares the source data so SQL can handle dirty values in a controlled way.

  

### 4.2 Staging Layer

  

The staging layer creates `stg_*` tables from the raw source tables.

  

This layer performs first-pass cleaning and validation:

  

- Standardizes IDs, text, dates, numbers, and boolean values.

- Detects duplicate business keys.

- Checks missing required IDs.

- Rejects invalid dates.

- Rejects invalid or negative business measures.

- Adds `is_valid` to mark whether a row can continue.

- Adds `error_reason` to explain why a row failed.

  

Example staging tables:

  

```text

stg_sales

stg_online_orders

stg_inventory

stg_delivery

stg_procurement

stg_products

stg_customers

stg_stores

```

  

The staging layer is important because it separates raw dirty data from data that is ready for business transformation.

  

### 4.3 Data-Quality Logging

  

Rows that fail staging validation are not ignored. They are recorded in:

  

```text

data_quality_issue

etl_error_log

```

  

The ETL classifies problems using issue codes such as:

  

```text

MISSING_REQUIRED_KEY

DUPLICATE_BUSINESS_KEY

INVALID_DATE

INVALID_MEASURE

STAGING_REJECT

LOOKUP_NOT_FOUND

```

  

This keeps dirty-data evidence visible for the final project. The goal is not to hide bad source data, but to show that the ETL detects and documents it.

  

### 4.4 Transform Layer

  

The transform layer creates `trf_*` tables from valid staging rows.

  

This layer turns cleaned data into business-ready records:

  

- Standardizes business values using `map_standard_value`.

- Converts typos such as `recieved` to `received`.

- Converts `delivred` to `delivered`.

- Maps channel names such as `e-commerce` to `eCommerce`.

- Fills safe descriptive defaults such as `Unknown`.

- Calculates sales, inventory, delivery, and procurement measures.

- Prepares records for dimension and fact loading.

  

Important transformation calculations include:

  

```text

net_sales = gross_sale - discount_amount

gross_profit = net_sales - sales_cost

gross_margin_pct = gross_profit / net_sales

discount_pct = discount_amount / gross_sale

total_order_value = order_value + delivery_fee

calculated_closing_stock = opening_stock + stock_in - stock_out - stock_loss

stock_variance = closing_stock - calculated_closing_stock

shrinkage_rate = stock_loss / (opening_stock + stock_in)

delay_hours = delay_minutes / 60

fill_rate = received_qty / ordered_qty

```

  

This layer is where the raw operational data becomes useful for analysis.

  

### 4.5 Dimension Loading

  

The dimension loading step creates the descriptive tables used by the star schema.

  

Dimension tables include:

  

```text

dim_date

dim_store

dim_product

dim_customer

dim_promotion

dim_payment_method

dim_channel

dim_supplier

dim_fulfilment_center

dim_distribution_center

```

  

The date dimension is generated from all relevant dates in the transform layer, including transaction dates, order dates, inventory dates, delivery dates, procurement dates, customer join dates, promotion dates, and store open dates.

  

Some dimensions are SCD Type 2-ready:

  

```text

dim_store

dim_product

dim_customer

dim_supplier

```

  

These tables include:

  

```text

effective_start_date_key

effective_end_date_key

is_current

```

  

This allows the warehouse to preserve old versions of dimension records when business attributes change.

  

### 4.6 Unknown Members

  

The schema creates unknown dimension rows with surrogate key `0`.

  

This protects the fact tables when a lookup fails. For example, if a sales row references a product that does not exist in `dim_product`, the ETL can still load the fact row using `product_key = 0` and record a `LOOKUP_NOT_FOUND` issue.

  

This design keeps the fact row traceable instead of silently dropping it.

  

### 4.7 Fact Loading

  

Fact tables are loaded from transform tables by joining to the dimension tables.

  


| Fact Table                  | Grain                              | Purpose                                                                             |
|-----------------------------|------------------------------------|-------------------------------------------------------------------------------------|
| `fact_sales`                | One row per sales transaction      | Sales, discount, margin, customer, product, store, and channel analysis             |
| `fact_online_orders`        | One row per online order           | Online order value, fulfilment center, order status, and channel analysis           |
| `fact_inventory_daily`      | One row per inventory record per day | Stock movement, variance, and shrinkage analysis                                  |
| `fact_delivery_performance` | One row per delivery event         | Delivery delay, on-time performance, and order accuracy analysis                    |
| `fact_procurement`          | One row per purchase order         | Supplier fill rate, purchase amount, and receipt delay analysis                     |

  

The fact loading process also logs lookup problems if a fact row cannot find a matching dimension key.

  

### 4.8 Incremental Loading

  

The ETL supports both full rebuild and incremental mode.

  

Full rebuild:

  

```powershell

python .\run_etl.py

```

  

Incremental mode:

  

```powershell

python .\run_etl.py --incremental

```

  

In incremental mode, the existing warehouse is kept and only new fact rows are appended. The fact load checks natural keys before inserting:

  

```text

transaction_id

online_order_id

inventory_record_id

delivery_id

purchase_order_id

```

  

The full project can also run incrementally:

  

```powershell

python .\run_project.py --incremental

```

  

Streamlit does not trigger incremental ETL by itself. It reads the warehouse after the ETL has already been run.

  

## 5. SQL Script Order

  

The ETL SQL scripts run in this order:

  


| Order | SQL Script                   | What It Does                                                                            |
|-------|------------------------------|-----------------------------------------------------------------------------------------|
| 1     | `sql/01_schema.sql`          | Creates audit tables, mapping table, dimensions, facts, and unknown members.            |
| 2     | `sql/02_staging.sql`         | Creates staging tables, cleans raw values, and flags invalid rows.                      |
| 3     | `sql/03_transform.sql`       | Builds transform tables, standardizes values, calculates metrics, and logs rejected rows. |
| 4     | `sql/03_load_dimensions.sql` | Loads date and business dimensions, including SCD-ready dimensions.                     |
| 5     | `sql/04_load_facts.sql`      | Loads facts and records lookup issues.                                                  |
| 6     | `sql/05_validation.sql`      | Contains reference validation queries.                                                  |

  

The full project runner uses this order:

  


| Step | Script                      | Purpose                             |
|------|-----------------------------|-------------------------------------|
| 1    | `run_etl.py`                | Build warehouse                     |
| 2    | `run_validation.py`         | Generate validation evidence        |
| 3    | `cube/run_cube.py`          | Create cube views                   |
| 4    | `run_dashboard.py`          | Generate static HTML dashboard      |
| 5    | `powerbi/export_powerbi.py` | Export Power BI-ready CSV files     |
  

## 6. Warehouse Model

  

The final warehouse uses a star-schema design.

  

### Dimensions

  


| Dimension                   | Purpose                                                       |
|-----------------------------|---------------------------------------------------------------|
| `dim_date`                  | Calendar, fiscal, month, quarter, and weekday attributes      |
| `dim_store`                 | Store profile, location, region, and type                     |
| `dim_product`               | Product, brand, category, cost, and price                     |
| `dim_customer`              | Customer demographic and membership attributes                |
| `dim_promotion`             | Promotion and discount information                            |
| `dim_payment_method`        | Payment type and provider                                     |
| `dim_channel`               | Store, online, app, delivery, and click-and-collect channels  |
| `dim_supplier`              | Supplier profile and lead time                                |
| `dim_fulfilment_center`     | Online fulfilment center profile                              |
| `dim_distribution_center`   | Procurement and warehouse distribution profile                |

  

### Facts

  


| Fact                        | Business Process                              |
|-----------------------------|-----------------------------------------------|
| `fact_sales`                | Customer sales transactions                   |
| `fact_online_orders`        | Online orders and fulfilment demand           |
| `fact_inventory_daily`      | Inventory movement and stock accuracy         |
| `fact_delivery_performance` | Delivery performance and delays               |
| `fact_procurement`          | Supplier purchase orders and replenishment    |

  

### Omnichannel Connection

  

The warehouse supports omnichannel analysis because multiple facts share conformed dimensions:

  


| Shared Dimension | Connected Facts                                           |
|------------------|-----------------------------------------------------------|
| `dim_date`       | Sales, online orders, inventory, delivery, procurement    |
| `dim_product`    | Sales, inventory, procurement                             |
| `dim_customer`   | Sales, online orders                                      |
| `dim_channel`    | Sales, online orders, delivery                            |
| `dim_store`      | Sales, inventory                                          |
  

## 7. Outputs

  

Running the full project creates:

  

```text

output\coles_warehouse_dw.sqlite

output\validation_summary.md

output\validation_*.csv

output\dashboard.html

output\powerbi\

```

  

Important outputs:

  


| Output                             | Purpose                           |
|------------------------------------|-----------------------------------|
| `output\coles_warehouse_dw.sqlite` | Final warehouse database          |
| `output\validation_summary.md`     | Human-readable validation summary |
| `output\validation_*.csv`          | Validation evidence files         |
| `output\dashboard.html`            | Static dashboard                  |
| `output\powerbi\`                 | Power BI-ready CSV files          |
  

## 8. Streamlit Dashboard

  

The Streamlit app is:

  

```text

streamlit_app.py

```

  

It reads:

  

```text

output\coles_warehouse_dw.sqlite

```

  

It displays:

  

- Net Sales

- Gross Profit

- Gross Margin %

- Online Order Value

- Total Discount

- Sales trend by month

- Sales by region

- Sales by product category

- Top 10 products

- Delivery status

- On-time delivery performance

- Data-quality issues

- Fact-table row counts

  

The date filter `Rentang tanggal` is constrained to the available sales range:

  

```text

2025-01-04 to 2025-12-19

```

  

If only one date is selected, the dashboard waits for the second date instead of showing misleading full-range values.

  

## 9. Validation

  

Validation is generated by:

  

```powershell

python .\run_validation.py

```

  

Validation files include:

  


| File                               | Checks                                           |
|------------------------------------|--------------------------------------------------|
| `validation_row_counts.csv`        | Dimension and fact row counts                    |
| `validation_transform_counts.csv`  | Transform-layer row counts                       |
| `validation_quality_issues.csv`    | Data-quality issues by layer and code            |
| `validation_unknown_keys.csv`      | Unknown surrogate key usage                      |
| `validation_negative_measures.csv` | Negative final fact measures                     |
| `validation_scd_status.csv`        | Current and historical rows for SCD-ready dimensions |
| `validation_sales_by_region.csv`   | Sales summary by region                          |
  

The project can still be valid even when data-quality issues exist. The source data is intentionally dirty, and the ETL is expected to classify and report those issues.

  

## 10. Cube Views and Power BI

  

The project creates OLAP-style cube views:

  

```text

vw_cube_sales

vw_cube_online_orders

vw_cube_inventory

vw_cube_delivery

vw_cube_procurement

```

  

Create cube views with:

  

```powershell

python .\cube\run_cube.py

```

  

Export Power BI-ready CSV files with:

  

```powershell

python .\powerbi\export_powerbi.py

```

  

Power BI supporting files are in:

  

```text

powerbi\

```

  

Useful files:

  

```text

model_relationships.md

dax_measures.md

dashboard_blueprint.md

final_dashboard_layout.md

```

  

## 11. Setup

  

Open PowerShell in the project folder:

  

```powershell

cd "C:\Users\Ichsan\Documents\6\Data Warehouse\ProjectColesWarehouse"

```

  

Create a virtual environment:

  

```powershell

python -m venv .venv

```

  

If `python` is not recognized:

  

```powershell

py -m venv .venv

```

  

Activate it:

  

```powershell

.\.venv\Scripts\Activate.ps1

```

  

Install dependencies:

  

```powershell

pip install -r requirements.txt

```

  

Dependencies:

  

```text

Pillow

streamlit

pandas

```

  

## 12. Running the Project

  

Run the full project:

  

```powershell

python .\run_project.py

```

  

Run the full project incrementally:

  

```powershell

python .\run_project.py --incremental

```

  

Run the full project without Power BI export:

  

```powershell

python .\run_project.py --skip-powerbi

```

  

Run only ETL:

  

```powershell

python .\run_etl.py

```

  

Run only validation:

  

```powershell

python .\run_validation.py

```

  

Run Streamlit:

  

```powershell

.\.venv\Scripts\python.exe -m streamlit run streamlit_app.py

```

  

If port `8501` is busy:

  

```powershell

.\.venv\Scripts\python.exe -m streamlit run streamlit_app.py --server.port 8502

```

  

## 13. Folder Structure

  

```text

ProjectColesWarehouse/
├── README.md
├── requirements.txt
├── run_project.py
├── run_etl.py
├── run_validation.py
├── run_dashboard.py
├── streamlit_app.py
│
├── data/
│   ├── raw/
│   ├── coles_dirty_source_50_records.sqlite
│   └── csv/
│
├── sql/
│   ├── 01_schema.sql
│   ├── 02_staging.sql
│   ├── 03_transform.sql
│   ├── 03_load_dimensions.sql
│   ├── 04_load_facts.sql
│   └── 05_validation.sql
│
├── cube/
│   ├── run_cube.py
│   └── olap_cube_views.sql
│
├── powerbi/
│   ├── export_powerbi.py
│   ├── model_relationships.md
│   ├── dax_measures.md
│   ├── dashboard_blueprint.md
│   └── final_dashboard_layout.md
│
└── output/
    ├── coles_warehouse_dw.sqlite
    ├── validation_summary.md
    ├── validation_*.csv
    ├── dashboard.html
    └── powerbi/

```

  

## 14. Demo Checklist

  

For a final demo:

  

1. Run the full pipeline.

  

```powershell

python .\run_project.py

```

  

2. Show the final warehouse:

  

```text

output\coles_warehouse_dw.sqlite

```

  

3. Show validation evidence:

  

```text

output\validation_summary.md

output\validation_*.csv

```

  

4. Open Streamlit:

  

```powershell

.\.venv\Scripts\python.exe -m streamlit run streamlit_app.py

```

  

5. Show Power BI export files:

  

```text

output\powerbi\

```

  

6. Explain the omnichannel purpose:

  

```text

The warehouse connects sales, online orders, delivery, inventory, procurement, customers, products, stores, and channels into one analytical model.

```

  

## 15. Troubleshooting

  

### `python` is not recognized

  

Try:

  

```powershell

py --version

```

  

If `py` works, use `py` instead of `python`.

  

### `streamlit` is not recognized

  

Use:

  

```powershell

.\.venv\Scripts\python.exe -m streamlit run streamlit_app.py

```

  

### Warehouse database not found

  

Run:

  

```powershell

python .\run_project.py

```

  

The Streamlit app needs:

  

```text

output\coles_warehouse_dw.sqlite

```

  

### SQLite database is locked

  

Close DB Browser for SQLite, Power BI, Streamlit, or any other app using:

  

```text

output\coles_warehouse_dw.sqlite

```

  

Then rerun the pipeline.

  

## 16. Future Omnichannel Improvements

  

The current project is a strong foundation, but full omnichannel analytics can be improved further.

  

Future progress steps:

  

1. Standardize channel grouping more clearly across store, online, mobile app, click-and-collect, and home delivery.

2. Add customer journey events such as product view, cart add, order placed, store purchase, pickup, delivery completed, and return created.

3. Add returns and refunds so revenue analysis includes post-purchase behavior.

4. Improve promotion attribution across sales and online orders.

5. Connect inventory availability to sales performance to identify stockout impact.

6. Expand delivery KPIs with fulfilment time, SLA breach rate, delivery partner performance, and order accuracy.

8.  Add scheduled refresh or automation for ETL, validation, and export steps.

  

## 17. Conclusion

  

This project demonstrates a complete local warehouse workflow for omnichannel retail analytics. It extracts dirty operational data, stages and validates it, transforms it into business-ready records, loads dimensions and facts, records data-quality evidence, creates cube views, and supports reporting through Streamlit, static HTML, and Power BI exports.
