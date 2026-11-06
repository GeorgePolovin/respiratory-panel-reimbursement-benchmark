/* =====================================================================
   RESPIRATORY PANEL PROJECT — ONE-TIME ADMINISTRATION ARCHIVE

   This file preserves the infrastructure setup that was already
   completed. It should NOT be run as part of normal analytics work.

   Why it is separate:
   - Resource-monitor administration requires ACCOUNTADMIN.
   - Routine project work should use SYSADMIN.
   - Re-running CREATE OR REPLACE RESOURCE MONITOR is unnecessary and can
     change an existing monitor.
   ===================================================================== */


/* =====================================================================
   01 — RESOURCE MONITOR
   Run only when initially creating or intentionally changing the monitor.
   ===================================================================== */

USE ROLE ACCOUNTADMIN;

CREATE RESOURCE MONITOR IF NOT EXISTS RESP_PANEL_COST_MONITOR
    WITH
        CREDIT_QUOTA = 10
        FREQUENCY = MONTHLY
        START_TIMESTAMP = IMMEDIATELY
        TRIGGERS
            ON 50 PERCENT DO NOTIFY
            ON 90 PERCENT DO SUSPEND
            ON 100 PERCENT DO SUSPEND_IMMEDIATE;


/* =====================================================================
   02 — PROJECT WAREHOUSE
   XSMALL and 60-second auto-suspend minimize unnecessary trial-credit
   consumption.
   ===================================================================== */

CREATE WAREHOUSE IF NOT EXISTS RESP_PANEL_WH
    WAREHOUSE_SIZE = XSMALL
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE
    INITIALLY_SUSPENDED = TRUE
    COMMENT = 'Respiratory panel market-access project';

ALTER WAREHOUSE RESP_PANEL_WH
    SET RESOURCE_MONITOR = RESP_PANEL_COST_MONITOR;


/* =====================================================================
   03 — DATABASE AND SCHEMAS
   SYSADMIN is used for the project database objects.
   ===================================================================== */

USE ROLE SYSADMIN;

CREATE DATABASE IF NOT EXISTS RESP_PANEL_ACCESS
    COMMENT = 'Public and synthetic respiratory market-access data';

CREATE SCHEMA IF NOT EXISTS RESP_PANEL_ACCESS.RAW
    COMMENT = 'Original data loaded with minimal transformation';

CREATE SCHEMA IF NOT EXISTS RESP_PANEL_ACCESS.REFERENCE
    COMMENT = 'Public coding, policy, fee schedule, payer, and account reference data';

CREATE SCHEMA IF NOT EXISTS RESP_PANEL_ACCESS.ANALYTICS
    COMMENT = 'Cleaned data, joins, classifications, and claim-level calculations';

CREATE SCHEMA IF NOT EXISTS RESP_PANEL_ACCESS.MART
    COMMENT = 'Aggregated Tableau-ready market-access datasets';


/* =====================================================================
   04 — ADMINISTRATION VALIDATION
   ===================================================================== */

SHOW WAREHOUSES LIKE 'RESP_PANEL_WH';
SHOW RESOURCE MONITORS LIKE 'RESP_PANEL_COST_MONITOR';
SHOW SCHEMAS IN DATABASE RESP_PANEL_ACCESS;
