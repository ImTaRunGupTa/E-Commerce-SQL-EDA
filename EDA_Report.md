# 📊 SQL Exploratory Data Analysis Report
**Project:** E-Commerce Sales Analytics - SQL EDA
**Dataset:** `Cleaned_Online_Retail_Dataset.csv` (UK online gift-ware retailer, Dec 2010 - Dec 2011)
**Engine:** SQLite 3.45 (window functions) - SQL files in `/sql`, result sets in `/results`
**Query references:** `Qx.y` tags map to the query ids inside the `.sql` files and to the CSV file names in `/results`.

---

## 1. Executive Summary

| Metric | Value |
|---|---|
| Total revenue | **3,875,487.99** |
| Orders (distinct invoices) | **7,961** |
| Customers | **2,997** |
| Products (stock codes) | **3,507** |
| Countries | **33** |
| Units sold | **2,205,617** |
| Average order value (AOV) | **486.81** (median 302.64) |
| Average selling price (ASP) | **1.76** per unit |
| Revenue per customer | **1,293.12** |
| Orders per customer | **2.66** |
| Repeat-customer rate | **51.18%** (1,534 customers) |

**Five things the data says**

1. **The business is wholesale-like and heavy-tailed.** A typical order has 15 lines and 151 units; 8,802 "extreme" line items (5.2% of lines) generate **46.1%** of revenue (Q8.5).
2. **Repeat customers are the engine.** 51% of customers buy more than once and produce **82%** of revenue; the top 25% of customers produce **76.6%** (Q3.2, Q5.4).
3. **One order distorts the headline numbers.** Invoice `581483` (customer 16446, 80,995 units of "Paper Craft, Little Birdie" at 2.08) is worth **168,469.60 = 4.35%** of revenue. It makes September look like the best month (+63.9% MoM) - without it September is **253,514.58**, slightly below August's 257,499 (Q4.10, Q8.7).
4. **The UK is 84.5% of revenue, but international customers are worth more per order** (AOV 778.65 vs 455.38) and a handful of wholesale accounts (EIRE, Netherlands, Australia) drive that (Q7.1, Q7.2).
5. **The file is not the full year.** Only **days 1-12 of every month** are present (Q2.13), so absolute totals are about a partial sample and month/weekday comparisons need care (see Section 3).

---

## 2. Dataset and Data Dictionary

168,631 rows x 13 columns, one row per invoice line.

| Column | Type | Description |
|---|---|---|
| InvoiceNo | int | Invoice (order) number, 6 digits, no cancellations left |
| StockCode | text | Product code (5 non-product codes exist, see 3.4) |
| Description | text | Product name |
| Quantity | int | Units on the line (1 - 80,995) |
| InvoiceDate | text | `DD-MM-YYYY HH:MM`. Parsed to `InvoiceDateTime` in SQL |
| UnitPrice | real | Price per unit (0.04 - 8,142.75) |
| CustomerID | int | Customer id (no missing values) |
| Country | text | Customer country (33 values) |
| Revenue | real | Quantity x UnitPrice |
| Year / Quarter / Month / Day | | Derived calendar fields (`Day` = weekday name) |

Helper columns created in `01_database_setup.sql`: `InvoiceDateTime`, `InvoiceDay`, `YearMonth`, `MonthNum`, `HourOfDay`.

---

## 3. Data Quality Assessment (`02_data_quality_checks.sql`)

| Check | Result | Verdict |
|---|---|---|
| NULL / blank values in any column (Q2.2) | 0 | ✅ |
| Zero or negative quantity, price or revenue (Q2.4) | 0 | ✅ |
| Cancelled invoices ("C" prefix) (Q2.4) | 0 | ✅ |
| Revenue = Quantity x UnitPrice (Q2.4) | 0 mismatches | ✅ |
| Year / Quarter / Month / Weekday consistent with the date (Q2.5) | 0 mismatches (weekday matches the DD-MM reading on 100% of rows) | ✅ |
| Exact duplicate rows (Q2.3) | **2,268 surplus rows (1.34%)**, revenue 10,024.91 (0.26%) | ⚠️ |
| Days of month present (Q2.13) | **Only days 1-12** | 🚩 |
| Non-product stock codes (Q2.7) | 636 lines, 67,216.24 (1.73%) | ⚠️ |
| Stock codes with several descriptions (Q2.8) | e.g. `23236` has 4 variants | ⚠️ minor |
| Customers in 2 countries (Q2.9) | 2 (`12394`, `12431`) | ⚠️ minor |
| Invoices with 2 timestamps (Q2.10, Q8.10) | 8 (one minute apart) | ⚠️ minor |

