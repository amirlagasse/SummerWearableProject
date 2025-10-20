# SummerWearableProject

The **SummerWearableProject** is a cross-platform wearable system for live heart-rate tracking and data visualization.  
This repository documents the evolution of the system from early prototypes to the current mobile build.

---

## Repository Structure

| Folder | Platform | Stage | Description |
|:-------|:----------|:------|:-------------|
| **flutter_app/** | Flutter (Dart) | Current Build | The main production-ready mobile application for iOS and Android. Supports BLE heart-rate streaming, workout logging, and customizable visualizations. |
| **older_builds/Streamlit_App/** | Streamlit (Python) | Second Iteration | A browser-based dashboard used to prototype data visualization and analytics features. |
| **older_builds/Kivy_App/** | Kivy (Python) | First Iteration | The original prototype for the wearable interface, focused on testing BLE connectivity and live HR rendering. |
| **arduino_code/** | Arduino (C/C++) | Firmware | The microcontroller-side firmware for the wearable device, handling sensor input, GPS data, and SD card logging. |

---

## Current Build — Flutter Application
**Location:** `flutter_app/`

### Features
- Real-time Bluetooth Low Energy (BLE) heart-rate monitoring  
- Dashboard with metrics, charts, and expandable workout logs  
- Configurable color themes and device connection settings  
- Cross-platform support for iOS and Android  

**Run:**
```bash
cd flutter_app
flutter run
cd older_builds/Streamlit_App
pip install -r requirements.txt
streamlit run app.py
cd older_builds/Kivy_App
pip install -r requirements.txt
python main.py
