-- Exploratory Data Analysis (EDA)
-- Dataset: World Layoffs
/*
Skills Used: Data Exploration, Filtering, Aggregate Functions, GROUP BY, ORDER BY, Common Table Expressions (CTEs), Window Functions (DENSE_RANK, SUM OVER), Date Functions (YEAR, SUBSTRING), Ranking, Rolling Aggregations
*/

-- ============================================================
-- WORLD LAYOFFS SQL PROJECT
-- Data Cleaning & Exploratory Data Analysis
-- Dataset: World Layoffs
-- ============================================================


-- ============================================================
-- DATA CLEANING
-- ============================================================

-- Create a staging table to preserve the raw dataset
CREATE TABLE world_layoffs.layoffs_staging
LIKE world_layoffs.layoffs;

INSERT INTO world_layoffs.layoffs_staging
SELECT *
FROM world_layoffs.layoffs;


-- ------------------------------------------------------------
-- 1. Remove Duplicate Records
-- ------------------------------------------------------------

-- Identify duplicate records using ROW_NUMBER()
CREATE TABLE world_layoffs.layoffs_staging2 (
    company TEXT,
    location TEXT,
    industry TEXT,
    total_laid_off INT,
    percentage_laid_off TEXT,
    date TEXT,
    stage TEXT,
    country TEXT,
    funds_raised_millions INT,
    row_num INT
);

INSERT INTO world_layoffs.layoffs_staging2
(
    company,
    location,
    industry,
    total_laid_off,
    percentage_laid_off,
    date,
    stage,
    country,
    funds_raised_millions,
    row_num
)
SELECT
    company,
    location,
    industry,
    total_laid_off,
    percentage_laid_off,
    date,
    stage,
    country,
    funds_raised_millions,
    ROW_NUMBER() OVER (
        PARTITION BY
            company,
            location,
            industry,
            total_laid_off,
            percentage_laid_off,
            date,
            stage,
            country,
            funds_raised_millions
    ) AS row_num
FROM world_layoffs.layoffs_staging;

-- Remove duplicate records
DELETE FROM world_layoffs.layoffs_staging2
WHERE row_num > 1;


-- ------------------------------------------------------------
-- 2. Standardize Data
-- ------------------------------------------------------------

-- Convert blank industry values to NULL
UPDATE world_layoffs.layoffs_staging2
SET industry = NULL
WHERE industry = '';

-- Populate missing industry values using other records
-- belonging to the same company
UPDATE world_layoffs.layoffs_staging2 t1
JOIN world_layoffs.layoffs_staging2 t2
    ON t1.company = t2.company
SET t1.industry = t2.industry
WHERE t1.industry IS NULL
  AND t2.industry IS NOT NULL;

-- Standardize variations of the Crypto industry
UPDATE world_layoffs.layoffs_staging2
SET industry = 'Crypto'
WHERE industry IN ('Crypto Currency', 'CryptoCurrency');

-- Remove trailing periods from country names
UPDATE world_layoffs.layoffs_staging2
SET country = TRIM(TRAILING '.' FROM country);

-- Convert date values from text to DATE format
UPDATE world_layoffs.layoffs_staging2
SET date = STR_TO_DATE(date, '%m/%d/%Y');

ALTER TABLE world_layoffs.layoffs_staging2
MODIFY COLUMN date DATE;


-- ------------------------------------------------------------
-- 3. Handle Missing Values
-- ------------------------------------------------------------

-- NULL values in total_laid_off, percentage_laid_off,
-- and funds_raised_millions are retained because they
-- represent unavailable source data and can be handled
-- appropriately during analysis.


-- ------------------------------------------------------------
-- 4. Remove Records Without Usable Layoff Data
-- ------------------------------------------------------------

-- Remove records where both key layoff metrics are unavailable
DELETE FROM world_layoffs.layoffs_staging2
WHERE total_laid_off IS NULL
  AND percentage_laid_off IS NULL;

-- Remove the temporary duplicate-tracking column
ALTER TABLE world_layoffs.layoffs_staging2
DROP COLUMN row_num;


-- ============================================================
-- EXPLORATORY DATA ANALYSIS (EDA)
-- ============================================================

/*
Skills Used:
Data Exploration, Filtering, Aggregate Functions, GROUP BY,
ORDER BY, Common Table Expressions (CTEs), Window Functions,
DENSE_RANK, SUM OVER, Date Functions, Ranking,
Rolling Aggregations
*/


