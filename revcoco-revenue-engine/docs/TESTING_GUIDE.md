# RevCOCO Revenue Engine - Testing Guide

## Quick Validation (Run This First)

```sql
-- Quick health check - run in Snowflake
SELECT 
    (SELECT COUNT(*) FROM KIPI_REVCOCO.MVP.ready_to_bill) AS ready_to_bill_records,
    (SELECT COUNT(*) FROM KIPI_REVCOCO.MVP.production_logs) AS production_logs,
    (SELECT COUNT(*) FROM KIPI_REVCOCO.MVP.at_risk_receivables WHERE risk_status = 'True') AS at_risk_count,
    (SELECT SUM(billable_amount) FROM KIPI_REVCOCO.MVP.ready_to_bill) AS total_billable;
```

---

## Test Suite Overview

| Test | What It Checks | Pass Criteria |
|------|----------------|---------------|
| 1 | Duplicate Contracts | 0 duplicates |
| 2 | Unmatched Production Logs | 0 orphaned logs |
| 3 | Billable Amount Calculation | Math is correct |
| 4 | ML Predictions Generated | No null predictions |
| 5 | Risk Score Validity | All scores 0-1 |
| 6 | Dynamic Table Freshness | < 5 min old |

---

## Test 1: Dynamic Table Reconciliation

### What to check:
Every production log should appear in ready_to_bill with correct pricing.

```sql
-- Check: Production logs match ready_to_bill count
SELECT 
    'Production Logs' AS source, COUNT(*) AS cnt FROM KIPI_REVCOCO.MVP.production_logs
UNION ALL
SELECT 'Ready-to-Bill', COUNT(*) FROM KIPI_REVCOCO.MVP.ready_to_bill;

-- Expected: Counts should be equal (or ready_to_bill slightly higher due to refresh timing)
```

### What to check:
Billable amount = quantity × rate

```sql
-- Verify calculation accuracy
SELECT client_name, event_type, quantity, unit_rate, billable_amount,
       quantity * unit_rate AS expected,
       CASE WHEN ABS(billable_amount - quantity * unit_rate) < 0.01 THEN 'OK' ELSE 'ERROR' END AS check
FROM KIPI_REVCOCO.MVP.ready_to_bill
LIMIT 20;
```

---

## Test 2: ML Model Accuracy

### Check model metrics:
```sql
CALL KIPI_REVCOCO.MVP.at_risk_receivable_model!SHOW_EVALUATION_METRICS();
```

**Expected:** Precision > 80%, Recall > 80%

### Check predictions are reasonable:
```sql
-- High-risk clients should have high DSO history
SELECT client_name, 
       AVG(past_dso_avg) AS avg_dso,
       AVG(risk_probability) AS avg_risk,
       COUNT(*) AS invoice_count
FROM KIPI_REVCOCO.MVP.at_risk_receivables
GROUP BY client_name
ORDER BY avg_risk DESC
LIMIT 10;

-- Clients with high historical DSO should have high risk scores
```

### Validate prediction distribution:
```sql
-- Risk distribution should be reasonable
SELECT 
    CASE 
        WHEN risk_probability < 0.3 THEN 'Low Risk (<30%)'
        WHEN risk_probability < 0.7 THEN 'Medium Risk (30-70%)'
        ELSE 'High Risk (>70%)'
    END AS risk_bucket,
    COUNT(*) AS count,
    ROUND(AVG(invoice_amount), 2) AS avg_amount
FROM KIPI_REVCOCO.MVP.at_risk_receivables
GROUP BY risk_bucket
ORDER BY risk_bucket;
```

---

## Test 3: End-to-End Flow

### Insert new production event and verify it flows through:

```sql
-- Step 1: Insert new event
INSERT INTO KIPI_REVCOCO.MVP.production_logs (client_id, event_type, quantity) 
VALUES ('C001', 'PRINT', 99999);

-- Step 2: Wait 1 minute for Dynamic Table refresh

-- Step 3: Verify it appears in ready_to_bill
SELECT * FROM KIPI_REVCOCO.MVP.ready_to_bill 
WHERE quantity = 99999;

-- Step 4: Verify it has ML prediction
SELECT * FROM KIPI_REVCOCO.MVP.at_risk_receivables 
WHERE invoice_id IN (SELECT event_id FROM KIPI_REVCOCO.MVP.ready_to_bill WHERE quantity = 99999);

-- Cleanup
DELETE FROM KIPI_REVCOCO.MVP.production_logs WHERE quantity = 99999;
```

---

## Test 4: Data Integrity

### Check for orphaned records:
```sql
-- Production logs without contracts (revenue leakage!)
SELECT p.client_id, COUNT(*) AS orphaned_count
FROM KIPI_REVCOCO.MVP.production_logs p
LEFT JOIN KIPI_REVCOCO.MVP.contracts c ON p.client_id = c.client_id
WHERE c.client_id IS NULL
GROUP BY p.client_id;

-- Expected: 0 rows (all logs have contracts)
```

### Check for duplicate contracts:
```sql
-- Duplicate client_ids cause over-billing
SELECT client_id, COUNT(*) AS duplicates
FROM KIPI_REVCOCO.MVP.contracts
GROUP BY client_id
HAVING COUNT(*) > 1;

-- Expected: 0 rows
```

---

## Test 5: Dynamic Table Health

```sql
-- Check refresh history
SELECT 
    refresh_action,
    state,
    refresh_action_start_time,
    refresh_action_end_time,
    TIMESTAMPDIFF('second', refresh_action_start_time, refresh_action_end_time) AS duration_sec
FROM TABLE(INFORMATION_SCHEMA.DYNAMIC_TABLE_REFRESH_HISTORY(NAME => 'KIPI_REVCOCO.MVP.READY_TO_BILL'))
ORDER BY refresh_action_start_time DESC
LIMIT 5;
```

---

## Common Issues & Fixes

| Issue | Symptom | Fix |
|-------|---------|-----|
| Duplicate contracts | Ready-to-bill has more rows than production_logs | Run `06_data_quality_fix.sql` |
| Missing contracts | Some production logs not appearing in ready_to_bill | Add missing contracts |
| Stale data | Dynamic table not refreshing | `ALTER DYNAMIC TABLE ready_to_bill REFRESH;` |
| ML predictions null | at_risk_receivables has null risk_status | Retrain model |

---

## Automated Test Script

Run the full test suite:
```bash
snowsql -f sql/05_validation_tests.sql
```

Fix data issues:
```bash
snowsql -f sql/06_data_quality_fix.sql
```

---

## Success Criteria

✅ **All tests pass**
✅ **Production logs = Ready-to-Bill count**  
✅ **ML precision > 80%**
✅ **No orphaned records**
✅ **Dynamic table refreshing every 1 min**
