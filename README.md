<h1 align="center">🛒 E-Commerce Sales SQL EDA</h1>

<h3 align="center">
Exploratory Data Analysis in SQL on Online Retail Transactions: Data Quality, Sales, Customers, Products and Countries
</h3>

<p align="center">
  <img src="https://img.shields.io/badge/SQL-EDA-blue?style=for-the-badge" />
  <img src="https://img.shields.io/badge/SQLite-Window%20Functions-003B57?style=for-the-badge&logo=sqlite&logoColor=white" />
  <img src="https://img.shields.io/badge/Python-Runner%20%26%20Charts-3776AB?style=for-the-badge&logo=python&logoColor=white" />
  <img src="https://img.shields.io/badge/Project-Completed-brightgreen?style=for-the-badge" />
</p>

---

## 📖 Project Overview

This project performs a complete **Exploratory Data Analysis (EDA) in SQL** on the cleaned **Online Retail (E-Commerce) dataset** that powers the [E-Commerce Sales Analytics Power BI dashboard](https://github.com/ImTaRunGupTa/E-Commerce_Sales_DashBoard).

It validates the quality of the cleaned data, recomputes every dashboard KPI in SQL, and goes further with **RFM segmentation, cohort retention, Pareto concentration, market-basket pairs, outlier detection and sensitivity analysis**, all using plain SQL (CTEs and window functions).

The full written findings are in **[`docs/EDA_Report.md`](docs/EDA_Report.md)**.

---

# 📑 Table of Contents

- [Project Highlights](#-project-highlights)
- [Tech Stack](#-tech-stack)
- [Project Structure](#-project-structure)
- [SQL Files & Query Catalog](#-sql-files--query-catalog)
- [Data Quality Findings](#-data-quality-findings)
- [KPIs Used](#-kpis-used)
- [Key Insights](#-key-insights)
- [Charts](#-charts)
- [How to Use](#-how-to-use)
- [Dataset](#-dataset)
- [Connect With Me](#-connect-with-me)

---

# ✨ Project Highlights

✔ 9 well-documented SQL files, 62 result queries

✔ Data quality audit (nulls, duplicates, business rules, date coverage, outliers)

✔ Dashboard KPIs rebuilt in SQL (Revenue, Orders, AOV, ASP, Repeat Rate ...)

✔ Time-series analysis with `LAG`, running totals and moving averages

✔ Customer value segments, **RFM scoring** and **cohort retention**

✔ Product Pareto, price bands and **market-basket analysis**

✔ Outlier and sensitivity analysis (with / without the largest order, with / without duplicates)

✔ Reusable reporting views for Power BI / Tableau

✔ One-command Python runner that exports every result to CSV

✔ Professional EDA report with business recommendations

---

# 🛠 Tech Stack

| Technology | Purpose |
|------------|---------|
| SQL (SQLite 3.25+) | Data profiling, EDA, segmentation |
| CTEs & Window Functions | `LAG`, `NTILE`, `ROW_NUMBER`, running totals |
| Python 3 (sqlite3) | Load CSV, execute SQL files, export results |
| Pandas & Matplotlib | Chart generation from SQL results |
| Git & GitHub | Version Control |

> The SQL is standard ANSI apart from a few date functions. Porting notes for **MySQL** and **PostgreSQL** are at the bottom of `01_database_setup.sql`.

---

# 📁 Project Structure

```text
E-Commerce-SQL-EDA
│
├── Dataset
│   └── Cleaned_Online_Retail_Dataset.csv
│
├── sql
│   ├── 01_database_setup.sql        # tables, CSV load, date parsing, indexes
│   ├── 02_data_quality_checks.sql   # nulls, duplicates, rules, coverage, outliers
│   ├── 03_overview_kpis.sql         # headline KPIs, descriptive statistics
│   ├── 04_sales_analysis.sql        # monthly / quarterly / weekday / hourly trends
│   ├── 05_customer_analysis.sql     # segments, repeat, RFM, cohorts
│   ├── 06_product_analysis.sql      # top products, price bands, Pareto
│   ├── 07_country_analysis.sql      # country league table, UK vs international
│   ├── 08_advanced_analysis.sql     # concentration, baskets, outliers, sensitivity
│   └── 09_reporting_views.sql       # views for BI tools
│
├── python
│   ├── run_eda.py                   # loads data and runs all SQL files
│   └── make_charts.py               # builds charts from /results
│
├── results                          # one CSV per query (Qx_y_*.csv)
├── images                           # charts used in the report
├── docs
│   └── EDA_Report.md                # full EDA report
│
├── requirements.txt
└── README.md
```

---

# 🧾 SQL Files & Query Catalog

Every query starts with a tag such as `-- Q5.9 : RFM segment summary`, and its output is saved as `results/Q5_9_*.csv`.

| File | Queries | What it answers |
|------|---------|-----------------|
| `01_database_setup.sql` | - | Creates `online_retail_raw`, parses `DD-MM-YYYY HH:MM` into `InvoiceDateTime`, `YearMonth`, `HourOfDay`, adds indexes |
| `02_data_quality_checks.sql` | Q2.1 - Q2.13 | Row counts, NULLs, duplicates, rule violations, derived-column consistency, non-product codes, multi-description codes, extreme values, **days-of-month coverage** |
| `03_overview_kpis.sql` | Q3.1 - Q3.5 | Revenue, orders, customers, AOV, ASP, repeat rate, mean / median / max per line and per order |
| `04_sales_analysis.sql` | Q4.1 - Q4.10 | MoM growth, running total, 3-month moving average, quarters, weekday, hour, day-part, best days, revenue per active day, outlier-adjusted trend |
| `05_customer_analysis.sql` | Q5.1 - Q5.10 | Top customers, order-frequency bands, value quartiles, repeat vs one-time, new vs returning, RFM, cohort retention |
| `06_product_analysis.sql` | Q6.1 - Q6.9 | Top products by revenue / quantity / popularity, price bands, non-product codes, Pareto, premium items |
| `07_country_analysis.sql` | Q7.1 - Q7.5 | Country league table, UK vs international, repeat rate by country, top products per market |
| `08_advanced_analysis.sql` | Q8.1 - Q8.10 | Customer Pareto, order-value bands, basket size, product pairs, IQR outliers, sensitivity tests, correlation |
| `09_reporting_views.sql` | Q9.1 - Q9.5 | `vw_monthly_sales`, `vw_customer_summary`, `vw_product_summary`, `vw_country_summary` (+ `vw_rfm`) |

### Sample query: RFM scoring with window functions

```sql
WITH base AS (
    SELECT CustomerID,
           CAST(julianday((SELECT MAX(InvoiceDay) FROM online_retail)) - julianday(MAX(InvoiceDay)) AS INTEGER) + 1 AS recency_days,
           COUNT(DISTINCT InvoiceNo) AS frequency,
           ROUND(SUM(Revenue), 2)    AS monetary
    FROM online_retail GROUP BY CustomerID
)
SELECT *,
       6 - NTILE(5) OVER (ORDER BY recency_days)    AS r_score,
       NTILE(5) OVER (ORDER BY frequency, monetary) AS f_score,
       NTILE(5) OVER (ORDER BY monetary)            AS m_score
FROM base;
```

---

# 🔎 Data Quality Findings

| Check | Result |
|-------|--------|
| NULL / blank values | ✅ 0 |
| Zero / negative quantity, price or revenue | ✅ 0 |
| Cancelled invoices ("C") | ✅ 0 |
| Revenue = Quantity × UnitPrice | ✅ 0 mismatches |
| Year / Quarter / Month / Weekday vs date | ✅ 0 mismatches |
| Exact duplicate rows | ⚠️ 2,268 surplus rows (1.34% of rows, 0.26% of revenue) |
| Non-product codes (POST, M, DOT, C2, BANK CHARGES) | ⚠️ 636 lines, 1.73% of revenue |
| **Date coverage** | 🚩 **Only days 1-12 of every month are present** |
| Extreme order | 🚩 Invoice 581483: 80,995 units, 168,469.60 (4.35% of revenue) |

> ⚠️ **Important:** because only days 1-12 of each month exist, the file is a partial sample of the year. Totals describe the sample; ratios, mixes and rankings are much more reliable. Re-check the date parsing in Power Query (DD/MM vs MM/DD).

---

# 📈 KPIs Used

- Total Revenue
- Total Orders
- Total Customers
- Total Products
- Quantity Sold
- Average Order Value (AOV)
- Average Selling Price (ASP)
- Repeat Customers
- Repeat Customer Rate
- Revenue per Customer
- Orders per Customer
- Revenue per Active Day *(added in SQL)*
- Recency / Frequency / Monetary scores *(added in SQL)*

| KPI | Value |
|-----|-------|
| Total Revenue | **3,875,487.99** |
| Total Orders | **7,961** |
| Total Customers | **2,997** |
| Total Products | **3,507** |
| Quantity Sold | **2,205,617** |
| AOV (mean / median) | **486.81 / 302.64** |
| ASP | **1.76** |
| Repeat Customer Rate | **51.18%** |
| Revenue per Customer | **1,293.12** |
| Orders per Customer | **2.66** |

---

# 🎯 Key Insights

- 💰 Total revenue in the file is **3.88M**, matching the Power BI dashboard.
- 👥 **51.2%** of customers are repeat buyers and they produce **82.1%** of revenue; the top 25% of customers produce **76.6%**.
- 🏆 RFM **Champions** are 23% of customers but **59.5%** of revenue; **232 "Cannot Lose Them"** customers (8.7% of revenue) have been quiet for about 217 days.
- 📉 New customers per month dropped from **331 (Jan)** to **88 (Dec)**; growth relies on the existing base.
- 🌍 The **United Kingdom** is **84.5%** of revenue, but international orders are larger (AOV **779** vs **455**); EIRE, the Netherlands and Australia are driven by 3-8 wholesale accounts.
- 🛒 The typical order has 15 lines and 151 units; **62%** of orders contain 11+ distinct products: a trade / wholesale pattern.
- 💎 Items priced **2-4.99** produce **41%** of revenue; 729 products (about 21%) make 80% of revenue (Pareto).
- 🕛 **85%** of revenue is booked between 09:00 and 16:00, with a peak at noon.
- 📆 The September "peak" (+63.9% MoM) comes from **one order**; without it September is 253.5k.
- 🔗 Products are bought together in **families** (Alarm Clock Green + Red, Jumbo Bag Pink Polkadot + Red Retrospot, the Lunch Bag range).

The complete analysis, tables and recommendations: **[docs/EDA_Report.md](docs/EDA_Report.md)**.

---

# 📸 Charts

<p align="center">
<img src="images/01_monthly_revenue.png" width="48%"> <img src="images/06_rfm_segments.png" width="48%">
</p>
<p align="center">
<img src="images/04_top_countries.png" width="48%"> <img src="images/05_top_products.png" width="48%">
</p>
<p align="center">
<img src="images/07_new_vs_returning.png" width="48%"> <img src="images/03_hourly_revenue.png" width="48%">
</p>

---

# 🚀 How to Use

### Clone the Repository

```bash
git clone https://github.com/ImTaRunGupTa/E-Commerce-SQL-EDA.git
cd E-Commerce-SQL-EDA
```

### Option A - One command (Python)

```bash
pip install -r requirements.txt
python python/run_eda.py        # builds ecommerce_eda.db, runs 01-09, writes /results
python python/make_charts.py    # regenerates /images
```

### Option B - Run the SQL by hand

```bash
sqlite3 ecommerce_eda.db
sqlite> .read sql/01_database_setup.sql
sqlite> .mode csv
sqlite> .import --skip 1 Dataset/Cleaned_Online_Retail_Dataset.csv online_retail_raw
sqlite> -- re-run STEP 3 and STEP 4 of 01_database_setup.sql, then:
sqlite> .read sql/02_data_quality_checks.sql
```

### Option C - MySQL / PostgreSQL

Load the CSV into `online_retail_raw`, convert the date as described in the porting notes at the end of `sql/01_database_setup.sql`, then run files 02-09 (replace `julianday()` and `strftime()` with the native date functions listed there).

---

# 📚 Dataset

**Dataset:** Online Retail (E-Commerce) Dataset, cleaned version

| Column | Description |
|--------|-------------|
| InvoiceNo | Invoice / order number |
| StockCode | Product code |
| Description | Product name |
| Quantity | Units sold |
| InvoiceDate | Date and time (`DD-MM-YYYY HH:MM`) |
| UnitPrice | Price per unit |
| CustomerID | Customer identifier |
| Country | Customer country |
| Revenue | Quantity × UnitPrice |
| Year, Quarter, Month, Day | Derived calendar fields (`Day` = weekday) |

168,631 rows · 2,997 customers · 33 countries · 1 Dec 2010 - 10 Dec 2011

---

# 🌐 Connect With Me

<p align="center">

<a href="https://github.com/ImTaRunGupTa">
<img src="https://img.shields.io/badge/GitHub-ImTaRunGupTa-181717?style=for-the-badge&logo=github">
</a>

<a href="https://www.linkedin.com/in/tarungupta190504/">
<img src="https://img.shields.io/badge/LinkedIn-Tarun%20Gupta-0077B5?style=for-the-badge&logo=linkedin">
</a>

</p>
