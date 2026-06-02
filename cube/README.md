# Cube Layer

This folder contains the OLAP/cube-style SQL layer for the Coles data warehouse.

Run the cube view script after ETL:

```powershell
python .\cube\run_cube.py
```

The script creates these analytical views inside `output\coles_warehouse_dw.sqlite`:

- `vw_cube_sales`
- `vw_cube_online_orders`
- `vw_cube_inventory`
- `vw_cube_delivery`
- `vw_cube_procurement`

Use these views when you want a flattened "cube" table for quick analysis. Use the base `dim_*` and `fact_*` tables when you want a proper Power BI star schema model.

`powerbi/export_powerbi.py` also refreshes these views automatically before exporting CSVs.
