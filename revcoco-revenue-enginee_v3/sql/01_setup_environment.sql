-- ============================================================
-- STEP 1: ENVIRONMENT SETUP FOR V3 ML MODEL COMPARISON
-- Uses standard XGBoost, Logistic Regression, and kNN
-- ============================================================

USE DATABASE KIPI_REVCOCO;
USE SCHEMA MVP;

SELECT COUNT(*) AS total_rows,
       COUNT_IF(is_late) AS late_count,
       COUNT_IF(NOT is_late) AS not_late_count,
       ROUND(COUNT_IF(is_late) * 100.0 / COUNT(*), 2) AS late_pct
FROM receivables_history;

CREATE OR REPLACE VIEW ml_training_sample_v3 AS
SELECT
    invoice_amount,
    past_dso_avg,
    is_late
FROM receivables_history
SAMPLE (100000 ROWS);

SELECT * FROM ml_training_sample_v3 LIMIT 10;
