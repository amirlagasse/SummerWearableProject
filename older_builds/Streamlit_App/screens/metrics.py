import streamlit as st
import pandas as pd
import os
from datetime import date, datetime
import altair as alt

def render():
    st.title("📈 Heart Rate Metrics")
    log_path = f"data/hr_log_{date.today().isoformat()}.csv"

    if not os.path.exists(log_path):
        st.warning("No heart rate log for today.")
        return

    bpm_values = []
    with open(log_path, "r") as f:
        for line in f:
            try:
                t_str, bpm = line.strip().split(",")
                bpm_values.append((datetime.fromisoformat(t_str), int(bpm)))
            except:
                continue

    if not bpm_values:
        st.error("No valid HR data.")
        return

    df = pd.DataFrame(bpm_values, columns=["timestamp", "bpm"])
    df["seconds"] = (df["timestamp"] - df["timestamp"].iloc[0]).dt.total_seconds()

    chart = alt.Chart(df).mark_line(color="crimson").encode(
        x="seconds", y="bpm"
    ).properties(width=700, height=300)
    st.altair_chart(chart)

    st.metric("Total readings", len(df))
    st.metric("Average HR", f"{df['bpm'].mean():.1f} BPM")
    st.metric("Max HR", f"{df['bpm'].max()} BPM")
    st.metric("Resting HR", f"{df['bpm'].min()} BPM")
    st.metric("Training Load (HR > 130)", sum(df["bpm"] > 130))
