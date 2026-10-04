/* =====================================================================
   08_advanced_analysis.sql
   Purpose : Concentration, basket behaviour, outliers, sensitivity checks
   ===================================================================== */

-- Q8.1 : Customer concentration (Pareto) - share of revenue from top customers
WITH cust AS (
    SELECT CustomerID, SUM(Revenue) AS revenue FROM online_retail GROUP BY CustomerID
), cum AS (
    SELECT revenue,
           SUM(revenue) OVER (ORDER BY revenue DESC) / SUM(revenue) OVER () AS cum_share,
           ROW_NUMBER() OVER (ORDER BY revenue DESC) AS rnk,
           COUNT(*) OVER () AS n
    FROM cust
)
SELECT 'Top 1% of customers'  AS band, CAST(n * 0.01 AS INTEGER) AS customers, ROUND(100.0 * MAX(CASE WHEN rnk <= n * 0.01 THEN cum_share END), 2) AS cumulative_revenue_pct FROM cum
UNION ALL SELECT 'Top 5% of customers',  CAST(n * 0.05 AS INTEGER), ROUND(100.0 * MAX(CASE WHEN rnk <= n * 0.05 THEN cum_share END), 2) FROM cum
UNION ALL SELECT 'Top 10% of customers', CAST(n * 0.10 AS INTEGER), ROUND(100.0 * MAX(CASE WHEN rnk <= n * 0.10 THEN cum_share END), 2) FROM cum
UNION ALL SELECT 'Top 20% of customers', CAST(n * 0.20 AS INTEGER), ROUND(100.0 * MAX(CASE WHEN rnk <= n * 0.20 THEN cum_share END), 2) FROM cum
UNION ALL SELECT 'Customers needed for 80% of revenue', MIN(CASE WHEN cum_share >= 0.8 THEN rnk END), ROUND(100.0 * MIN(CASE WHEN cum_share >= 0.8 THEN cum_share END), 2) FROM cum;

-- Q8.2 : Order-value bands
WITH orders AS (
    SELECT InvoiceNo, SUM(Revenue) AS order_value FROM online_retail GROUP BY InvoiceNo
)
SELECT CASE WHEN order_value < 100  THEN '1 Under 100'
            WHEN order_value < 250  THEN '2 100 - 249'
            WHEN order_value < 500  THEN '3 250 - 499'
            WHEN order_value < 1000 THEN '4 500 - 999'
            WHEN order_value < 5000 THEN '5 1,000 - 4,999'
            ELSE '6 5,000 and above' END AS order_value_band,
       COUNT(*) AS orders,
       ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM orders), 2) AS order_share_pct,
       ROUND(SUM(order_value), 2) AS revenue,
       ROUND(100.0 * SUM(order_value) / (SELECT SUM(order_value) FROM orders), 2) AS revenue_share_pct
FROM orders
GROUP BY 1
ORDER BY 1;

-- Q8.3 : Basket size - number of distinct products per order
WITH basket AS (
    SELECT InvoiceNo, COUNT(DISTINCT StockCode) AS distinct_products FROM online_retail GROUP BY InvoiceNo
)
SELECT CASE WHEN distinct_products = 1 THEN '1 item'
            WHEN distinct_products <= 5 THEN '2-5 items'
            WHEN distinct_products <= 10 THEN '6-10 items'
            WHEN distinct_products <= 20 THEN '11-20 items'
            WHEN distinct_products <= 50 THEN '21-50 items'
            ELSE '51+ items' END AS basket_size,
       COUNT(*) AS orders,
       ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM basket), 2) AS order_share_pct
FROM basket
GROUP BY 1
ORDER BY MIN(distinct_products);

-- Q8.4 : Products most often bought together (market-basket pairs among the 30 most popular products)
WITH popular AS (
    SELECT StockCode FROM online_retail
    WHERE StockCode GLOB '[0-9][0-9][0-9][0-9][0-9]*'
    GROUP BY StockCode ORDER BY COUNT(DISTINCT InvoiceNo) DESC LIMIT 30
), items AS (
    SELECT DISTINCT o.InvoiceNo, o.StockCode FROM online_retail o JOIN popular p USING (StockCode)
), names AS (
    SELECT StockCode, MIN(Description) AS description FROM online_retail GROUP BY StockCode
), pairs AS (
    SELECT a.StockCode AS item_a, b.StockCode AS item_b, COUNT(*) AS orders_together
    FROM items a JOIN items b ON a.InvoiceNo = b.InvoiceNo AND a.StockCode < b.StockCode
    GROUP BY a.StockCode, b.StockCode
)
SELECT p.item_a, na.description AS description_a, p.item_b, nb.description AS description_b,
       p.orders_together,
       ROUND(100.0 * p.orders_together / (SELECT COUNT(DISTINCT InvoiceNo) FROM online_retail), 2) AS support_pct
