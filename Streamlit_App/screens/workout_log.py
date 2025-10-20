import streamlit as st

def render():
    st.title("📝 Workout Log")

    def workout_entry(workout, duration, hr, time, expanded=False):
        with st.expander(f"{workout}  {duration}  {hr}  {time}", expanded=expanded):
            st.text("Pace: 2:05/500m")
            st.text("Calories: 350 kcal")
            st.text("[Graph Placeholder]")

    workout_entry("Bike", "45 min", "137 bpm", "7:00 AM")
    workout_entry("Row", "30 min", "145 bpm", "6:45 PM")
    workout_entry("Lift", "60 min", "120 bpm", "1:00 PM")