### 3.1 Partial date coverage 🚩
`Q2.13` shows rows exist **only for day-of-month 1 to 12**, in all 13 months (Dec-2010 to Dec-2011). The file therefore covers roughly 12/30 of each month. The last transaction is `2011-12-10`; to my knowledge the public UCI Online Retail data ends on 9 Dec 2011, which suggests a date-format (DD/MM vs MM/DD) issue upstream. **Recommendation:** re-check the date parsing step in Power Query against the raw file before publishing absolute figures.
Consequences for this report:
- Absolute totals (3.88M revenue, 7,961 orders) describe the sample, not the full year.
- Ratios and mixes (repeat rate, AOV, country share, product ranking) are far less affected.
- Month, weekday and retention comparisons use unequal numbers of active days (8-11), so `Q4.9` (revenue per active day) is provided.

### 3.2 Duplicates
2,092 duplicate groups hold 2,268 surplus rows. The README of the dashboard says duplicates were removed, so this step did not fully work - or these are legitimate repeated scans on the same invoice. Removing them lowers revenue only from 3,875,487.99 to 3,865,463.08 (**-0.26%**, Q8.8), so conclusions do not change. The analysis keeps the data as provided.

### 3.3 Outliers (not errors, but influential)
| Item | Evidence |
|---|---|
| 80,995 units in one line | Invoice 581483, 168,469.60 (Q8.6) |
| 60 "Picnic Basket Wicker 60 Pieces" at 649.50 | Invoice 556444, 38,970.00. Stock code `22502` is shared with the small basket that sells for 4.95-5.95, so check whether the code is mapped correctly |
| POSTAGE line of 8,142.75 | Invoice 551697 |
| Quantity > 1,000: 59 lines, 254,176.83 | Q2.11 |
In the public UCI data, invoice 581483 is reversed by cancellation invoice `C581484`; because cancellations were removed in cleaning, the reversal is no longer in this file. Worth confirming against the source.

### 3.4 Non-product codes
`POST` 35,247.15 - `M` (manual) 26,016.79 - `DOT` 3,662.30 - `C2` 2,200.00 - `BANK CHARGES` 90.00. Total 1.73% of revenue; they are excluded from product rankings (Q6.1-Q6.4, Q6.7, Q6.9).

---

## 4. Overall Distributions (`03_overview_kpis.sql`)

| Metric | Min | Mean | Median | Max |
|---|---|---|---|---|
| Quantity per line | 1 | 13.08 | 6 | 80,995 |
| Unit price | 0.04 | 3.15 | 1.95 | 8,142.75 |
| Revenue per line | 0.10 | 22.98 | 11.70 | 168,469.60 |
| Order value | 0.38 | 486.81 | 302.64 | 168,469.60 |
| Units per order | 1 | 277.05 | 151 | 80,995 |
| Lines per order | 1 | 21.18 | 15 | 529 |

All distributions are strongly right-skewed (mean >> median), which is why medians and shares are used next to averages. The linear correlation between price and quantity is **-0.003** (Q8.9): quantity is not driven by price at line level.

---

## 5. Sales Trends (`04_sales_analysis.sql`)

