/* =====================================================================
   04_sales_analysis.sql
   Purpose : Time-based sales analysis - trend, seasonality, weekday, hour
   ===================================================================== */

-- Q4.1 : Monthly sales with month-over-month growth
WITH monthly AS (
    SELECT YearMonth,
           COUNT(DISTINCT InvoiceNo)  AS orders,
           COUNT(DISTINCT CustomerID) AS customers,
           SUM(Quantity)              AS quantity,
           SUM(Revenue)               AS revenue
    FROM online_retail GROUP BY YearMonth
)
SELECT YearMonth, orders, customers, quantity,
       ROUND(revenue, 2)                                   AS revenue,
       ROUND(revenue / orders, 2)                          AS aov,
       ROUND(100.0 * (revenue - LAG(revenue) OVER (ORDER BY YearMonth))
                   / LAG(revenue) OVER (ORDER BY YearMonth), 2) AS mom_growth_pct
FROM monthly
ORDER BY YearMonth;

-- Q4.2 : Running total and 3-month moving average of revenue
WITH monthly AS (
    SELECT YearMonth, SUM(Revenue) AS revenue FROM online_retail GROUP BY YearMonth
)
SELECT YearMonth,
       ROUND(revenue, 2)                                              AS revenue,
       ROUND(SUM(revenue) OVER (ORDER BY YearMonth), 2)               AS cumulative_revenue,
       ROUND(AVG(revenue) OVER (ORDER BY YearMonth
                                ROWS BETWEEN 2 PRECEDING AND CURRENT ROW), 2) AS moving_avg_3m
FROM monthly
ORDER BY YearMonth;

-- Q4.3 : Quarterly performance
SELECT Year, Quarter,
       COUNT(DISTINCT InvoiceNo) AS orders,
       SUM(Quantity)             AS quantity,
       ROUND(SUM(Revenue), 2)    AS revenue,
       ROUND(100.0 * SUM(Revenue) / (SELECT SUM(Revenue) FROM online_retail), 2) AS revenue_share_pct
FROM online_retail
GROUP BY Year, Quarter
ORDER BY Year, Quarter;

-- Q4.4 : Seasonality by calendar month (all years combined)
SELECT MonthNum, MonthName,
       COUNT(DISTINCT YearMonth)  AS months_in_data,
       ROUND(SUM(Revenue), 2)     AS revenue,
       ROUND(SUM(Revenue) / COUNT(DISTINCT YearMonth), 2) AS avg_revenue_per_month,
       COUNT(DISTINCT InvoiceNo)  AS orders
FROM online_retail
GROUP BY MonthNum, MonthName
ORDER BY MonthNum;

-- Q4.5 : Revenue by weekday
SELECT WeekdayName,
       COUNT(DISTINCT InvoiceNo) AS orders,
       SUM(Quantity)             AS quantity,
       ROUND(SUM(Revenue), 2)    AS revenue,
       ROUND(100.0 * SUM(Revenue) / (SELECT SUM(Revenue) FROM online_retail), 2) AS revenue_share_pct,
       ROUND(SUM(Revenue) / COUNT(DISTINCT InvoiceNo), 2) AS aov
FROM online_retail
GROUP BY WeekdayName
ORDER BY CASE WeekdayName WHEN 'Monday' THEN 1 WHEN 'Tuesday' THEN 2 WHEN 'Wednesday' THEN 3
                          WHEN 'Thursday' THEN 4 WHEN 'Friday' THEN 5 WHEN 'Saturday' THEN 6 ELSE 7 END;

-- Q4.6 : Revenue by hour of the day
SELECT HourOfDay,
       COUNT(DISTINCT InvoiceNo) AS orders,
       ROUND(SUM(Revenue), 2)    AS revenue,
       ROUND(100.0 * SUM(Revenue) / (SELECT SUM(Revenue) FROM online_retail), 2) AS revenue_share_pct
FROM online_retail
GROUP BY HourOfDay
ORDER BY HourOfDay;

-- Q4.7 : Day-part analysis
SELECT CASE WHEN HourOfDay < 12 THEN '1 Morning (before 12)'
            WHEN HourOfDay < 15 THEN '2 Midday (12-14)'
            WHEN HourOfDay < 18 THEN '3 Afternoon (15-17)'
            ELSE '4 Evening (18+)' END AS day_part,
       COUNT(DISTINCT InvoiceNo)  AS orders,
       ROUND(SUM(Revenue), 2)     AS revenue,
       ROUND(100.0 * SUM(Revenue) / (SELECT SUM(Revenue) FROM online_retail), 2) AS revenue_share_pct
FROM online_retail
GROUP BY 1
ORDER BY 1;

-- Q4.8 : Ten best revenue days
SELECT InvoiceDay, WeekdayName,
       COUNT(DISTINCT InvoiceNo) AS orders,
       ROUND(SUM(Revenue), 2)    AS revenue
FROM online_retail
GROUP BY InvoiceDay, WeekdayName
ORDER BY revenue DESC
LIMIT 10;

-- Q4.9 : Average daily revenue by month (adjusts for the different number of days with data)
SELECT YearMonth,
       COUNT(DISTINCT InvoiceDay)                         AS active_days,
       ROUND(SUM(Revenue), 2)                             AS revenue,
       ROUND(SUM(Revenue) / COUNT(DISTINCT InvoiceDay), 2) AS revenue_per_active_day
FROM online_retail
GROUP BY YearMonth
ORDER BY YearMonth;

-- Q4.10 : Monthly revenue with and without the single largest order (outlier-adjusted trend)
WITH big AS (
    SELECT InvoiceNo FROM online_retail GROUP BY InvoiceNo ORDER BY SUM(Revenue) DESC LIMIT 1
)
SELECT YearMonth,
       ROUND(SUM(Revenue), 2) AS revenue_as_provided,
       ROUND(SUM(CASE WHEN InvoiceNo NOT IN (SELECT InvoiceNo FROM big) THEN Revenue ELSE 0 END), 2) AS revenue_excl_largest_order
FROM online_retail
GROUP BY YearMonth
ORDER BY YearMonth;
