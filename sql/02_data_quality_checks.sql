/* =====================================================================
   02_data_quality_checks.sql
   Purpose : Validate the "cleaned" dataset before any analysis.
   Each query starts with a "-- Qx.y : title" tag used by run_eda.py.
   ===================================================================== */

-- Q2.1 : Table shape and date range
SELECT COUNT(*)                         AS total_rows,
       COUNT(DISTINCT InvoiceNo)        AS distinct_invoices,
       MIN(InvoiceDateTime)             AS first_transaction,
       MAX(InvoiceDateTime)             AS last_transaction,
       CAST(julianday(MAX(InvoiceDay)) - julianday(MIN(InvoiceDay)) AS INTEGER) + 1 AS days_covered
FROM online_retail;

-- Q2.2 : NULL / blank count for every column
SELECT 'InvoiceNo'   AS column_name, SUM(InvoiceNo   IS NULL)                                  AS null_or_blank FROM online_retail
UNION ALL SELECT 'StockCode',   SUM(StockCode   IS NULL OR TRIM(StockCode)   = '') FROM online_retail
UNION ALL SELECT 'Description', SUM(Description IS NULL OR TRIM(Description) = '') FROM online_retail
UNION ALL SELECT 'Quantity',    SUM(Quantity    IS NULL) FROM online_retail
UNION ALL SELECT 'InvoiceDate', SUM(InvoiceDateTime IS NULL) FROM online_retail
UNION ALL SELECT 'UnitPrice',   SUM(UnitPrice   IS NULL) FROM online_retail
UNION ALL SELECT 'CustomerID',  SUM(CustomerID  IS NULL) FROM online_retail
UNION ALL SELECT 'Country',     SUM(Country     IS NULL OR TRIM(Country) = '') FROM online_retail
UNION ALL SELECT 'Revenue',     SUM(Revenue     IS NULL) FROM online_retail;

-- Q2.3 : Exact duplicate rows (all business columns identical)
SELECT COUNT(*)                              AS duplicate_groups,
       SUM(cnt - 1)                          AS surplus_rows,
       ROUND(100.0 * SUM(cnt - 1) / (SELECT COUNT(*) FROM online_retail), 2) AS pct_of_rows,
       ROUND(SUM((cnt - 1) * line_revenue), 2)                               AS revenue_in_surplus_rows
FROM (
    SELECT InvoiceNo, StockCode, Description, Quantity, InvoiceDateTime, UnitPrice, CustomerID, Country,
           MAX(Revenue) AS line_revenue, COUNT(*) AS cnt
    FROM online_retail
    GROUP BY InvoiceNo, StockCode, Description, Quantity, InvoiceDateTime, UnitPrice, CustomerID, Country
    HAVING COUNT(*) > 1
);

-- Q2.4 : Business-rule violations (should all be 0 in a cleaned file)
SELECT SUM(Quantity  <= 0)                         AS non_positive_quantity,
       SUM(UnitPrice <= 0)                         AS non_positive_price,
       SUM(Revenue   <= 0)                         AS non_positive_revenue,
       SUM(CAST(InvoiceNo AS TEXT) LIKE 'C%')      AS cancelled_invoices,
       SUM(ABS(Revenue - Quantity * UnitPrice) > 0.01) AS revenue_formula_mismatch
FROM online_retail;

-- Q2.5 : Internal consistency of derived columns (Year / Quarter / Month / Weekday)
SELECT SUM(Year    <> CAST(substr(InvoiceDay,1,4) AS INTEGER))               AS year_mismatch,
       SUM(Quarter <> ((MonthNum - 1) / 3) + 1)                              AS quarter_mismatch_calendar,
       SUM(CASE WHEN MonthName <> CASE MonthNum
              WHEN 1 THEN 'January' WHEN 2 THEN 'February' WHEN 3 THEN 'March'
              WHEN 4 THEN 'April'   WHEN 5 THEN 'May'      WHEN 6 THEN 'June'
              WHEN 7 THEN 'July'    WHEN 8 THEN 'August'   WHEN 9 THEN 'September'
              WHEN 10 THEN 'October' WHEN 11 THEN 'November' ELSE 'December' END
            THEN 1 ELSE 0 END)                                               AS month_name_mismatch,
       SUM(WeekdayName <> CASE strftime('%w', InvoiceDay)
              WHEN '0' THEN 'Sunday' WHEN '1' THEN 'Monday' WHEN '2' THEN 'Tuesday'
              WHEN '3' THEN 'Wednesday' WHEN '4' THEN 'Thursday' WHEN '5' THEN 'Friday'
              ELSE 'Saturday' END)                                           AS weekday_mismatch
