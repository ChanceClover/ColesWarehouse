# Coles Warehouse Data Warehouse ETL

SQL-first ETL project for the Coles Australia warehouse/retail management case study.

The flow follows the preparation document:

`Raw Dirty Database -> Staging -> Cleansing & Transformation -> Dimension/Fact Tables -> Validation`

## Source Data

Default source database:

`C:\Users\Ichsan\Downloads\coles_dirty_source_50_records\coles_dirty_source_generated\coles_dirty_source_50_records.sqlite`

The raw database contains operational tables for store sales, online orders, inventory, delivery, procurement, and supporting master data.

## Project Structure

- `run_etl.py` - runs the full ETL into a new SQLite warehouse database.
- `sql/01_schema.sql` - creates the data warehouse schema, error log, and audit log.
- `sql/02_staging.sql` - extracts raw data into staging tables and applies cleansing rules.
- `sql/03_load_dimensions.sql` - loads `dim_*` tables.
- `sql/04_load_facts.sql` - loads `fact_*` tables and rejects invalid rows.
- `sql/05_validation.sql` - validation and sample analysis queries.
- `cube/` - OLAP/cube views for analysis.
- `powerbi/` - Power BI CSV export, DAX measures, relationships, and dashboard blueprint.

## How To Run

```powershell
python .\run_etl.py
```

This creates:

`output\coles_warehouse_dw.sqlite`

To use a different source or output:

```powershell
python .\run_etl.py --source "C:\path\to\source.sqlite" --output "output\my_dw.sqlite"
```

## Cube And Power BI

After running ETL, create cube views:

```powershell
python .\cube\run_cube.py
```

Then export the warehouse and cube views to CSV for Power BI:

```powershell
python .\powerbi\export_powerbi.py
```

Power BI-ready CSV files are generated in:

`output\powerbi`

Use `powerbi\model_relationships.md`, `powerbi\dax_measures.md`, and `powerbi\dashboard_blueprint.md` to build the semantic model and dashboard pages.

## Main Cleansing Rules

- Trim whitespace from IDs and text.
- Uppercase business keys such as `ST001`, `PRD0001`, `CUST0001`.
- Parse mixed date formats into `YYYY-MM-DD`.
- Convert date values into `date_key` format `YYYYMMDD`.
- Standardize boolean values such as `Y`, `Yes`, `TRUE`, and `1`.
- Standardize typo/categorical values such as `super market`, `Discountt`, `delivred`, and `recieved`.
- Reject missing required business keys.
- Reject duplicate master records after standardizing business keys.
- Reject negative quantities, amounts, stock, cost, capacity, and delivery time.
- Reject fact records when dimension lookup fails.
- Store rejected rows in `etl_error_log`.
- Store process counts in `etl_audit_log`.

## Star Schema

Dimensions:

- `dim_date`
- `dim_store`
- `dim_product`
- `dim_customer`
- `dim_promotion`
- `dim_payment_method`
- `dim_channel`
- `dim_supplier`
- `dim_fulfilment_center`
- `dim_distribution_center`

Facts:

- `fact_sales`
- `fact_online_orders`
- `fact_inventory_daily`
- `fact_delivery_performance`
- `fact_procurement`

## Useful Validation Queries

Run the SQL in `sql/05_validation.sql` against `output\coles_warehouse_dw.sqlite`.

Important checks include:

- Row counts for every dimension and fact.
- Rejected rows by source table and error type.
- Negative-value checks in fact tables.
- Missing foreign-key checks.
- Example analysis by region, category, channel, delivery status, and supplier.
