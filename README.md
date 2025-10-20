# SummerWearableProject

The **SummerWearableProject** is a full-stack, cross-platform wearable system designed to capture, analyze, and visualize real-time physiological data — primarily heart rate — from a custom-built hardware sensor suite.

The project’s goal is to bridge the gap between hardware sensing and data-driven health insights, enabling users to monitor live biometric data, log workouts, and view long-term performance trends through an intuitive mobile interface.

---

## Overview

This repository documents the evolution of the system — from early Python-based prototypes to the current Flutter mobile application — showcasing the integration of embedded firmware, Bluetooth communication, and cloud-ready visualization tools.

---

## Repository Structure

| Folder | Platform | Stage | Description |
|:-------|:----------|:------|:-------------|
| **flutter_app/** | Flutter (Dart) | Current Build | The main production-ready mobile application for iOS and Android. Supports BLE heart-rate streaming, workout logging, and customizable visualizations. |
| **older_builds/Streamlit_App/** | Streamlit (Python) | Second Iteration | A browser-based dashboard used to prototype data visualization and analytics features. |
| **older_builds/Kivy_App/** | Kivy (Python) | First Iteration | The original prototype for the wearable interface, focused on testing BLE connectivity and live heart-rate rendering. |
| **arduino_code/** | Arduino (C/C++) | Firmware | The microcontroller-side firmware for the wearable device, handling sensor input, GPS data, tap detection, and SD card logging. |

---

## Project Goal

To develop a fully functional, WHOOP-style wearable that:
- Collects heart rate, SpO₂, and GPS data via onboard sensors  
- Streams data to a mobile dashboard through Bluetooth Low Energy (BLE)  
- Enables real-time monitoring, data logging, and custom analytics  
- Demonstrates a complete hardware–software ecosystem for personalized health tracking  

Ultimately, the project serves as a research and prototyping platform for future work in HRV analysis, activity recognition, and biometric modeling using sensor fusion and embedded AI.

---

## Run Instructions

### Flutter App (Current Build)
```bash
cd flutter_app
flutter run
```

### Streamlit Dashboard (Older Build)
```bash
cd older_builds/Streamlit_App
pip install -r requirements.txt
streamlit run app.py
```

### Kivy Prototype (Earliest Build)
```bash
cd older_builds/Kivy_App
pip install -r requirements.txt
python main.py
```

---

## Development Timeline

1. **Kivy App** — initial BLE and visualization prototype  
2. **Streamlit App** — browser-based analytics dashboard  
3. **Flutter App** — full native mobile implementation  
4. **Arduino Firmware** — embedded data collection and logging layer

