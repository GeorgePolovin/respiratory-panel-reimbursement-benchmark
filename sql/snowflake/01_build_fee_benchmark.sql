/* =====================================================================
   RESPIRATORY PANEL MARKET-ACCESS PROJECT
   Clean, repeatable build script

   Purpose
   -------
   1. Use the existing Snowflake environment.
   2. Validate the raw CMS CLFS source table.
   3. Rebuild the cleaned CLFS reference table.
   4. Rebuild the respiratory-code reference map.
   5. Rebuild the first respiratory reimbursement analytical view.
   6. Run quality checks and display the preserved analytical output.

   Important
   ---------
   - This file intentionally excludes one-time account administration,
     warehouse creation, and resource-monitor creation.
   - Those commands are preserved separately in:
       00_admin_setup_archive.sql
   - The raw source table is never replaced or modified by this script.
   - Derived REFERENCE tables and the ANALYTICS view are reproducible and
     are therefore created with CREATE OR REPLACE.
   ===================================================================== */


/* =====================================================================
   00 — SESSION CONTEXT
   Use SYSADMIN for routine project work. ACCOUNTADMIN is not needed for
   querying or rebuilding the project tables and views.
   ===================================================================== */

USE ROLE SYSADMIN;
USE WAREHOUSE RESP_PANEL_WH;
USE DATABASE RESP_PANEL_ACCESS;
USE SCHEMA RAW;


/* =====================================================================
   01 — BASIC ENVIRONMENT CHECK
   Confirms that VS Code is connected to the intended Snowflake context.
   Run this statement first before executing any CREATE OR REPLACE steps.
   ===================================================================== */

SELECT
    CURRENT_USER()       AS current_user,
    CURRENT_ROLE()       AS current_role,
    CURRENT_WAREHOUSE()  AS current_warehouse,
    CURRENT_DATABASE()   AS current_database,
    CURRENT_SCHEMA()     AS current_schema,
    CURRENT_VERSION()    AS snowflake_version;


/* =====================================================================
   02 — RAW CMS CLFS SOURCE VALIDATION
   Source grain:
     One row represents a CMS CLFS code/modifier/effective-date record
     from the CY2026 Q3 V1 source file.

   These checks do not alter the raw table.
   ===================================================================== */

-- Confirm the raw table structure and source column names.
DESCRIBE TABLE RESP_PANEL_ACCESS.RAW.CMS_CLFS_2026_Q3_RAW;

-- Preserve the raw source row count for reconciliation.
SELECT
    COUNT(*) AS raw_row_count
FROM RESP_PANEL_ACCESS.RAW.CMS_CLFS_2026_Q3_RAW;

-- Confirm that the four respiratory codes needed for the project exist.
SELECT
    YEAR,
    HCPCS,
    MOD,
    EFF_DATE,
    INDICATOR,
    RATE,
    SHORTDESC,
    EXTENDEDLONGDESC
FROM RESP_PANEL_ACCESS.RAW.CMS_CLFS_2026_Q3_RAW
WHERE HCPCS IN ('0202U', '87631', '87632', '87633')
ORDER BY
    HCPCS,
    MOD;


/* =====================================================================
   03 — CLEANED CLFS REFERENCE TABLE
   Output:
     RESP_PANEL_ACCESS.REFERENCE.CMS_CLFS

   Purpose:
   - Standardize names and data types.
   - Convert blank modifiers to NULL.
   - Convert the effective date into a Snowflake DATE.
   - Preserve source lineage for later validation.

   The table remains at the same logical grain as the raw source.
   ===================================================================== */

CREATE OR REPLACE TABLE RESP_PANEL_ACCESS.REFERENCE.CMS_CLFS AS
SELECT
    YEAR::NUMBER(4,0)                         AS calendar_year,
    TRIM(HCPCS)::VARCHAR                      AS hcpcs_code,
    NULLIF(TRIM(MOD), '')::VARCHAR            AS modifier,
    TRY_TO_DATE(EFF_DATE::VARCHAR, 'YYYYMMDD') AS effective_date,
    TRIM(INDICATOR)::VARCHAR                  AS payment_indicator,
    RATE::NUMBER(10,2)                        AS national_rate,
    TRIM(SHORTDESC)::VARCHAR                  AS short_description,
    TRIM(LONGDESC)::VARCHAR                   AS long_description,
    TRIM(EXTENDEDLONGDESC)::VARCHAR           AS extended_long_description,
    'CMS Clinical Laboratory Fee Schedule'   AS source_name,
    'CY2026 Q3 V1'                            AS source_release,
    DATE '2026-07-23'                         AS retrieval_date,
    'PUBLIC'                                  AS data_origin
