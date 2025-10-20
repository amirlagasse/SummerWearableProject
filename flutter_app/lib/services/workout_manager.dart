import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../models/heart_rate_sample.dart';
import '../models/workout_session.dart';
import 'heart_rate_manager.dart';

class WorkoutManager {
  WorkoutManager._();

  static final WorkoutManager instance = WorkoutManager._();

  final ValueNotifier<List<WorkoutSession>> sessions =
      ValueNotifier<List<WorkoutSession>>(<WorkoutSession>[]);
  final ValueNotifier<ActiveWorkoutState?> currentWorkout =
      ValueNotifier<ActiveWorkoutState?>(null);
  final ValueNotifier<List<WorkoutSession>> recentlyDeleted =
      ValueNotifier<List<WorkoutSession>>(<WorkoutSession>[]);

  Directory? _storageDir;
  bool _initialized = false;
  final Uuid _uuid = const Uuid();

  _ActiveWorkout? _activeWorkout;
  VoidCallback? _heartRateListener;
  Timer? _ticker;

  static const String _sessionsFileName = 'sessions.json';
  static const String _deletedFileName = 'deleted_sessions.json';

  Future<void> initialize() async {
    if (_initialized) return;
    final docs = await getApplicationDocumentsDirectory();
    _storageDir = Directory(p.join(docs.path, 'workouts'));
    if (!await _storageDir!.exists()) {
      await _storageDir!.create(recursive: true);
    }

    final file = await _sessionsFile();
    if (await file.exists()) {
      final content = await file.readAsString();
      final list = WorkoutSession.decodeList(content);
      list.sort((a, b) => b.startTime.compareTo(a.startTime));
      sessions.value = list;
    }

    final deletedFile = await _deletedSessionsFile();
    if (await deletedFile.exists()) {
      final content = await deletedFile.readAsString();
      final list = WorkoutSession.decodeList(content);
      list.sort((a, b) => b.startTime.compareTo(a.startTime));
      recentlyDeleted.value = list;
    }

    _initialized = true;
  }

  Future<void> startWorkout(String workoutType) async {
    if (_activeWorkout != null) return;
    final now = DateTime.now();
    _activeWorkout = _ActiveWorkout(
      id: _uuid.v4(),
      workoutType: workoutType,
      startTime: now,
    );
    _emitActiveState();
    _registerHeartRateListener();
    _startTicker();
  }

  Future<void> stopWorkout({required bool save}) async {
    final active = _activeWorkout;
    if (active == null) return;

    _stopLiveTracking();

    if (!save) {
      _activeWorkout = null;
      currentWorkout.value = null;
      return;
    }

    final now = DateTime.now();
    final samples = active.samples;
    final duration = now.difference(active.startTime);
    final stats = _calculateStats(samples);

    final session = WorkoutSession(
      id: active.id,
      workoutType: active.workoutType,
      startTime: active.startTime,
      endTime: now,
      duration: duration,
      avgBpm: stats.avg,
      maxBpm: stats.max,
      minBpm: stats.min,
      sampleCount: samples.length,
      distanceMeters: 0,
      avgPaceSecondsPerKm: 0,
      calories: 0,
    );

    final updated = <WorkoutSession>[session, ...sessions.value];
    sessions.value = updated;
    await _persistSessions(updated);
    _activeWorkout = null;
    currentWorkout.value = null;
  }

  Future<void> deleteSession(String id) async {
    final currentSessions = sessions.value;
    final index = currentSessions.indexWhere((session) => session.id == id);
    if (index == -1) return;

    final session = currentSessions[index];
    final updatedSessions = List<WorkoutSession>.from(currentSessions)
      ..removeAt(index);
    sessions.value = updatedSessions;
    await _persistSessions(updatedSessions);

    final updatedDeleted = <WorkoutSession>[session, ...recentlyDeleted.value];
    recentlyDeleted.value = updatedDeleted;
    await _persistDeleted(updatedDeleted);
  }

  Future<void> clearRecentlyDeleted() async {
    recentlyDeleted.value = <WorkoutSession>[];
    await _persistDeleted(const <WorkoutSession>[]);
  }

