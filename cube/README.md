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

Use these views when you want a flattened analytical dataset for quick SQL analysis. The final Power BI exporter intentionally does not create or export these views because the report uses the base star schema.
