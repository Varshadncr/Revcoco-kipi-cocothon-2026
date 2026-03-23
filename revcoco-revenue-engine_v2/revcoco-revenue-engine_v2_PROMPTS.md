# RevCOCO Revenue Engine V2 — Prompts

## Phase 2: V2 — Ensemble ML with Hard Voting

### Prompt 15 — V2 Setup & 3 Cortex ML Models
> Create a V2 version with a separate database KIPI_REVCOCO_V2. Same data setup but copy receivables_history from V1. Same dynamic table. But now train 3 separate Cortex ML classification models: Model 1 (base features — invoice_amount, past_dso_avg), Model 2 (add categorical features — amount_bucket LOW/MEDIUM/HIGH/VERY_HIGH, payer_category FAST/AVERAGE/SLOW, high_risk_combo flag), Model 3 (math transforms — log amount, amount_per_dso_day ratio, dso_squared_scaled, amount_normalized).

### Prompt 16 — Ensemble Hard Voting View
> Create an ensemble view (at_risk_ensemble) that runs all 3 models on each receivable and does hard voting — majority wins (2+ votes for late = at-risk). Show individual model predictions, votes_for_late count, ensemble_prediction, and ensemble_avg_probability. Also create a backward-compatible at_risk_receivables view that maps to the ensemble output.

### Prompt 17 — Ensemble Validation
> Create a validation view (ensemble_validation) that samples 10K rows from receivables_history, runs all 3 models, and calculates individual model accuracy and ensemble accuracy.

### Prompt 18 — V2 Streamlit Dashboard
> Create a V2 Streamlit dashboard with 4 tabs: Dashboard (same KPIs + billing table), Ensemble Analysis (explanation of hard voting, vote distribution chart, model agreement chart), Model Comparison (V1 single model accuracy vs V2 ensemble accuracy, individual model metrics tabs), and Detailed Predictions (full table with all model predictions and probabilities).
