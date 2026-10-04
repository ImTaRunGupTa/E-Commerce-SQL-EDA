/* =====================================================================
   09_reporting_views.sql
   Purpose : Reusable views that can be connected to Power BI / Tableau
   ===================================================================== */

-- Q9.1 : View - monthly sales summary
DROP VIEW IF EXISTS vw_monthly_sales;
CREATE VIEW vw_monthly_sales AS
SELECT YearMonth, Year, MonthNum, MonthName,
       COUNT(DISTINCT InvoiceNo)  AS orders,
       COUNT(DISTINCT CustomerID) AS customers,
       SUM(Quantity)              AS quantity,
       ROUND(SUM(Revenue), 2)     AS revenue,
       ROUND(SUM(Revenue) / COUNT(DISTINCT InvoiceNo), 2) AS aov
FROM online_retail
GROUP BY YearMonth, Year, MonthNum, MonthName;

-- Q9.2 : View - customer summary
DROP VIEW IF EXISTS vw_customer_summary;
CREATE VIEW vw_customer_summary AS
SELECT CustomerID, MIN(Country) AS Country,
       MIN(InvoiceDay) AS first_purchase, MAX(InvoiceDay) AS last_purchase,
       COUNT(DISTINCT InvoiceNo) AS orders,
       SUM(Quantity)             AS quantity,
       ROUND(SUM(Revenue), 2)    AS revenue,
       ROUND(SUM(Revenue) / COUNT(DISTINCT InvoiceNo), 2) AS aov,
       CASE WHEN COUNT(DISTINCT InvoiceNo) > 1 THEN 'Repeat' ELSE 'One-time' END AS customer_type
FROM online_retail
GROUP BY CustomerID;

-- Q9.3 : View - product summary
DROP VIEW IF EXISTS vw_product_summary;
CREATE VIEW vw_product_summary AS
SELECT StockCode, MIN(Description) AS Description,
       COUNT(DISTINCT InvoiceNo)  AS orders,
       COUNT(DISTINCT CustomerID) AS customers,
       SUM(Quantity)              AS quantity,
       ROUND(SUM(Revenue), 2)     AS revenue,
       ROUND(SUM(Revenue) / SUM(Quantity), 2) AS avg_selling_price
FROM online_retail
GROUP BY StockCode;

-- Q9.4 : View - country summary
DROP VIEW IF EXISTS vw_country_summary;
CREATE VIEW vw_country_summary AS
SELECT Country,
       COUNT(DISTINCT CustomerID) AS customers,
       COUNT(DISTINCT InvoiceNo)  AS orders,
       SUM(Quantity)              AS quantity,
       ROUND(SUM(Revenue), 2)     AS revenue,
       ROUND(SUM(Revenue) / COUNT(DISTINCT InvoiceNo), 2) AS aov
FROM online_retail
GROUP BY Country;

-- Q9.5 : Smoke test - views return data
SELECT (SELECT COUNT(*) FROM vw_monthly_sales)    AS monthly_rows,
       (SELECT COUNT(*) FROM vw_customer_summary) AS customer_rows,
       (SELECT COUNT(*) FROM vw_product_summary)  AS product_rows,
       (SELECT COUNT(*) FROM vw_country_summary)  AS country_rows,
       (SELECT COUNT(*) FROM vw_rfm)              AS rfm_rows;
