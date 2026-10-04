/* =====================================================================
   06_product_analysis.sql
   Purpose : Product performance - revenue, volume, price, concentration
   Note    : Non-product codes (POST, M, DOT, C2, BANK CHARGES) are kept in
             the overall counts but are excluded where we rank "products".
   ===================================================================== */

-- Q6.1 : Top 10 products by revenue
SELECT StockCode, MIN(Description) AS description,
       SUM(Quantity)             AS quantity,
       COUNT(DISTINCT InvoiceNo) AS orders,
       ROUND(SUM(Revenue), 2)    AS revenue,
       ROUND(SUM(Revenue) / SUM(Quantity), 2) AS avg_selling_price,
       ROUND(100.0 * SUM(Revenue) / (SELECT SUM(Revenue) FROM online_retail), 2) AS revenue_share_pct
FROM online_retail
WHERE StockCode GLOB '[0-9][0-9][0-9][0-9][0-9]*'
GROUP BY StockCode
ORDER BY revenue DESC
LIMIT 10;

-- Q6.2 : Top 10 products by quantity sold
SELECT StockCode, MIN(Description) AS description,
       SUM(Quantity) AS quantity,
       ROUND(SUM(Revenue), 2) AS revenue,
       ROUND(SUM(Revenue) / SUM(Quantity), 2) AS avg_selling_price
FROM online_retail
WHERE StockCode GLOB '[0-9][0-9][0-9][0-9][0-9]*'
GROUP BY StockCode
ORDER BY quantity DESC
LIMIT 10;

-- Q6.3 : Top 10 most popular products (appear in most orders)
SELECT StockCode, MIN(Description) AS description,
       COUNT(DISTINCT InvoiceNo)  AS orders_containing,
       ROUND(100.0 * COUNT(DISTINCT InvoiceNo) / (SELECT COUNT(DISTINCT InvoiceNo) FROM online_retail), 2) AS order_penetration_pct,
       COUNT(DISTINCT CustomerID) AS customers
FROM online_retail
WHERE StockCode GLOB '[0-9][0-9][0-9][0-9][0-9]*'
GROUP BY StockCode
ORDER BY orders_containing DESC
LIMIT 10;

-- Q6.4 : Ten lowest-revenue products that sold at least 10 units
SELECT StockCode, MIN(Description) AS description,
       SUM(Quantity) AS quantity, ROUND(SUM(Revenue), 2) AS revenue
FROM online_retail
WHERE StockCode GLOB '[0-9][0-9][0-9][0-9][0-9]*'
GROUP BY StockCode
HAVING SUM(Quantity) >= 10
ORDER BY revenue ASC
LIMIT 10;

-- Q6.5 : Unit-price bands
SELECT CASE WHEN UnitPrice < 1    THEN '1 Under 1'
            WHEN UnitPrice < 2    THEN '2 1 - 1.99'
            WHEN UnitPrice < 5    THEN '3 2 - 4.99'
            WHEN UnitPrice < 10   THEN '4 5 - 9.99'
            WHEN UnitPrice < 50   THEN '5 10 - 49.99'
            ELSE '6 50 and above' END AS price_band,
       COUNT(DISTINCT StockCode)  AS products,
       SUM(Quantity)              AS quantity,
       ROUND(SUM(Revenue), 2)     AS revenue,
       ROUND(100.0 * SUM(Revenue) / (SELECT SUM(Revenue) FROM online_retail), 2) AS revenue_share_pct,
       ROUND(100.0 * SUM(Quantity) / (SELECT SUM(Quantity) FROM online_retail), 2) AS quantity_share_pct
FROM online_retail
GROUP BY 1
ORDER BY 1;

-- Q6.6 : Revenue from non-product codes (postage, manual entries, fees)
SELECT CASE WHEN StockCode GLOB '[0-9][0-9][0-9][0-9][0-9]*' THEN 'Product' ELSE 'Non-product (fees/postage/manual)' END AS code_type,
       COUNT(DISTINCT StockCode) AS codes,
       COUNT(*)                  AS line_items,
       ROUND(SUM(Revenue), 2)    AS revenue,
       ROUND(100.0 * SUM(Revenue) / (SELECT SUM(Revenue) FROM online_retail), 2) AS revenue_share_pct
FROM online_retail
GROUP BY 1;

-- Q6.7 : Products sold in the most countries
SELECT StockCode, MIN(Description) AS description,
       COUNT(DISTINCT Country) AS countries,
       ROUND(SUM(Revenue), 2)  AS revenue
FROM online_retail
WHERE StockCode GLOB '[0-9][0-9][0-9][0-9][0-9]*'
GROUP BY StockCode
ORDER BY countries DESC, revenue DESC
LIMIT 10;

-- Q6.8 : Product concentration (Pareto) - how many products make 80% of revenue?
WITH prod AS (
    SELECT StockCode, SUM(Revenue) AS revenue FROM online_retail GROUP BY StockCode
), cum AS (
    SELECT StockCode, revenue,
           SUM(revenue) OVER (ORDER BY revenue DESC) / SUM(revenue) OVER () AS cum_share,
           ROW_NUMBER() OVER (ORDER BY revenue DESC) AS rnk,
           COUNT(*) OVER () AS total_products
    FROM prod
)
SELECT 'Top 10% of products' AS band, ROUND(100.0 * MAX(CASE WHEN rnk <= total_products * 0.10 THEN cum_share END), 2) AS cumulative_revenue_pct, CAST(total_products * 0.10 AS INTEGER) AS products FROM cum
UNION ALL
SELECT 'Top 20% of products', ROUND(100.0 * MAX(CASE WHEN rnk <= total_products * 0.20 THEN cum_share END), 2), CAST(total_products * 0.20 AS INTEGER) FROM cum
UNION ALL
SELECT 'Products needed for 80% revenue', ROUND(100.0 * MIN(CASE WHEN cum_share >= 0.8 THEN cum_share END), 2), MIN(CASE WHEN cum_share >= 0.8 THEN rnk END) FROM cum;

-- Q6.9 : Items with a very high price but low volume (premium items)
SELECT StockCode, MIN(Description) AS description,
       ROUND(AVG(UnitPrice), 2) AS avg_unit_price,
       SUM(Quantity) AS quantity,
       ROUND(SUM(Revenue), 2) AS revenue
FROM online_retail
WHERE StockCode GLOB '[0-9][0-9][0-9][0-9][0-9]*'
GROUP BY StockCode
HAVING AVG(UnitPrice) >= 20
ORDER BY avg_unit_price DESC
LIMIT 10;
