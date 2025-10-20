import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../widgets/app_snackbar.dart';
import 'package:intl/intl.dart';

import '../constants/workout_definitions.dart';
import '../models/workout_session.dart';
import '../services/heart_rate_manager.dart';
import '../services/workout_manager.dart';

class WorkoutLogScreen extends StatefulWidget {
  const WorkoutLogScreen({super.key});

  @override
  State<WorkoutLogScreen> createState() => _WorkoutLogScreenState();
}

class _WorkoutLogScreenState extends State<WorkoutLogScreen> {
  final WorkoutManager _workoutManager = WorkoutManager.instance;
  final HeartRateManager _heartRateManager = HeartRateManager.instance;

  String _selectedWorkout = workoutDefinitions.first.name;
  String? _expandedSessionId;
  final Map<String, Color> _workoutColors = <String, Color>{};
  bool _recentlyDeletedExpanded = false;

  @override
  void initState() {
    super.initState();
    _loadWorkoutColors();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadWorkoutColors();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Workouts')),
      body: SafeArea(
        child: ValueListenableBuilder<ActiveWorkoutState?>(
          valueListenable: _workoutManager.currentWorkout,
          builder: (context, activeWorkout, _) {
            return ValueListenableBuilder<List<WorkoutSession>>(
              valueListenable: _workoutManager.sessions,
              builder: (context, sessions, __) {
                return ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    _buildStatusCard(activeWorkout),
                    const SizedBox(height: 24),
                    Text(
                      'Workout history',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildHistorySection(sessions),
                    const SizedBox(height: 20),
                    ValueListenableBuilder<List<WorkoutSession>>(
                      valueListenable: _workoutManager.recentlyDeleted,
                      builder: (context, deleted, ____) {
                        if (deleted.isEmpty) {
                          return const SizedBox.shrink();
                        }
                        return _buildRecentlyDeleted(deleted);
                      },
                    ),
                    const SizedBox(height: 80),
                  ],
                );
              },
            );
          },
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: ValueListenableBuilder<ActiveWorkoutState?>(
          valueListenable: _workoutManager.currentWorkout,
          builder: (context, activeWorkout, _) {
            final bool isActive = activeWorkout != null;
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: ElevatedButton.icon(
                icon: Icon(isActive ? Icons.stop : Icons.play_arrow),
                label: Text(isActive ? 'Stop workout' : 'Start workout'),
                onPressed: isActive ? _confirmStopWorkout : _startWorkout,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  textStyle: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildStatusCard(ActiveWorkoutState? active) {
    if (active != null) {
      final bool hasSamples = active.sampleCount > 0;
      final latestBpm = active.latestBpm != null
          ? '${active.latestBpm} bpm'
          : '--';
      final avgBpm = hasSamples ? '${active.avgBpm} bpm' : '--';
      final maxBpm = hasSamples ? '${active.maxBpm} bpm' : '--';
      final minBpm = hasSamples ? '${active.minBpm} bpm' : '--';
      final duration = _formatDuration(active.duration);
      final Color accentColor = _colorForWorkout(active.workoutType);
      final Color bubbleColor = accentColor.withAlpha((0.18 * 255).round());
      final Color tileColor = accentColor.withAlpha((0.14 * 255).round());

      return Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: tileColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.fiber_smart_record, color: accentColor),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Recording ${active.workoutType}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Elapsed • $duration',
                          style: const TextStyle(color: Colors.white60),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: bubbleColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      latestBpm,
                      style: TextStyle(
                        color: accentColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 24,
                runSpacing: 12,
                children: [
                  _statTile('Average HR', avgBpm),
                  _statTile('Max HR', maxBpm),
                  _statTile('Min HR', minBpm),
                  _statTile('Samples', '${active.sampleCount}'),
                ],
              ),
            ],
          ),
        ),
      );
    }

    final Color selectedColor = _colorForWorkout(_selectedWorkout);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: selectedColor.withAlpha((0.18 * 255).round()),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.flag, color: selectedColor),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Ready for your next session',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Select a workout and tap start to begin tracking.',
                        style: TextStyle(color: Colors.white60),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<String>(
              initialValue: _selectedWorkout,
              decoration: InputDecoration(
                labelText: 'Workout type',
                filled: true,
                fillColor: selectedColor.withAlpha((0.08 * 255).round()),
              ),
              items: workoutDefinitions.map((definition) {
                final color = _colorForWorkout(definition.name);
                return DropdownMenuItem<String>(
                  value: definition.name,
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 10,
                        backgroundColor: color,
                        child: Icon(
                          definition.icon,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(definition.name),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _selectedWorkout = value;
                });
              },
            ),
            const SizedBox(height: 16),
            ValueListenableBuilder<HeartRateConnectionStatus>(
              valueListenable: _heartRateManager.connectionStatus,
              builder: (context, status, __) {
                final statusText = _connectionLabel(status);
                final statusColor =
                    status == HeartRateConnectionStatus.connected
                    ? Colors.greenAccent
                    : status == HeartRateConnectionStatus.connecting
                    ? Colors.orangeAccent
                    : Colors.white54;
                return Row(
                  children: [
                    Icon(
                      status == HeartRateConnectionStatus.connected
                          ? Icons.check_circle
                          : status == HeartRateConnectionStatus.connecting
                          ? Icons.sync
                          : Icons.bluetooth_disabled,
                      size: 18,
                      color: statusColor,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Strap status: $statusText',
                      style: TextStyle(color: statusColor),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistorySection(List<WorkoutSession> sessions) {
    if (sessions.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.auto_graph, size: 42, color: Colors.white38),
              SizedBox(height: 12),
              Text(
                'No workouts saved yet',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 6),
              Text(
                'Finish a session and choose save to see it appear here.',
                style: TextStyle(color: Colors.white54),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: sessions.length,
        separatorBuilder: (_, __) =>
            const Divider(height: 1, color: Colors.white12),
        itemBuilder: (context, index) {
          final session = sessions[index];
          return _buildDismissibleSession(session);
        },
      ),
    );
  }

  Widget _buildRecentlyDeleted(List<WorkoutSession> sessions) {
    final count = sessions.length;
    final theme = Theme.of(context);

    return Card(
      color: Colors.redAccent.withAlpha((0.08 * 255).round()),
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: _recentlyDeletedExpanded,
          onExpansionChanged: (expanded) {
            setState(() => _recentlyDeletedExpanded = expanded);
          },
          iconColor: Colors.redAccent,
          collapsedIconColor: Colors.redAccent,
          title: Row(
            children: [
              const Icon(Icons.delete_outline, color: Colors.redAccent),
              const SizedBox(width: 12),
              Text(
                'Recently deleted',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withAlpha((0.2 * 255).round()),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$count',
                  style: const TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          children: [
            const SizedBox(height: 8),
            ...sessions.map((session) {
              final color = _colorForWorkout(
                session.workoutType,
              ).withAlpha((0.18 * 255).round());
              final startLabel = DateFormat(
                'MMM d, yyyy • h:mm a',
              ).format(session.startTime);
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            session.workoutType,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () => _restoreWorkout(session),
                          icon: const Icon(Icons.restore_outlined),
                          label: const Text('Restore'),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      startLabel,
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Avg ${session.avgBpm} bpm • Max ${session.maxBpm} • ${_formatDuration(session.duration)}',
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              );
            }),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                  side: const BorderSide(color: Colors.redAccent),
                ),
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Empty recently deleted'),
                      content: const Text(
                        'Permanently remove all recently deleted workouts?',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          child: const Text('Delete all'),
                        ),
                      ],
                    ),
                  );

                  if (confirm == true) {
                    await _workoutManager.clearRecentlyDeleted();
                    if (!mounted) return;
                    showAppSnackBar(
                      context,
                      'Recently deleted cleared',
                      icon: Icons.delete_sweep_outlined,
                    );
                  }
                },
                icon: const Icon(Icons.delete_sweep_outlined),
                label: const Text('Empty recently deleted'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionBody(WorkoutSession session) {
    final List<MapEntry<String, String>> stats = [
      MapEntry('Average HR', '${session.avgBpm} bpm'),
      MapEntry('Max HR', '${session.maxBpm} bpm'),
      MapEntry('Min HR', '${session.minBpm} bpm'),
      MapEntry('Samples', '${session.sampleCount}'),
      MapEntry('Duration', _formatDuration(session.duration)),
      MapEntry(
        'Distance',
        '${(session.distanceMeters / 1000).toStringAsFixed(2)} km',
      ),
      MapEntry(
        'Avg pace',
        session.avgPaceSecondsPerKm > 0
            ? _formatPace(session.avgPaceSecondsPerKm)
            : '--',
      ),
      MapEntry('Calories', '${session.calories} kcal'),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Wrap(
        spacing: 24,
        runSpacing: 12,
        children: stats.map((stat) => _statTile(stat.key, stat.value)).toList(),
      ),
    );
  }

  Future<void> _startWorkout() async {
    await _workoutManager.startWorkout(_selectedWorkout);
    if (!mounted) return;
    showAppSnackBar(
      context,
      'Started $_selectedWorkout session',
      icon: Icons.play_arrow,
    );
  }

  Future<void> _restoreWorkout(WorkoutSession session) async {
    await _workoutManager.restoreSession(session.id);
    if (!mounted) return;
    showAppSnackBar(context, 'Workout restored', icon: Icons.restore_outlined);
  }

  Future<void> _confirmStopWorkout() async {
    final bool? save = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Finish workout'),
        content: const Text('Would you like to save this workout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Discard'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (save == null) return;
    await _workoutManager.stopWorkout(save: save);
    if (!mounted) return;
    if (save) {
      showAppSnackBar(
        context,
        'Workout saved',
        icon: Icons.check_circle_outline,
      );
    }
  }

  Future<bool> _confirmDeleteSession(WorkoutSession session) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete workout'),
        content: Text(
          'Delete ${session.workoutType} from ${DateFormat('MMM d, yyyy • h:mm a').format(session.startTime)}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  Widget _buildSessionHeader(
    WorkoutSession session,
    bool isExpanded,
    Color accent,
  ) {
    final startLabel = DateFormat(
      'MMM d, yyyy • h:mm a',
    ).format(session.startTime);
    final duration = _formatDuration(session.duration);
    final definition = workoutDefinitions.firstWhere(
      (def) => def.name == session.workoutType,
      orElse: () => workoutDefinitions.last,
    );

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: CircleAvatar(
        backgroundColor: accent.withAlpha((0.18 * 255).round()),
        child: Icon(definition.icon, color: accent),
      ),
      title: Text(
        session.workoutType,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text('$startLabel\nDuration • $duration'),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '${session.avgBpm} avg bpm',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${session.maxBpm} / ${session.minBpm}',
                style: const TextStyle(color: Colors.white60, fontSize: 12),
              ),
              const SizedBox(width: 8),
              Icon(
                isExpanded ? Icons.expand_less : Icons.expand_more,
                size: 20,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDismissibleSession(WorkoutSession session) {
    final bool isExpanded = _expandedSessionId == session.id;
    final Color accent = _colorForWorkout(session.workoutType);
    final Color tileColor = accent.withAlpha((0.12 * 255).round());

    return Dismissible(
      key: ValueKey(session.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => _confirmDeleteSession(session),
      onDismissed: (_) async {
        if (_expandedSessionId == session.id) {
          setState(() => _expandedSessionId = null);
        }
        await _workoutManager.deleteSession(session.id);
        if (!mounted) return;
        showAppSnackBar(context, 'Workout deleted', icon: Icons.delete_outline);
      },
      background: Container(color: Colors.transparent),
      secondaryBackground: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        color: Colors.redAccent.withAlpha((0.18 * 255).round()),
        child: const Icon(Icons.delete, color: Colors.redAccent),
      ),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: tileColor,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () {
                setState(() {
                  _expandedSessionId = isExpanded ? null : session.id;
                });
              },
              child: _buildSessionHeader(session, isExpanded, accent),
            ),
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: _buildSessionBody(session),
              crossFadeState: isExpanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 200),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadWorkoutColors() async {
    final prefs = await SharedPreferences.getInstance();
    final map = <String, Color>{};
    for (final definition in workoutDefinitions) {
      final stored = prefs.getString('color_${definition.name}');
      final hex = _extractHex(stored);
      if (hex != null) {
        map[definition.name] = _colorFromHex(hex);
      }
    }
    if (!mounted) return;
    if (!mapEquals(_workoutColors, map)) {
      setState(() {
        _workoutColors
          ..clear()
          ..addAll(map);
      });
    }
  }

  Color _colorForWorkout(String name) {
    return _workoutColors[name] ?? Colors.blueGrey;
  }

  String? _extractHex(String? value) {
    if (value == null) return null;
    final match = RegExp(r'#([0-9A-Fa-f]{6})').firstMatch(value);
    if (match == null) return null;
    return '#${match.group(1)!.toUpperCase()}';
  }

  Color _colorFromHex(String hex) {
    final buffer = StringBuffer();
    final sanitized = hex.replaceFirst('#', '');
    if (sanitized.length == 6) {
      buffer.write('FF');
    }
    buffer.write(sanitized);
    return Color(int.parse(buffer.toString(), radix: 16));
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    final buffer = StringBuffer();
    if (hours > 0) {
      buffer.write('${hours.toString().padLeft(2, '0')}:');
    }
    buffer.write('${minutes.toString().padLeft(2, '0')}:');
    buffer.write(seconds.toString().padLeft(2, '0'));
    return buffer.toString();
  }

  String _formatPace(double secondsPerKm) {
    final totalSeconds = secondsPerKm.round();
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')} /km';
  }

  String _connectionLabel(HeartRateConnectionStatus status) {
    switch (status) {
      case HeartRateConnectionStatus.connected:
        return 'Connected';
      case HeartRateConnectionStatus.connecting:
        return 'Connecting...';
      case HeartRateConnectionStatus.disconnected:
        return 'Not connected';
    }
  }

  Widget _statTile(String label, String value) {
    return SizedBox(
      width: 140,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
