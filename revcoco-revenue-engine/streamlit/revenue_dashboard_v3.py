import streamlit as st
from snowflake.snowpark.context import get_active_session

st.set_page_config(page_title="RevCOCO Revenue Engine", layout="wide")
session = get_active_session()

st.title("🚀 RevCOCO Native Revenue Engine")
st.markdown("**Real-time Order-to-Cash Automation & AR Risk Intelligence**")

# KPI Header
col1, col2, col3, col4 = st.columns(4)
rtb_df = session.sql("SELECT COUNT(*) as cnt, SUM(billable_amount) as total FROM KIPI_REVCOCO.MVP.ready_to_bill").to_pandas()
risk_df = session.sql("SELECT COUNT(*) as cnt, COALESCE(SUM(invoice_amount), 0) as total FROM KIPI_REVCOCO.MVP.at_risk_receivables WHERE risk_status = 'True'").to_pandas()

col1.metric("📋 Ready-to-Bill", f"{int(rtb_df['CNT'][0]):,}")
col2.metric("💰 Total Billable", f"${rtb_df['TOTAL'][0]/1e9:.2f}B")
col3.metric("⚠️ At-Risk Invoices", f"{int(risk_df['CNT'][0]):,}")
col4.metric("🔴 At-Risk Amount", f"${risk_df['TOTAL'][0]/1e9:.2f}B")

st.divider()

# Main Tabs
tab1, tab2, tab3, tab4, tab5 = st.tabs([
    "📊 Ready-to-Bill", 
    "⚠️ At-Risk", 
    "📈 Revenue Analytics",
    "🎯 Risk Analytics",
    "🏆 Client Intelligence"
])

# TAB 1: Ready-to-Bill
with tab1:
    st.subheader("Ready-to-Bill Records (Auto-Reconciled)")
    rtb_data = session.sql("""
        SELECT client_name, event_type, quantity, unit_rate, billable_amount, event_timestamp
        FROM KIPI_REVCOCO.MVP.ready_to_bill ORDER BY event_timestamp DESC LIMIT 100
    """).to_pandas()
    st.dataframe(rtb_data, use_container_width=True, height=400)

# TAB 2: At-Risk
with tab2:
    st.subheader("At-Risk Receivables (ML Predictions)")
    at_risk_data = session.sql("""
        SELECT client_name, invoice_amount, past_dso_avg, risk_status, ROUND(risk_probability * 100, 1) as risk_pct
        FROM KIPI_REVCOCO.MVP.at_risk_receivables ORDER BY risk_probability DESC LIMIT 100
    """).to_pandas()
    st.dataframe(at_risk_data, use_container_width=True, height=400)

# TAB 3: Revenue Analytics
with tab3:
    st.subheader("📈 Revenue Analytics")
    
    # Row 1
    col_a, col_b = st.columns(2)
    with col_a:
        st.markdown("##### 📅 Monthly Revenue Trend")
        trend = session.sql("""
            SELECT DATE_TRUNC('MONTH', event_timestamp) as month, SUM(billable_amount)/1e9 as revenue_b
            FROM KIPI_REVCOCO.MVP.ready_to_bill GROUP BY month ORDER BY month
        """).to_pandas()
        st.line_chart(trend.set_index('MONTH'))
    
    with col_b:
        st.markdown("##### 📊 Revenue by Event Type")
        by_type = session.sql("""
            SELECT event_type, ROUND(SUM(billable_amount)/1e9, 2) as revenue_billions
            FROM KIPI_REVCOCO.MVP.ready_to_bill GROUP BY event_type
        """).to_pandas()
        st.bar_chart(by_type.set_index('EVENT_TYPE'))
    
    # Row 2
    col_c, col_d = st.columns(2)
    with col_c:
        st.markdown("##### 🏢 Top 10 Clients")
        top_clients = session.sql("""
            SELECT client_name, ROUND(SUM(billable_amount)/1e6, 1) as revenue_m
            FROM KIPI_REVCOCO.MVP.ready_to_bill GROUP BY client_name ORDER BY revenue_m DESC LIMIT 10
        """).to_pandas()
        st.bar_chart(top_clients.set_index('CLIENT_NAME'))
    
    with col_d:
        st.markdown("##### 💎 Rate Tier Analysis")
        rate_tiers = session.sql("""
            SELECT 
                CASE WHEN unit_rate <= 0.10 THEN '1. Low (≤$0.10)'
                     WHEN unit_rate <= 0.15 THEN '2. Mid ($0.10-$0.15)'
                     ELSE '3. Premium (>$0.15)' END as rate_tier,
                COUNT(*) as txn_count,
                ROUND(SUM(billable_amount)/1e9, 2) as revenue_b
            FROM KIPI_REVCOCO.MVP.ready_to_bill GROUP BY rate_tier ORDER BY rate_tier
        """).to_pandas()
        st.dataframe(rate_tiers, use_container_width=True)
    
    # Row 3
    col_e, col_f = st.columns(2)
    with col_e:
        st.markdown("##### 📆 Day of Week Pattern")
        dow = session.sql("""
            SELECT DAYNAME(event_timestamp) as day, DAYOFWEEK(event_timestamp) as num,
                   ROUND(SUM(billable_amount)/1e6, 0) as revenue_m
            FROM KIPI_REVCOCO.MVP.ready_to_bill GROUP BY day, num ORDER BY num
        """).to_pandas()
        st.bar_chart(dow.set_index('DAY')['REVENUE_M'])
    
    with col_f:
        st.markdown("##### 🎪 Revenue Concentration")
        pareto = session.sql("""
            WITH ranked AS (
                SELECT client_name, SUM(billable_amount) as rev, 
                       ROW_NUMBER() OVER (ORDER BY SUM(billable_amount) DESC) as rn
                FROM KIPI_REVCOCO.MVP.ready_to_bill GROUP BY client_name
            )
            SELECT 
                'Top 10 Clients' as segment,
                ROUND(SUM(rev)*100/(SELECT SUM(billable_amount) FROM KIPI_REVCOCO.MVP.ready_to_bill), 1) as pct
            FROM ranked WHERE rn <= 10
            UNION ALL
            SELECT 'Top 20 Clients', ROUND(SUM(rev)*100/(SELECT SUM(billable_amount) FROM KIPI_REVCOCO.MVP.ready_to_bill), 1)
            FROM ranked WHERE rn <= 20
        """).to_pandas()
        for _, row in pareto.iterrows():
            st.metric(row['SEGMENT'], f"{row['PCT']}% of Revenue")

