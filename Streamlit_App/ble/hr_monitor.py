import asyncio
from bleak import BleakClient, BleakScanner

HR_UUID = "00002a37-0000-1000-8000-00805f9b34fb"

class HRMonitor:
    _selected_address = None
    _selected_name = None
    _last_scan_results = []
    _device_update_callbacks = []

    def __init__(self, on_hr_callback=None):
        print("[INIT] HRMonitor created.")
        self.client = None
        self.latest_hr = 0
        self.on_hr_callback = on_hr_callback
        self._listener_task = None

    @classmethod
    async def scan_named_devices(cls, limit=5):
        print("[BLE] 🔍 Scanning for named BLE devices...")
        try:
            devices = await BleakScanner.discover(timeout=5.0)
            named = [d for d in devices if d.name]
            cls._last_scan_results = named[:limit]
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
        if not address:
            print("[BLE] ❗ No address set.")
            return False

        try:
            self.client = BleakClient(address)
            await self.client.connect()

            if self.client.is_connected:
                await self.client.start_notify(HR_UUID, self._hr_handler)
                print("[BLE] ✅ Connected and listening for HR notifications")
                self._listener_task = asyncio.create_task(self._stream_loop())
                return True
        except Exception as e:
            print(f"[BLE] ❗ Exception during connect: {e}")
            return False

    def _hr_handler(self, sender, data):
        print(f"[BLE] 🔄 Raw HR data: {list(data)}")

        # Parse flags
        flags = data[0]
        hr_format_uint16 = flags & 0b1

        if hr_format_uint16:
            hr = int.from_bytes(data[1:3], byteorder='little')
        else:
            hr = data[1]

        self.latest_hr = hr
        print(f"[BLE] ❤️ Heart Rate: {hr} BPM")

        if self.on_hr_callback:
            self.on_hr_callback(hr)

    async def _stream_loop(self):
        print("[BLE] 🌀 Streaming HR data...")
        try:
            while self.client and self.client.is_connected:
                await asyncio.sleep(1)
        except asyncio.CancelledError:
            print("[BLE] ❌ Stream loop cancelled.")
