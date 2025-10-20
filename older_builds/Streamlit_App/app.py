# app.py

import streamlit as st
from screens import dashboard, metrics, workout_log, settings
from utils.graph_utils import save_sleep_graph

st.set_page_config(layout="wide", page_title="Wearable Dashboard")

save_sleep_graph()

page = st.sidebar.selectbox("📱 Navigation", [
    "📊 Dashboard",
    "📈 Metrics",
    "📝 Workout Log",
    "⚙️ Settings"
])

if page == "📊 Dashboard":
    dashboard.render()
elif page == "📈 Metrics":
    metrics.render()
elif page == "📝 Workout Log":
    workout_log.render()
elif page == "⚙️ Settings":
    settings.render()
