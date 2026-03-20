-- ============================================================
-- REVCOCO ADVANCED ANALYTICS QUERIES
-- Copy these into your Streamlit dashboard
-- ============================================================

-- ============================================================
-- 1. EXECUTIVE SUMMARY METRICS
-- ============================================================

-- Daily Revenue Pulse
SELECT 
    DATE(event_timestamp) as date,
    COUNT(*) as transactions,
    SUM(billable_amount) as daily_revenue,
    AVG(billable_amount) as avg_transaction
FROM KIPI_REVCOCO.MVP.ready_to_bill
WHERE event_timestamp >= DATEADD('day', -30, CURRENT_DATE())
GROUP BY date
ORDER BY date;

-- Week-over-Week Growth
SELECT 
    'This Week' as period,
    SUM(billable_amount) as revenue,
    COUNT(*) as transactions
FROM KIPI_REVCOCO.MVP.ready_to_bill
WHERE event_timestamp >= DATE_TRUNC('week', CURRENT_DATE())
UNION ALL
SELECT 
    'Last Week',
    SUM(billable_amount),
    COUNT(*)
FROM KIPI_REVCOCO.MVP.ready_to_bill
WHERE event_timestamp >= DATEADD('week', -1, DATE_TRUNC('week', CURRENT_DATE()))
  AND event_timestamp < DATE_TRUNC('week', CURRENT_DATE());

-- ============================================================
-- 2. CLIENT SEGMENTATION (RFM-Style)
-- ============================================================

-- Client Tiers by Revenue
SELECT 
    CASE 
        WHEN revenue >= 500000000 THEN '🏆 Platinum'
        WHEN revenue >= 200000000 THEN '🥇 Gold'
        WHEN revenue >= 100000000 THEN '🥈 Silver'
        ELSE '🥉 Bronze'
    END as client_tier,
    COUNT(*) as client_count,
    ROUND(SUM(revenue)/1000000000, 2) as total_revenue_billions,
    ROUND(AVG(revenue)/1000000, 1) as avg_revenue_millions
FROM (
    SELECT client_id, client_name, SUM(billable_amount) as revenue
    FROM KIPI_REVCOCO.MVP.ready_to_bill
    GROUP BY client_id, client_name
)
GROUP BY client_tier
ORDER BY total_revenue_billions DESC;

-- Client Health Score
SELECT 
    client_name,
    ROUND(SUM(billable_amount)/1000000, 2) as revenue_millions,
    COUNT(*) as transaction_count,
    ROUND(AVG(CASE WHEN r.risk_status = 'True' THEN 1 ELSE 0 END) * 100, 1) as pct_at_risk,
    CASE 
        WHEN AVG(CASE WHEN r.risk_status = 'True' THEN 1 ELSE 0 END) < 0.2 THEN '🟢 Healthy'
        WHEN AVG(CASE WHEN r.risk_status = 'True' THEN 1 ELSE 0 END) < 0.5 THEN '🟡 Monitor'
        ELSE '🔴 At Risk'
    END as health_status
FROM KIPI_REVCOCO.MVP.ready_to_bill b
JOIN KIPI_REVCOCO.MVP.at_risk_receivables r ON b.event_id = r.invoice_id
GROUP BY client_name
ORDER BY revenue_millions DESC
LIMIT 15;

-- ============================================================
-- 3. REVENUE COMPOSITION ANALYSIS
-- ============================================================

-- Print vs Digital Deep Dive
SELECT 
    event_type,
    COUNT(*) as transactions,
    ROUND(SUM(quantity)/1000000, 1) as total_quantity_millions,
    ROUND(SUM(billable_amount)/1000000000, 2) as revenue_billions,
    ROUND(AVG(unit_rate), 3) as avg_rate,
    ROUND(MIN(unit_rate), 3) as min_rate,
    ROUND(MAX(unit_rate), 3) as max_rate,
    ROUND(AVG(quantity), 0) as avg_quantity_per_txn
FROM KIPI_REVCOCO.MVP.ready_to_bill
GROUP BY event_type;

-- Revenue by Rate Tier
SELECT 
    event_type,
    CASE 
        WHEN unit_rate <= 0.10 THEN 'Low Rate (≤$0.10)'
        WHEN unit_rate <= 0.15 THEN 'Mid Rate ($0.10-$0.15)'
        ELSE 'Premium Rate (>$0.15)'
    END as rate_tier,
    COUNT(*) as transactions,
    ROUND(SUM(billable_amount)/1000000, 1) as revenue_millions
