/* =====================================================================
   05_customer_analysis.sql
   Purpose : Who buys, how often, how much - segmentation, RFM, cohorts
   ===================================================================== */

-- Q5.1 : Top 10 customers by revenue
SELECT CustomerID,
       MIN(Country)               AS country,
       COUNT(DISTINCT InvoiceNo)  AS orders,
       SUM(Quantity)              AS quantity,
       ROUND(SUM(Revenue), 2)     AS revenue,
       ROUND(100.0 * SUM(Revenue) / (SELECT SUM(Revenue) FROM online_retail), 2) AS revenue_share_pct
FROM online_retail
GROUP BY CustomerID
ORDER BY revenue DESC
LIMIT 10;

-- Q5.2 : Top 10 customers by number of orders
SELECT CustomerID,
       MIN(Country)               AS country,
       COUNT(DISTINCT InvoiceNo)  AS orders,
       ROUND(SUM(Revenue), 2)     AS revenue,
       ROUND(SUM(Revenue) / COUNT(DISTINCT InvoiceNo), 2) AS aov
FROM online_retail
GROUP BY CustomerID
ORDER BY orders DESC, revenue DESC
LIMIT 10;

-- Q5.3 : Distribution of customers by number of orders
WITH cust AS (
    SELECT CustomerID, COUNT(DISTINCT InvoiceNo) AS orders, SUM(Revenue) AS revenue
    FROM online_retail GROUP BY CustomerID
)
SELECT CASE WHEN orders = 1 THEN '1 order'
            WHEN orders = 2 THEN '2 orders'
            WHEN orders BETWEEN 3 AND 5 THEN '3-5 orders'
            WHEN orders BETWEEN 6 AND 10 THEN '6-10 orders'
            ELSE '11+ orders' END AS order_frequency_band,
       COUNT(*)                                          AS customers,
       ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM cust), 2) AS customer_share_pct,
       ROUND(SUM(revenue), 2)                            AS revenue,
       ROUND(100.0 * SUM(revenue) / (SELECT SUM(revenue) FROM cust), 2) AS revenue_share_pct
FROM cust
GROUP BY 1
ORDER BY MIN(orders);

-- Q5.4 : Value segments - customers split into revenue quartiles
WITH cust AS (
    SELECT CustomerID, SUM(Revenue) AS revenue FROM online_retail GROUP BY CustomerID
), q AS (
    SELECT CustomerID, revenue, NTILE(4) OVER (ORDER BY revenue DESC) AS quartile FROM cust
)
SELECT CASE quartile WHEN 1 THEN 'Q1 - Top 25% (High value)'
                     WHEN 2 THEN 'Q2 - Upper-mid 25%'
                     WHEN 3 THEN 'Q3 - Lower-mid 25%'
                     ELSE 'Q4 - Bottom 25% (Low value)' END AS value_segment,
       COUNT(*)                         AS customers,
       ROUND(MIN(revenue), 2)           AS min_revenue,
       ROUND(MAX(revenue), 2)           AS max_revenue,
       ROUND(AVG(revenue), 2)           AS avg_revenue,
       ROUND(SUM(revenue), 2)           AS revenue,
       ROUND(100.0 * SUM(revenue) / (SELECT SUM(revenue) FROM cust), 2) AS revenue_share_pct
FROM q
GROUP BY quartile
ORDER BY quartile;

-- Q5.5 : Repeat vs one-time customers
WITH cust AS (
    SELECT CustomerID, COUNT(DISTINCT InvoiceNo) AS orders, SUM(Revenue) AS revenue, SUM(Quantity) AS qty
    FROM online_retail GROUP BY CustomerID
)
SELECT CASE WHEN orders > 1 THEN 'Repeat' ELSE 'One-time' END AS customer_type,
       COUNT(*)                              AS customers,
       ROUND(SUM(revenue), 2)                AS revenue,
       ROUND(AVG(revenue), 2)                AS avg_revenue_per_customer,
       ROUND(AVG(orders), 2)                 AS avg_orders,
       ROUND(SUM(revenue) / SUM(orders), 2)  AS aov
FROM cust
GROUP BY 1;

-- Q5.6 : New vs returning customers each month
WITH first_order AS (
    SELECT CustomerID, MIN(YearMonth) AS first_month FROM online_retail GROUP BY CustomerID
), activity AS (
    SELECT DISTINCT o.YearMonth, o.CustomerID, f.first_month
    FROM online_retail o JOIN first_order f USING (CustomerID)
)
SELECT YearMonth,
       SUM(YearMonth = first_month)  AS new_customers,
       SUM(YearMonth > first_month)  AS returning_customers,
       COUNT(*)                      AS active_customers,
       ROUND(100.0 * SUM(YearMonth > first_month) / COUNT(*), 2) AS returning_pct
