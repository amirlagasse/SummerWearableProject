import 'dart:convert';

import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../models/heart_rate_sample.dart';
import '../services/heart_rate_manager.dart';
import '../widgets/heart_rate_chart.dart';
import 'full_screen_heart_rate_chart_page.dart';

enum DashboardWidgetType {
  heartSummary,
  heartChart,
  hrv,
  spo2,
  stepsChart,
}

enum DashboardRowLayout { split, single }

DashboardRowLayout _spanForType(DashboardWidgetType type) {
  switch (type) {
    case DashboardWidgetType.heartSummary:
    case DashboardWidgetType.hrv:
    case DashboardWidgetType.spo2:
      return DashboardRowLayout.split;
    case DashboardWidgetType.heartChart:
    case DashboardWidgetType.stepsChart:
      return DashboardRowLayout.single;
  }
}

class DashboardRow {
  DashboardRow({
    required this.layout,
    this.left,
    this.right,
  });

  DashboardRowLayout layout;
  DashboardWidgetType? left;
  DashboardWidgetType? right;
}

class DraggedDashboardItem {
    DraggedDashboardItem({
      required this.type,
      this.fromRow,
      this.fromSlot,
    });

    final DashboardWidgetType type;
    final int? fromRow;
    final int? fromSlot;
}

class SlotPosition {
  const SlotPosition(this.row, this.slot);
  final int row;
  final int slot;

  @override
  bool operator ==(Object other) {
    return other is SlotPosition && row == other.row && slot == other.slot;
  }