FROM KIPI_REVCOCO.MVP.ready_to_bill
GROUP BY event_type, rate_tier
ORDER BY event_type, rate_tier;

-- ============================================================
-- 4. TIME-BASED ANALYTICS
-- ============================================================

-- Hourly Distribution (Peak Hours)
SELECT 
    HOUR(event_timestamp) as hour_of_day,
    COUNT(*) as transactions,
    ROUND(SUM(billable_amount)/1000000, 1) as revenue_millions
FROM KIPI_REVCOCO.MVP.ready_to_bill
GROUP BY hour_of_day
ORDER BY hour_of_day;

-- Day of Week Pattern
SELECT 
    DAYNAME(event_timestamp) as day_of_week,
    DAYOFWEEK(event_timestamp) as day_num,
    COUNT(*) as transactions,
    ROUND(SUM(billable_amount)/1000000, 1) as revenue_millions
FROM KIPI_REVCOCO.MVP.ready_to_bill
GROUP BY day_of_week, day_num
ORDER BY day_num;

-- Monthly Year-over-Year
SELECT 
    YEAR(event_timestamp) as year,
    MONTH(event_timestamp) as month,
    MONTHNAME(event_timestamp) as month_name,
    ROUND(SUM(billable_amount)/1000000000, 2) as revenue_billions,
    COUNT(*) as transactions
FROM KIPI_REVCOCO.MVP.ready_to_bill
GROUP BY year, month, month_name
ORDER BY year, month;

-- ============================================================
-- 5. RISK ANALYTICS
-- ============================================================

-- Risk Heatmap Data (Client x Risk Level)
SELECT 
    client_name,
    SUM(CASE WHEN risk_probability < 0.3 THEN invoice_amount ELSE 0 END) as low_risk_amount,
    SUM(CASE WHEN risk_probability >= 0.3 AND risk_probability < 0.6 THEN invoice_amount ELSE 0 END) as medium_risk_amount,
    SUM(CASE WHEN risk_probability >= 0.6 THEN invoice_amount ELSE 0 END) as high_risk_amount,
    ROUND(AVG(risk_probability) * 100, 1) as avg_risk_pct
FROM KIPI_REVCOCO.MVP.at_risk_receivables
GROUP BY client_name
ORDER BY high_risk_amount DESC
LIMIT 15;

-- Expected Collection Timeline
SELECT 
    CASE 
        WHEN past_dso_avg < 15 THEN '0-15 days'
        WHEN past_dso_avg < 30 THEN '15-30 days'
        WHEN past_dso_avg < 45 THEN '30-45 days'
        ELSE '45+ days'
    END as expected_collection,
    COUNT(*) as invoice_count,
    ROUND(SUM(invoice_amount)/1000000000, 2) as amount_billions,
    ROUND(AVG(risk_probability) * 100, 1) as avg_risk_pct
FROM KIPI_REVCOCO.MVP.at_risk_receivables
GROUP BY expected_collection
ORDER BY expected_collection;

-- Collection Probability Distribution
SELECT 
    FLOOR(risk_probability * 10) * 10 as risk_bucket_start,
    FLOOR(risk_probability * 10) * 10 + 10 as risk_bucket_end,
    COUNT(*) as invoice_count,
    ROUND(SUM(invoice_amount)/1000000, 1) as amount_millions
FROM KIPI_REVCOCO.MVP.at_risk_receivables
GROUP BY risk_bucket_start, risk_bucket_end
ORDER BY risk_bucket_start;

-- ============================================================
-- 6. PARETO ANALYSIS (80/20 Rule)
-- ============================================================

-- Top 20% Clients = X% Revenue
WITH client_revenue AS (
    SELECT 
        client_name,
        SUM(billable_amount) as revenue,
        ROW_NUMBER() OVER (ORDER BY SUM(billable_amount) DESC) as rank
    FROM KIPI_REVCOCO.MVP.ready_to_bill
    GROUP BY client_name
),
totals AS (
    SELECT 
        COUNT(*) as total_clients,
        SUM(revenue) as total_revenue
    FROM client_revenue
)
SELECT 
    ROUND(COUNT(*) * 100.0 / MAX(t.total_clients), 1) as pct_of_clients,
    ROUND(SUM(c.revenue) * 100.0 / MAX(t.total_revenue), 1) as pct_of_revenue,
    COUNT(*) as client_count,
    ROUND(SUM(c.revenue)/1000000000, 2) as revenue_billions
