# Validation Summary - Coles Data Warehouse

## Executive Result

Validation status: PASS for final-project demonstration.

The latest ETL batch `BATCH_20260602_202922` finished with status `SUCCESS` in `REBUILD` mode. The warehouse loaded 15 dimension/fact tables, found 0 negative business-measure rows after cleansing, and recorded 37 unknown surrogate-key references for traceable lookup issues.

The project recorded 242 data-quality issues. These are expected evidence from the dirty operational source: the ETL classifies them instead of hiding them.

## Latest Batch

| Batch ID | Mode | Started | Completed | Status |
| --- | --- | --- | --- | --- |
| BATCH_20260602_202922 | REBUILD | 2026-06-02 13:29:22 | 2026-06-02 13:29:22 | SUCCESS |

## Loaded Warehouse Tables

| Table | Row Count |
| --- | --- |
| dim_date | 297 |
| dim_store | 50 |
| dim_product | 38 |
| dim_customer | 45 |
| dim_promotion | 34 |
| dim_payment_method | 48 |
| dim_channel | 45 |
| dim_supplier | 40 |
| dim_fulfilment_center | 45 |
| dim_distribution_center | 46 |
| fact_sales | 39 |
| fact_online_orders | 38 |
| fact_inventory_daily | 30 |
| fact_delivery_performance | 6 |
| fact_procurement | 34 |

## Data Quality Issues

| Layer | Issue Code | Severity | Count |
| --- | --- | --- | --- |
| lookup | LOOKUP_NOT_FOUND | WARNING | 84 |
| staging | MISSING_REQUIRED_KEY | ERROR | 68 |
| staging | INVALID_MEASURE | ERROR | 63 |
| staging | INVALID_DATE | ERROR | 21 |
| staging | DUPLICATE_BUSINESS_KEY | ERROR | 5 |
| staging | STAGING_REJECT | ERROR | 1 |

## Negative Measure Check

| Check | Result |
| --- | ---: |
| Negative fact rows after ETL | 0 |

## Unknown Key Check

| Check | Result |
| --- | ---: |
| Fact rows using unknown surrogate keys | 37 |

## Sales by Region

| Region | Net Sales | Gross Profit | Avg Margin |
| --- | --- | --- | --- |
| West | 5,598.75 | 1,255.82 | 22.17% |
| East | 4,884.40 | 1,268.13 | 26.09% |
| Regional | 4,597.03 | 262.26 | 9.64% |
| Metro | 4,433.09 | 979.06 | 18.12% |
| North | 2,201.22 | 298.86 | 22.15% |
| Central | 461.21 | 108.82 | 15.22% |

## Generated Evidence

- `output/validation_row_counts.csv`
- `output/validation_transform_counts.csv`
- `output/validation_quality_issues.csv`
- `output/validation_unknown_keys.csv`
- `output/validation_negative_measures.csv`
- `output/validation_scd_status.csv`
- `output/validation_sales_by_region.csv`
