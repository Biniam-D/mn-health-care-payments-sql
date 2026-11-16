/*==========================================================
Minnesota Health Care Programs Payment Analysis, CY2020-2024
=============================================================
Author: Biniam Degaga
Language: SQL (Postgres 16)
Source: MN DHS, Medical Assistance and MinnesotaCare Payments by County, 
        CY2020-2024 (five Excel workbooks cleaned and saved as CSV)
Note: Submitted in SQL as the alternative language for non-SAS programmers. The same logic maps to SAS; PROC SQL uses the same syntax, and the joins, aggregations, 
		and validation checks shown here are the same tasks performed in SAS for encounter data quality work.   
Purpose: Build an analytical file from five years of DHS payment data, validate it, and summarize payment trends.*/ 
/*---------------------------------------------------------------
SECTION 1: LOAD RAW DATA
One table per year, matching the CSV layout
-----------------------------------------------------------------*/
--Drop table from earlier runs so that the script can be rerun from scratch
DROP TABLE IF EXISTS raw_2020, raw_2021, raw_2022, raw_2023, raw_2024 CASCADE; 

CREATE TABLE raw_2020 (
county TEXT, 
	ma_families_children NUMERIC, 
	ma_disabled        NUMERIC, 
	ma_elderly      NUMERIC, 
	ma_adults_no_children NUMERIC, 
	ma_total   NUMERIC, 
	ma_imd     NUMERIC, 
	ma_schip_unborn  NUMERIC, 
	ma_state_only_other  NUMERIC,
	mnc_families_children  NUMERIC,
	mnc_adults_no_children  NUMERIC,
	mnc_state_only_funded NUMERIC, 
	mnc_total NUMERIC 
	);
	
	--Create the other four tables. Same structure for the remaining years
	
CREATE TABLE raw_2021(LIKE raw_2020);
CREATE TABLE raw_2022(LIKE raw_2020);
CREATE TABLE raw_2023(LIKE raw_2020);
CREATE TABLE raw_2024(LIKE raw_2020);

--Load each year's CSV into its table. 
COPY raw_2020 FROM 'C:/mn_data/mn_2020.csv' WITH (FORMAT csv, HEADER true);
COPY raw_2021 FROM 'C:/mn_data/mn_2021.csv' WITH (FORMAT csv, HEADER true);
COPY raw_2022 FROM 'C:/mn_data/mn_2022.csv' WITH (FORMAT csv, HEADER true);
COPY raw_2023 FROM 'C:/mn_data/mn_2023.csv' WITH (FORMAT csv, HEADER true);
COPY raw_2024 FROM 'C:/mn_data/mn_2024.csv' WITH (FORMAT csv, HEADER true);

--Check: each year should have 89 rows (87 counties+other+Statewide)
SELECT 2020 AS year, COUNT(*) AS n_rows FROM raw_2020
UNION ALL SELECT 2021, COUNT(*) FROM raw_2021
UNION ALL SELECT 2022, COUNT(*) FROM raw_2022
UNION ALL SELECT 2023, COUNT(*) FROM raw_2023
UNION ALL SELECT 2024, COUNT(*) FROM raw_2024;

/*---------------------------------------------------------------
SECTION 2: BUILDING THE ANALYSIS-READY FILE


-----------------------------------------------------------------*/
DROP TABLE IF EXISTS payments_stacked, statewide_control, analytic_payments CASCADE;
--Combine the five years; add year column
CREATE TABLE payments_stacked AS
        SELECT 2020 AS year, * FROM raw_2020
UNION ALL SELECT 2021, * FROM raw_2021
UNION ALL SELECT 2022, * FROM raw_2022
UNION ALL SELECT 2023, * FROM raw_2023
UNION ALL SELECT 2024, * FROM raw_2024;

--Move DHS's statewide total rows to a separate table
CREATE TABLE statewide_control AS
SELECT * FROM payments_stacked WHERE county='Statewide';

--Final analytic file: one row per county per year.
--Statewide is excluded to avoid double counting.
--ma_all_total adds the three MA categories reported outside ma_total.

CREATE TABLE analytic_payments AS
SELECT *, 
ma_total + ma_imd+ ma_schip_unborn + ma_state_only_other AS ma_all_total
FROM payments_stacked
WHERE county <> 'Statewide'; 


/*---------------------------------------------------------------
SECTION 3: DATA QUALITY CHECKS
-----------------------------------------------------------------*/

--Completeness: 88 rows and 88 unique counties per year, 0 missing

SELECT year,
COUNT(*)    AS n_rows,
COUNT(DISTINCT county) AS n_counties, 
COUNT(*) FILTER (WHERE ma_total IS NULL OR mnc_total IS NULL) AS n_missing
FROM analytic_payments
GROUP BY year
ORDER BY year;

--Reconciliation: county rows must match DHS Statewide totals (within $1)

SELECT a.year,
CASE WHEN ABS(SUM(a.ma_total)-MAX(s.ma_total)) <=1
     AND ABS(SUM(a.mnc_total)-MAX(s.mnc_total)) <=1
	 THEN 'PASS' ELSE 'REVIEW' END AS status
	 FROM analytic_payments a
	 JOIN statewide_control s USING (year)
	 GROUP BY a.year
     ORDER BY a.year;

/*---------------------------------------------------------------
SECTION 4: SUMMARY ANALYSIS
-----------------------------------------------------------------*/

--Total payments by program and year, with year-over-year growth
--LAG() pulls the prior year's total to calculate growth. 
--pct_growth is blank for 2020 as there is no earlier year to compare with

WITH yearly AS (
    SELECT year,
           SUM(ma_all_total)             AS ma,
           SUM(mnc_total)                AS mnc,
           SUM(ma_all_total + mnc_total) AS total
    FROM analytic_payments
    GROUP BY year
)
SELECT year,
       ROUND(ma    / 1e9, 2) AS ma_billions,
       ROUND(mnc   / 1e9, 2) AS mnc_billions,
       ROUND(total / 1e9, 2) AS total_billions,
       ROUND(100 * (total / LAG(total) OVER (ORDER BY year) - 1), 1) AS pct_growth
FROM yearly
ORDER BY year;
