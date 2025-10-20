#include <SPI.h>
#include <SD.h>
#include <Wire.h>
#include "MAX30105.h"
#include "heartRate.h"
#include <TinyGPS++.h>
#include <LSM6DS3.h>

#define SD_CS_PIN    6
#define RED_PIN      0
#define GREEN_PIN    1
#define BLUE_PIN     2

MAX30105 sensor;
TinyGPSPlus gps;
LSM6DS3 imu(I2C_MODE, 0x6A);
File dataFile;

float bpm = 0;
unsigned long lastBeat = 0;
unsigned long lastPrint = 0;
bool logging = false;
bool waitingForRelease = false;

const char* filename = "data.csv";

void setColor(bool r, bool g, bool b) {
  digitalWrite(RED_PIN, r ? HIGH : LOW);
  digitalWrite(GREEN_PIN, g ? HIGH : LOW);
  digitalWrite(BLUE_PIN, b ? HIGH : LOW);
}

void setup() {
  Serial.begin(115200);
  while (!Serial);
  Serial.println("🩺 Starting wearable logger...");

  pinMode(RED_PIN, OUTPUT);
  pinMode(GREEN_PIN, OUTPUT);
  pinMode(BLUE_PIN, OUTPUT);
  setColor(0, 0, 1);  // 🔵 idle

  // --- SD Setup ---
  Serial.print("🔁 Initializing SD card...");
  if (!SD.begin(SD_CS_PIN)) {
    Serial.println(" ❌ SD init failed.");
    setColor(1, 0, 0);  // 🔴 error
    while (1);
  }
  Serial.println(" ✅ SD card ready.");
  delay(500);

  if (SD.exists(filename)) {
    SD.remove(filename);
    delay(100);
  }

  File file = SD.open(filename, FILE_WRITE);
  if (file) {
    file.println("BPM,Latitude,Longitude");
    file.close();
    Serial.println("🧹 CSV file created and cleared.");
  } else {
    Serial.println("❌ Couldn't prepare CSV.");
    setColor(1, 0, 0);
    while (1);
  }

  // --- HR sensor ---
  if (!sensor.begin(Wire, I2C_SPEED_STANDARD)) {
    Serial.println("❌ MAX30102 not found.");
    setColor(1, 0, 0);
    while (1);
  }
  sensor.setup(0x05, 4, 2, 100);
  sensor.setPulseAmplitudeRed(0x05);
  sensor.setPulseAmplitudeIR(0x05);
  sensor.setPulseAmplitudeGreen(0);
  Serial.println("💓 MAX30102 ready.");

  // --- GPS ---
  Serial1.begin(9600);
  Serial.println("🧭 GPS started.");

  // --- IMU ---
  if (imu.begin() != 0) {
    Serial.println("❌ IMU init failed!");
    setColor(1, 0, 0);
    while (1);
  }
  Serial.println("✅ IMU ready.");

  imu.writeRegister(LSM6DS3_ACC_GYRO_TAP_CFG1, 0x8E);
  imu.writeRegister(LSM6DS3_ACC_GYRO_TAP_THS_6D, 0x03);
  imu.writeRegister(LSM6DS3_ACC_GYRO_INT_DUR2, 0x7F);
  imu.writeRegister(LSM6DS3_ACC_GYRO_WAKE_UP_THS, 0x80);
  imu.writeRegister(LSM6DS3_ACC_GYRO_MD1_CFG, 0x40);

  Serial.println("👆 Tap to start logging.");
}

void loop() {
  // --- Update GPS ---
  while (Serial1.available()) {
    gps.encode(Serial1.read());
  }

  // --- Heart Rate ---
  long irValue = sensor.getIR();
  if (checkForBeat(irValue)) {
    unsigned long now = millis();
    bpm = 60.0 / ((now - lastBeat) / 1000.0);
    lastBeat = now;
  }

  // --- Tap Detection ---
  uint8_t tapSrc = 0;
  imu.readRegister(&tapSrc, LSM6DS3_ACC_GYRO_TAP_SRC);
  if (tapSrc & 0x40) {
    if (!waitingForRelease) {
      logging = !logging;
      waitingForRelease = true;

      if (logging) {
        Serial.println("▶️ Logging started.");
        setColor(1, 1, 0);  // 🟠 orange
      } else {
        Serial.println("⏹ Logging stopped.");
        printAndDeleteFile();
        setColor(0, 1, 0);  // 🟢 done
      }
    }
  } else {
    waitingForRelease = false;
  }

  // --- Print every second ---
  if (millis() - lastPrint >= 1000) {
    lastPrint = millis();

    String hrStr = (bpm > 20 && bpm < 220) ? String(bpm, 1) : "null";
    String latStr = gps.location.isValid() ? String(gps.location.lat(), 6) : "null";
    String lonStr = gps.location.isValid() ? String(gps.location.lng(), 6) : "null";

    Serial.print("📊 ");
    Serial.print("BPM: "); Serial.print(hrStr);
    Serial.print(" | Lat: "); Serial.print(latStr);
    Serial.print(" Lon: "); Serial.println(lonStr);

    if (logging) {
      File file = SD.open(filename, FILE_WRITE);
      if (file) {
        file.print(hrStr); file.print(",");
        file.print(latStr); file.print(",");
        file.println(lonStr);
        file.close();
      } else {
        Serial.println("❌ Failed to write to SD.");
      }
    }
  }
}

void printAndDeleteFile() {
  Serial.println("📂 Printing CSV contents:");
  File file = SD.open("data.csv");
  if (file) {
    while (file.available()) {
      Serial.write(file.read());
    }
    file.close();
  } else {
    Serial.println("❌ Couldn’t read CSV.");
  }

  Serial.println("\n🗑 Deleting CSV file...");
  if (SD.remove("data.csv")) {
    Serial.println("✅ File deleted.");
  } else {
    Serial.println("❌ Failed to delete.");
  }
}