import 'dart:convert';

class WorkoutSession {
  const WorkoutSession({
    required this.id,
    required this.workoutType,
    required this.startTime,
    required this.endTime,
    required this.duration,
    required this.avgBpm,
    required this.maxBpm,
    required this.minBpm,
    required this.sampleCount,
    this.distanceMeters = 0,
    this.avgPaceSecondsPerKm = 0,
    this.calories = 0,
  });

  final String id;
  final String workoutType;
  final DateTime startTime;
  final DateTime endTime;
  final Duration duration;
  final int avgBpm;
  final int maxBpm;
  final int minBpm;
  final int sampleCount;
  final double distanceMeters;
  final double avgPaceSecondsPerKm;
  final int calories;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'workoutType': workoutType,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'durationMs': duration.inMilliseconds,
      'avgBpm': avgBpm,
      'maxBpm': maxBpm,
      'minBpm': minBpm,
      'sampleCount': sampleCount,
      'distanceMeters': distanceMeters,
      'avgPaceSecondsPerKm': avgPaceSecondsPerKm,
      'calories': calories,
    };
  }

  static WorkoutSession fromJson(Map<String, dynamic> json) {
    return WorkoutSession(
      id: json['id'] as String,
      workoutType: json['workoutType'] as String,
      startTime: DateTime.parse(json['startTime'] as String),
      endTime: DateTime.parse(json['endTime'] as String),
      duration: Duration(milliseconds: json['durationMs'] as int),
      avgBpm: json['avgBpm'] as int,
      maxBpm: json['maxBpm'] as int,
      minBpm: json['minBpm'] as int,
      sampleCount: json['sampleCount'] as int,
      distanceMeters: (json['distanceMeters'] as num?)?.toDouble() ?? 0,
      avgPaceSecondsPerKm:
          (json['avgPaceSecondsPerKm'] as num?)?.toDouble() ?? 0,
      calories: json['calories'] as int? ?? 0,
    );
  }

  static List<WorkoutSession> decodeList(String raw) {
    if (raw.isEmpty) return const [];
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((entry) => WorkoutSession.fromJson(entry as Map<String, dynamic>))
        .toList();
  }

  static String encodeList(List<WorkoutSession> sessions) {
    final encoded = sessions.map((session) => session.toJson()).toList();
    return jsonEncode(encoded);
  }
}
