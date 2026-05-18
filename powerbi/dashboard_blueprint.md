# Dashboard Blueprint

## Page 1: Executive Overview

Purpose: Show overall retail and warehouse performance.

Visuals:

- KPI cards: `Net Sales`, `Gross Profit`, `Gross Margin %`, `Total Online Order Value`
- Line chart: `Net Sales` by `dim_date[month_name]`
- Bar chart: `Net Sales` by `dim_store[region]`
- Donut chart: `Net Sales` by `dim_channel[channel_name]`
- Table: top product categories by `Net Sales`

## Page 2: Sales & Omnichannel

Purpose: Compare store, eCommerce, mobile, home delivery, and click-and-collect performance.

Visuals:

- Column chart: `Net Sales` by `dim_channel[channel_name]`
- Matrix: `dim_store[region]` x `dim_product[category]` with `Net Sales`
- Bar chart: `Quantity Sold` by product category
- Slicers: year, region, channel, category

## Page 3: Inventory

Purpose: Track stock movement and stock variance.

Visuals:

- KPI cards: `Closing Stock`, `Stock Variance`
- Line chart: closing stock by month
- Bar chart: stock loss by region
- Table: product/store combinations with largest stock variance

## Page 4: Delivery & Fulfillment

Purpose: Evaluate online order fulfillment and delivery reliability.

Visuals:

- KPI cards: `Fulfillment Rate %`, `On Time Delivery %`, `Average Delay Minutes`
- Bar chart: deliveries by delivery status
- Column chart: on-time delivery by fulfilment center
- Table: late deliveries with delay minutes

## Page 5: Procurement

Purpose: Analyze supplier performance and purchasing cost.

Visuals:

- KPI cards: `Total Purchase Amount`, `Late Procurement %`
- Bar chart: purchase amount by supplier
- Bar chart: late delivery percentage by supplier
- Matrix: supplier type x product category