  Future<void> restoreSession(String id) async {
    final deletedSessions = recentlyDeleted.value;
    final index = deletedSessions.indexWhere((session) => session.id == id);
    if (index == -1) return;

    final session = deletedSessions[index];
    final updatedDeleted = List<WorkoutSession>.from(deletedSessions)
      ..removeAt(index);
    recentlyDeleted.value = updatedDeleted;
    await _persistDeleted(updatedDeleted);

    final updatedSessions = <WorkoutSession>[session, ...sessions.value]
      ..sort((a, b) => b.startTime.compareTo(a.startTime));
    sessions.value = updatedSessions;
    await _persistSessions(updatedSessions);
  }

  Future<void> _persistSessions(List<WorkoutSession> sessions) async {
    final file = await _sessionsFile();
    await file.writeAsString(WorkoutSession.encodeList(sessions));
  }

  Future<File> _sessionsFile() async {
    final dir =
        _storageDir ??
        (throw StateError('WorkoutManager.initialize() not called.'));
    return File(p.join(dir.path, _sessionsFileName));
  }

  Future<void> _persistDeleted(List<WorkoutSession> sessions) async {
    final file = await _deletedSessionsFile();
    await file.writeAsString(WorkoutSession.encodeList(sessions));
  }

  Future<File> _deletedSessionsFile() async {
    final dir =
        _storageDir ??
        (throw StateError('WorkoutManager.initialize() not called.'));
    return File(p.join(dir.path, _deletedFileName));
  }

  void _registerHeartRateListener() {
    _removeHeartRateListener();
    final heartRate = HeartRateManager.instance.heartRate;
    _heartRateListener = () {
      final bpm = heartRate.value;
      final active = _activeWorkout;
      if (bpm == null || active == null) return;
      active.samples.add(HeartRateSample(timestamp: DateTime.now(), bpm: bpm));
      _emitActiveState(latestBpm: bpm);
    };
    heartRate.addListener(_heartRateListener!);
  }

  void _removeHeartRateListener() {
    final listener = _heartRateListener;
    if (listener == null) return;
    HeartRateManager.instance.heartRate.removeListener(listener);
    _heartRateListener = null;
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _emitActiveState(),
    );
  }

  void _stopLiveTracking() {
    _removeHeartRateListener();
    _ticker?.cancel();
    _ticker = null;
  }

  void _emitActiveState({int? latestBpm}) {
    final active = _activeWorkout;
    if (active == null) {
      return;
    }

    final samples = active.samples;
    final stats = _calculateStats(samples);
    final duration = DateTime.now().difference(active.startTime);
    final int? mostRecent =
        latestBpm ?? (samples.isNotEmpty ? samples.last.bpm : null);

    currentWorkout.value = ActiveWorkoutState(
      id: active.id,
      workoutType: active.workoutType,
      startTime: active.startTime,
      duration: duration,
      latestBpm: mostRecent,
      avgBpm: stats.avg,
      maxBpm: stats.max,
      minBpm: stats.min,
      sampleCount: samples.length,
    );
  }

  _WorkoutStats _calculateStats(List<HeartRateSample> samples) {
    if (samples.isEmpty) {
      return const _WorkoutStats(avg: 0, max: 0, min: 0);
    }

    int max = samples.first.bpm;
    int min = samples.first.bpm;
    int total = 0;

    for (final sample in samples) {
      if (sample.bpm > max) max = sample.bpm;
      if (sample.bpm < min) min = sample.bpm;
      total += sample.bpm;
    }

    final avg = total ~/ samples.length;
    return _WorkoutStats(avg: avg, max: max, min: min);
  }
}

class _ActiveWorkout {
  _ActiveWorkout({
    required this.id,
    required this.workoutType,
    required this.startTime,
  });

  final String id;
  final String workoutType;
  final DateTime startTime;
  final List<HeartRateSample> samples = <HeartRateSample>[];
}

class _WorkoutStats {
  const _WorkoutStats({
    required this.avg,
    required this.max,
    required this.min,
  });

  final int avg;
  final int max;
  final int min;
}

class ActiveWorkoutState {
  const ActiveWorkoutState({
    required this.id,
    required this.workoutType,
    required this.startTime,
    required this.duration,
    required this.latestBpm,
    required this.avgBpm,
    required this.maxBpm,
    required this.minBpm,
    required this.sampleCount,
  });

  final String id;
  final String workoutType;
  final DateTime startTime;
  final Duration duration;
  final int? latestBpm;
  final int avgBpm;
  final int maxBpm;
  final int minBpm;
  final int sampleCount;
}
