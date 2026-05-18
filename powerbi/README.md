# Power BI Implementation

Use this folder to prepare the Power BI dashboard layer.

## Export Data

Run ETL first:

```powershell
python .\run_etl.py
```

Create cube views:

```powershell
python .\cube\run_cube.py
```

Export Power BI-ready CSV files:

```powershell
python .\powerbi\export_powerbi.py
```

The CSV files are created in:

`output\powerbi`

## Recommended Power BI Model

For the proper star schema model, import these tables:

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
- `fact_sales`
- `fact_online_orders`
- `fact_inventory_daily`
- `fact_delivery_performance`
- `fact_procurement`

Use one-to-many relationships from dimensions to facts. Keep relationship direction single from dimension to fact.

## Quick Cube Option

For fast dashboard building, import the cube views:

- `vw_cube_sales`
- `vw_cube_online_orders`
- `vw_cube_inventory`
- `vw_cube_delivery`
- `vw_cube_procurement`

These are flattened analytical views. They are easier for screenshots and demonstrations, but the star schema is better for explaining data warehouse design.
