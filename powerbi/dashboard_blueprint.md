# Power BI Dashboard Blueprint

## Page 1 - Omnichannel Executive Overview

Tujuan: memberikan ringkasan performa penjualan dan operasional omnichannel.

KPI cards:

- Net Sales
- Gross Margin %
- Sales Transactions
- Total Online Order Value
- Fulfillment Rate %
- On Time Delivery %
- Average Shrinkage %

Visuals:

- Line chart: Net Sales by Month
- Bar chart: Net Sales by Channel
- Donut chart: Channel Contribution
- Matrix: Channel x Product Category dengan Net Sales

Slicers:

- Channel
- Product Category
- Region

## Page 2 - Customer & Channel Behaviour

Tujuan: menunjukkan channel dan customer segment yang menghasilkan transaksi.

KPI cards:

- Sales Transactions
- Net Sales
- Average Transaction Value

Visuals:

- Bar chart: Sales Transactions by Age Group
- Bar chart: Net Sales by Membership Type
- Bar chart: Net Sales by Channel
- Matrix: Channel x Membership Type dengan Net Sales

Slicers:

- Channel
- Membership Type
- Age Group
- Product Category

`None` berarti customer valid yang bukan member. `Unknown` berarti customer tidak berhasil dipetakan saat ETL.

## Page 3 - Fulfilment & Inventory Support

Tujuan: mengukur kualitas order online, delivery, dan ketersediaan inventory.

KPI cards:

- Online Orders
- Total Online Order Value
- Fulfillment Rate %
- On Time Delivery %
- Average Delay Hours
- Average Shrinkage %

Visuals:

- Bar chart: On Time Delivery % by Delivery Partner
- Bar chart: On Time Delivery % by Fulfilment Center
- Bar chart: Total Stock Loss by Product Category
- Table: Region, Store, Category, Closing Stock, Stock Loss, dan Average Shrinkage %

Slicers:

- Channel
- Product Category
- Region
- Fulfilment Center

Absolute Stock Variance tidak ditampilkan karena seluruh record saat ini berhasil direkonsiliasi dan menghasilkan variance `0`.