  @override
  int get hashCode => Object.hash(row, slot);
}

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
  bool _editing = false;
  SlotPosition? _hoverSlot;
  List<DashboardRow> _rows = [];

  static const String _layoutPrefsKey = 'dashboard_layout_v2';
  static const double _halfTileHeight = 200;

  @override
  void initState() {
    super.initState();
    _selectedDay = _floorToDay(DateTime.now());
    _rows = _defaultRows();
    _loadLayout();
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
                      final today = _floorToDay(DateTime.now());
                      final historySorted = List<HeartRateSample>.from(history)
                        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
                      final hasSamplesForSelected = historySorted.any(
                        (sample) => _isOnSelectedDay(
                          sample.timestamp,
                          selectedDay: _selectedDay,
                        ),
                      );
                      final bool isFuture = _selectedDay.isAfter(today);
                      final message = isFuture
                          ? 'This date is in the future.'
                          : 'No data recorded on this day.';

                      return Stack(
                        children: [
                          SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 24,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildDashboardGrid(
                                  status: status,
                                  bpm: bpm,
                                  history: historySorted,
                                  displayDay: _selectedDay,
                                  today: today,
                                  hasSamples: hasSamplesForSelected,
                                  isFuture: isFuture,
                                  message: message,
                                ),
                                const SizedBox(height: 24),
                                Center(
                                  child: OutlinedButton.icon(
                                    icon: Icon(
                                      _editing ? Icons.check : Icons.tune,
                                    ),
                                    label: Text(
                                      _editing
                                          ? 'Done Editing'
                                          : 'Edit Dashboard',
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _editing = !_editing;
                                        _hoverSlot = null;
                                      });
                                    },
                                  ),
                                ),
                                if (!hasSamplesForSelected && !isFuture)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 24),
                                    child: Text(
                                      status ==
                                              HeartRateConnectionStatus
                                                  .connected
                                          ? 'No heart rate data for this day yet. Keep your monitor on to start logging.'
                                          : 'Reconnect your monitor to start building your heart rate history.',
                                      style: const TextStyle(
                                        color: Colors.white60,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                if (_editing) ...[
                                  const SizedBox(height: 32),
                                  _buildLibrary(),
                                ],
                              ],
                            ),
                          ),
                        ],
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

  Widget _buildDashboardGrid({
    required HeartRateConnectionStatus status,
    required int? bpm,
    required List<HeartRateSample> history,
    required DateTime displayDay,
    required DateTime today,
    required bool hasSamples,
    required bool isFuture,
    required String message,
  }) {
    final children = <Widget>[];
    for (int i = 0; i < _rows.length; i++) {
      children.add(
        _buildRow(
          rowIndex: i,
          row: _rows[i],
          status: status,
          bpm: bpm,
          history: history,
          displayDay: displayDay,
          today: today,
          hasSamples: hasSamples,
          isFuture: isFuture,
          message: message,
        ),
      );
      if (_editing) {
        children.add(_buildGapTarget(i + 1));
      } else if (i != _rows.length - 1) {
        children.add(const SizedBox(height: 20));
      }
    }
    if (_editing && children.isEmpty) {
      children.add(_buildGapTarget(0));
    }
    return Column(children: children);
  }

  Widget _buildRow({
    required int rowIndex,
    required DashboardRow row,
    required HeartRateConnectionStatus status,
    required int? bpm,
    required List<HeartRateSample> history,
    required DateTime displayDay,
    required DateTime today,
    required bool hasSamples,
    required bool isFuture,
    required String message,
  }) {
    final widgets = <Widget>[];

    if (row.layout == DashboardRowLayout.single) {
      widgets.add(
        _buildSlot(
          rowIndex: rowIndex,
          slotIndex: 0,
          type: row.left,
          isHalf: false,
          status: status,
          bpm: bpm,
          history: history,
          displayDay: displayDay,
          today: today,
          hasSamples: hasSamples,
          isFuture: isFuture,
          message: message,
        ),
      );
    } else {
      widgets.add(
        Row(
          children: [
            Expanded(
              child: _buildSlot(
                rowIndex: rowIndex,
                slotIndex: 0,
                type: row.left,
                isHalf: true,
                status: status,
                bpm: bpm,
                history: history,
                displayDay: displayDay,
                today: today,
                hasSamples: hasSamples,
                isFuture: isFuture,
                message: message,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildSlot(
                rowIndex: rowIndex,
                slotIndex: 1,
                type: row.right,
                isHalf: true,
                status: status,
                bpm: bpm,
                history: history,
                displayDay: displayDay,
                today: today,
                hasSamples: hasSamples,
                isFuture: isFuture,
                message: message,
              ),
            ),
          ],
        ),
      );
    }

    return Column(children: widgets);
  }

  Widget _buildSlot({
    required int rowIndex,
    required int slotIndex,
    required DashboardWidgetType? type,
    required bool isHalf,
    required HeartRateConnectionStatus status,
    required int? bpm,
    required List<HeartRateSample> history,
    required DateTime displayDay,
    required DateTime today,
    required bool hasSamples,
    required bool isFuture,
    required String message,
  }) {
    Widget? baseWidget;
    if (type != null) {
      baseWidget = _buildWidgetForType(
        type: type,
        status: status,
        bpm: bpm,
        history: history,
        displayDay: displayDay,
        today: today,
        hasSamples: hasSamples,
        isFuture: isFuture,
        message: message,
        isHalf: isHalf,
      );
    }

    if (!_editing) {
      return baseWidget ?? const SizedBox.shrink();
    }

    return DragTarget<DraggedDashboardItem>(
      onWillAcceptWithDetails: (details) {
        if (slotIndex == 1 &&
            _rows[rowIndex].layout != DashboardRowLayout.split) {
          return false;
        }
        if (_spanForType(details.data.type) !=
            (_rows[rowIndex].layout == DashboardRowLayout.split
                ? DashboardRowLayout.split
                : DashboardRowLayout.single)) {
          return false;
        }
        setState(() => _hoverSlot = SlotPosition(rowIndex, slotIndex));
        return true;
      },
      onLeave: (_) {
        if (_hoverSlot == SlotPosition(rowIndex, slotIndex)) {
          setState(() => _hoverSlot = null);
        }
      },
      onAcceptWithDetails: (details) {
        setState(() => _hoverSlot = null);
        _handleDrop(details.data, rowIndex, slotIndex);
      },
      builder: (context, candidate, rejected) {
        final bool highlight = _hoverSlot == SlotPosition(rowIndex, slotIndex);
        if (type == null) {
          final double height = isHalf ? 160 : 200;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            height: height,
            padding: const EdgeInsets.all(2),
            child: DottedBorder(
              borderType: BorderType.RRect,
              radius: const Radius.circular(16),
              dashPattern: const [6, 4],
              color: highlight ? Colors.blueAccent : Colors.white38,
              strokeWidth: highlight ? 2 : 1.2,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: highlight
                      ? Colors.blueAccent.withValues(alpha: 0.08)
                      : const Color.fromRGBO(255, 255, 255, 0.03),
                ),
                alignment: Alignment.center,
                child: highlight
                    ? const Text(
                        'Drop widget here',
                        style: TextStyle(color: Colors.white70),
                      )
                    : const SizedBox.shrink(),
              ),
            ),
          );
        }

        final dragData = DraggedDashboardItem(
          type: type,
          fromRow: rowIndex,
          fromSlot: slotIndex,
        );
        final decorated = _wrapEditable(
          type: type,
          child: baseWidget!,
          isHalf: isHalf,
          highlight: highlight,
        );

        return LongPressDraggable<DraggedDashboardItem>(
          data: dragData,
          feedback: _buildDragFeedback(type),
          childWhenDragging: Opacity(
            opacity: 0.25,
            child: decorated,
          ),
          child: Stack(
            children: [
              decorated,
              Positioned(
                top: 8,
                left: 8,
                child: IconButton(
                  tooltip: 'Remove widget',
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => setState(
                    () => _removeWidget(rowIndex, slotIndex),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _wrapEditable({
    required DashboardWidgetType type,
    required Widget child,
    required bool isHalf,
    required bool highlight,
  }) {
    if (!_editing) return child;
    final radius = BorderRadius.circular(18);
    return DottedBorder(
      borderType: BorderType.RRect,
      radius: const Radius.circular(18),
      dashPattern: highlight ? const [8, 3] : const [6, 4],
      color: highlight ? Colors.blueAccent : Colors.white30,
      strokeWidth: highlight ? 2 : 1.3,
      child: ClipRRect(
        borderRadius: radius,
        child: child,
      ),
    );
  }

  Widget _buildWidgetForType({
    required DashboardWidgetType type,
    required HeartRateConnectionStatus status,
    required int? bpm,
    required List<HeartRateSample> history,
    required DateTime displayDay,
    required DateTime today,
    required bool hasSamples,
    required bool isFuture,
    required String message,
    required bool isHalf,
  }) {
    switch (type) {
      case DashboardWidgetType.heartSummary:
        return _buildHeartSummaryCard(status: status, bpm: bpm);
      case DashboardWidgetType.heartChart:
        return _buildHeartChartTile(
          history: history,
          displayDay: displayDay,
          today: today,
          hasSamples: hasSamples,
          isFuture: isFuture,
          message: message,
        );
      case DashboardWidgetType.hrv:
        return _buildMetricCard(
          title: 'HRV',
          value: '48 ms',
          subtitle: '7-day average',
          icon: Icons.auto_awesome,
          accent: Colors.purpleAccent,
        );
      case DashboardWidgetType.spo2:
        return _buildMetricCard(
          title: 'SpO₂',
          value: '97%',
          subtitle: 'Resting average',
          icon: Icons.water_drop,
          accent: Colors.lightBlueAccent,
        );
      case DashboardWidgetType.stepsChart:
        return _buildStepsChartTile();
    }
  }

  Widget _buildHeartSummaryCard({
    required HeartRateConnectionStatus status,
    required int? bpm,
  }) {
    final String display = bpm != null
        ? '$bpm'
        : status == HeartRateConnectionStatus.connected
            ? '--'
            : '0';
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

    return SizedBox(
      height: _halfTileHeight,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.favorite,
                      color: Colors.redAccent,
                      size: 26,
                    ),
                  ),
                  const Spacer(),
                  if (status != HeartRateConnectionStatus.connected)
                    IconButton(
                      icon: const Icon(
                        Icons.info_outline,
                        size: 20,
                        color: Colors.white70,
                      ),
                      onPressed: () => _showConnectionHelp(context),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    display,
                    style: const TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Padding(
                    padding: EdgeInsets.only(bottom: 6),
                    child: Text(
                      'bpm',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeartChartTile({
    required List<HeartRateSample> history,
    required DateTime displayDay,
    required DateTime today,
    required bool hasSamples,
    required bool isFuture,
    required String message,
  }) {
    final bool interactive = hasSamples && !isFuture;
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
            if (!_isSameDay(displayDay, today))
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
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Opacity(
                      opacity: interactive ? 1 : 0.25,
                      child: HeartRateChart(
                        key: _chartKey,
                        samples: history,
                        selectedDay: displayDay,
                        interactive: false,
                        enableCursor: false,
                      ),
                    ),
                  ),
                  if (interactive)
                    Positioned(
                      bottom: 36,
                      right: 16,
                      child: IconButton(
                        tooltip: 'Fullscreen',
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black45,
                        ),
                        icon: const Icon(Icons.fullscreen, color: Colors.white),
                        onPressed: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => FullScreenHeartRateChartPage(
                                samples: history,
                                selectedDay: displayDay,
                              ),
                            ),
                          );
                        },
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
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    String? subtitle,
    required IconData icon,
    required Color accent,
  }) {
    return SizedBox(
      height: _halfTileHeight,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: accent),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 13,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepsChartTile() {
    final data = <_StepPoint>[
      _StepPoint(6, 1200),
      _StepPoint(8, 2400),
      _StepPoint(10, 4100),
      _StepPoint(12, 5200),
      _StepPoint(14, 6200),
      _StepPoint(16, 7800),
      _StepPoint(18, 9100),
      _StepPoint(20, 10200),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Steps',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 220,
              child: SfCartesianChart(
                plotAreaBorderWidth: 0,
                primaryXAxis: NumericAxis(
                  minimum: 6,
                  maximum: 22,
                  interval: 2,
                  labelFormat: '{value}:00',
                  majorGridLines: const MajorGridLines(width: 0.2),
                ),
                primaryYAxis: NumericAxis(
                  minimum: 0,
                  maximum: 12000,
                  interval: 3000,
                  majorGridLines: const MajorGridLines(width: 0.2),
                  labelFormat: '{value}',
                ),
                series: <CartesianSeries<_StepPoint, num>>[
                  ColumnSeries<_StepPoint, num>(
                    dataSource: data,
                    xValueMapper: (point, _) => point.hour,
                    yValueMapper: (point, _) => point.steps,
                    borderRadius: BorderRadius.circular(6),
                    color: const Color(0xFF4A90E2),
                    width: 0.4,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGapTarget(int insertIndex) {
    return DragTarget<DraggedDashboardItem>(
      onWillAcceptWithDetails: (details) {
        setState(() => _hoverSlot = SlotPosition(insertIndex, -1));
        return true;
      },
      onLeave: (_) {
        if (_hoverSlot == SlotPosition(insertIndex, -1)) {
          setState(() => _hoverSlot = null);
        }
      },
      onAcceptWithDetails: (details) {
        final data = details.data;
        setState(() {
          _hoverSlot = null;
          final layout = _spanForType(data.type);
          final newRow = DashboardRow(
            layout: layout,
            left: data.type,
            right: layout == DashboardRowLayout.split ? null : null,
          );
          _rows.insert(insertIndex, newRow);
          if (data.fromRow != null && data.fromSlot != null) {
            _removeWidget(data.fromRow!, data.fromSlot!, cleanup: false);
          }
          _cleanupRows();
        });
      },
      builder: (context, candidate, rejected) {
        final bool show = _hoverSlot == SlotPosition(insertIndex, -1);
        return AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: show ? 24 : 12,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: show
                ? Colors.blueAccent.withValues(alpha: 0.12)
                : Colors.transparent,
          ),
        );
      },
    );
  }

  Widget _buildLibrary() {
    final available = DashboardWidgetType.values
        .where((type) => !_isTypePresent(type))
        .toList();
    return DragTarget<DraggedDashboardItem>(
      onWillAcceptWithDetails: (details) => true,
      onAcceptWithDetails: (details) {
        if (details.data.fromRow != null && details.data.fromSlot != null) {
          _removeWidget(details.data.fromRow!, details.data.fromSlot!);
        }
      },
      builder: (context, candidate, rejected) {
        final bool hovering = candidate.isNotEmpty;
        return DottedBorder(
          borderType: BorderType.RRect,
          radius: const Radius.circular(18),
          dashPattern: const [8, 4],
          color: hovering ? Colors.blueAccent : Colors.white30,
          strokeWidth: 1.2,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C1C),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Available widgets',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 14),
                if (available.isEmpty)
                  const Text(
                    'All widgets are already on the dashboard.',
                    style: TextStyle(color: Colors.white38),
                  )
                else
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: available
                        .map(
                          (type) => _buildLibraryChip(
                            type: type,
                            disabled: false,
                          ),
                        )
                        .toList(),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLibraryChip({
    required DashboardWidgetType type,
    required bool disabled,
  }) {
    final chip = Container(
      width: 150,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF232323),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          Icon(
            _iconForType(type),
            color: disabled ? Colors.white30 : Colors.blueAccent,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _labelForType(type),
              style: TextStyle(
                color: disabled ? Colors.white30 : Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (disabled) {
      return Opacity(opacity: 0.35, child: chip);
    }

    return LongPressDraggable<DraggedDashboardItem>(
      data: DraggedDashboardItem(type: type),
      feedback: _buildDragFeedback(type),
      child: chip,
    );
  }

  void _handleDrop(
    DraggedDashboardItem data,
    int targetRow,
    int targetSlot,
  ) {
    setState(() {
      if (data.fromRow != null && data.fromSlot != null) {
        _removeWidget(data.fromRow!, data.fromSlot!, cleanup: false);
      }
      final row = _rows[targetRow];
      if (targetSlot == 0) {
        row.left = data.type;
        if (row.layout == DashboardRowLayout.single) {
          row.right = null;
        }
      } else {
        row.right = data.type;
      }
      _cleanupRows();
    });
  }

  void _removeWidget(int rowIndex, int slotIndex, {bool cleanup = true}) {
    final row = _rows[rowIndex];
    if (slotIndex == 0) {
      row.left = null;
      if (row.layout == DashboardRowLayout.single) {
        row.right = null;
      }
    } else {
      row.right = null;
    }
    if (cleanup) {
      _cleanupRows();
    }
  }

  void _cleanupRows() {
    for (final row in _rows) {
      if (row.layout == DashboardRowLayout.split &&
          row.left == null &&
          row.right != null) {
        row.left = row.right;
        row.right = null;
      }
    }
    _rows.removeWhere((row) {
      if (row.layout == DashboardRowLayout.single) {
        return row.left == null;
      }
      return row.left == null && row.right == null;
    });
    if (_rows.isEmpty) {
      _rows = _defaultRows();
    }
    _persistLayout();
  }

  Future<void> _persistLayout() async {
    final prefs = await SharedPreferences.getInstance();
    final payload = _rows
        .map(
          (row) => {
            'layout': row.layout.name,
            'left': row.left?.name,
            'right': row.right?.name,
          },
        )
        .toList();
    await prefs.setString(_layoutPrefsKey, jsonEncode(payload));
  }

  Future<void> _loadLayout() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_layoutPrefsKey);
    if (raw == null) return;
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      final loadedRows = decoded.map((entry) {
        final map = entry as Map<String, dynamic>;
        final layout = DashboardRowLayout.values.firstWhere(
          (value) => value.name == map['layout'],
          orElse: () => DashboardRowLayout.single,
        );
        DashboardWidgetType? decodeType(String? value) => value == null
            ? null
            : DashboardWidgetType.values.firstWhere(
                (t) => t.name == value,
                orElse: () => DashboardWidgetType.heartSummary,
              );
        return DashboardRow(
          layout: layout,
          left: decodeType(map['left'] as String?),
          right: decodeType(map['right'] as String?),
        );
      }).toList();
      if (loadedRows.isNotEmpty && mounted) {
        setState(() {
          _rows = loadedRows;
        });
      }
    } catch (_) {
      // ignore malformed preferences
    }
  }

  List<DashboardRow> _defaultRows() => [
        DashboardRow(
          layout: DashboardRowLayout.split,
          left: DashboardWidgetType.heartSummary,
          right: null,
        ),
        DashboardRow(
          layout: DashboardRowLayout.single,
          left: DashboardWidgetType.heartChart,
          right: null,
        ),
      ];

  bool _isTypePresent(DashboardWidgetType type) {
    for (final row in _rows) {
      if (row.left == type || row.right == type) return true;
    }
    return false;
  }

  Widget _buildDragFeedback(DashboardWidgetType type) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 160,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF1F1F1F),
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Colors.black54,
              blurRadius: 12,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(
              _iconForType(type),
              color: Colors.blueAccent,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _labelForType(type),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showConnectionHelp(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Connect Your Strap'),
        content: const Text(
          'Open Settings > Heart Rate Strap and select your device to start streaming data.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  DateTime _floorToDay(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  bool _isOnSelectedDay(DateTime timestamp, {required DateTime selectedDay}) {
    final dayStart = _floorToDay(selectedDay);
    final dayEnd = dayStart.add(const Duration(days: 1));
    return !timestamp.isBefore(dayStart) && timestamp.isBefore(dayEnd);
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

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

  static String _statusLabel(HeartRateConnectionStatus status) {
    switch (status) {
      case HeartRateConnectionStatus.connected:
        return 'Connected';
      case HeartRateConnectionStatus.connecting:
        return 'Connecting';
      case HeartRateConnectionStatus.disconnected:
        return 'Disconnected';
    }
  }

  IconData _iconForType(DashboardWidgetType type) {
    switch (type) {
      case DashboardWidgetType.heartSummary:
        return Icons.favorite;
      case DashboardWidgetType.heartChart:
        return Icons.show_chart;
      case DashboardWidgetType.hrv:
        return Icons.auto_awesome;
      case DashboardWidgetType.spo2:
        return Icons.water_drop;
      case DashboardWidgetType.stepsChart:
        return Icons.directions_walk;
    }
  }

  String _labelForType(DashboardWidgetType type) {
    switch (type) {
      case DashboardWidgetType.heartSummary:
        return 'Heart Summary';
      case DashboardWidgetType.heartChart:
        return 'Heart Chart';
      case DashboardWidgetType.hrv:
        return 'HRV';
      case DashboardWidgetType.spo2:
        return 'SpO₂';
      case DashboardWidgetType.stepsChart:
        return 'Steps Chart';
    }
  }
}

class _StepPoint {
  const _StepPoint(this.hour, this.steps);
  final int hour;
  final int steps;
}
