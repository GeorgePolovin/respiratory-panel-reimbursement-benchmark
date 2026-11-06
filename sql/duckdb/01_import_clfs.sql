-- ============================================================
-- 01_import_clfs.sql  (DuckDB port of sql/snowflake/01_build_fee_benchmark.sql)
--
-- Load the public CMS Clinical Laboratory Fee Schedule (CY2026 Q3 V1)
-- unchanged into raw, then standardize it into reference.cms_clfs.
-- Grain: calendar year + HCPCS code + modifier + effective date.
-- ============================================================

CREATE SCHEMA IF NOT EXISTS raw;
CREATE SCHEMA IF NOT EXISTS reference;
CREATE SCHEMA IF NOT EXISTS analytics;

CREATE OR REPLACE TABLE raw.cms_clfs_2026_q3 AS
SELECT * FROM read_csv('data/raw/cms_clfs_2026_q3.csv', header = true, all_varchar = true);

CREATE OR REPLACE TABLE reference.cms_clfs AS
SELECT
    CAST(YEAR AS INTEGER)                          AS calendar_year,
    TRIM(HCPCS)                                    AS hcpcs_code,
    NULLIF(TRIM(MOD), '')                          AS modifier,
    strptime(EFF_DATE, '%Y%m%d')::DATE             AS effective_date,
    TRIM(INDICATOR)                                AS payment_indicator,
    CAST(RATE AS DECIMAL(10, 2))                   AS national_rate,
    TRIM(SHORTDESC)                                AS short_description,
    TRIM(LONGDESC)                                 AS long_description,
    TRIM(EXTENDEDLONGDESC)                         AS extended_long_description,
    'CMS Clinical Laboratory Fee Schedule'         AS source_name,
    'CY2026 Q3 V1'                                 AS source_release
FROM raw.cms_clfs_2026_q3;

-- Row counts must match (standardization, not filtering); grain must be unique.
SELECT
    (SELECT COUNT(*) FROM raw.cms_clfs_2026_q3) AS raw_rows,
    (SELECT COUNT(*) FROM reference.cms_clfs)   AS reference_rows,
    (SELECT COUNT(*) FROM (
        SELECT 1 FROM reference.cms_clfs
        GROUP BY calendar_year, hcpcs_code, COALESCE(modifier, '-'), effective_date
        HAVING COUNT(*) > 1)) AS duplicate_grain_rows,
    CASE WHEN (SELECT COUNT(*) FROM raw.cms_clfs_2026_q3) = (SELECT COUNT(*) FROM reference.cms_clfs)
          AND (SELECT COUNT(*) FROM reference.cms_clfs WHERE national_rate IS NULL) = 0
         THEN 'PASS' ELSE 'REVIEW' END AS clfs_import_status;
