"""
run_eda.py - Loads the CSV into SQLite, runs every SQL file in /sql in order
and saves each query result as a CSV in /results.

Usage:  python python/run_eda.py
"""

import csv, re, sqlite3, sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = next(
    (
        p
        for p in (HERE.parent, HERE, Path.cwd())
        if (p / "sql").is_dir() and (p / "Dataset").is_dir()
    ),
    None,
)
if ROOT is None:
    sys.exit(
        "Keep the project structure: Dataset/, sql/ and python/ folders must sit together."
    )
CSV = ROOT / "Dataset" / "Cleaned_Online_Retail_Dataset.csv"
SQLD = ROOT / "sql"
OUT = ROOT / "results"
DB = ROOT / "ecommerce_eda.db"

TAG = re.compile(r"^--\s*(Q\d+\.\d+)\s*:\s*(.+)$", re.M)


def load_csv(con):
    con.executescript(
        (SQLD / "01_database_setup.sql").read_text().split("-- STEP 3")[0]
    )
    with open(CSV, newline="", encoding="utf-8") as f:
        rdr = csv.reader(f)
        next(rdr)
        con.executemany(
            "INSERT INTO online_retail_raw VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)", rdr
        )
    con.commit()
    # STEP 3 + 4 of the setup file (analysis table + indexes)
    con.executescript(
        "-- STEP 3" + (SQLD / "01_database_setup.sql").read_text().split("-- STEP 3")[1]
    )


def run_queries(con, path):
    text = path.read_text()
    # strip block comments, split at the Qx.y tags
    text = re.sub(r"/\*.*?\*/", "", text, flags=re.S)
    parts = TAG.split(text)  # [pre, id, title, body, id, title, body ...]
    for i in range(1, len(parts), 3):
        qid, title, body = (
            parts[i],
            parts[i + 1].strip(),
            parts[i + 2].strip().rstrip(";"),
        )
        body = "\n".join(l for l in body.splitlines() if not l.strip().startswith("--"))
        if body.upper().startswith(
            ("DROP", "CREATE")
        ):  # DDL, may hold several statements
            con.executescript(body + ";")
            print(f"  {qid:7} {title}  [DDL]")
            continue
        cur = con.execute(body)
        if cur.description is None:  # DDL (views etc.)
            print(f"  {qid:7} {title}  [DDL]")
            continue
        cols = [d[0] for d in cur.description]
        rows = cur.fetchall()
        fn = (
            OUT
            / f"{qid.replace('.', '_')}_{re.sub(r'[^a-z0-9]+', '_', title.lower()).strip('_')[:50]}.csv"
        )
        with open(fn, "w", newline="", encoding="utf-8") as f:
            w = csv.writer(f)
            w.writerow(cols)
            w.writerows(rows)
        print(f"  {qid:7} {title}  -> {len(rows)} rows")


def main():
    OUT.mkdir(exist_ok=True)
    for old in OUT.glob("*.csv"):
        old.unlink()
    if DB.exists():
        DB.unlink()
    con = sqlite3.connect(DB)
    print("Loading CSV ...")
    load_csv(con)
    for f in sorted(SQLD.glob("*.sql")):
        if f.name.startswith("01_"):
            continue
        print(f.name)
        run_queries(con, f)
    con.close()
    print("Done ->", OUT)


if __name__ == "__main__":
    sys.exit(main())
