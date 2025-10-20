# ble_hr.py

import asyncio
from bleak import BleakClient, BleakScanner

HR_UUID = "00002a37-0000-1000-8000-00805f9b34fb"


class HRMonitor:
    _selected_address = None
    _last_scan_results = []
    _device_update_callbacks = []
    _selected_name = None


    def __init__(self, on_hr_callback=None):
        print("[INIT] HRMonitor created.")
        self.client = None
        self.latest_hr = 0
        self.on_hr_callback = on_hr_callback

    @classmethod
    async def scan_named_devices(cls, limit=5):
        print("[BLE] 🔍 Scanning for named BLE devices...")
        try:
            devices = await BleakScanner.discover(timeout=5.0)
            named = [d for d in devices if d.name]
            cls._last_scan_results = named[:limit]
            print("[BLE] 📋 Scan Results:")
            for i, d in enumerate(cls._last_scan_results):
                print(f"  {i+1}. {d.name} | {d.address}")
            return cls._last_scan_results
        except Exception as e:
            print(f"[BLE] 🚨 Scan error: {e}")
            return []

    @classmethod
    def set_device(cls, address, name=None):
        print(f"[BLE] 📡 Device address set to: {address}")
        cls._selected_address = address
        cls._selected_name = name
        for cb in cls._device_update_callbacks:
            cb()


    @classmethod
    def register_device_update_callback(cls, cb):
        if cb not in cls._device_update_callbacks:
            cls._device_update_callbacks.append(cb)

    async def connect(self):
        address = self._selected_address
        print(f"[BLE] 🔌 Connecting to: {address}")
        try:
            self.client = BleakClient(address)
            await self.client.connect()

            if self.client.is_connected:
                print("[BLE] ✅ Connected.")
                await self.client.start_notify(HR_UUID, self._hr_handler)
                return True
            else:
                print("[BLE] ❌ Connection failed.")
                return False
        except Exception as e:
            print(f"[BLE] ❗ Exception: {e}")
            return False

    def _hr_handler(self, sender, data):
        if len(data) > 1:
            self.latest_hr = int(data[1])
            print(f"[BLE] ❤️ HR = {self.latest_hr}")
            if self.on_hr_callback:
                self.on_hr_callback(self.latest_hr)