FROM RESP_PANEL_ACCESS.RAW.CMS_CLFS_2026_Q3_RAW;


/* =====================================================================
   04 — CLFS REFERENCE-TABLE VALIDATION
   These checks confirm that the transformation preserved row counts and
   did not introduce unexpected missing values or duplicate grain.
   ===================================================================== */

-- Confirm that the table exists.
SHOW TABLES LIKE 'CMS_CLFS'
    IN SCHEMA RESP_PANEL_ACCESS.REFERENCE;

-- Inspect final column names and data types.
DESCRIBE TABLE RESP_PANEL_ACCESS.REFERENCE.CMS_CLFS;

-- Raw and reference row counts should match because this is a
-- standardization step, not a filtering step.
SELECT
    (SELECT COUNT(*)
       FROM RESP_PANEL_ACCESS.RAW.CMS_CLFS_2026_Q3_RAW) AS raw_rows,
    (SELECT COUNT(*)
       FROM RESP_PANEL_ACCESS.REFERENCE.CMS_CLFS)       AS reference_rows;

-- Assess missing values in the fields needed for reimbursement analysis.
SELECT
    COUNT_IF(hcpcs_code IS NULL)    AS missing_codes,
    COUNT_IF(national_rate IS NULL) AS missing_rates,
    COUNT_IF(effective_date IS NULL) AS missing_dates
FROM RESP_PANEL_ACCESS.REFERENCE.CMS_CLFS;

-- Test the expected source grain:
-- calendar year + code + modifier + effective date.
-- A result set with zero rows means no duplicate grain was found.
SELECT
    calendar_year,
    hcpcs_code,
    COALESCE(modifier, 'NO_MODIFIER') AS modifier_group,
    effective_date,
    COUNT(*) AS record_count
FROM RESP_PANEL_ACCESS.REFERENCE.CMS_CLFS
GROUP BY
    calendar_year,
    hcpcs_code,
    COALESCE(modifier, 'NO_MODIFIER'),
    effective_date
HAVING COUNT(*) > 1
ORDER BY
    record_count DESC;


/* =====================================================================
   05 — RESPIRATORY CODE REFERENCE MAP
   Output:
     RESP_PANEL_ACCESS.REFERENCE.RESPIRATORY_CODE_MAP

   Purpose:
   Adds market-access interpretation that is not contained in the CMS
   fee schedule itself, including panel size, product specificity, and
   each code's role in the project.
   ===================================================================== */

CREATE OR REPLACE TABLE
    RESP_PANEL_ACCESS.REFERENCE.RESPIRATORY_CODE_MAP AS
SELECT *
FROM VALUES
    (
        '0202U',
        'PLA',
        'Study panel: 22-target syndromic respiratory panel',
        22,
        22,
        'BROAD_MULTIPLEX',
        TRUE,
        TRUE,
        'Primary product-specific respiratory-panel code'
    ),
    (
        '87631',
        'GENERIC_CPT',
        'Respiratory virus panel, 3 to 5 targets',
        3,
        5,
        'SMALL_TARGETED_PANEL',
        FALSE,
        FALSE,
        'Small-panel policy and reimbursement comparator'
    ),
    (
        '87632',
        'GENERIC_CPT',
        'Respiratory virus panel, 6 to 11 targets',
        6,
        11,
        'INTERMEDIATE_PANEL',
        FALSE,
        FALSE,
        'Intermediate-panel policy and reimbursement comparator'
    ),
    (
        '87633',
        'GENERIC_CPT',
        'Respiratory virus panel, 12 to 25 targets',
        12,
        25,
        'BROAD_MULTIPLEX',
        FALSE,
        FALSE,
        'Broad generic-panel policy and reimbursement comparator'
    )
