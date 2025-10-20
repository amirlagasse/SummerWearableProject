import streamlit as st
import asyncio
import os
from datetime import datetime
from ble.hr_monitor import HRMonitor
import nest_asyncio
nest_asyncio.apply()

# Session state defaults
for key, val in {
    "live_bpm": 0,
    "connected": False,
    "connecting": False,
    "monitor": None,
    "status": "not_connected"  # one of: not_connected, connecting, connected, failed
}.items():
    if key not in st.session_state:
        st.session_state[key] = val

# Log HR to CSV
def log_heart_rate(bpm):
    st.session_state.live_bpm = bpm
    timestamp = datetime.now()
    date_str = timestamp.date().isoformat()
    os.makedirs("data", exist_ok=True)
    with open(f"data/hr_log_{date_str}.csv", "a") as f:
        f.write(f"{timestamp.isoformat()},{bpm}\n")

# Render dashboard
def render():
    st.title("📊 Daily Dashboard")

    # Device info
    selected = HRMonitor._selected_address
    name = HRMonitor._selected_name
    st.write("🛰️ " + (
        f"Selected Device: {name} ({selected[:4]})" if selected and name else
        f"Selected Device: Unknown ({selected[:4]})" if selected else
        "No device selected"
    ))

    # Image + connect logic
    img_col, status_col = st.columns([1, 2])
    with img_col:
        st.image("assets/wearable.png", width=180)

    with status_col:
        if st.button("🔗 Connect", key="connect_btn"):
            st.session_state.status = "connecting"
            st.session_state.connecting = True
            st.session_state.monitor = HRMonitor(on_hr_callback=log_heart_rate)

            async def do_connect():
                try:
                    result = await st.session_state.monitor.connect()
                    st.session_state.connected = result
                    st.session_state.status = "connected" if result else "failed"
                except Exception as e:
                    st.session_state.connected = False
                    st.session_state.status = "failed"
                    st.error(f"⚠️ Exception: {e}")
                finally:
                    st.session_state.connecting = False

            asyncio.run(do_connect())

        # Status indicator
        status = st.session_state.status
        if status == "connected":
            st.success("🟢 Connected")
        elif status == "connecting":
            st.warning("🟡 Connecting...")
        elif status == "failed":
            st.error("⚠️ Failed to Connect")
        else:
            st.warning("🔴 Not Connected")

    st.divider()

    # Daily metrics
    st.subheader("Daily Metrics")
    st.progress(0.8, text="Readiness: 80%")
    st.progress(0.6, text="Sleep: 60%")
    st.progress(0.7, text="Vitality: 70%")

    # Sleep graph
    st.subheader("Sleep History")
    graph_path = "assets/sleep_graph.png"
    if os.path.exists(graph_path):
        st.image(graph_path, width=600)
    else:
        st.warning("⚠️ Sleep graph image not found.")

    # Live Heart Rate
    st.subheader("Live Heart Rate")
    st.metric("Current HR", f"{st.session_state.live_bpm} BPM")
