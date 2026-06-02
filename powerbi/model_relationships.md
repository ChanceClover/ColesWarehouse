# Power BI Relationship Model

Create these relationships in Power BI Model view.

## Sales

- `dim_date[date_key]` -> `fact_sales[date_key]`
- `dim_store[store_key]` -> `fact_sales[store_key]`
- `dim_product[product_key]` -> `fact_sales[product_key]`
- `dim_customer[customer_key]` -> `fact_sales[customer_key]`
- `dim_promotion[promotion_key]` -> `fact_sales[promotion_key]`
- `dim_payment_method[payment_method_key]` -> `fact_sales[payment_method_key]`
- `dim_channel[channel_key]` -> `fact_sales[channel_key]`

## Online Orders

- `dim_date[date_key]` -> `fact_online_orders[order_date_key]`
- `dim_customer[customer_key]` -> `fact_online_orders[customer_key]`
- `dim_fulfilment_center[fulfilment_center_key]` -> `fact_online_orders[fulfilment_center_key]`
- `dim_channel[channel_key]` -> `fact_online_orders[channel_key]`

## Inventory

- `dim_date[date_key]` -> `fact_inventory_daily[snapshot_date_key]`
- `dim_store[store_key]` -> `fact_inventory_daily[store_key]`
- `dim_product[product_key]` -> `fact_inventory_daily[product_key]`

## Delivery

- `fact_online_orders[online_order_key]` -> `fact_delivery_performance[online_order_key]`
- `dim_date[date_key]` -> `fact_delivery_performance[promised_date_key]`

Power BI may warn about multiple date relationships. Keep one active date relationship per fact if needed, then use cube views for simpler delivery dashboarding.

## Procurement

- `dim_date[date_key]` -> `fact_procurement[purchase_order_date_key]`
- `dim_supplier[supplier_key]` -> `fact_procurement[supplier_key]`
- `dim_distribution_center[distribution_center_key]` -> `fact_procurement[distribution_center_key]`
- `dim_product[product_key]` -> `fact_procurement[product_key]`

## ETL Health

These tables are usually kept disconnected, then used on a separate ETL health page:

- `etl_load_batch`
- `etl_audit_log`
- `etl_error_log`
- `data_quality_issue`
- `map_standard_value`

If you want batch-level filtering, create relationships from `etl_load_batch[batch_id]` to:

- `etl_audit_log[batch_id]`
- `etl_error_log[batch_id]`
- `data_quality_issue[batch_id]`

Keep these relationships separate from the business star schema to avoid confusing business filters with ETL-process filters.