# TAB 4: Risk Analytics
with tab4:
    st.subheader("🎯 Risk Analytics")
    
    # Row 1
    col_a, col_b = st.columns(2)
    with col_a:
        st.markdown("##### 🚦 Risk Distribution")
        risk_dist = session.sql("""
            SELECT 
                CASE WHEN risk_probability < 0.3 THEN '🟢 Low Risk'
                     WHEN risk_probability < 0.6 THEN '🟡 Medium Risk'
                     ELSE '🔴 High Risk' END as risk_level,
                COUNT(*) as invoices,
                ROUND(SUM(invoice_amount)/1e9, 2) as amount_b
            FROM KIPI_REVCOCO.MVP.at_risk_receivables GROUP BY risk_level ORDER BY risk_level
        """).to_pandas()
        st.dataframe(risk_dist, use_container_width=True)
    
    with col_b:
        st.markdown("##### ⏱️ Expected Collection Timeline")
        timeline = session.sql("""
            SELECT 
                CASE WHEN past_dso_avg < 15 THEN '1. 0-15 days'
                     WHEN past_dso_avg < 30 THEN '2. 15-30 days'
                     WHEN past_dso_avg < 45 THEN '3. 30-45 days'
                     ELSE '4. 45+ days' END as collection_window,
                COUNT(*) as invoices,
                ROUND(SUM(invoice_amount)/1e9, 2) as amount_b
            FROM KIPI_REVCOCO.MVP.at_risk_receivables GROUP BY collection_window ORDER BY collection_window
        """).to_pandas()
        st.dataframe(timeline, use_container_width=True)
    
    # Row 2
    col_c, col_d = st.columns(2)
    with col_c:
        st.markdown("##### 📊 Risk Probability Histogram")
        histogram = session.sql("""
            SELECT CONCAT(FLOOR(risk_probability*10)*10, '-', FLOOR(risk_probability*10)*10+10, '%') as bucket,
                   COUNT(*) as count
            FROM KIPI_REVCOCO.MVP.at_risk_receivables GROUP BY bucket ORDER BY bucket
        """).to_pandas()
        st.bar_chart(histogram.set_index('BUCKET'))
    
    with col_d:
        st.markdown("##### ⚠️ Highest Risk Clients")
        high_risk = session.sql("""
            SELECT client_name, COUNT(*) as at_risk_invoices,
                   ROUND(SUM(invoice_amount)/1e6, 1) as at_risk_m,
                   ROUND(AVG(risk_probability)*100, 0) as avg_risk_pct
            FROM KIPI_REVCOCO.MVP.at_risk_receivables WHERE risk_status = 'True'
            GROUP BY client_name ORDER BY at_risk_m DESC LIMIT 10
        """).to_pandas()
        st.dataframe(high_risk, use_container_width=True)
    
    # Row 3: Risk Summary
    st.markdown("##### 📋 Risk Summary")
    risk_summary = session.sql("""
        SELECT 
            COUNT(*) as total_invoices,
            SUM(CASE WHEN risk_status = 'True' THEN 1 ELSE 0 END) as at_risk_count,
            ROUND(100.0 * SUM(CASE WHEN risk_status = 'True' THEN 1 ELSE 0 END) / COUNT(*), 1) as at_risk_pct,
            ROUND(SUM(CASE WHEN risk_status = 'True' THEN invoice_amount ELSE 0 END)/1e9, 2) as at_risk_billions,
            ROUND(AVG(risk_probability)*100, 1) as avg_risk_score
        FROM KIPI_REVCOCO.MVP.at_risk_receivables
    """).to_pandas()
    
    m1, m2, m3, m4 = st.columns(4)
    m1.metric("Total Invoices", f"{int(risk_summary['TOTAL_INVOICES'][0]):,}")
    m2.metric("At-Risk Count", f"{int(risk_summary['AT_RISK_COUNT'][0]):,}")
    m3.metric("At-Risk %", f"{risk_summary['AT_RISK_PCT'][0]}%")
    m4.metric("Avg Risk Score", f"{risk_summary['AVG_RISK_SCORE'][0]}%")

