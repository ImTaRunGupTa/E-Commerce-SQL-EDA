"""make_charts.py - builds the report charts from the CSV files in /results (run run_eda.py first)."""
import pandas as pd, matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from pathlib import Path

R = Path(__file__).resolve().parent.parent / "results"
I = Path(__file__).resolve().parent.parent / "images"; I.mkdir(exist_ok=True)
rd = lambda p: pd.read_csv(next(R.glob(p)))
plt.rcParams.update({"figure.figsize": (9, 4.5), "axes.spines.top": False, "axes.spines.right": False,
                     "axes.grid": True, "grid.alpha": .25, "font.size": 10})
C1, C2, C3 = "#2563eb", "#f59e0b", "#dc2626"

# 1 monthly revenue (as provided vs excluding the largest order)
m = rd("Q4_10_*"); fig, ax = plt.subplots()
ax.plot(m.YearMonth, m.revenue_as_provided/1e3, marker="o", color=C1, label="As provided")
ax.plot(m.YearMonth, m.revenue_excl_largest_order/1e3, marker="o", ls="--", color=C2, label="Excluding largest order")
ax.set_title("Monthly revenue (days 1-12 of each month only)"); ax.set_ylabel("Revenue (thousand)")
plt.xticks(rotation=45); ax.legend(); fig.tight_layout(); fig.savefig(I/"01_monthly_revenue.png", dpi=140); plt.close()

# 2 weekday
w = rd("Q4_5_*"); fig, ax = plt.subplots(); ax.bar(w.WeekdayName, w.revenue/1e3, color=C1)
ax.set_title("Revenue by weekday"); ax.set_ylabel("Revenue (thousand)"); fig.tight_layout(); fig.savefig(I/"02_weekday_revenue.png", dpi=140); plt.close()

# 3 hour
h = rd("Q4_6_*"); fig, ax = plt.subplots(); ax.bar(h.HourOfDay, h.revenue/1e3, color=C1)
ax.set_title("Revenue by hour of day"); ax.set_xlabel("Hour"); ax.set_ylabel("Revenue (thousand)"); ax.set_xticks(h.HourOfDay)
fig.tight_layout(); fig.savefig(I/"03_hourly_revenue.png", dpi=140); plt.close()

# 4 countries (top 10, excl UK shown separately in title)
c = rd("Q7_1_*"); t = c.iloc[1:11].iloc[::-1]; fig, ax = plt.subplots()
ax.barh(t.Country, t.revenue/1e3, color=C1); ax.set_title(f"Top 10 international markets (UK = {c.revenue_share_pct.iloc[0]:.1f}% of revenue)")
ax.set_xlabel("Revenue (thousand)"); fig.tight_layout(); fig.savefig(I/"04_top_countries.png", dpi=140); plt.close()

# 5 top products
p = rd("Q6_1_*").iloc[::-1]; fig, ax = plt.subplots(); ax.barh(p.description.str[:32], p.revenue/1e3, color=[C3 if s == "23843" or s == 23843 else C1 for s in p.StockCode])
ax.set_title("Top 10 products by revenue (red = single 80,995-unit order)"); ax.set_xlabel("Revenue (thousand)")
fig.tight_layout(); fig.savefig(I/"05_top_products.png", dpi=140); plt.close()

# 6 RFM
r = rd("Q5_9_*"); fig, ax = plt.subplots(1, 2, figsize=(11, 4.5))
ax[0].barh(r.segment[::-1], r.customer_share_pct[::-1], color=C2); ax[0].set_title("Share of customers (%)")
ax[1].barh(r.segment[::-1], r.revenue_share_pct[::-1], color=C1); ax[1].set_title("Share of revenue (%)")
fig.tight_layout(); fig.savefig(I/"06_rfm_segments.png", dpi=140); plt.close()

# 7 new vs returning
n = rd("Q5_6_*"); fig, ax = plt.subplots(); ax.bar(n.YearMonth, n.new_customers, color=C2, label="New")
ax.bar(n.YearMonth, n.returning_customers, bottom=n.new_customers, color=C1, label="Returning")
ax.set_title("Active customers per month: new vs returning"); plt.xticks(rotation=45); ax.legend(); fig.tight_layout()
fig.savefig(I/"07_new_vs_returning.png", dpi=140); plt.close()

# 8 price bands
b = rd("Q6_5_*"); x = range(len(b)); fig, ax = plt.subplots()
ax.bar([i-.2 for i in x], b.quantity_share_pct, .4, color=C2, label="% of units"); ax.bar([i+.2 for i in x], b.revenue_share_pct, .4, color=C1, label="% of revenue")
ax.set_xticks(list(x)); ax.set_xticklabels([s[2:] for s in b.price_band]); ax.set_title("Units vs revenue by unit-price band"); ax.legend()
fig.tight_layout(); fig.savefig(I/"08_price_bands.png", dpi=140); plt.close()
print("charts saved to", I)
