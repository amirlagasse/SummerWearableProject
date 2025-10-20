import asyncio
from bleak import BleakScanner, BleakClient

async def scan_ble_devices():
    print("🔍 Scanning for BLE devices...")
    devices = await BleakScanner.discover(timeout=5.0)

    if not devices:
        print("❌ No BLE devices found.")
        return

    for i, device in enumerate(devices):
        name = device.name or "Unknown"
        address = device.address

        print(f"\n📱 Device {i + 1}")
        print(f"  Name: {name}")
        print(f"  Address: {address}")
        print(f"  🔄 Connecting to {name}...")

        try:
            async with BleakClient(address) as client:
                if client.is_connected:
                    print(f"  ✅ Connected to {name}")
                else:
                    print(f"  ⚠️ Failed to connect to {name}")
        except Exception as e:
            print(f"  ❌ Error connecting to {name}: {e}")

asyncio.run(scan_ble_devices())
