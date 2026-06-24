# Power BI Implementation

Folder ini berisi exporter dan panduan untuk dashboard Power BI tiga halaman.

## Export Data

Jalankan pipeline lengkap:

```powershell
.\.venv\Scripts\python.exe .\run_project.py
```

Atau jalankan exporter setelah ETL:

```powershell
.\.venv\Scripts\python.exe .\powerbi\export_powerbi.py
```

File dibuat di `output/powerbi/`. Exporter menghapus CSV lama sebelum menghasilkan 10 tabel final:

- `dim_date`
- `dim_store`
- `dim_product`
- `dim_customer`
- `dim_channel`
- `dim_fulfilment_center`
- `fact_sales`
- `fact_online_orders`
- `fact_inventory_daily`
- `fact_delivery_performance`

Jangan impor `trf_*`, ETL log, procurement, atau cube views ke dashboard final.

## Build Order

1. Import 10 CSV dengan **Get Data > Text/CSV**.
2. Pastikan numeric columns menggunakan Decimal Number atau Whole Number yang sesuai.
3. Buat relationship berdasarkan `model_relationships.md`.
4. Buat measure pada satu Measure Table berdasarkan `dax_measures.md`.
5. Bangun tiga halaman berdasarkan `dashboard_blueprint.md`.
6. Uji slicer, totals, cross-filtering, dan format measure.

Khusus `fact_inventory_daily[shrinkage_rate]`, gunakan tipe **Decimal Number**, lalu format measure sebagai Percentage.
