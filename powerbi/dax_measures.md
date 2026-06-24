# DAX Measures

Buat satu table khusus bernama `Measure Table`, lalu tambahkan measure berikut.

## Sales dan Customer

```DAX
Net Sales = SUM(fact_sales[net_sales])
```

```DAX
Gross Profit = SUM(fact_sales[gross_profit])
```

```DAX
Gross Margin % = DIVIDE([Gross Profit], [Net Sales])
```

```DAX
Sales Transactions = DISTINCTCOUNT(fact_sales[transaction_id])
```

```DAX
Average Transaction Value = DIVIDE([Net Sales], [Sales Transactions])
```

## Online Orders

```DAX
Total Online Order Value = SUM(fact_online_orders[total_order_value])
```

```DAX
Online Orders = COUNTROWS(fact_online_orders)
```

```DAX
Fulfilled Orders =
CALCULATE(
    COUNTROWS(fact_online_orders),
    fact_online_orders[fulfilled_flag] = 1
)
```

```DAX
Fulfillment Rate % = DIVIDE([Fulfilled Orders], [Online Orders])
```

## Delivery

```DAX
On Time Deliveries =
CALCULATE(
    COUNTROWS(fact_delivery_performance),
    fact_delivery_performance[on_time_flag] = 1
)
```

```DAX
On Time Delivery % =
DIVIDE([On Time Deliveries], COUNTROWS(fact_delivery_performance))
```

```DAX
Average Delay Hours = AVERAGE(fact_delivery_performance[delay_hours])
```

## Inventory

```DAX
Closing Stock = SUM(fact_inventory_daily[closing_stock])
```

```DAX
Total Stock Loss = SUM(fact_inventory_daily[stock_loss])
```

```DAX
Average Shrinkage % = AVERAGE(fact_inventory_daily[shrinkage_rate])
```

```DAX
Shrinkage Gauge Maximum = 0.05
```

Format `Gross Margin %`, `Fulfillment Rate %`, `On Time Delivery %`, dan `Average Shrinkage %` sebagai Percentage. Format sales dan order value sebagai Currency.