![Monthly revenue](https://github.com/ImTaRunGupTa/E-Commerce-SQL-EDA/blob/main/graphs/01_monthly_revenue.png)

| Month | Orders | Revenue | MoM | Revenue / active day |
|---|---|---|---|---|
| 2010-12 | 891 | 362,834 | - | 36,283 |
| 2011-01 | 588 | 239,994 | -33.9% | 23,999 |
| 2011-02 | 476 | 209,542 | -12.7% | 26,193 |
| 2011-03 | 463 | 261,508 | +24.8% | 29,056 |
| 2011-04 | 629 | 329,347 | +25.9% | 29,941 |
| 2011-05 | 636 | 322,262 | -2.2% | 35,807 |
| 2011-06 | 707 | 305,544 | -5.2% | 27,777 |
| 2011-07 | 702 | 322,994 | +5.7% | 29,363 |
| 2011-08 | 660 | 257,499 | -20.3% | 25,750 |
| 2011-09 | 562 | **421,984** | +63.9% | 42,198 |
| 2011-10 | 554 | 291,456 | -30.9% | 29,146 |
| 2011-11 | 629 | 345,332 | +18.5% | 34,533 |
| 2011-12 | 464 | 205,191 | -40.6% | 25,649 |

**Findings**
- **Seasonality:** revenue dips in Jan-Feb, recovers in spring, and builds again in Nov (+18.5%), the pre-Christmas season. After removing invoice 581483, September drops to 253,515 (about 25,351 per active day), so the apparent September peak is an outlier, not a season (Q4.10).
- **Strongest real periods:** Dec-2010 (36.3k per active day), May-2011 (35.8k) and Nov-2011 (34.5k).
- **Quarters (Q4.3):** Q2-2011 24.7%, Q3 25.9% (inflated by the outlier), Q4-2011 21.7%, Q1-2011 18.4%.
- **Weekday (Q4.5):** Thursday 17.1%, Tuesday 16.9%, Monday 15.9% lead; Saturday (10.7%) and Wednesday (11.0%) trail. Monday's AOV of 613 is inflated by the 12-Sep order. Treat weekday differences as indicative, because only 12 days per month are present.
- **Hours (Q4.6, Q4.7):** noon is the peak hour (1,411 orders, 15.9% of revenue); 09:00-15:59 accounts for **85.3%** of revenue and after 18:00 only 2.1%. This is a B2B-style office-hours pattern.

![Weekday revenue](https://github.com/ImTaRunGupTa/E-Commerce-SQL-EDA/blob/main/graphs/02_weekday_revenue.png)
![Hourly revenue](https://github.com/ImTaRunGupTa/E-Commerce-SQL-EDA/blob/main/graphs/03_hourly_revenue.png)

---

## 6. Customer Analysis (`05_customer_analysis.sql`)

### 6.1 Repeat behaviour
| Type | Customers | Revenue | Avg revenue / customer | Avg orders |
|---|---|---|---|---|
| Repeat | 1,534 (51.2%) | 3,182,218 (82.1%) | 2,074 | 4.24 |
| One-time | 1,463 (48.8%) | 693,270 (17.9%) | 474 | 1.00 |

AOV is almost identical (489.72 vs 473.87): repeat customers are worth more because they **come back**, not because they spend more per order. The 78 customers with 11+ orders (2.6%) generate **27.1%** of revenue (Q5.3).

### 6.2 Concentration
| Group | Share of revenue |
|---|---|
| Top 1% (29 customers) | 29.6% (includes the 168k single order) |
| Top 5% | 48.7% |
| Top 10% | 59.1% |
| Top 20% | 72.0% |
| 883 customers (29.5%) needed for 80% | 80.0% |

Value quartiles (Q5.4): Top 25% 76.6% of revenue, next 25% 13.9%, next 6.7%, bottom 2.8%.
Top accounts (Q5.1): `16446` (168,470 - one order only), `18102` (UK, 29 orders, 135,953), `14646` (Netherlands, 28 orders, 87,617), `14911` (EIRE, **75 orders**, 59,176).

### 6.3 RFM segmentation (Q5.8 - Q5.9)
![RFM](https://github.com/ImTaRunGupTa/E-Commerce-SQL-EDA/blob/main/graphs/06_rfm_segments.png)

| Segment | Customers | Customer share | Revenue share | Avg recency (days) |
|---|---|---|---|---|
| Champions | 698 | 23.3% | **59.5%** | 34 |
| Loyal Customers | 615 | 20.5% | 20.6% | 97 |
| Cannot Lose Them | 232 | 7.7% | 8.7% | 217 |
| At Risk | 586 | 19.6% | 6.9% | 269 |
| New / Promising | 290 | 9.7% | 1.8% | 46 |
| Lost / Hibernating | 380 | 12.7% | 1.3% | 276 |
| Need Attention | 196 | 6.5% | 1.2% | 128 |

**"Cannot Lose Them"** (232 customers, 3 orders each on average, 217 days quiet) hold 8.7% of revenue and are the highest-value win-back target.

### 6.4 Acquisition vs retention (Q5.6, Q5.10)
![New vs returning](https://github.com/ImTaRunGupTa/E-Commerce-SQL-EDA/blob/main/graphs/07_new_vs_returning.png)

- New customers per month fall from **331 (Jan)** to **88 (Dec)**; the returning share climbs from 29.7% to 76.5%. Growth is coming from the existing base, not from acquisition.
- The Dec-2010 cohort (644 customers) was active again at 21.7% in month 1 and 15.8% in month 12. Later cohorts return less (month-1 retention 5-15%). Because only 12 days per month are observed, absolute retention is understated; compare cohorts to each other, not to external benchmarks.
- Repeat customers' average gap between orders is about 86 days (Q5.7).

---

## 7. Product Analysis (`06_product_analysis.sql`)

![Top products](https://github.com/ImTaRunGupTa/E-Commerce-SQL-EDA/blob/main/graphs/05_top_products.png)

| Rank by revenue | Product | Revenue | Orders | ASP |
|---|---|---|---|---|
| 1 | Paper Craft, Little Birdie (one order) | 168,470 | 1 | 2.08 |
| 2 | Regency Cakestand 3 Tier | 62,422 | 736 | 11.53 |
| 3 | Cream Hanging Heart T-Light Holder | 48,067 | 888 | 2.75 |
| 4 | Picnic Basket Wicker (code 22502, two items, see 3.3) | 43,858 | 119 | 51.24 (blend of ~5 and 649.50) |
| 5 | Jumbo Bag Red Retrospot | 37,977 | 680 | 1.84 |

- **Most popular:** Cream Hanging Heart T-Light Holder is in 11.2% of all orders (Q6.3).
- **Volume vs value:** World War 2 Gliders sold 24,682 units at 0.25 and gave only 6,052; the Regency Cakestand sold 5,412 units for 62,422.
- **Price bands (Q6.5):** items under 1 are 38.8% of units but 11.3% of revenue; the **2-4.99 band delivers 41.1% of revenue**. 14 premium products over 50 give 2.4% of revenue from 246 units.

![Price bands](https://github.com/ImTaRunGupTa/E-Commerce-SQL-EDA/blob/main/graphs/08_price_bands.png)

- **Concentration (Q6.8):** top 10% of stock codes = 62.7% of revenue, top 20% = 79.1%; 729 codes (20.8%) reach 80%. A classic Pareto shape, with the 80,995-unit item inflating the top.
- **Cross-selling (Q8.4):** the strongest pairs are design variants of the same family: Alarm Clock Green + Red (240 orders), Jumbo Bag Pink Polkadot + Red Retrospot (233), and the Lunch Bag family around Red Retrospot (up to 225 orders). Bundle by collection.
- **Long tail (Q6.4, Q6.9):** many items earn under 5 in total; large furniture items (sideboard 159, kitchen cabinet 155) sell in very small volumes.

---

## 8. Geographic Analysis (`07_country_analysis.sql`)

![Countries](https://github.com/ImTaRunGupTa/E-Commerce-SQL-EDA/blob/main/graphs/04_top_countries.png)

| Market | Customers | Orders | Revenue | Share | AOV | Revenue / customer |
|---|---|---|---|---|---|---|
| United Kingdom | 2,713 | 7,187 | 3,272,810 | 84.5% | 455 | 1,206 |
| International (32 countries) | 284 | 774 | 602,678 | 15.5% | **779** | **2,122** |

Largest international markets: EIRE 97,500 (3 customers!), Germany 94,022 (71), Netherlands 89,851 (**8 customers**, AOV 2,428), France 85,120 (63), Australia 49,210 (7).
- EIRE, Netherlands and Australia are **account-driven**: a few wholesale buyers with very high orders. Germany and France are **broad-based** (60+ customers) and have repeat rates of 52.1% and **60.3%** (UK 51.4%) (Q7.3).
- Local tastes differ: Netherlands and Germany favour snack boxes and lunch boxes, France night lights, Australia pantry tins (Q7.4).
- Data labelled `Unspecified` and `European Community` contain 3 customers - minor, but should be cleaned.

---

## 9. Order and Basket Behaviour (`08_advanced_analysis.sql`)

- **Order value bands (Q8.2):** 41.7% of orders are under 250 but give only 11.4% of revenue; the 7.1% of orders above 1,000 give **41.3%**.
- **Basket size (Q8.3):** only 7.8% of orders are single-item; **62.2%** contain 11 or more distinct products, again typical of trade buyers.
- **Sensitivity (Q8.7, Q8.8):** removing the largest order lowers revenue 4.3% and AOV from 486.81 to 465.71; removing duplicates lowers revenue 0.26%.

---

## 10. Recommendations

1. **Fix the data before reporting absolute numbers** - verify the date parsing (days 1-12 only), remove or justify the 2,268 duplicate rows, and decide how to treat invoice 581483, the 649.50 picnic-basket price and non-product codes.
2. **Show medians and outlier-adjusted KPIs** next to averages on the Power BI dashboard (AOV 486.81 vs median 302.64).
3. **Protect and grow the Champions and Loyal groups** (44% of customers, 80% of revenue) with loyalty offers and early access.
4. **Run a win-back campaign** for "Cannot Lose Them" (232 customers) and "At Risk" (586).
5. **Restart acquisition** - new customers per month fell by about 73% between January and December 2011.
6. **Bundle by product family** (colour/design variants) and promote the 2-5 price band, where revenue concentrates.
7. **Treat large international accounts individually** (EIRE, Netherlands, Australia) and grow Germany/France, where the base is broader.
8. **Staff and message for office hours** - 85% of revenue lands between 09:00 and 16:00.

## 11. Limitations
- Partial month coverage (days 1-12) and a 13-month window: no year-over-year comparison is possible.
- Outliers and duplicates described above are left in the data; sensitivity queries show their effect.
- Revenue is the invoiced value; returns/cancellations are not available, so net revenue is unknown.
- Country is taken from the transaction, not a verified customer address.

## 12. Reproducibility
```bash
pip install -r requirements.txt
python python/run_eda.py        # loads the CSV, runs all SQL files, writes /results
python python/make_charts.py    # builds /images from /results
```
