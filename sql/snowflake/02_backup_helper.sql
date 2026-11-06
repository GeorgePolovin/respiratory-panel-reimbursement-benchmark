/* =====================================================================
   RESPIRATORY PANEL PROJECT — LOCAL BACKUP HELPER
   Run each numbered statement separately in the Snowflake VS Code
   extension. Use the Save-results button in the results pane to save
   each data result as a local CSV.

   Suggested local folder:
     RESP_PANEL_ACCESS/
       backup/
         ddl/
         data/
         manifests/

   This script does not alter any project data.
   ===================================================================== */

USE ROLE SYSADMIN;
USE WAREHOUSE RESP_PANEL_WH;
USE DATABASE RESP_PANEL_ACCESS;
USE SCHEMA RAW;


/* =====================================================================
   01 — BACKUP MANIFEST
   Save the result as:
     backup/manifests/resp_panel_object_inventory.csv
   ===================================================================== */

SELECT
    table_catalog,
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


/* =====================================================================
   02 — DATABASE DDL BACKUP
   GET_DDL recursively returns supported database, schema, table, and
   view definitions.

   Run the query, copy the text from the DATABASE_DDL result cell, and
   paste it into this local file:
     backup/ddl/resp_panel_project_database_ddl.sql

   Keep the original 01_build_fee_benchmark.sql as the human-commented source
   of truth; this generated DDL is a machine-produced recovery backup.
   ===================================================================== */

SELECT GET_DDL(
    'DATABASE',
    'RESP_PANEL_ACCESS',
    TRUE
) AS database_ddl;


/* =====================================================================
   03 — RAW SOURCE DATA BACKUP
   Run and save the result as:
     backup/data/raw_cms_clfs_2026_q3_raw.csv
   ===================================================================== */

SELECT *
FROM RESP_PANEL_ACCESS.RAW.CMS_CLFS_2026_Q3_RAW;


/* =====================================================================
   04 — CLEANED CLFS REFERENCE BACKUP
   Run and save the result as:
     backup/data/reference_cms_clfs.csv
   ===================================================================== */

SELECT *
FROM RESP_PANEL_ACCESS.REFERENCE.CMS_CLFS;


/* =====================================================================
   05 — RESPIRATORY CODE MAP BACKUP
   Run and save the result as:
     backup/data/reference_respiratory_code_map.csv
   ===================================================================== */

SELECT *
FROM RESP_PANEL_ACCESS.REFERENCE.RESPIRATORY_CODE_MAP
ORDER BY hcpcs_code;


/* =====================================================================
   06 — FIRST ANALYTICAL OUTPUT SNAPSHOT
   Views can be recreated from DDL, but this CSV preserves the completed
   output for review or Tableau use without an active Snowflake account.

   Save as:
     backup/data/analytics_respiratory_fee_benchmark.csv
   ===================================================================== */

SELECT *
FROM RESP_PANEL_ACCESS.ANALYTICS.V_RESPIRATORY_FEE_BENCHMARK
ORDER BY national_rate;


/* =====================================================================
   07 — BACKUP RECONCILIATION COUNTS
   Save as:
     backup/manifests/resp_panel_backup_row_counts.csv

   Compare these counts with the number of rows in the exported CSVs.
   ===================================================================== */

SELECT
    'RAW.CMS_CLFS_2026_Q3_RAW' AS object_name,
    COUNT(*) AS row_count
FROM RESP_PANEL_ACCESS.RAW.CMS_CLFS_2026_Q3_RAW

UNION ALL

SELECT
    'REFERENCE.CMS_CLFS',
    COUNT(*)
FROM RESP_PANEL_ACCESS.REFERENCE.CMS_CLFS

UNION ALL

SELECT
    'REFERENCE.RESPIRATORY_CODE_MAP',
    COUNT(*)
FROM RESP_PANEL_ACCESS.REFERENCE.RESPIRATORY_CODE_MAP

UNION ALL

SELECT
    'ANALYTICS.V_RESPIRATORY_FEE_BENCHMARK',
    COUNT(*)
FROM RESP_PANEL_ACCESS.ANALYTICS.V_RESPIRATORY_FEE_BENCHMARK

ORDER BY object_name;


/* =====================================================================
   08 — ENVIRONMENT VALIDATION
   Run after completing the backup steps.
   ===================================================================== */

SELECT
    CURRENT_USER()       AS current_user,
    CURRENT_ROLE()       AS current_role,
    CURRENT_WAREHOUSE()  AS current_warehouse,
    CURRENT_DATABASE()   AS current_database,
    CURRENT_SCHEMA()     AS current_schema,
    CURRENT_VERSION()    AS snowflake_version;

SHOW SCHEMAS IN DATABASE RESP_PANEL_ACCESS;
SHOW TABLES IN DATABASE RESP_PANEL_ACCESS;
SHOW VIEWS IN DATABASE RESP_PANEL_ACCESS;