FROM pairs p JOIN names na ON na.StockCode = p.item_a JOIN names nb ON nb.StockCode = p.item_b
ORDER BY p.orders_together DESC
LIMIT 10;

-- Q8.5 : Outliers by IQR rule on line revenue (Tukey fences)
WITH ranked AS (
    SELECT Revenue, ROW_NUMBER() OVER (ORDER BY Revenue) AS rn, COUNT(*) OVER () AS n FROM online_retail
), q AS (
    SELECT (SELECT Revenue FROM ranked WHERE rn = CAST(n * 0.25 AS INTEGER) + 1) AS q1,
           (SELECT Revenue FROM ranked WHERE rn = CAST(n * 0.75 AS INTEGER) + 1) AS q3
    FROM ranked LIMIT 1
)
SELECT ROUND(q1, 2) AS q1, ROUND(q3, 2) AS q3,
       ROUND(q3 + 1.5 * (q3 - q1), 2)                 AS upper_fence,
       ROUND(q3 + 3.0 * (q3 - q1), 2)                 AS extreme_fence,
       (SELECT COUNT(*) FROM online_retail WHERE Revenue > q3 + 1.5 * (q3 - q1)) AS mild_outlier_lines,
       (SELECT COUNT(*) FROM online_retail WHERE Revenue > q3 + 3.0 * (q3 - q1)) AS extreme_outlier_lines,
       (SELECT ROUND(100.0 * SUM(Revenue) / (SELECT SUM(Revenue) FROM online_retail), 2)
          FROM online_retail WHERE Revenue > q3 + 3.0 * (q3 - q1))                AS extreme_outlier_revenue_pct
FROM q;

-- Q8.6 : The 10 largest single line items
SELECT InvoiceNo, InvoiceDateTime, CustomerID, Country, StockCode, Description,
       Quantity, UnitPrice, ROUND(Revenue, 2) AS revenue
FROM online_retail
ORDER BY Revenue DESC
LIMIT 10;

-- Q8.7 : Sensitivity - KPIs with and without the single largest order
WITH big AS (
    SELECT InvoiceNo FROM online_retail GROUP BY InvoiceNo ORDER BY SUM(Revenue) DESC LIMIT 1
)
SELECT 'As provided' AS scenario, ROUND(SUM(Revenue), 2) AS total_revenue,
       COUNT(DISTINCT InvoiceNo) AS orders,
       ROUND(SUM(Revenue) / COUNT(DISTINCT InvoiceNo), 2) AS aov,
       ROUND(SUM(Revenue) / SUM(Quantity), 2) AS asp
FROM online_retail
UNION ALL
SELECT 'Without largest order', ROUND(SUM(Revenue), 2), COUNT(DISTINCT InvoiceNo),
       ROUND(SUM(Revenue) / COUNT(DISTINCT InvoiceNo), 2), ROUND(SUM(Revenue) / SUM(Quantity), 2)
FROM online_retail WHERE InvoiceNo NOT IN (SELECT InvoiceNo FROM big);

-- Q8.8 : Sensitivity - impact of removing exact duplicate rows
WITH dedup AS (
    SELECT DISTINCT InvoiceNo, StockCode, Description, Quantity, InvoiceDateTime,
                    UnitPrice, CustomerID, Country, Revenue
    FROM online_retail
)
SELECT 'As provided' AS scenario, COUNT(*) AS line_items, ROUND(SUM(Revenue), 2) AS total_revenue,
       SUM(Quantity) AS quantity FROM online_retail
UNION ALL
SELECT 'Duplicates removed', COUNT(*), ROUND(SUM(Revenue), 2), SUM(Quantity) FROM dedup;

-- Q8.9 : Correlation between unit price and quantity (Pearson, line level)
SELECT ROUND(
  (AVG(UnitPrice * Quantity) - AVG(UnitPrice) * AVG(Quantity)) /
  (SQRT(AVG(UnitPrice * UnitPrice) - AVG(UnitPrice) * AVG(UnitPrice)) *
   SQRT(AVG(Quantity * Quantity)   - AVG(Quantity)   * AVG(Quantity))), 4) AS corr_price_quantity
FROM online_retail;

-- Q8.10 : Invoices that carry more than one timestamp (the 8 cases flagged in the quality checks)
SELECT InvoiceNo, CustomerID, COUNT(DISTINCT InvoiceDateTime) AS timestamps,
       MIN(InvoiceDateTime) AS first_ts, MAX(InvoiceDateTime) AS last_ts
FROM online_retail
GROUP BY InvoiceNo
HAVING COUNT(DISTINCT InvoiceDateTime) > 1
ORDER BY InvoiceNo;
