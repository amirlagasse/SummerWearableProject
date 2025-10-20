import streamlit as st
import asyncio
from ble.hr_monitor import HRMonitor
from bleak import BleakScanner

HR_KEYWORDS = ["hr", "heart", "h10", "whoop", "polar", "garmin", "forerunner"]

def render():
    st.title("⚙️ Settings")

    # =========================
    # 📱 Device Selector
    # =========================
    with st.expander("📱 Device Selector"):
        if st.button("🔍 Scan for HR Devices"):
            async def scan():
                devices = await BleakScanner.discover(timeout=5.0)
                seen = set()
                filtered = []

                for d in devices:
                    name = d.name or "(Unnamed)"
                    addr = d.address
                    key = (name, addr)
                    if key not in seen:
                        seen.add(key)
                        if any(k in name.lower() for k in HR_KEYWORDS):
                            filtered.append((name, addr))

                st.session_state.scan_results = filtered

            asyncio.run(scan())

        for name, addr in st.session_state.get("scan_results", []):
            if st.button(f"Select {name}", key=f"select_{name}_{addr}"):
                HRMonitor.set_device(addr, name)
                st.success(f"Selected {name}")

    # =========================
    # 🎨 Workout Color Selector (Live)
    # =========================
    with st.expander("🎨 Workout Colors"):
        workouts = ['Bike', 'Run', 'Row', 'Lift', 'Yoga', 'Swim', 'Walk', 'Stretch', 'HIIT', 'Other']
        COLOR_OPTIONS = {
            "🟣 Purple": "#7E57C2",
            "🔵 Cyan": "#00ACC1",
            "🟠 Orange": "#FF5722",
            "🟤 Brown": "#795548"
        }

        dropdown_choices = ["— Unlabeled —"] + [f"{k} ({v})" for k, v in COLOR_OPTIONS.items()]

        # Track current selections
        if "workout_colors" not in st.session_state:
            st.session_state.workout_colors = {w: "— Unlabeled —" for w in workouts}

        # Check for duplicates
        seen = {}
        duplicates = set()

        for workout in workouts:
            current = st.session_state.workout_colors.get(workout, "— Unlabeled —")
            if current != "— Unlabeled —":
                hex_val = current.split("(")[-1].strip(")")
                if hex_val in seen:
                    duplicates.add(hex_val)
                else:
                    seen[hex_val] = workout

        if duplicates:
            st.error("❌ Duplicate colors selected! Each workout must have a unique color.")

        # Show dropdowns
        for workout in workouts:
            current = st.session_state.workout_colors.get(workout, "— Unlabeled —")
            selected = st.selectbox(
                f"{workout} Color",
                dropdown_choices,
                index=dropdown_choices.index(current) if current in dropdown_choices else 0,
                key=f"{workout}_color"
            )
            st.session_state.workout_colors[workout] = selected
