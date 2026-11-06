-- ============================================================
-- 03_fee_benchmark.sql
--
-- Compare every mapped respiratory code with two benchmarks:
--   * the study panel (rate parity among broad panels)
--   * the small targeted panel 87631 (payer substitution savings)
-- Only unmodified rows are used; a CLIA-waived (QW) flag is added.
-- ============================================================

CREATE OR REPLACE VIEW analytics.v_respiratory_fee_benchmark AS
WITH rates AS (
    SELECT m.*, f.effective_date, f.national_rate,
           EXISTS (SELECT 1 FROM reference.cms_clfs q
                   WHERE q.hcpcs_code = m.hcpcs_code AND q.modifier = 'QW') AS clia_waived_version
    FROM reference.respiratory_code_map m
    JOIN reference.cms_clfs f ON m.hcpcs_code = f.hcpcs_code AND f.modifier IS NULL
)
SELECT
    *,
    MAX(CASE WHEN competitive_role = 'Study product' THEN national_rate END) OVER () AS study_panel_rate,
    MAX(CASE WHEN hcpcs_code = '87631' THEN national_rate END) OVER ()            AS small_panel_rate,
    ROUND(national_rate / MAX(CASE WHEN competitive_role = 'Study product' THEN national_rate END) OVER (), 2)
        AS index_vs_study_panel,
    national_rate - MAX(CASE WHEN competitive_role = 'Study product' THEN national_rate END) OVER ()
        AS gap_vs_study_panel_usd,
    ROUND(national_rate / MAX(CASE WHEN hcpcs_code = '87631' THEN national_rate END) OVER (), 2)
        AS index_vs_small_panel
FROM rates;

SELECT competitive_role, test_configuration, national_rate, index_vs_study_panel
FROM analytics.v_respiratory_fee_benchmark
ORDER BY national_rate DESC;

SELECT
    COUNT(*) FILTER (WHERE maximum_targets >= 12 AND national_rate = study_panel_rate) AS broad_codes_at_parity,
    COUNT(*) FILTER (WHERE maximum_targets >= 12) AS broad_codes,
    CASE WHEN COUNT(*) = 13 THEN 'PASS' ELSE 'REVIEW' END AS benchmark_status
FROM analytics.v_respiratory_fee_benchmark;

-- Export with the study company's codes masked (charts and tables are de-identified).
COPY (
    SELECT CASE WHEN competitive_role IN ('Study product', 'Own portfolio') THEN 'study PLA'
                ELSE hcpcs_code END AS hcpcs_code,
           * EXCLUDE (hcpcs_code)
    FROM analytics.v_respiratory_fee_benchmark
    ORDER BY national_rate DESC, maximum_targets DESC
) TO 'outputs/tables/respiratory_fee_benchmark.csv' (HEADER, DELIMITER ',');
