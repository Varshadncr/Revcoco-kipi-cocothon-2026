# RevCOCO Native Revenue Engine V2 - Ensemble Edition

A unified Native Revenue Engine with **Ensemble ML using Hard Voting** for improved prediction accuracy.

## What's New in V2

| Feature | V1 | V2 |
|---------|----|----|
| ML Approach | Single XGBoost model | 3 models + Hard Voting |
| Feature Engineering | 2 base features | Base + Categorical + Transforms |
| Prediction | Single model output | Majority vote (2/3 wins) |

## Ensemble Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    INPUT FEATURES                          │
│         (invoice_amount, past_dso_avg)                     │
└─────────────────────────────────────────────────────────────┘
                            │
         ┌──────────────────┼──────────────────┐
         ▼                  ▼                  ▼
┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐
│    MODEL 1      │ │    MODEL 2      │ │    MODEL 3      │
│  Base Features  │ │   Categorical   │ │  Transforms     │
│                 │ │   Buckets       │ │  (log, ratios)  │
│ invoice_amount  │ │ amount_bucket   │ │ log_amount      │
│ past_dso_avg    │ │ payer_category  │ │ amount_per_dso  │
│                 │ │ high_risk_combo │ │ dso_squared     │
└─────────────────┘ └─────────────────┘ └─────────────────┘
         │                  │                  │
         ▼                  ▼                  ▼
┌─────────────────────────────────────────────────────────────┐
│                    HARD VOTING                              │
│              If 2+ models predict "late" → AT RISK          │
└─────────────────────────────────────────────────────────────┘
```

## Quick Start

### 1. Setup Environment
```sql
-- Creates KIPI_REVCOCO_V2 database with same data as V1
snowsql -f sql/01_setup_environment.sql
```

### 2. Create Dynamic Tables
```sql
snowsql -f sql/02_dynamic_tables.sql
```

### 3. Train Ensemble Models
```sql
-- Trains 3 models with different feature engineering
snowsql -f sql/03_cortex_ml_ensemble.sql
```

### 4. Deploy Dashboard
```sql
snowsql -f sql/04_streamlit_deploy.sql
```

## Model Details

### Model 1: Base Features
- Same as V1 for baseline comparison
- Features: `invoice_amount`, `past_dso_avg`

### Model 2: Categorical Features
- Amount buckets: LOW/MEDIUM/HIGH/VERY_HIGH
- Payer categories: FAST/AVERAGE/SLOW
- High-risk combination flag

### Model 3: Mathematical Transforms
- Log transform of amount
- Amount per DSO day ratio
- Squared DSO (scaled)
- Normalized amount

## Comparing V1 vs V2

```sql
-- V1 Accuracy
SELECT * FROM KIPI_REVCOCO.MVP.at_risk_receivable_model!SHOW_CONFUSION_MATRIX();

-- V2 Ensemble Accuracy
SELECT * FROM KIPI_REVCOCO_V2.MVP.ensemble_validation;
```

## Project Structure

```
revcoco-revenue-engine_v2/
├── README.md
├── sql/
│   ├── 01_setup_environment.sql    # V2 database setup
│   ├── 02_dynamic_tables.sql       # Same as V1
│   ├── 03_cortex_ml_ensemble.sql   # 3 models + hard voting
│   └── 04_streamlit_deploy.sql     # Dashboard deployment
└── streamlit/
    └── revenue_dashboard_ensemble.py   # V2 dashboard with comparison
```

## License

MIT
