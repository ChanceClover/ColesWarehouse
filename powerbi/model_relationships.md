# Power BI Relationship Model

Gunakan cardinality **one-to-many**, cross-filter direction **single**, dan relationship **active**.

## Sales

- `dim_date[date_key]` -> `fact_sales[date_key]`
- `dim_store[store_key]` -> `fact_sales[store_key]`
- `dim_product[product_key]` -> `fact_sales[product_key]`
- `dim_customer[customer_key]` -> `fact_sales[customer_key]`
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

Relationship online order ke delivery membuat filter order date, channel, customer, dan fulfilment center mengalir ke delivery. Jangan menambahkan relationship tanggal delivery lain sebagai active relationship karena dapat membuat jalur filter ambigu.
