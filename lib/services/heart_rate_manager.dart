import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/heart_rate_sample.dart';

enum HeartRateConnectionStatus { disconnected, connecting, connected }

class HeartRateManager {
  HeartRateManager._();

  static final HeartRateManager instance = HeartRateManager._();

  final ValueNotifier<int?> heartRate = ValueNotifier<int?>(null);
  final ValueNotifier<HeartRateConnectionStatus> connectionStatus =
      ValueNotifier<HeartRateConnectionStatus>(
        HeartRateConnectionStatus.disconnected,
      );
  final ValueNotifier<String?> connectedDeviceId = ValueNotifier<String?>(null);
  final ValueNotifier<List<HeartRateSample>> heartRateHistory =
      ValueNotifier<List<HeartRateSample>>(<HeartRateSample>[]);
  final ValueNotifier<List<DateTime>> availableDays =
      ValueNotifier<List<DateTime>>(<DateTime>[]);

  BluetoothDevice? _device;
  StreamSubscription<List<int>>? _heartRateSubscription;
  StreamSubscription<BluetoothConnectionState>? _connectionSubscription;
  bool _isConnecting = false;
  Directory? _storageDirectory;
  bool _initialized = false;
  final List<HeartRateSample> _history = <HeartRateSample>[];
  final Map<DateTime, List<HeartRateSample>> _dailyCache =
      <DateTime, List<HeartRateSample>>{};

  static final String _heartRateServiceUuidString =
      "0000180d-0000-1000-8000-00805f9b34fb";
  static final String _heartRateServiceUuidShort = "180d";
  static final String _heartRateCharacteristicUuidString =
      "00002a37-0000-1000-8000-00805f9b34fb";
  static final String _heartRateCharacteristicUuidShort = "2a37";

  Future<void> initialize() async {
    if (_initialized) return;

    final docsDir = await getApplicationDocumentsDirectory();
    _storageDirectory = Directory(p.join(docsDir.path, 'heart_rate'));
    if (!await _storageDirectory!.exists()) {
      await _storageDirectory!.create(recursive: true);
    }

    final files = await _storageDirectory!
        .list()
        .where((entity) => entity is File && entity.path.endsWith('.csv'))
        .cast<File>()
        .toList();

    files.sort((a, b) => a.path.compareTo(b.path));

    final Set<DateTime> daySet = <DateTime>{};
    final List<HeartRateSample> collected = <HeartRateSample>[];

    for (final file in files) {
      final day = _dayFromFilename(file);
      if (day == null) continue;
      final samples = await _loadSamplesFromFile(file);
      if (samples.isEmpty) continue;
      collected.addAll(samples);
      _dailyCache[day] = samples;
      daySet.add(day);
    }

    collected.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    _history
      ..clear()
      ..addAll(collected);
    heartRateHistory.value = List<HeartRateSample>.unmodifiable(_history);

    final sortedDays = daySet.toList()..sort();
    availableDays.value = sortedDays;

    _initialized = true;
  }

  Future<void> connectToDevice(String remoteId) async {
    if (_isConnecting) return;

    final alreadyConnected =
        connectionStatus.value == HeartRateConnectionStatus.connected &&
        connectedDeviceId.value == remoteId;
    if (alreadyConnected) {
      return;
    }

    _isConnecting = true;
    connectionStatus.value = HeartRateConnectionStatus.connecting;
    heartRate.value = null;

    try {
      if (_device != null && _device!.remoteId.str != remoteId) {
        await disconnect();
      }

      _device = BluetoothDevice.fromId(remoteId);
      connectedDeviceId.value = remoteId;

      // Establish connection if needed
      if (_device!.isDisconnected) {
        await _device!.connect(timeout: const Duration(seconds: 15));
      }

      await _subscribeToHeartRate();
      _listenToConnectionState();

      connectionStatus.value = HeartRateConnectionStatus.connected;
    } catch (error) {
      await disconnect();
      rethrow;
    } finally {
      _isConnecting = false;
    }
  }

  Future<void> disconnect() async {
    _heartRateSubscription?.cancel();
    _heartRateSubscription = null;

    _connectionSubscription?.cancel();
    _connectionSubscription = null;

    if (_device != null && _device!.isConnected) {
      await _device!.disconnect();
    }

    _device = null;
    heartRate.value = null;
    connectedDeviceId.value = null;
    connectionStatus.value = HeartRateConnectionStatus.disconnected;
  }

  Future<void> _subscribeToHeartRate() async {
    if (_device == null) return;

    var services = await _device!.discoverServices();
    if (services.isEmpty) {
      await Future.delayed(const Duration(milliseconds: 500));
      services = await _device!.discoverServices();
    }

    BluetoothCharacteristic? hrCharacteristic;

    outerLoop:
    for (final service in services) {
      final serviceUuid = service.uuid.str.toLowerCase();
      if (serviceUuid == _heartRateServiceUuidString ||
          serviceUuid == _heartRateServiceUuidShort) {
        for (final characteristic in service.characteristics) {
          final charUuid = characteristic.uuid.str.toLowerCase();
          if (charUuid == _heartRateCharacteristicUuidString ||
              charUuid == _heartRateCharacteristicUuidShort) {
            hrCharacteristic = characteristic;
            break outerLoop;
          }
        }
      }
    }

    hrCharacteristic ??= services
        .expand((service) => service.characteristics)
        .firstWhere(
          (characteristic) {
            final candidate = characteristic.uuid.str.toLowerCase();
            return candidate == _heartRateCharacteristicUuidString ||
                candidate == _heartRateCharacteristicUuidShort;
          },
          orElse: () => throw HeartRateCharacteristicNotFoundException(
            _summarizeServices(services),
          ),
        );

    await hrCharacteristic.setNotifyValue(true);
    _heartRateSubscription?.cancel();
    _heartRateSubscription = hrCharacteristic.onValueReceived.listen((data) {
      final bpm = _parseHeartRateMeasurement(data);
      if (bpm != null) {
        heartRate.value = bpm;
        _recordSample(bpm);
      }
    });

    // Immediately emit the last value if present
    final initial = hrCharacteristic.lastValue;
    final initialBpm = _parseHeartRateMeasurement(initial);
    if (initialBpm != null) {
      heartRate.value = initialBpm;
      _recordSample(initialBpm);
    }
  }

