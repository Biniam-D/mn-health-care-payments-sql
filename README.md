# Minnesota Health Care Programs Payment Analysis (CY2020–2024)

A documented, rerunnable SQL workflow that builds a validated analytic file from five years of Minnesota Department of Human Services (DHS) payment data, checks it for completeness and accuracy, and summarizes payment trends for Medical Assistance (MA) and MinnesotaCare.

**Language:** SQL (PostgreSQL 16)
**Script:** [`mn_payment.sql`](mn_payment.sql)

---

## Data

Source: Minnesota DHS, *Medical Assistance and MinnesotaCare Payments by County*, calendar years 2020–2024 (public reports).

Each year is one Excel workbook, saved as CSV, with 87 counties, an "Other" row for unassigned payments, and a "Statewide" total row (89 rows per year). The CSV files are not included in this repository; download the reports from DHS and save them as `mn_2020.csv` … `mn_2024.csv`, then update the `COPY` paths in Section 1.

---

## Workflow

| Section | What it does |
|---|---|
| 1. Load raw data | Creates one raw table per year matching the 13 CSV columns and loads each file with `COPY`. Payment columns use `NUMERIC` to keep dollar amounts exact. Raw tables are never modified, so every result traces back to the source. |
| 2. Build the analytic file | Stacks the five years with `UNION ALL`, adds a `year` column, moves DHS's Statewide rows to a separate control table to avoid double counting, and creates `analytic_payments` (one row per county per year, 440 rows). Adds `ma_all_total`, because DHS reports three MA categories (IMD, SCHIP Unborn, State-Only MA Other) outside its MA Total. |
| 3. Data quality checks | Completeness (rows, unique counties, missing values per year) and reconciliation of county rows to DHS's Statewide totals within $1. |
| 4. Summary analysis | Total payments by program and year, with year-over-year growth using a CTE and the `LAG()` window function. |

Every table is dropped with `DROP TABLE IF EXISTS` before it is created, so the script runs cleanly from scratch each time. During development, the row-count check caught a duplicate load (178 rows per year), which is why the drop step was added.

---

## Data quality results

| Check | What it tests | Result |
|---|---|---|
| Completeness | Rows, unique counties, and missing values per year | 88 rows, 88 unique counties, 0 missing each year |
| Reconciliation | County rows sum to DHS Statewide totals within $1 (source rounding) | PASS, 2020–2024 |

---

## Key findings

- Total payments grew from **$14.11 billion in 2020 to $21.23 billion in 2024**, driven mainly by Medical Assistance.
- Growth slowed from **14.8% in 2022 to 5.3% in 2023**, consistent with the end of continuous Medicaid enrollment.
- MinnesotaCare payments stayed steady at about **$0.69 billion**.

---

## Author

**Biniam Degaga** — M.Sc. Data Science | Medical Laboratory Scientist (ASCP)
