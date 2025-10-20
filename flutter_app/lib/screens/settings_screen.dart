import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/workout_definitions.dart';
import '../services/heart_rate_manager.dart';
import '../widgets/app_snackbar.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final HeartRateManager _heartRateManager = HeartRateManager.instance;
  static const String _rememberedDevicesKey = 'remembered_devices';

  List<ScanResult> scanResults = [];
  String? _selectedDeviceId;
  String? _selectedDeviceName;
  String? _pendingDeviceId;
  bool _isConnectingDevice = false;
  StreamSubscription<List<ScanResult>>? _scanSubscription;
  StreamSubscription<bool>? _scanStateSubscription;

  final List<WorkoutDefinition> workouts = workoutDefinitions;

  final Map<String, String> colorOptions = {
    'Purple': '#7E57C2',
    'Cyan': '#00ACC1',
    'Orange': '#FF5722',
    'Brown': '#795548',
  };

  Map<String, String> workingColors = {};
  Map<String, String> savedColors = {};
  bool showErrors = false;
  bool _isScanning = false;
  bool _hasRequestedScan = false;
  List<_RememberedDevice> rememberedDevices = [];

  @override
  void initState() {
    super.initState();
    for (final workout in workouts) {
      workingColors[workout.name] = 'Unlabeled';
      savedColors[workout.name] = 'Unlabeled';
    }
    _scanSubscription = FlutterBluePlus.scanResults.listen(_onScanResults);
    _scanStateSubscription = FlutterBluePlus.isScanning.listen((isScanning) {
      if (!mounted) return;
      setState(() {
        _isScanning = isScanning;
      });
    });
    _loadSavedColors();
  }

  Future<void> _loadSavedColors() async {
    final prefs = await SharedPreferences.getInstance();
    final savedDeviceId = prefs.getString('selected_device_id');
    final savedDeviceName = prefs.getString('selected_device_name');
    if (!mounted) return;
    setState(() {
      for (final workout in workouts) {
        final saved = prefs.getString('color_${workout.name}');
        if (saved != null) {
          final normalized = _normalizeColorLabel(saved);
          savedColors[workout.name] = normalized;
          workingColors[workout.name] = normalized;
        }
      }
      _selectedDeviceId = savedDeviceId;
      _selectedDeviceName = savedDeviceName;
    });

    await _loadRememberedDevices(prefs);

    if (savedDeviceId != null) {
      final friendlyName = savedDeviceName ?? "saved device";
      try {
        await _heartRateManager.connectToDevice(savedDeviceId);
        if (savedDeviceName != null) {
          await _addRememberedDevice(
            id: savedDeviceId,
            name: savedDeviceName,
            persist: false,
          );
        }
      } catch (_) {
        if (!mounted) return;
        showAppSnackBar(
          context,
          "Unable to reconnect to $friendlyName. Make sure the device is on.",
          icon: Icons.info_outline,
        );
      }
    }
  }

  Future<void> _saveColorsToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    for (final workout in workouts) {
      await prefs.setString(
        'color_${workout.name}',
        workingColors[workout.name]!,
      );
    }
  }

  Future<void> scanForDevices() async {
    if (Platform.isIOS) {
      final status = await Permission.bluetooth.request();

      if (status.isPermanentlyDenied || status == PermissionStatus.restricted) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Bluetooth access is disabled. Go to Settings → Privacy & Security → Bluetooth and enable Flutter App.",
            ),
            duration: Duration(seconds: 5),
          ),
        );
        return;
      }

      // When status is denied but not permanent, iOS has not shown the native prompt yet.
      // Proceed with the scan so CoreBluetooth can trigger it.
    } else {
      final permissionRequests = <Permission>{
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.location,
      };

      final statuses = await permissionRequests.toList().request();
      final permanentlyDenied = statuses.values.any(
        (status) => status.isPermanentlyDenied,
      );
      final missingAccess = statuses.values.any(
        (status) => !_isPermissionGranted(status),
      );

      if (missingAccess) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              permanentlyDenied
                  ? "Bluetooth access is disabled. Enable it in Settings to scan for devices."
                  : "Bluetooth permissions are required to scan for devices.",
            ),
            action: permanentlyDenied
                ? SnackBarAction(
                    label: "Open Settings",
                    onPressed: () {
                      openAppSettings();
                    },
                  )
                : null,
          ),
        );
        return;
      }
    }

    if (!mounted) return;
    setState(() {
      scanResults.clear();
      _hasRequestedScan = true;
    });

    try {
      await FlutterBluePlus.stopScan();
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 8));
    } on FlutterBluePlusException catch (ex) {
      final unauthorized = await _isBluetoothUnauthorized();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            unauthorized
                ? "Bluetooth access is disabled. Go to Settings → Privacy & Security → Bluetooth and enable Flutter App."
                : "Failed to start Bluetooth scan: ${ex.description ?? ex.code ?? ex.function}",
          ),
          duration: const Duration(seconds: 5),
        ),
      );
    } catch (ex) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to start Bluetooth scan: $ex")),
      );
    }
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    _scanStateSubscription?.cancel();
    FlutterBluePlus.stopScan();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final usedHex = workingColors.values
        .map(_extractHex)
        .whereType<String>()
        .toList();

    final duplicates = usedHex
        .toSet()
        .where((c) => usedHex.where((x) => x == c).length > 1)
        .toSet();
    final tooManyLabeled = usedHex.length > 4;
    final changed = workingColors.toString() != savedColors.toString();
    final saveDisabled = !changed || duplicates.isNotEmpty || tooManyLabeled;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // BLE Device Selector
          ExpansionTile(
            leading: const Icon(Icons.watch_outlined),
            title: const Text(
              'Device Selector',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            children: [
              ValueListenableBuilder<HeartRateConnectionStatus>(
                valueListenable: _heartRateManager.connectionStatus,
                builder: (context, status, _) {
                  String subtitle;
                  Color subtitleColor = Colors.white70;
                  switch (status) {
                    case HeartRateConnectionStatus.connected:
                      subtitle = "Status: Connected";
                      subtitleColor = Colors.greenAccent;
                      break;
                    case HeartRateConnectionStatus.connecting:
                      subtitle = "Status: Connecting...";
                      subtitleColor = Colors.orangeAccent;
                      break;
                    default:
                      subtitle = "Status: Not connected";
                      subtitleColor = Colors.white70;
                  }

                  final showSpinner =
                      status == HeartRateConnectionStatus.connecting ||
                      _isConnectingDevice;

                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      _selectedDeviceName ?? "No device selected",
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      subtitle,
                      style: TextStyle(color: subtitleColor),
                    ),
                    trailing: showSpinner
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : status == HeartRateConnectionStatus.connected &&
                              _selectedDeviceId != null
                        ? TextButton(
                            onPressed: _disconnectSelectedDevice,
                            child: const Text("Disconnect"),
                          )
                        : null,
                  );
                },
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: _isScanning
                    ? () async {
                        await FlutterBluePlus.stopScan();
                      }
                    : scanForDevices,
                icon: Icon(_isScanning ? Icons.stop : Icons.search),
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_isScanning ? "Stop Scan" : "Scan for HR Devices"),
                    if (_isScanning) ...[
                      const SizedBox(width: 12),
                      const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 10),
              if (_isScanning)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text(
                    "Scanning for nearby Bluetooth devices...",
                    style: TextStyle(color: Colors.white70),
                  ),
                )
              else if (_hasRequestedScan && scanResults.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text(
                    "No heart rate monitors detected. Make sure your strap is on and in pairing mode.",
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
              ...scanResults.map(_buildDeviceTile),
              if (rememberedDevices.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text(
                  'Remembered Devices',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                ),
                const SizedBox(height: 8),
                ...rememberedDevices.map(_buildRememberedTile),
              ],
            ],
          ),

          // Workout Color Selector
          ExpansionTile(
            leading: const Icon(Icons.palette_outlined),
            title: const Text(
              'Workout Colors',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            children: [
              if (!saveDisabled)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  child: Row(
                    children: [
                      ElevatedButton.icon(
                        icon: const Icon(Icons.save_outlined),
                        onPressed: saveDisabled
                            ? null
                            : () async {
                                await _saveColorsToPrefs();
                                if (!mounted) return;
                                setState(() {
                                  savedColors = Map.from(workingColors);
                                  showErrors = false;
                                });
                                if (!context.mounted) return;
                                showAppSnackBar(
                                  context,
                                  'Changes saved',
                                  icon: Icons.check_circle_outline,
                                );
                              },
                        label: const Text("Save changes"),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.undo),
                        onPressed: () {
                          setState(() {
                            workingColors = Map.from(savedColors);
                            showErrors = false;
                          });
                        },
                        label: const Text("Reset"),
                      ),
                    ],
                  ),
                ),
              ...workouts.map((workout) {
                final name = workout.name;
                final current = workingColors[name] ?? 'Unlabeled';
                final List<String> dropdownItems = [
                  'Unlabeled',
                  ...colorOptions.entries.map(
                    (entry) => '${entry.key} (${entry.value})',
                  ),
                ];
                final hex = _extractHex(current);
                final Color baseColor = hex != null
                    ? _colorFromHex(hex)
                    : Colors.white24;
                final Color previewColor = baseColor;
                final Color avatarBackground = hex != null
                    ? baseColor.withAlpha((0.2 * 255).round())
                    : Colors.white24;
                final bool isDuplicate =
                    hex != null && duplicates.contains(hex);

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        leading: CircleAvatar(
                          backgroundColor: avatarBackground,
                          child: Icon(
                            workout.icon,
                            color: hex != null ? previewColor : Colors.white70,
                          ),
                        ),
                        title: Text(
                          name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        trailing: SizedBox(
                          width: 170,
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: current,
                              isExpanded: true,
                              dropdownColor: Theme.of(context).cardColor,
                              style: const TextStyle(color: Colors.white),
                              onChanged: (val) {
                                if (val == null) return;
                                setState(() {
                                  workingColors[name] = val;
                                });
                              },
                              items: dropdownItems.map((val) {
                                final itemHex = _extractHex(val);
                                return DropdownMenuItem(
                                  value: val,
                                  child: Row(
                                    children: [
                                      _ColorSwatchDot(
                                        color: itemHex != null
                                            ? _colorFromHex(itemHex)
                                            : null,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(_readableLabel(val)),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ),
                      if (isDuplicate)
                        Padding(
                          padding: const EdgeInsets.only(left: 28, top: 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(
                                Icons.warning_amber_rounded,
                                color: Colors.orangeAccent,
                                size: 16,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'Duplicate color',
                                style: TextStyle(color: Colors.orangeAccent),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                );
              }),

              if (duplicates.isNotEmpty || tooManyLabeled)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Colors.redAccent,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        duplicates.isNotEmpty
                            ? "Duplicate colors selected"
                            : "Too many workouts labeled",
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String? _extractHex(String value) {
    final match = RegExp(r'#([0-9A-Fa-f]{6})').firstMatch(value);
    if (match == null) return null;
    return '#${match.group(1)!.toUpperCase()}';
  }

  Color _colorFromHex(String hex) {
    final buffer = StringBuffer();
    final sanitized = hex.replaceFirst('#', '');
    if (sanitized.length == 6) {
      buffer.write('FF');
    } else if (sanitized.length == 8) {
      buffer.write('');
    } else {
      return Colors.white54;
    }
    buffer.write(sanitized);
    return Color(int.parse(buffer.toString(), radix: 16));
  }

  String _normalizeColorLabel(String raw) {
    if (raw == 'Unlabeled' || raw == '— Unlabeled —') {
      return 'Unlabeled';
    }

    const legacyPrefixes = {
      '🟣 Purple': 'Purple',
      '🔵 Cyan': 'Cyan',
      '🟠 Orange': 'Orange',
      '🟤 Brown': 'Brown',
    };

    for (final entry in legacyPrefixes.entries) {
      if (raw.startsWith(entry.key)) {
        final hex = colorOptions[entry.value]!;
        return '${entry.value} ($hex)';
      }
    }

    final hex = _extractHex(raw);
    if (hex != null) {
      for (final entry in colorOptions.entries) {
        if (entry.value.toUpperCase() == hex.toUpperCase()) {
          return '${entry.key} ($hex)';
        }
      }
    }

    for (final key in colorOptions.keys) {
      if (raw.toLowerCase().contains(key.toLowerCase())) {
        final hex = colorOptions[key]!;
        return '$key ($hex)';
      }
    }

    return 'Unlabeled';
  }

  String _readableLabel(String value) {
    if (value == 'Unlabeled') return 'Unlabeled';
    final separatorIndex = value.indexOf(' (');
    if (separatorIndex == -1) return value;
    return value.substring(0, separatorIndex);
  }

  void _onScanResults(List<ScanResult> results) {
    final unique = <String, ScanResult>{};
    for (final result in results) {
      unique[result.device.remoteId.str] = result;
    }

    final devices =
        unique.values.where((result) {
          final remoteId = result.device.remoteId.str;
          final matchesSelection =
              _selectedDeviceId != null && remoteId == _selectedDeviceId;
          return matchesSelection || _isLikelyHeartRate(result);
        }).toList()..sort((a, b) {
          final aLikely = _isLikelyHeartRate(a) ? 0 : 1;
          final bLikely = _isLikelyHeartRate(b) ? 0 : 1;
          if (aLikely != bLikely) return aLikely - bLikely;
          return b.rssi.compareTo(a.rssi);
        });

    if (!mounted) return;
    setState(() {
      scanResults = devices;
      if (_selectedDeviceId != null) {
        for (final result in devices) {
          if (result.device.remoteId.str == _selectedDeviceId) {
            _selectedDeviceName = _deviceDisplayName(result);
            break;
          }
        }
      }
    });
  }

  bool _isLikelyHeartRate(ScanResult result) {
    final normalized = _deviceDisplayName(result).toLowerCase();
    const keywords = [
      "hr",
      "heart",
      "whoop",
      "garmin",
      "polar",
      "wahoo",
      "tickr",
      "strap",
      "pulse",
      "forerunner",
    ];
    if (keywords.any((word) => normalized.contains(word))) {
      return true;
    }
    return result.advertisementData.serviceUuids.any(
      (uuid) => uuid.toString().toLowerCase().contains("180d"),
    );
  }

  String _deviceDisplayName(ScanResult result) {
    final candidates = [
      result.device.platformName,
      result.device.advName,
      result.advertisementData.advName,
    ].where((name) => name.isNotEmpty);

    if (candidates.isNotEmpty) {
      return candidates.first;
    }

    return result.device.remoteId.str;
  }

  Widget _buildRememberedTile(_RememberedDevice device) {
    final bool isSelected = _selectedDeviceId == device.id;
    final bool isPending = _pendingDeviceId == device.id && _isConnectingDevice;

    return Card(
      child: ListTile(
        leading: const Icon(Icons.history),
        title: Text(device.name),
        subtitle: Text(device.id),
        trailing: isPending
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : isSelected
            ? const Icon(Icons.check_circle, color: Colors.green)
            : TextButton(
                onPressed: () => _connectToRememberedDevice(device),
                child: const Text('Connect'),
              ),
      ),
    );
  }

  Widget _buildDeviceTile(ScanResult result) {
    final remoteId = result.device.remoteId.str;
    final displayName = _deviceDisplayName(result);
    final bool isSelected = _selectedDeviceId == remoteId;
    final bool isPending = _pendingDeviceId == remoteId && _isConnectingDevice;

    return ListTile(
      leading: Icon(
        Icons.monitor_heart,
        color: _isLikelyHeartRate(result)
            ? Colors.pinkAccent
            : Colors.blueAccent,
      ),
      title: Text(displayName),
      subtitle: Text("$remoteId  |  RSSI ${result.rssi} dBm"),
      trailing: isPending
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : isSelected
          ? const Icon(Icons.check_circle, color: Colors.green)
          : null,
      onTap: () => _handleDeviceTap(result, displayName),
    );
  }

  Future<void> _connectToRememberedDevice(_RememberedDevice device) async {
    setState(() {
      _pendingDeviceId = device.id;
      _isConnectingDevice = true;
    });

    try {
      await FlutterBluePlus.stopScan();
      await _heartRateManager.connectToDevice(device.id);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('selected_device_id', device.id);
      await prefs.setString('selected_device_name', device.name);

      if (!mounted) return;
      setState(() {
        _selectedDeviceId = device.id;
        _selectedDeviceName = device.name;
        _isScanning = false;
      });

      showAppSnackBar(
        context,
        "Connected to ${device.name}",
        icon: Icons.check_circle_outline,
      );

      await _addRememberedDevice(id: device.id, name: device.name);
    } catch (error) {
      if (!mounted) return;
      showAppSnackBar(
        context,
        'Failed to connect: $error',
        icon: Icons.error_outline,
        duration: const Duration(seconds: 5),
      );
    } finally {
      if (mounted) {
        setState(() {
          _pendingDeviceId = null;
          _isConnectingDevice = false;
        });
      }
    }
  }

  Future<void> _handleDeviceTap(ScanResult result, String displayName) async {
    final remoteId = result.device.remoteId.str;

    setState(() {
      _pendingDeviceId = remoteId;
      _isConnectingDevice = true;
    });

    try {
      await FlutterBluePlus.stopScan();
      await _heartRateManager.connectToDevice(remoteId);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('selected_device_id', remoteId);
      await prefs.setString('selected_device_name', displayName);

      if (!mounted) return;
      setState(() {
        _selectedDeviceId = remoteId;
        _selectedDeviceName = displayName;
        _isScanning = false;
      });

      showAppSnackBar(
        context,
        "Connected to $displayName",
        icon: Icons.check_circle_outline,
      );

      await _addRememberedDevice(id: remoteId, name: displayName);
    } catch (error) {
      String message;
      if (error is HeartRateCharacteristicNotFoundException) {
        message =
            "Could not find a heart rate service on this device.\n"
            "If you're using a Garmin Forerunner, enable “Broadcast Heart Rate” on the watch and try again.\n\n"
            "Discovered services:\n${error.servicesSummary}";
      } else {
        message = "Failed to connect: $error";
      }
      if (!mounted) return;
      showAppSnackBar(context, message, icon: Icons.error_outline);
    } finally {
      if (mounted) {
        setState(() {
          _pendingDeviceId = null;
          _isConnectingDevice = false;
        });
      }
    }
  }

  Future<void> _disconnectSelectedDevice() async {
    await _heartRateManager.disconnect();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('selected_device_id');
    await prefs.remove('selected_device_name');

    if (!mounted) return;
    setState(() {
      _selectedDeviceId = null;
      _selectedDeviceName = null;
    });

    showAppSnackBar(context, "Disconnected", icon: Icons.info_outline);
  }

  Future<void> _loadRememberedDevices(SharedPreferences prefs) async {
    final raw = prefs.getStringList(_rememberedDevicesKey) ?? <String>[];
    final parsed = <_RememberedDevice>[];
    for (final entry in raw) {
      final parts = entry.split('|');
      if (parts.length == 2) {
        parsed.add(_RememberedDevice(id: parts[0], name: parts[1]));
      }
    }
    if (!mounted) return;
    setState(() {
      rememberedDevices = parsed;
    });
  }

  Future<void> _saveRememberedDevices() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = rememberedDevices
        .map((device) => '${device.id}|${device.name}')
        .toList();
    await prefs.setStringList(_rememberedDevicesKey, encoded);
  }

  Future<void> _addRememberedDevice({
    required String id,
    required String name,
    bool persist = true,
  }) async {
    final updated = rememberedDevices
        .where((device) => device.id != id)
        .toList();
    updated.insert(0, _RememberedDevice(id: id, name: name));
    if (updated.length > 6) {
      updated.removeRange(6, updated.length);
    }
    if (!mounted) return;
    setState(() {
      rememberedDevices = updated;
    });
    if (persist) {
      await _saveRememberedDevices();
    }
  }

  bool _isPermissionGranted(PermissionStatus status) {
    return status == PermissionStatus.granted ||
        status == PermissionStatus.limited ||
        status == PermissionStatus.restricted;
  }

  Future<bool> _isBluetoothUnauthorized() async {
    var state = FlutterBluePlus.adapterStateNow;
    if (state == BluetoothAdapterState.unauthorized) {
      return true;
    }

    if (state == BluetoothAdapterState.unknown) {
      try {
        state = await FlutterBluePlus.adapterState.first.timeout(
          const Duration(milliseconds: 500),
        );
      } catch (_) {
        return false;
      }

      if (state == BluetoothAdapterState.unauthorized) {
        return true;
      }
    }

    return false;
  }
}

class _ColorSwatchDot extends StatelessWidget {
  const _ColorSwatchDot({this.color});

  final Color? color;

  @override
  Widget build(BuildContext context) {
    final Color fill = color ?? Colors.transparent;
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        color: color == null ? Colors.transparent : fill,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: color == null ? Colors.white30 : fill),
      ),
    );
  }
}

class _RememberedDevice {
  const _RememberedDevice({required this.id, required this.name});

  final String id;
  final String name;
}
