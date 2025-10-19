import 'package:flutter/material.dart';

import '../models/heart_rate_sample.dart';
import '../services/heart_rate_manager.dart';
import '../widgets/heart_rate_chart.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final HeartRateManager _heartRateManager = HeartRateManager.instance;
  final GlobalKey<HeartRateChartState> _chartKey =
      GlobalKey<HeartRateChartState>();

  late DateTime _selectedDay;
  bool _selectionZoomEnabled = false;
  bool _chartInteractionLocked = false;

  @override
  void initState() {
    super.initState();
    _selectedDay = _floorToDay(DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: ValueListenableBuilder<HeartRateConnectionStatus>(
        valueListenable: _heartRateManager.connectionStatus,
        builder: (context, status, _) {
          return ValueListenableBuilder<int?>(
            valueListenable: _heartRateManager.heartRate,
            builder: (context, bpm, __) {
              return ValueListenableBuilder<List<HeartRateSample>>(
                valueListenable: _heartRateManager.heartRateHistory,
                builder: (context, history, ___) {
                  return ValueListenableBuilder<List<DateTime>>(
                    valueListenable: _heartRateManager.availableDays,
                    builder: (context, _, ____) {
                      final DateTime today = _floorToDay(DateTime.now());
                      final historySorted = List<HeartRateSample>.from(history)
                        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
                      final hasSamplesForSelected = historySorted.any(
                        (sample) => _isOnSelectedDay(
                          sample.timestamp,
                          selectedDay: _selectedDay,
                        ),
                      );
                      final bool isFuture = _selectedDay.isAfter(today);

                      if (!hasSamplesForSelected &&
                          !isFuture &&
                          historySorted.isNotEmpty) {
                        final earliest = _floorToDay(
                          historySorted.first.timestamp,
                        );
                        final latest = _floorToDay(
                          historySorted.last.timestamp,
                        );
                        if (_selectedDay.isBefore(earliest) ||
                            _selectedDay.isAfter(latest)) {
                          // Allow viewing any day; no adjustment needed.
                        }
                      }

                      return SingleChildScrollView(
                        physics: _chartInteractionLocked
                            ? const NeverScrollableScrollPhysics()
                            : const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 24,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildHeartRateCard(status: status, bpm: bpm),
                            const SizedBox(height: 20),
                            _buildChartCard(
                              context: context,
                              status: status,
                              history: historySorted,
                              displayDay: _selectedDay,
                              today: today,
                              resetZoom: () =>
                                  _chartKey.currentState?.resetView(),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildHeartRateCard({
    required HeartRateConnectionStatus status,
    required int? bpm,
  }) {
    final String display = bpm != null
        ? '$bpm bpm'
        : status == HeartRateConnectionStatus.connected
        ? '-- bpm'
        : '0 bpm';
    final Color statusColor;
    switch (status) {
      case HeartRateConnectionStatus.connected:
        statusColor = Colors.greenAccent;
        break;
      case HeartRateConnectionStatus.connecting:
        statusColor = Colors.orangeAccent;
        break;
      case HeartRateConnectionStatus.disconnected:
        statusColor = Colors.redAccent;
        break;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.redAccent.withAlpha(38),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.favorite,
                color: Colors.redAccent,
                size: 30,
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    display,
                    style: const TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        status == HeartRateConnectionStatus.connected
                            ? Icons.check_circle
                            : status == HeartRateConnectionStatus.connecting
                            ? Icons.sync
                            : Icons.cancel,
                        color: statusColor,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _statusLabel(status),
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  if (status != HeartRateConnectionStatus.connected)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text(
                        'Select your heart rate strap in Settings to start streaming.',
                        style: TextStyle(color: Colors.white60),
                      ),
                    ),
                ],
              ),
            ),
            if (status == HeartRateConnectionStatus.connecting)
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartCard({
    required BuildContext context,
    required HeartRateConnectionStatus status,
    required List<HeartRateSample> history,
    required DateTime displayDay,
    required DateTime today,
    required VoidCallback resetZoom,
  }) {
    final bool isToday = _isSameDay(displayDay, today);
    final bool isFuture = displayDay.isAfter(today);
    final bool hasSamples = history.any(
      (sample) => _isOnSelectedDay(sample.timestamp, selectedDay: displayDay),
    );
    final bool interactive = hasSamples && !isFuture;
    final message = isFuture
        ? 'This date is in the future.'
        : 'No data recorded on this day.';

    if (!interactive && _chartInteractionLocked) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _setChartInteractionLocked(false);
        }
      });
    }

    if (!interactive && _selectionZoomEnabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _selectionZoomEnabled = false;
          });
        }
      });
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () {
                    setState(() {
                      _selectedDay = _selectedDay.subtract(
                        const Duration(days: 1),
                      );
                      _chartKey.currentState?.resetView();
                    });
                  },
                  icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                ),
                Expanded(
                  child: Text(
                    _formatDayLabel(displayDay),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () {
                    setState(() {
                      _selectedDay = _selectedDay.add(const Duration(days: 1));
                      _chartKey.currentState?.resetView();
                    });
                  },
                  icon: const Icon(Icons.arrow_forward_ios, size: 18),
                ),
              ],
            ),
            if (!isToday)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    setState(() {
                      _selectedDay = today;
                      _chartKey.currentState?.resetView();
                    });
                  },
                  child: const Text('Jump to today'),
                ),
              ),
            const SizedBox(height: 16),
            SizedBox(
              height: 260,
              child: Listener(
                onPointerDown: interactive
                    ? (_) => _setChartInteractionLocked(true)
                    : null,
                onPointerUp: interactive
                    ? (_) => _setChartInteractionLocked(false)
                    : null,
                onPointerCancel: interactive
                    ? (_) => _setChartInteractionLocked(false)
                    : null,
                child: Stack(
                  children: [
                    Opacity(
                      opacity: interactive ? 1 : 0.25,
                      child: IgnorePointer(
                        ignoring: !interactive,
                        child: HeartRateChart(
                          key: _chartKey,
                          samples: history,
                          selectedDay: displayDay,
                          enableSelectionZoom:
                              interactive && _selectionZoomEnabled,
                          interactive: interactive,
                          onTrackballActive: _setChartInteractionLocked,
                        ),
                      ),
                    ),
                    if (!interactive)
                      Positioned.fill(
                        child: Center(
                          child: Text(
                            message,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (interactive) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _selectionZoomEnabled = !_selectionZoomEnabled;
                      });
                    },
                    icon: Icon(
                      _selectionZoomEnabled
                          ? Icons.crop_free
                          : Icons.touch_app_outlined,
                    ),
                    label: Text(
                      _selectionZoomEnabled
                          ? 'Selection zoom on'
                          : 'Selection zoom off',
                    ),
                  ),
                  TextButton.icon(
                    onPressed: resetZoom,
                    icon: const Icon(Icons.zoom_out_map, size: 16),
                    label: const Text('Reset'),
                  ),
                ],
              ),
            ],
            if (!hasSamples && !isFuture)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  status == HeartRateConnectionStatus.connected
                      ? 'No heart rate data for this day yet. Keep your monitor on to start logging.'
                      : 'Reconnect your monitor to start building your heart rate history.',
                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }

  DateTime _floorToDay(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  void _setChartInteractionLocked(bool locked) {
    if (_chartInteractionLocked == locked) return;
    setState(() {
      _chartInteractionLocked = locked;
    });
  }

  bool _isOnSelectedDay(DateTime timestamp, {required DateTime selectedDay}) {
    final dayStart = _floorToDay(selectedDay);
    final dayEnd = dayStart.add(const Duration(days: 1));
    return !timestamp.isBefore(dayStart) && timestamp.isBefore(dayEnd);
  }

  String _formatDayLabel(DateTime day) {
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final weekday = weekdays[(day.weekday - 1) % weekdays.length];
    final month = months[day.month - 1];
    return '$weekday, $month ${day.day}';
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static String _statusLabel(HeartRateConnectionStatus status) {
    switch (status) {
      case HeartRateConnectionStatus.connected:
        return 'Connected';
      case HeartRateConnectionStatus.connecting:
        return 'Connecting';
      case HeartRateConnectionStatus.disconnected:
        return 'Not connected';
    }
  }
}
