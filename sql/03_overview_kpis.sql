/* =====================================================================
   03_overview_kpis.sql
   Purpose : Headline business KPIs (mirrors the Power BI dashboard KPIs)
   Definitions
     Order    = DISTINCT InvoiceNo
     AOV      = Total Revenue / Total Orders
     ASP      = Total Revenue / Total Quantity
     Repeat   = customer with more than 1 distinct invoice
   ===================================================================== */

-- Q3.1 : Headline KPIs
SELECT COUNT(*)                                                  AS line_items,
       COUNT(DISTINCT InvoiceNo)                                 AS total_orders,
       COUNT(DISTINCT CustomerID)                                AS total_customers,
       COUNT(DISTINCT StockCode)                                 AS total_products,
       COUNT(DISTINCT Country)                                   AS total_countries,
       SUM(Quantity)                                             AS quantity_sold,
       ROUND(SUM(Revenue), 2)                                    AS total_revenue,
       ROUND(SUM(Revenue) / COUNT(DISTINCT InvoiceNo), 2)        AS avg_order_value,
       ROUND(SUM(Revenue) / SUM(Quantity), 2)                    AS avg_selling_price,
       ROUND(SUM(Revenue) / COUNT(DISTINCT CustomerID), 2)       AS revenue_per_customer,
       ROUND(COUNT(DISTINCT InvoiceNo) * 1.0 / COUNT(DISTINCT CustomerID), 2) AS orders_per_customer,
       ROUND(COUNT(*) * 1.0 / COUNT(DISTINCT InvoiceNo), 2)      AS lines_per_order,
       ROUND(SUM(Quantity) * 1.0 / COUNT(DISTINCT InvoiceNo), 2) AS units_per_order
FROM online_retail;

-- Q3.2 : Repeat-customer KPIs
WITH cust AS (
    SELECT CustomerID, COUNT(DISTINCT InvoiceNo) AS orders, SUM(Revenue) AS revenue
    FROM online_retail GROUP BY CustomerID
)
SELECT COUNT(*)                                            AS customers,
       SUM(orders > 1)                                     AS repeat_customers,
       SUM(orders = 1)                                     AS one_time_customers,
       ROUND(100.0 * SUM(orders > 1) / COUNT(*), 2)        AS repeat_rate_pct,
       ROUND(100.0 * SUM(CASE WHEN orders > 1 THEN revenue END) / SUM(revenue), 2) AS revenue_share_from_repeat_pct
FROM cust;

-- Q3.3 : Revenue by calendar year
SELECT Year,
       COUNT(DISTINCT InvoiceNo)  AS orders,
       COUNT(DISTINCT CustomerID) AS customers,
       SUM(Quantity)              AS quantity,
       ROUND(SUM(Revenue), 2)     AS revenue,
       ROUND(100.0 * SUM(Revenue) / (SELECT SUM(Revenue) FROM online_retail), 2) AS revenue_share_pct
FROM online_retail
GROUP BY Year
ORDER BY Year;

-- Q3.4 : Descriptive statistics at line level
WITH ranked AS (
    SELECT Quantity, UnitPrice, Revenue,
           ROW_NUMBER() OVER (ORDER BY Quantity)  AS rq,
           ROW_NUMBER() OVER (ORDER BY UnitPrice) AS rp,
           ROW_NUMBER() OVER (ORDER BY Revenue)   AS rr,
           COUNT(*) OVER ()                       AS n
    FROM online_retail
)
SELECT 'Quantity' AS metric, MIN(Quantity) AS min_val, ROUND(AVG(Quantity),2) AS mean_val,
       (SELECT AVG(Quantity) FROM ranked WHERE rq IN ((n+1)/2, (n+2)/2)) AS median_val,
       MAX(Quantity) AS max_val,
       ROUND(AVG(Quantity*Quantity) - AVG(Quantity)*AVG(Quantity), 2) AS variance
FROM ranked
UNION ALL
SELECT 'UnitPrice', MIN(UnitPrice), ROUND(AVG(UnitPrice),2),
       (SELECT AVG(UnitPrice) FROM ranked WHERE rp IN ((n+1)/2, (n+2)/2)),
       MAX(UnitPrice), ROUND(AVG(UnitPrice*UnitPrice) - AVG(UnitPrice)*AVG(UnitPrice), 2)
FROM ranked
UNION ALL
SELECT 'Revenue', MIN(Revenue), ROUND(AVG(Revenue),2),
       (SELECT AVG(Revenue) FROM ranked WHERE rr IN ((n+1)/2, (n+2)/2)),
       MAX(Revenue), ROUND(AVG(Revenue*Revenue) - AVG(Revenue)*AVG(Revenue), 2)
FROM ranked;

-- Q3.5 : Descriptive statistics at order level (value of a basket)
WITH orders AS (
    SELECT InvoiceNo, SUM(Revenue) AS order_value, SUM(Quantity) AS units, COUNT(*) AS lines
    FROM online_retail GROUP BY InvoiceNo
), ranked AS (
    SELECT order_value, units, lines,
           ROW_NUMBER() OVER (ORDER BY order_value) AS rv,
           ROW_NUMBER() OVER (ORDER BY units)       AS ru,
           ROW_NUMBER() OVER (ORDER BY lines)       AS rl,
           COUNT(*) OVER () AS n
    FROM orders
)
SELECT 'Order value' AS metric, ROUND(MIN(order_value),2) AS min_val, ROUND(AVG(order_value),2) AS mean_val,
       ROUND((SELECT AVG(order_value) FROM ranked WHERE rv IN ((n+1)/2,(n+2)/2)),2) AS median_val,
       ROUND(MAX(order_value),2) AS max_val FROM ranked
UNION ALL
SELECT 'Units per order', MIN(units), ROUND(AVG(units),2),
       (SELECT AVG(units) FROM ranked WHERE ru IN ((n+1)/2,(n+2)/2)), MAX(units) FROM ranked
UNION ALL
SELECT 'Lines per order', MIN(lines), ROUND(AVG(lines),2),
       (SELECT AVG(lines) FROM ranked WHERE rl IN ((n+1)/2,(n+2)/2)), MAX(lines) FROM ranked;