FROM activity
GROUP BY YearMonth
ORDER BY YearMonth;

-- Q5.7 : Time between a customer's first and last purchase (repeat customers only)
WITH span AS (
    SELECT CustomerID,
           julianday(MAX(InvoiceDay)) - julianday(MIN(InvoiceDay)) AS days_active,
           COUNT(DISTINCT InvoiceNo) AS orders
    FROM online_retail GROUP BY CustomerID HAVING COUNT(DISTINCT InvoiceNo) > 1
)
SELECT COUNT(*)                                    AS repeat_customers,
       ROUND(AVG(days_active), 1)                  AS avg_days_between_first_last,
       ROUND(AVG(days_active / (orders - 1)), 1)   AS avg_days_between_orders,
       MAX(days_active)                            AS max_days_active
FROM span;

-- Q5.8 : RFM scoring (snapshot = last transaction date + 1 day)
DROP VIEW IF EXISTS vw_rfm;
CREATE VIEW vw_rfm AS
WITH base AS (
    SELECT CustomerID,
           CAST(julianday((SELECT MAX(InvoiceDay) FROM online_retail)) - julianday(MAX(InvoiceDay)) AS INTEGER) + 1 AS recency_days,
           COUNT(DISTINCT InvoiceNo) AS frequency,
           ROUND(SUM(Revenue), 2)    AS monetary
    FROM online_retail GROUP BY CustomerID
), scored AS (
    SELECT *,
           6 - NTILE(5) OVER (ORDER BY recency_days)   AS r_score,
           NTILE(5) OVER (ORDER BY frequency, monetary) AS f_score,
           NTILE(5) OVER (ORDER BY monetary)            AS m_score
    FROM base
)
SELECT *,
       CASE
         WHEN r_score >= 4 AND f_score >= 4 THEN 'Champions'
         WHEN r_score >= 3 AND f_score >= 3 THEN 'Loyal Customers'
         WHEN r_score >= 4 AND f_score <= 2 THEN 'New / Promising'
         WHEN r_score = 3  AND f_score <= 2 THEN 'Need Attention'
         WHEN r_score <= 2 AND f_score >= 4 THEN 'Cannot Lose Them'
         WHEN r_score <= 2 AND f_score >= 2 THEN 'At Risk'
         ELSE 'Lost / Hibernating'
       END AS segment
FROM scored;

-- Q5.9 : RFM segment summary
SELECT segment,
       COUNT(*)                          AS customers,
       ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM vw_rfm), 2) AS customer_share_pct,
       ROUND(AVG(recency_days), 1)       AS avg_recency_days,
       ROUND(AVG(frequency), 2)          AS avg_orders,
       ROUND(AVG(monetary), 2)           AS avg_revenue,
       ROUND(SUM(monetary), 2)           AS revenue,
       ROUND(100.0 * SUM(monetary) / (SELECT SUM(monetary) FROM vw_rfm), 2) AS revenue_share_pct
FROM vw_rfm
GROUP BY segment
ORDER BY revenue DESC;

-- Q5.10 : Monthly cohort retention (% of a cohort that is active N months later)
WITH first_order AS (
    SELECT CustomerID, MIN(YearMonth) AS cohort FROM online_retail GROUP BY CustomerID
), activity AS (
    SELECT DISTINCT o.CustomerID, f.cohort, o.YearMonth,
           (CAST(substr(o.YearMonth,1,4) AS INTEGER) - CAST(substr(f.cohort,1,4) AS INTEGER)) * 12
         + (CAST(substr(o.YearMonth,6,2) AS INTEGER) - CAST(substr(f.cohort,6,2) AS INTEGER)) AS month_index
    FROM online_retail o JOIN first_order f USING (CustomerID)
), cohort_size AS (
    SELECT cohort, COUNT(*) AS size FROM first_order GROUP BY cohort
)
SELECT a.cohort, s.size AS cohort_size,
       ROUND(100.0 * SUM(a.month_index = 1)  / s.size, 1) AS m1_pct,
       ROUND(100.0 * SUM(a.month_index = 2)  / s.size, 1) AS m2_pct,
       ROUND(100.0 * SUM(a.month_index = 3)  / s.size, 1) AS m3_pct,
       ROUND(100.0 * SUM(a.month_index = 6)  / s.size, 1) AS m6_pct,
       ROUND(100.0 * SUM(a.month_index = 12) / s.size, 1) AS m12_pct
FROM activity a JOIN cohort_size s USING (cohort)
GROUP BY a.cohort, s.size
ORDER BY a.cohort;
