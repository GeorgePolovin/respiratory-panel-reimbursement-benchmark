-- ============================================================
-- 02_respiratory_code_map.sql
--
-- Market-access interpretation that the fee schedule does not contain:
-- panel size, code type, competitive role and (for competitor PLA codes)
-- the manufacturer, attributed from the AMA PLA list and payer policies.
-- The study company's own products are labelled generically.
-- ============================================================

CREATE OR REPLACE TABLE reference.respiratory_code_map AS
SELECT * FROM (VALUES
    ('0202U', 'PLA',         'Study panel',                                  22, 22, 'BROAD_MULTIPLEX',      'Study product'),
    ('0563U', 'PLA',         'Study co. POC panel, resp. menu',             15, 15, 'BROAD_MULTIPLEX',      'Own portfolio'),
    ('0564U', 'PLA',         'Study co. POC panel, throat menu',              14, 14, 'BROAD_MULTIPLEX',      'Own portfolio'),
    ('0223U', 'PLA',         'QIAGEN QIAstat-Dx Respiratory',                22, 22, 'BROAD_MULTIPLEX',      'Broad competitor'),
    ('0225U', 'PLA',         'Roche (GenMark) ePlex RP2',                    21, 21, 'BROAD_MULTIPLEX',      'Broad competitor'),
    ('0115U', 'PLA',         'Roche (GenMark) ePlex RP',                     20, 20, 'BROAD_MULTIPLEX',      'Broad competitor'),
    ('0556U', 'PLA',         'HealthTrackRx (Thermo Fisher)',                12, 12, 'BROAD_MULTIPLEX',      'Broad competitor'),
    ('87633', 'GENERIC_CPT', 'Respiratory panel, 12-25 targets',             12, 25, 'BROAD_MULTIPLEX',      'Generic code'),
    ('87632', 'GENERIC_CPT', 'Respiratory panel, 6-11 targets',               6, 11, 'INTERMEDIATE_PANEL',   'Targeted substitute'),
    ('87631', 'GENERIC_CPT', 'Respiratory panel, 3-5 targets',                3,  5, 'SMALL_TARGETED_PANEL', 'Targeted substitute'),
    ('87637', 'GENERIC_CPT', 'SARS-CoV-2 + flu A/B + RSV PCR',                4,  4, 'SMALL_TARGETED_PANEL', 'Targeted substitute'),
    ('87636', 'GENERIC_CPT', 'SARS-CoV-2 + flu A/B PCR',                      3,  3, 'SMALL_TARGETED_PANEL', 'Targeted substitute'),
    ('87812', 'GENERIC_CPT', 'SARS-CoV-2 + flu A/B antigen',                  3,  3, 'ANTIGEN',              'Targeted substitute')
) AS m(hcpcs_code, code_type, test_configuration, minimum_targets, maximum_targets,
       panel_size_category, competitive_role);

-- Every mapped code must have exactly one unmodified national rate.
SELECT
    COUNT(*) AS mapped_codes,
    COUNT(f.hcpcs_code) AS codes_with_rate,
    CASE WHEN COUNT(*) = COUNT(f.hcpcs_code) THEN 'PASS' ELSE 'REVIEW' END AS code_map_status
FROM reference.respiratory_code_map AS m
LEFT JOIN reference.cms_clfs AS f
    ON m.hcpcs_code = f.hcpcs_code AND f.modifier IS NULL;
