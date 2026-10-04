/* =====================================================================
   07_country_analysis.sql
   Purpose : Geographic split of revenue, customers and order behaviour
   ===================================================================== */

-- Q7.1 : Country league table
SELECT Country,
       COUNT(DISTINCT CustomerID) AS customers,
       COUNT(DISTINCT InvoiceNo)  AS orders,
       SUM(Quantity)              AS quantity,
       ROUND(SUM(Revenue), 2)     AS revenue,
       ROUND(100.0 * SUM(Revenue) / (SELECT SUM(Revenue) FROM online_retail), 2) AS revenue_share_pct,
       ROUND(SUM(Revenue) / COUNT(DISTINCT InvoiceNo), 2)  AS aov,
       ROUND(SUM(Revenue) / COUNT(DISTINCT CustomerID), 2) AS revenue_per_customer
FROM online_retail
GROUP BY Country
ORDER BY revenue DESC;

-- Q7.2 : United Kingdom vs rest of the world
SELECT CASE WHEN Country = 'United Kingdom' THEN 'United Kingdom' ELSE 'International' END AS market,
       COUNT(DISTINCT Country)    AS countries,
       COUNT(DISTINCT CustomerID) AS customers,
       COUNT(DISTINCT InvoiceNo)  AS orders,
       ROUND(SUM(Revenue), 2)     AS revenue,
       ROUND(100.0 * SUM(Revenue) / (SELECT SUM(Revenue) FROM online_retail), 2) AS revenue_share_pct,
       ROUND(SUM(Revenue) / COUNT(DISTINCT InvoiceNo), 2)  AS aov,
       ROUND(SUM(Revenue) / COUNT(DISTINCT CustomerID), 2) AS revenue_per_customer,
       ROUND(SUM(Quantity) * 1.0 / COUNT(DISTINCT InvoiceNo), 1) AS units_per_order
FROM online_retail
GROUP BY 1
ORDER BY revenue DESC;

-- Q7.3 : Repeat-customer rate by country (countries with 20+ customers)
WITH cust AS (
    SELECT Country, CustomerID, COUNT(DISTINCT InvoiceNo) AS orders
    FROM online_retail GROUP BY Country, CustomerID
)
SELECT Country, COUNT(*) AS customers, SUM(orders > 1) AS repeat_customers,
       ROUND(100.0 * SUM(orders > 1) / COUNT(*), 2) AS repeat_rate_pct
FROM cust
GROUP BY Country
HAVING COUNT(*) >= 20
ORDER BY repeat_rate_pct DESC;

-- Q7.4 : Top-3 products in each of the 5 biggest international markets
WITH top_countries AS (
    SELECT Country FROM online_retail WHERE Country <> 'United Kingdom'
    GROUP BY Country ORDER BY SUM(Revenue) DESC LIMIT 5
), ranked AS (
    SELECT o.Country, o.StockCode, MIN(o.Description) AS description,
           SUM(o.Quantity) AS quantity, ROUND(SUM(o.Revenue), 2) AS revenue,
           ROW_NUMBER() OVER (PARTITION BY o.Country ORDER BY SUM(o.Revenue) DESC) AS rnk
    FROM online_retail o JOIN top_countries t USING (Country)
    WHERE o.StockCode GLOB '[0-9][0-9][0-9][0-9][0-9]*'
    GROUP BY o.Country, o.StockCode
)
SELECT Country, rnk AS rank_in_country, StockCode, description, quantity, revenue
FROM ranked WHERE rnk <= 3
ORDER BY Country, rnk;

-- Q7.5 : Monthly revenue - UK vs International
SELECT YearMonth,
       ROUND(SUM(CASE WHEN Country = 'United Kingdom' THEN Revenue ELSE 0 END), 2) AS uk_revenue,
       ROUND(SUM(CASE WHEN Country <> 'United Kingdom' THEN Revenue ELSE 0 END), 2) AS international_revenue,
       ROUND(100.0 * SUM(CASE WHEN Country <> 'United Kingdom' THEN Revenue ELSE 0 END) / SUM(Revenue), 2) AS international_share_pct
FROM online_retail
GROUP BY YearMonth
ORDER BY YearMonth;