  void _listenToConnectionState() {
    if (_device == null) return;

    _connectionSubscription?.cancel();
    _connectionSubscription = _device!.connectionState.listen((state) {
      if (state == BluetoothConnectionState.connected) {
        connectionStatus.value = HeartRateConnectionStatus.connected;
      } else if (state == BluetoothConnectionState.disconnected) {
        connectionStatus.value = HeartRateConnectionStatus.disconnected;
        heartRate.value = null;
        connectedDeviceId.value = null;
      }
    });
  }

  void _recordSample(int bpm) {
    final timestamp = DateTime.now();
    final sample = HeartRateSample(timestamp: timestamp, bpm: bpm);

    if (_history.isNotEmpty && !timestamp.isAfter(_history.last.timestamp)) {
      _history[_history.length - 1] = sample;
    } else {
      _history.add(sample);
    }
    heartRateHistory.value = List<HeartRateSample>.unmodifiable(_history);

    final dayKey = _dayKey(timestamp);
    final daySamples = List<HeartRateSample>.from(
      _dailyCache[dayKey] ?? <HeartRateSample>[],
    );
    final bool appendedDay;
    if (daySamples.isNotEmpty &&
        !timestamp.isAfter(daySamples.last.timestamp)) {
      daySamples[daySamples.length - 1] = sample;
      appendedDay = false;
    } else {
      daySamples.add(sample);
      appendedDay = true;
    }
    _dailyCache[dayKey] = daySamples;
    _ensureDayListed(dayKey);

    if (_storageDirectory != null) {
      unawaited(_persistDaySamples(dayKey, daySamples, appended: appendedDay));
    }
  }

  int? _parseHeartRateMeasurement(List<int> data) {
    if (data.isEmpty) return null;

    final flags = data[0];
    final isHeartRate16Bits = (flags & 0x01) != 0;

    if (isHeartRate16Bits) {
      if (data.length < 3) return null;
      return data[1] | (data[2] << 8);
    } else {
      if (data.length < 2) return null;
      return data[1];
    }
  }

  void dispose() {
    _heartRateSubscription?.cancel();
    _connectionSubscription?.cancel();
    heartRate.dispose();
    connectionStatus.dispose();
    connectedDeviceId.dispose();
    heartRateHistory.dispose();
    availableDays.dispose();
  }

  String _summarizeServices(List<BluetoothService> services) {
    if (services.isEmpty) {
      return "No services discovered.";
    }

    final buffer = StringBuffer();
    for (final service in services) {
      final chars = service.characteristics.map((c) => c.uuid.str).join(", ");
      buffer.writeln("${service.uuid.str} -> [$chars]");
    }
    return buffer.toString();
  }

  DateTime? _dayFromFilename(File file) {
    final name = p.basenameWithoutExtension(file.path);
    if (!name.startsWith('hr_')) return null;
    final datePart = name.substring(3);
    try {
      final parsed = DateTime.parse(datePart);
      return _dayKey(parsed);
    } catch (_) {
      return null;
    }
  }

  DateTime _dayKey(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  void _ensureDayListed(DateTime day) {
    final existing = List<DateTime>.from(availableDays.value);
    if (!existing.contains(day)) {
      existing.add(day);
      existing.sort();
      availableDays.value = existing;
    }
  }

  Future<void> _persistDaySamples(
    DateTime day,
    List<HeartRateSample> samples, {
    required bool appended,
  }) async {
    final directory = _storageDirectory;
    if (directory == null) return;
    final file = File(p.join(directory.path, _filenameForDay(day)));

    if (appended && await file.exists()) {
      final sample = samples.last;
      final sink = file.openWrite(mode: FileMode.append);
      sink.writeln('${sample.timestamp.toIso8601String()},${sample.bpm}');
      await sink.close();
      return;
    }

    final buffer = StringBuffer()..writeln('timestamp,bpm');
    for (final sample in samples) {
      buffer.writeln('${sample.timestamp.toIso8601String()},${sample.bpm}');
    }
    await file.writeAsString(buffer.toString());
  }

  String _filenameForDay(DateTime day) {
    final formatted =
        '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
    return 'hr_$formatted.csv';
  }

  Future<List<HeartRateSample>> _loadSamplesFromFile(File file) async {
    final lines = await file.readAsLines();
    final List<HeartRateSample> samples = <HeartRateSample>[];
    for (final line in lines.skip(1)) {
      if (line.trim().isEmpty) continue;
      final parts = line.split(',');
      if (parts.length < 2) continue;
      final timestamp = DateTime.tryParse(parts[0]);
      final bpm = int.tryParse(parts[1]);
      if (timestamp == null || bpm == null) continue;
      samples.add(HeartRateSample(timestamp: timestamp, bpm: bpm));
    }
    samples.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return samples;
  }
}

class HeartRateCharacteristicNotFoundException implements Exception {
  final String servicesSummary;

  HeartRateCharacteristicNotFoundException(this.servicesSummary);

  @override
  String toString() => "Heart rate characteristic not found.\n$servicesSummary";
}