FROM online_retail;

-- Q2.6 : Cardinality of the key dimensions
SELECT COUNT(DISTINCT CustomerID) AS customers,
       COUNT(DISTINCT StockCode)  AS stock_codes,
       COUNT(DISTINCT Description) AS descriptions,
       COUNT(DISTINCT Country)    AS countries,
       COUNT(DISTINCT YearMonth)  AS months_covered
FROM online_retail;

-- Q2.7 : Stock codes that are NOT products (postage, fees, manual entries ...)
SELECT StockCode, MIN(Description) AS description, COUNT(*) AS line_items,
       SUM(Quantity) AS qty, ROUND(SUM(Revenue),2) AS revenue
FROM online_retail
WHERE StockCode NOT GLOB '[0-9][0-9][0-9][0-9][0-9]*'
GROUP BY StockCode
ORDER BY revenue DESC;

-- Q2.8 : One StockCode mapped to several descriptions
SELECT StockCode, COUNT(DISTINCT Description) AS description_variants
FROM online_retail
GROUP BY StockCode
HAVING COUNT(DISTINCT Description) > 1
ORDER BY description_variants DESC
LIMIT 15;

-- Q2.9 : Customers appearing in more than one country
SELECT CustomerID, COUNT(DISTINCT Country) AS countries
FROM online_retail
GROUP BY CustomerID
HAVING COUNT(DISTINCT Country) > 1;

-- Q2.10 : Invoices spanning more than one timestamp or customer (should be 0)
SELECT SUM(CASE WHEN ts > 1 THEN 1 ELSE 0 END)   AS invoices_with_multiple_timestamps,
       SUM(CASE WHEN cu > 1 THEN 1 ELSE 0 END)   AS invoices_with_multiple_customers
FROM (SELECT InvoiceNo, COUNT(DISTINCT InvoiceDateTime) AS ts, COUNT(DISTINCT CustomerID) AS cu
      FROM online_retail GROUP BY InvoiceNo);

-- Q2.11 : Extreme values (outlier candidates)
SELECT 'Quantity > 1000'    AS check_name, COUNT(*) AS rows_flagged, ROUND(SUM(Revenue),2) AS revenue FROM online_retail WHERE Quantity > 1000
UNION ALL SELECT 'UnitPrice > 500',    COUNT(*), ROUND(SUM(Revenue),2) FROM online_retail WHERE UnitPrice > 500
UNION ALL SELECT 'Line revenue > 5000', COUNT(*), ROUND(SUM(Revenue),2) FROM online_retail WHERE Revenue > 5000
UNION ALL SELECT 'UnitPrice < 0.10',   COUNT(*), ROUND(SUM(Revenue),2) FROM online_retail WHERE UnitPrice < 0.10;

-- Q2.12 : Rows per month (reveals partial months)
SELECT YearMonth, COUNT(*) AS rows_in_month,
       MIN(InvoiceDay) AS first_day, MAX(InvoiceDay) AS last_day,
       COUNT(DISTINCT InvoiceDay) AS active_days
FROM online_retail
GROUP BY YearMonth
ORDER BY YearMonth;

-- Q2.13 : Which days of the month are present? (coverage check)
SELECT CAST(substr(InvoiceDay, 9, 2) AS INTEGER) AS day_of_month,
       COUNT(*)                                  AS rows_on_that_day,
       COUNT(DISTINCT YearMonth)                 AS months_with_data
FROM online_retail
GROUP BY day_of_month
ORDER BY day_of_month;
