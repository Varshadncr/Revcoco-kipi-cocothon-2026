-- ============================================================
-- STEP 1: SETUP ENVIRONMENT & MOCK DATA
-- RevCOCO Native Revenue Engine
-- ============================================================

-- 1. Create Database and Schema
CREATE DATABASE IF NOT EXISTS KIPI_REVCOCO;
USE DATABASE KIPI_REVCOCO;
CREATE SCHEMA IF NOT EXISTS MVP;
USE SCHEMA MVP;

-- 2. Create Contracts Table (The Pricing Source of Truth)
CREATE OR REPLACE TABLE contracts (
    client_id VARCHAR,
    client_name VARCHAR,
    print_rate FLOAT,
    digital_rate FLOAT,
    contract_start_date DATE
);

INSERT INTO contracts VALUES 
    ('C001', 'Acme Corp', 0.15, 0.05, '2025-01-01'),
    ('C002', 'Global Tech', 0.12, 0.04, '2025-02-01'),
    ('C003', 'Local Bank', 0.18, 0.06, '2024-06-01');

-- 3. Create Production Logs (The Disconnected Events)
CREATE OR REPLACE TABLE production_logs (
    event_id VARCHAR DEFAULT UUID_STRING(),
    client_id VARCHAR,
    event_type VARCHAR, -- 'PRINT' or 'DIGITAL'
    quantity INT,
    event_timestamp TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- Insert mock production data
INSERT INTO production_logs (client_id, event_type, quantity, event_timestamp) VALUES 
    ('C001', 'PRINT', 10000, DATEADD(day, -2, CURRENT_TIMESTAMP())),
    ('C001', 'DIGITAL', 50000, DATEADD(day, -1, CURRENT_TIMESTAMP())),
    ('C002', 'PRINT', 5000, CURRENT_TIMESTAMP()),
    ('C003', 'DIGITAL', 100000, CURRENT_TIMESTAMP());

-- 4. Create Historical Receivables (For Cortex ML Training)
CREATE OR REPLACE TABLE receivables_history (
    invoice_id VARCHAR,
    client_id VARCHAR,
    invoice_amount FLOAT,
    days_to_pay INT,
    past_dso_avg INT,
    is_late BOOLEAN
);

-- Insert synthetic training data
INSERT INTO receivables_history VALUES 
    ('INV-100', 'C001', 1500.00, 15, 16, FALSE),
    ('INV-101', 'C001', 2500.00, 20, 16, FALSE),
    ('INV-102', 'C002', 800.00,  28, 25, FALSE),
    ('INV-103', 'C003', 6000.00, 45, 40, TRUE),
    ('INV-104', 'C003', 7500.00, 50, 40, TRUE),
    ('INV-105', 'C002', 5000.00, 35, 25, TRUE);

-- Verify setup
SELECT 'contracts' as table_name, COUNT(*) as row_count FROM contracts
UNION ALL SELECT 'production_logs', COUNT(*) FROM production_logs
UNION ALL SELECT 'receivables_history', COUNT(*) FROM receivables_history;