FROM client_revenue c, totals t
WHERE c.rank <= t.total_clients * 0.2;

-- ============================================================
-- 7. ANOMALY DETECTION
-- ============================================================

-- Unusually Large Transactions (>3 std dev)
WITH stats AS (
    SELECT 
        AVG(billable_amount) as avg_amount,
        STDDEV(billable_amount) as std_amount
    FROM KIPI_REVCOCO.MVP.ready_to_bill
)
SELECT 
    r.client_name,
    r.event_type,
    r.quantity,
    r.billable_amount,
    r.event_timestamp,
    ROUND((r.billable_amount - s.avg_amount) / s.std_amount, 2) as z_score
FROM KIPI_REVCOCO.MVP.ready_to_bill r, stats s
WHERE r.billable_amount > s.avg_amount + (3 * s.std_amount)
ORDER BY r.billable_amount DESC
LIMIT 20;

-- Clients with Sudden Revenue Spike
WITH monthly_revenue AS (
    SELECT 
        client_name,
        DATE_TRUNC('month', event_timestamp) as month,
        SUM(billable_amount) as revenue
    FROM KIPI_REVCOCO.MVP.ready_to_bill
    GROUP BY client_name, month
),
with_lag AS (
    SELECT 
        *,
        LAG(revenue) OVER (PARTITION BY client_name ORDER BY month) as prev_revenue
    FROM monthly_revenue
)
SELECT 
    client_name,
    month,
    ROUND(revenue/1000000, 2) as revenue_millions,
    ROUND(prev_revenue/1000000, 2) as prev_revenue_millions,
    ROUND((revenue - prev_revenue) / NULLIF(prev_revenue, 0) * 100, 1) as pct_change
FROM with_lag
WHERE prev_revenue > 0 AND (revenue - prev_revenue) / prev_revenue > 0.5
ORDER BY pct_change DESC
LIMIT 10;

-- ============================================================
-- 8. FORECASTING DATA (for trend lines)
-- ============================================================

-- 7-Day Moving Average
SELECT 
    DATE(event_timestamp) as date,
    SUM(billable_amount) as daily_revenue,
    AVG(SUM(billable_amount)) OVER (ORDER BY DATE(event_timestamp) ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) as moving_avg_7d
FROM KIPI_REVCOCO.MVP.ready_to_bill
GROUP BY date
ORDER BY date;

-- ============================================================
-- 9. OPERATIONAL METRICS
-- ============================================================

-- Billing Efficiency
SELECT 
    'Total Production Events' as metric, COUNT(*)::VARCHAR as value FROM KIPI_REVCOCO.MVP.production_logs
UNION ALL
SELECT 'Billed Events', COUNT(*)::VARCHAR FROM KIPI_REVCOCO.MVP.ready_to_bill
UNION ALL
SELECT 'Billing Rate', ROUND(100.0 * (SELECT COUNT(*) FROM KIPI_REVCOCO.MVP.ready_to_bill) / (SELECT COUNT(*) FROM KIPI_REVCOCO.MVP.production_logs), 2) || '%'
UNION ALL
SELECT 'Avg Processing Time', '< 1 minute (Dynamic Table)'
UNION ALL
SELECT 'Unique Clients Billed', (SELECT COUNT(DISTINCT client_id) FROM KIPI_REVCOCO.MVP.ready_to_bill)::VARCHAR;

-- ============================================================
-- 10. EXECUTIVE SCORECARD
-- ============================================================

SELECT 
    -- Revenue Metrics
    ROUND(SUM(billable_amount)/1000000000, 2) as total_revenue_billions,
    COUNT(*) as total_transactions,
    COUNT(DISTINCT client_id) as active_clients,
    ROUND(AVG(billable_amount), 2) as avg_transaction_value,
    
    -- Risk Metrics
    (SELECT COUNT(*) FROM KIPI_REVCOCO.MVP.at_risk_receivables WHERE risk_status = 'True') as at_risk_invoices,
    (SELECT ROUND(SUM(invoice_amount)/1000000000, 2) FROM KIPI_REVCOCO.MVP.at_risk_receivables WHERE risk_status = 'True') as at_risk_billions,
    
    -- Efficiency
    ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM KIPI_REVCOCO.MVP.production_logs), 2) as billing_capture_rate
    
FROM KIPI_REVCOCO.MVP.ready_to_bill;
