# DAX Measures

Create these measures in Power BI.

```DAX
Total Sales = SUM(fact_sales[total_sales_amount])
```

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
Quantity Sold = SUM(fact_sales[quantity_sold])
```

```DAX
Average Order Value = AVERAGE(fact_online_orders[order_value])
```

```DAX
Total Online Order Value = SUM(fact_online_orders[order_value])
```

```DAX
Total Order Value With Fees = SUM(fact_online_orders[total_order_value])
```

```DAX
Fulfilled Orders = CALCULATE(COUNTROWS(fact_online_orders), fact_online_orders[fulfilled_flag] = 1)
```

```DAX
Fulfillment Rate % = DIVIDE([Fulfilled Orders], COUNTROWS(fact_online_orders))
```

```DAX
Closing Stock = SUM(fact_inventory_daily[closing_stock])
```

```DAX
Stock Variance = SUM(fact_inventory_daily[stock_variance])
```

```DAX
Absolute Stock Variance = SUM(fact_inventory_daily[stock_variance_abs])
```

```DAX
Average Shrinkage % = AVERAGE(fact_inventory_daily[shrinkage_rate])
```

```DAX
On Time Deliveries = CALCULATE(COUNTROWS(fact_delivery_performance), fact_delivery_performance[on_time_flag] = 1)
```

```DAX
On Time Delivery % = DIVIDE([On Time Deliveries], COUNTROWS(fact_delivery_performance))
```

```DAX
Average Delay Minutes = AVERAGE(fact_delivery_performance[delay_minutes])
```

```DAX
Average Delay Hours = AVERAGE(fact_delivery_performance[delay_hours])
```

```DAX
Total Purchase Amount = SUM(fact_procurement[purchase_amount])
```

```DAX
Average Supplier Fill Rate % = AVERAGE(fact_procurement[fill_rate])
```

```DAX
Late Procurement Deliveries = CALCULATE(COUNTROWS(fact_procurement), fact_procurement[late_delivery_flag] = 1)
```

```DAX
Late Procurement % = DIVIDE([Late Procurement Deliveries], COUNTROWS(fact_procurement))
```

```DAX
Data Quality Issues = COUNTROWS(data_quality_issue)
```

```DAX
Hard Rejects = CALCULATE(COUNTROWS(data_quality_issue), data_quality_issue[severity] = "ERROR")
```

```DAX
Lookup Warnings = CALCULATE(COUNTROWS(data_quality_issue), data_quality_issue[issue_code] = "LOOKUP_NOT_FOUND")
```
