/* =====================================================================
   01_database_setup.sql
   Project : E-Commerce Sales SQL EDA
   Purpose : Create the tables, load the CSV and build the analysis
             table with parsed date/time helper columns.
   Dialect : SQLite 3.25+ (window functions required).
             Porting notes for MySQL / PostgreSQL are at the bottom.
   ===================================================================== */

-- ---------------------------------------------------------------------
-- STEP 1 : Raw landing table (exact copy of the CSV, nothing changed)
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS online_retail_raw;

CREATE TABLE online_retail_raw (
    InvoiceNo    INTEGER,
    StockCode    TEXT,
    Description  TEXT,
    Quantity     INTEGER,
    InvoiceDate  TEXT,      -- stored as 'DD-MM-YYYY HH:MM' in the CSV
    UnitPrice    REAL,
    CustomerID   INTEGER,
    Country      TEXT,
    Revenue      REAL,
    Year         INTEGER,
    Quarter      INTEGER,
    Month        TEXT,
    Day          TEXT       -- weekday name (Monday ... Sunday)
);

-- ---------------------------------------------------------------------
-- STEP 2 : Load the CSV
--   sqlite3 CLI :  .mode csv
--                  .import --skip 1 Dataset/Cleaned_Online_Retail_Dataset.csv online_retail_raw
--   Python      :  python/run_eda.py does this automatically.
-- ---------------------------------------------------------------------

-- ---------------------------------------------------------------------
-- STEP 3 : Analysis table with proper date columns
--   InvoiceDate 'DD-MM-YYYY HH:MM'  ->  ISO 'YYYY-MM-DD HH:MM:SS'
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS online_retail;

CREATE TABLE online_retail AS
SELECT
    InvoiceNo,
    StockCode,
    TRIM(Description)                                            AS Description,
    Quantity,
    UnitPrice,
    CustomerID,
    Country,
    Revenue,
    Year,
    Quarter,
    Month                                                        AS MonthName,
    Day                                                          AS WeekdayName,
    /* parsed timestamp */
    substr(InvoiceDate, 7, 4) || '-' || substr(InvoiceDate, 4, 2) || '-' ||
    substr(InvoiceDate, 1, 2) || ' ' || substr(InvoiceDate, 12, 5) || ':00'
                                                                 AS InvoiceDateTime,
    substr(InvoiceDate, 7, 4) || '-' || substr(InvoiceDate, 4, 2) || '-' ||
    substr(InvoiceDate, 1, 2)                                    AS InvoiceDay,
    substr(InvoiceDate, 7, 4) || '-' || substr(InvoiceDate, 4, 2) AS YearMonth,
    CAST(substr(InvoiceDate, 4, 2) AS INTEGER)                   AS MonthNum,
    CAST(substr(InvoiceDate, 12, 2) AS INTEGER)                  AS HourOfDay
FROM online_retail_raw;

-- ---------------------------------------------------------------------
-- STEP 4 : Indexes to keep the EDA queries fast
-- ---------------------------------------------------------------------
CREATE INDEX idx_or_invoice  ON online_retail (InvoiceNo);
CREATE INDEX idx_or_customer ON online_retail (CustomerID);
CREATE INDEX idx_or_stock    ON online_retail (StockCode);
CREATE INDEX idx_or_country  ON online_retail (Country);
CREATE INDEX idx_or_ym       ON online_retail (YearMonth);

/* ---------------------------------------------------------------------
   PORTING NOTES
   MySQL      : LOAD DATA LOCAL INFILE '...csv' INTO TABLE online_retail_raw
                FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
                LINES TERMINATED BY '\r\n' IGNORE 1 LINES;
                Date  -> STR_TO_DATE(InvoiceDate, '%d-%m-%Y %H:%i')
                Month -> DATE_FORMAT(dt, '%Y-%m'),  Hour -> HOUR(dt)
   PostgreSQL : \copy online_retail_raw FROM 'file.csv' CSV HEADER;
                Date  -> TO_TIMESTAMP(InvoiceDate, 'DD-MM-YYYY HH24:MI')
                Month -> TO_CHAR(dt, 'YYYY-MM'),  Hour -> EXTRACT(HOUR FROM dt)
   Date diff  : SQLite julianday(a)-julianday(b) | MySQL DATEDIFF(a,b)
                PostgreSQL (a::date - b::date)
   --------------------------------------------------------------------- */