AS code_map (
    hcpcs_code,
    code_type,
    test_configuration,
    minimum_targets,
    maximum_targets,
    panel_size_category,
    product_specific_flag,
    primary_project_flag,
    market_access_role
);


/* =====================================================================
   06 — REFERENCE JOIN CHECK
   Confirms that every respiratory code maps to its CMS reimbursement
   record. A LEFT JOIN is retained so a missing fee-schedule record is
   visible rather than silently removed.
   ===================================================================== */

SELECT
    m.hcpcs_code,
    m.code_type,
    m.test_configuration,
    m.panel_size_category,
    m.product_specific_flag,
    f.modifier,
    f.effective_date,
    f.national_rate,
    f.source_release
FROM RESP_PANEL_ACCESS.REFERENCE.RESPIRATORY_CODE_MAP AS m
LEFT JOIN RESP_PANEL_ACCESS.REFERENCE.CMS_CLFS AS f
    ON m.hcpcs_code = f.hcpcs_code
ORDER BY
    m.hcpcs_code,
    f.modifier;


/* =====================================================================
   07 — FIRST MARKET-ACCESS ANALYTICAL VIEW
   Output:
     RESP_PANEL_ACCESS.ANALYTICS.V_RESPIRATORY_FEE_BENCHMARK

   Business purpose:
   Compare each respiratory panel's national CLFS rate with the small
   targeted-panel benchmark represented by HCPCS 87631.

   Calculated metrics:
   - incremental_rate_vs_small_panel:
       national rate minus the 87631 rate.
   - rate_index_vs_small_panel:
       national rate divided by the 87631 rate.
       Example: 2.00 means twice the small-panel benchmark.

   Only rows without modifiers are used to avoid mixing modifier-specific
   reimbursement records into the national benchmark.
   ===================================================================== */

CREATE OR REPLACE VIEW
    RESP_PANEL_ACCESS.ANALYTICS.V_RESPIRATORY_FEE_BENCHMARK AS

WITH respiratory_rates AS (
    SELECT
        m.hcpcs_code,
        m.code_type,
        m.test_configuration,
        m.minimum_targets,
        m.maximum_targets,
        m.panel_size_category,
        m.product_specific_flag,
        m.primary_project_flag,
        f.effective_date,
        f.national_rate,

        MAX(
            IFF(
                m.hcpcs_code = '87631',
                f.national_rate,
                NULL
            )
        ) OVER () AS small_panel_rate

    FROM RESP_PANEL_ACCESS.REFERENCE.RESPIRATORY_CODE_MAP AS m
    LEFT JOIN RESP_PANEL_ACCESS.REFERENCE.CMS_CLFS AS f
        ON m.hcpcs_code = f.hcpcs_code
    WHERE f.modifier IS NULL
)

SELECT
    hcpcs_code,
    code_type,
    test_configuration,
    minimum_targets,
    maximum_targets,
    panel_size_category,
    product_specific_flag,
    primary_project_flag,
    effective_date,
    national_rate,
    small_panel_rate,
    national_rate - small_panel_rate
        AS incremental_rate_vs_small_panel,
    national_rate / NULLIF(small_panel_rate, 0)
        AS rate_index_vs_small_panel
FROM respiratory_rates;


/* =====================================================================
   08 — PRESERVED ANALYTICAL OUTPUT
   This is the first completed project output and should return the four
   respiratory codes ordered by national reimbursement rate.
   ===================================================================== */

SELECT *
FROM RESP_PANEL_ACCESS.ANALYTICS.V_RESPIRATORY_FEE_BENCHMARK
ORDER BY
    national_rate;


/* =====================================================================
   09 — FINAL OBJECT INVENTORY
   Confirms the project objects available to the current role.
   INFORMATION_SCHEMA is excluded because it is Snowflake metadata rather
   than a user-created project schema.
   ===================================================================== */

SELECT
    table_schema,
    table_name,
    table_type,
    row_count,
    bytes,
    created,
    last_altered
FROM RESP_PANEL_ACCESS.INFORMATION_SCHEMA.TABLES
WHERE table_schema <> 'INFORMATION_SCHEMA'
ORDER BY
    table_schema,
    table_name;
