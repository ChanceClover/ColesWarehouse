# Coles Omnichannel Data Warehouse

Project ini membangun data warehouse retail omnichannel dari sumber SQLite yang sengaja berisi data kotor. Pipeline membersihkan data, mencatat masalah kualitas, memuat star schema, menjalankan validasi, lalu mengekspor tabel final untuk dashboard Power BI.

## Tujuan Project

Dashboard akhir menjawab tiga kelompok kebutuhan bisnis:

1. Performa penjualan omnichannel secara keseluruhan.
2. Perilaku customer berdasarkan channel dan segmentasi.
3. Kualitas fulfilment, delivery, dan dukungan inventory.

Deliverable utama adalah dashboard Power BI tiga halaman. Streamlit dipertahankan sebagai prototipe interaktif untuk referensi selama perancangan dashboard.

## Arsitektur

```text
Dirty SQLite Source
        |
        v
Staging dan Data Quality Checks
        |
        v
Cleansing dan Standardization
        |
        v
Dimension dan Fact Tables
        |
        +--> Validation Reports
        |
        +--> Power BI CSV Export --> Power BI Dashboard
```

Repository juga memiliki analytical cube views di folder `cube/`. Layer tersebut menyediakan dataset hasil join untuk query cepat, tetapi export Power BI final menggunakan star schema agar relationship dan cross-filtering tetap jelas.

## Sumber Data

Sumber resmi ETL:

```text
data/raw/coles_dirty_source_50_records.sqlite
```

Salinan CSV raw tersedia di `data/raw/csv/` untuk inspeksi. Data sumber mengandung variasi format tanggal, typo kategori, ID tidak konsisten, duplicate key, missing lookup, nilai tidak valid, dan status yang belum terstandardisasi.

## Proses ETL

Pipeline dijalankan oleh `run_etl.py` dengan urutan SQL berikut:

| Tahap | File | Fungsi |
| --- | --- | --- |
| Schema | `sql/01_schema.sql` | Membuat staging, transform, dimension, fact, dan ETL log tables |
| Staging | `sql/02_staging.sql` | Extract raw data, standardisasi awal, dan tandai baris tidak valid |
| Transform | `sql/03_transform.sql` | Membersihkan nilai, tanggal, ID, kategori, dan business rules |
| Dimensions | `sql/03_load_dimensions.sql` | Memuat conformed dimensions dan surrogate keys |
| Facts | `sql/04_load_facts.sql` | Memuat fakta valid dan mencatat lookup yang gagal |
| Validation | `sql/05_validation.sql` | Menyediakan query pemeriksaan warehouse |
| Analytics | `sql/06_analytics.sql` | Menyediakan query analitik yang selaras dengan dashboard |

Fungsi Python seperti `CLEAN_TEXT`, `CLEAN_ID`, `PARSE_DATE`, `DATE_KEY`, `NUM`, dan `CLEAN_BOOL` didaftarkan ke SQLite sebelum script SQL dijalankan.

## Model Data

Warehouse lengkap menyimpan seluruh domain retail, termasuk sales, online order, inventory, delivery, procurement, promotion, payment, supplier, dan distribution center.

Model Power BI final hanya membutuhkan tabel berikut:

### Dimensions

- `dim_date`
- `dim_store`
- `dim_product`
- `dim_customer`
- `dim_channel`
- `dim_fulfilment_center`

### Facts

- `fact_sales`
- `fact_online_orders`
- `fact_inventory_daily`
- `fact_delivery_performance`

Tabel staging, transform, ETL log, procurement, dan dimension lain tetap berada di warehouse sebagai bagian proses ETL, tetapi tidak diekspor ke model Power BI tiga halaman.

## Data Quality

Baris bermasalah tidak dihapus tanpa jejak. Pipeline mencatatnya pada:

- `data_quality_issue`
- `etl_error_log`
- `etl_audit_log`
- `etl_load_batch`

Lookup yang tidak ditemukan dipetakan ke surrogate key `0` agar fakta tetap dapat ditelusuri. Nilai tersebut tampil sebagai `Unknown` pada dashboard. Validation report memeriksa row count, negative measures, unknown keys, status SCD, dan ringkasan hasil load.

Output validasi utama:

```text
output/validation_summary.md
output/validation_row_counts.csv
output/validation_quality_issues.csv
output/validation_unknown_keys.csv
output/validation_negative_measures.csv
```

## Menjalankan Project

### 1. Siapkan environment

```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
```

### 2. Jalankan pipeline final

```powershell
.\.venv\Scripts\python.exe .\run_project.py
```

Perintah tersebut menjalankan:

1. Full rebuild warehouse.
2. Validation reports.
3. Export CSV untuk Power BI.

Mode incremental tersedia dengan:

```powershell
.\.venv\Scripts\python.exe .\run_project.py --incremental
```

### 3. Jalankan komponen secara terpisah

```powershell
.\.venv\Scripts\python.exe .\run_etl.py
.\.venv\Scripts\python.exe .\run_validation.py
.\.venv\Scripts\python.exe .\powerbi\export_powerbi.py
```

## Power BI

CSV final dibuat di:

```text
output/powerbi/
```

Exporter membersihkan CSV lama dan hanya menghasilkan 10 tabel yang digunakan dashboard. Detail relationship, DAX, dan susunan visual tersedia di:

- `powerbi/model_relationships.md`
- `powerbi/dax_measures.md`
- `powerbi/dashboard_blueprint.md`

Tiga halaman final:

1. **Omnichannel Executive Overview**
2. **Customer & Channel Behaviour**
3. **Fulfilment & Inventory Support**

## Streamlit Prototype

Jalankan prototipe dashboard dengan:

```powershell
.\.venv\Scripts\streamlit.exe run streamlit_app.py
```

Streamlit membaca warehouse SQLite langsung dan menggunakan fact serta dimension tables yang sama dengan model Power BI.

## Analytical Cube Views

Folder `cube/` menyediakan view berikut:

- `vw_cube_sales`
- `vw_cube_online_orders`
- `vw_cube_inventory`
- `vw_cube_delivery`
- `vw_cube_procurement`

View dapat dibuat secara terpisah dengan:

```powershell
.\.venv\Scripts\python.exe .\cube\run_cube.py
```

Cube views berguna untuk ad-hoc SQL dan dataset datar. Komponen ini dipertahankan sebagai analytical layer tambahan dan tidak ikut diekspor oleh pipeline Power BI final.

## Struktur Repository

```text
ProjectColesWarehouse/
|-- cube/                 # Analytical SQL views
|-- data/raw/             # Dirty source database dan CSV
|-- powerbi/              # Exporter dan panduan Power BI
|-- sql/                  # Schema, ETL, validation, analytics
|-- run_etl.py            # ETL orchestrator
|-- run_validation.py     # Validation report generator
|-- run_project.py        # Final pipeline runner
|-- streamlit_app.py      # Dashboard prototype
|-- requirements.txt
`-- README.md
```

Folder `output/` berisi artefak hasil proses dan tidak dimasukkan ke Git.