# TAB 5: Client Intelligence
with tab5:
    st.subheader("🏆 Client Intelligence")
    
    # Row 1
    col_a, col_b = st.columns(2)
    with col_a:
        st.markdown("##### 🎖️ Client Tiers")
        tiers = session.sql("""
            SELECT 
                CASE WHEN revenue >= 500000000 THEN '🏆 Platinum'
                     WHEN revenue >= 200000000 THEN '🥇 Gold'
                     WHEN revenue >= 100000000 THEN '🥈 Silver'
                     ELSE '🥉 Bronze' END as tier,
                COUNT(*) as clients,
                ROUND(SUM(revenue)/1e9, 2) as revenue_b
            FROM (SELECT client_name, SUM(billable_amount) as revenue 
                  FROM KIPI_REVCOCO.MVP.ready_to_bill GROUP BY client_name)
            GROUP BY tier ORDER BY revenue_b DESC
        """).to_pandas()
        st.dataframe(tiers, use_container_width=True)
    
    with col_b:
        st.markdown("##### 💚 Client Health Score")
        health = session.sql("""
            SELECT 
                CASE WHEN avg_risk < 0.3 THEN '🟢 Healthy'
                     WHEN avg_risk < 0.5 THEN '🟡 Monitor'
                     ELSE '🔴 At Risk' END as health,
                COUNT(*) as clients,
                ROUND(SUM(revenue)/1e9, 2) as revenue_b
            FROM (
                SELECT b.client_name, SUM(b.billable_amount) as revenue, AVG(r.risk_probability) as avg_risk
                FROM KIPI_REVCOCO.MVP.ready_to_bill b
                JOIN KIPI_REVCOCO.MVP.at_risk_receivables r ON b.event_id = r.invoice_id
                GROUP BY b.client_name
            ) GROUP BY health ORDER BY revenue_b DESC
        """).to_pandas()
        st.dataframe(health, use_container_width=True)
    
    # Row 2
    st.markdown("##### 📋 Client Detail View")
    client_list = session.sql("SELECT DISTINCT client_name FROM KIPI_REVCOCO.MVP.ready_to_bill ORDER BY client_name").to_pandas()
    selected_client = st.selectbox("Select Client", client_list['CLIENT_NAME'].tolist())
    
    if selected_client:
        client_detail = session.sql(f"""
            SELECT 
                b.client_name,
                COUNT(*) as transactions,
                SUM(CASE WHEN event_type = 'PRINT' THEN 1 ELSE 0 END) as print_txn,
                SUM(CASE WHEN event_type = 'DIGITAL' THEN 1 ELSE 0 END) as digital_txn,
                ROUND(SUM(billable_amount)/1e6, 2) as revenue_millions,
                ROUND(AVG(r.risk_probability)*100, 1) as avg_risk_pct,
                SUM(CASE WHEN r.risk_status = 'True' THEN 1 ELSE 0 END) as at_risk_invoices
            FROM KIPI_REVCOCO.MVP.ready_to_bill b
            JOIN KIPI_REVCOCO.MVP.at_risk_receivables r ON b.event_id = r.invoice_id
            WHERE b.client_name = '{selected_client}'
            GROUP BY b.client_name
        """).to_pandas()
        
        c1, c2, c3, c4 = st.columns(4)
        c1.metric("Total Transactions", f"{int(client_detail['TRANSACTIONS'][0]):,}")
        c2.metric("Revenue", f"${client_detail['REVENUE_MILLIONS'][0]}M")
        c3.metric("Avg Risk", f"{client_detail['AVG_RISK_PCT'][0]}%")
        c4.metric("At-Risk Invoices", f"{int(client_detail['AT_RISK_INVOICES'][0]):,}")
        
        # Client monthly trend
        st.markdown(f"##### 📈 {selected_client} - Monthly Trend")
        client_trend = session.sql(f"""
            SELECT DATE_TRUNC('MONTH', event_timestamp) as month, 
                   ROUND(SUM(billable_amount)/1e6, 2) as revenue_m
            FROM KIPI_REVCOCO.MVP.ready_to_bill 
            WHERE client_name = '{selected_client}'
            GROUP BY month ORDER BY month
        """).to_pandas()
        st.line_chart(client_trend.set_index('MONTH'))

st.divider()
st.caption("Powered by Snowflake Dynamic Tables & Cortex ML | Real-time data refresh every 1 minute")
