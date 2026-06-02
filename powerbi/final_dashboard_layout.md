# Final Power BI Dashboard Layout

This layout is ready to reproduce in Power BI Desktop using CSV files from `output/powerbi`.

## Page 1 - Executive Overview

Purpose: show whether the Coles-style retail warehouse is ready for business analysis.

KPI cards:

- Net Sales: 22,175.70
- Gross Profit: 4,172.95
- Gross Margin %: 18.91%
- Total Online Order Value: 6,588.23
- On-time Delivery %: 16.67%
- Data Quality Issues: 242

Visuals:

- Bar chart: Net Sales by Region, using `fact_sales[net_sales]` and `dim_store[region]`.
- Bar chart: Net Sales by Channel, using `fact_sales[net_sales]` and `dim_channel[channel_name]`.
- Validation card group: negative measure rows, unknown surrogate-key rows, latest ETL batch status.
- Bar chart: issue count by `data_quality_issue[issue_code]`.

## Page 2 - Sales and Omnichannel

Visuals:

- Column chart: Net Sales by `dim_channel[channel_name]`.
- Matrix: `dim_store[region]` by `dim_product[category]`, value `fact_sales[net_sales]`.
- Bar chart: Quantity Sold by product category.
- Slicers: Year, Region, Channel, Category.

## Page 3 - ETL Health

Visuals:

- KPI cards: Data Quality Issues, Error Log Rows, Audit Log Rows, Latest Batch Status.
- Matrix: `data_quality_issue[layer_name]` by `severity`.
- Bar chart: issue count by `issue_code`.
- Table: `etl_audit_log` process_name, source_table, target_table, rows_loaded, rows_rejected, status.

## Preview Evidence

- PNG preview: `output/powerbi/dashboard_final_preview.png`
- HTML preview: `output/powerbi/dashboard_final_preview.html`

Use the PNG as a minimal final dashboard screenshot if Power BI Desktop is not available during submission.