-- ------------------------------------------------------------
-- 1. Initial Data Exploration
-- ------------------------------------------------------------

SELECT *
FROM world_layoffs.layoffs_staging2;


-- Maximum layoffs recorded in a single event
SELECT MAX(total_laid_off) AS max_layoffs
FROM world_layoffs.layoffs_staging2;


-- Minimum and maximum percentage of workforce laid off
SELECT
    MIN(percentage_laid_off) AS min_percentage_laid_off,
    MAX(percentage_laid_off) AS max_percentage_laid_off
FROM world_layoffs.layoffs_staging2
WHERE percentage_laid_off IS NOT NULL;


-- Companies with 100% workforce layoffs
SELECT *
FROM world_layoffs.layoffs_staging2
WHERE percentage_laid_off = 1;


-- Companies with 100% layoffs ordered by funds raised
SELECT *
FROM world_layoffs.layoffs_staging2
WHERE percentage_laid_off = 1
ORDER BY funds_raised_millions DESC;


-- ------------------------------------------------------------
-- 2. Aggregated Analysis
-- ------------------------------------------------------------

-- Top 5 largest single layoff events
SELECT
    company,
    total_laid_off
FROM world_layoffs.layoffs_staging2
ORDER BY total_laid_off DESC
LIMIT 5;


-- Companies with the highest total layoffs
SELECT
    company,
    SUM(total_laid_off) AS total_layoffs
FROM world_layoffs.layoffs_staging2
GROUP BY company
ORDER BY total_layoffs DESC
LIMIT 10;


-- Total layoffs by location
SELECT
    location,
    SUM(total_laid_off) AS total_layoffs
FROM world_layoffs.layoffs_staging2
GROUP BY location
ORDER BY total_layoffs DESC
LIMIT 10;


-- Total layoffs by country
SELECT
    country,
    SUM(total_laid_off) AS total_layoffs
FROM world_layoffs.layoffs_staging2
GROUP BY country
ORDER BY total_layoffs DESC;


-- Year-wise layoffs
SELECT
    YEAR(date) AS year,
    SUM(total_laid_off) AS total_layoffs
FROM world_layoffs.layoffs_staging2
GROUP BY YEAR(date)
ORDER BY year ASC;


-- Total layoffs by industry
SELECT
    industry,
    SUM(total_laid_off) AS total_layoffs
FROM world_layoffs.layoffs_staging2
GROUP BY industry
ORDER BY total_layoffs DESC;


-- Total layoffs by company stage
SELECT
    stage,
    SUM(total_laid_off) AS total_layoffs
FROM world_layoffs.layoffs_staging2
GROUP BY stage
ORDER BY total_layoffs DESC;


-- ------------------------------------------------------------
-- 3. Advanced Analysis
-- ------------------------------------------------------------

-- Top 3 companies with the highest layoffs each year
WITH Company_Year AS (
    SELECT
        company,
        YEAR(date) AS year,
        SUM(total_laid_off) AS total_layoffs
    FROM world_layoffs.layoffs_staging2
    GROUP BY company, YEAR(date)
),

Company_Year_Rank AS (
    SELECT
        company,
        year,
        total_layoffs,
        DENSE_RANK() OVER (
            PARTITION BY year
            ORDER BY total_layoffs DESC
        ) AS ranking
    FROM Company_Year
)

SELECT
    company,
    year,
    total_layoffs,
    ranking
FROM Company_Year_Rank
WHERE ranking <= 3
  AND year IS NOT NULL
ORDER BY year ASC, total_layoffs DESC;


-- ------------------------------------------------------------
-- 4. Monthly Layoff Trends
-- ------------------------------------------------------------

-- Monthly layoffs
SELECT
    SUBSTRING(date, 1, 7) AS month,
    SUM(total_laid_off) AS total_layoffs
FROM world_layoffs.layoffs_staging2
GROUP BY month
ORDER BY month ASC;


-- Rolling total of layoffs by month
WITH Date_CTE AS (
    SELECT
        SUBSTRING(date, 1, 7) AS month,
        SUM(total_laid_off) AS total_layoffs
    FROM world_layoffs.layoffs_staging2
    GROUP BY month
)

SELECT
    month,
    SUM(total_layoffs) OVER (
        ORDER BY month ASC
    ) AS rolling_total_layoffs
FROM Date_CTE
ORDER BY month ASC;
