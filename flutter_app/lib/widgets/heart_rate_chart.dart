import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../models/heart_rate_sample.dart';

class HeartRateChart extends StatefulWidget {
  const HeartRateChart({
    super.key,
    required this.samples,
    required this.selectedDay,
    required this.enableSelectionZoom,
    required this.interactive,
    this.onTrackballActive,
  });

  final List<HeartRateSample> samples;
  final DateTime selectedDay;
  final bool enableSelectionZoom;
  final bool interactive;
  final ValueChanged<bool>? onTrackballActive;

  @override
  HeartRateChartState createState() => HeartRateChartState();
}

class HeartRateChartState extends State<HeartRateChart> {
  ZoomPanBehavior _zoomPanBehavior = ZoomPanBehavior(zoomMode: ZoomMode.x);
  DateTimeIntervalType _intervalType = DateTimeIntervalType.hours;
  double _interval = 1;

  Offset? _cursorPosition;
  HeartRateSample? _cursorSample;

  bool get _cursorActive => _cursorSample != null;

  @override
  void didUpdateWidget(covariant HeartRateChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedDay != widget.selectedDay) {
      _clearCursor();
      _intervalType = DateTimeIntervalType.hours;
      _interval = 1;
    }
  }

  void resetView() {
    _zoomPanBehavior.reset();
    setState(() {
      _intervalType = DateTimeIntervalType.hours;
      _interval = 1;
    });
    _clearCursor();
  }

  void _clearCursor() {
    if (!_cursorActive) return;
    setState(() {
      _cursorSample = null;
      _cursorPosition = null;
    });
    widget.onTrackballActive?.call(false);
  }

  void _setCursor(HeartRateSample sample, double dx) {
    final bool wasActive = _cursorActive;
    setState(() {
      _cursorSample = sample;
      _cursorPosition = Offset(dx, 0);
    });
    if (!wasActive) {
      widget.onTrackballActive?.call(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dayStart = DateTime(
      widget.selectedDay.year,
      widget.selectedDay.month,
      widget.selectedDay.day,
    );
    final dayEnd = dayStart.add(const Duration(days: 1));
    final points = widget.samples
        .where(
          (sample) =>
              !sample.timestamp.isBefore(dayStart) &&
              sample.timestamp.isBefore(dayEnd),
        )
        .toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final xAxis = DateTimeAxis(
          minimum: dayStart,
          maximum: dayEnd,
          intervalType: _intervalType,
          interval: _interval,
          dateFormat: _buildDateFormat(),
          majorGridLines: const MajorGridLines(width: 0.5),
          axisLine: const AxisLine(width: 0),
          edgeLabelPlacement: EdgeLabelPlacement.shift,
          labelRotation: _labelRotation(),
        );

        final yAxis = NumericAxis(
          title: AxisTitle(text: 'BPM'),
          minimum: 40,
          maximum: 200,
          majorGridLines: const MajorGridLines(width: 0.5),
          axisLine: const AxisLine(width: 0),
          labelFormat: '{value}',
        );

        _zoomPanBehavior = ZoomPanBehavior(
          zoomMode: ZoomMode.x,
          enablePanning: widget.interactive && !_cursorActive,
          enablePinching:
              widget.interactive &&
              !widget.enableSelectionZoom &&
              !_cursorActive,
          enableDoubleTapZooming: widget.interactive && !_cursorActive,
          enableSelectionZooming:
              widget.interactive &&
              widget.enableSelectionZoom &&
              !_cursorActive,
        );

        final chart = SfCartesianChart(
          primaryXAxis: xAxis,
          primaryYAxis: yAxis,
          plotAreaBorderWidth: 0,
          zoomPanBehavior: widget.interactive ? _zoomPanBehavior : null,
          series: <CartesianSeries<HeartRateSample, DateTime>>[
            LineSeries<HeartRateSample, DateTime>(
              dataSource: points,
              xValueMapper: (sample, _) => sample.timestamp,
              yValueMapper: (sample, _) => sample.bpm,
              color: Theme.of(context).colorScheme.secondary,
              width: 2,
              markerSettings: MarkerSettings(
                isVisible: points.length < 90,
                width: 4,
                height: 4,
              ),
            ),
          ],
          onActualRangeChanged: (args) {
            if (!widget.interactive) return;
            final min = args.visibleMin;
            final max = args.visibleMax;
            if (min is DateTime && max is DateTime) {
              _updateAxisForRange(max.difference(min));
            }
          },
        );

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (details) {
            if (!widget.interactive || points.isEmpty) return;
            final local = details.localPosition;
            if (_cursorActive) {
              _clearCursor();
            } else {
              _updateCursor(local.dx, constraints.maxWidth, dayStart, points);
            }
          },
          onPanUpdate: (details) {
            if (!widget.interactive || !_cursorActive || points.isEmpty) return;
            _updateCursor(
              details.localPosition.dx,
              constraints.maxWidth,
              dayStart,
              points,
            );
          },
          child: Stack(
            children: [
              chart,
              if (_cursorActive && _cursorPosition != null)
                CustomPaint(
                  size: Size(constraints.maxWidth, constraints.maxHeight),
                  painter: _CursorPainter(
                    x: _cursorPosition!.dx,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                ),
              if (_cursorActive &&
                  _cursorSample != null &&
                  _cursorPosition != null)
                Positioned(
                  top: 12,
                  left: (_cursorPosition!.dx - 80).clamp(
                    12,
                    constraints.maxWidth - 92,
                  ),
                  child: _CursorLabel(sample: _cursorSample!),
                ),
            ],
          ),
        );
      },
    );
  }

  void _updateCursor(
    double dx,
    double width,
    DateTime dayStart,
    List<HeartRateSample> samples,
  ) {
    if (width <= 0 || samples.isEmpty) return;
    final double clampedDx = dx.clamp(0.0, width).toDouble();
    final totalMs = const Duration(days: 1).inMilliseconds;
    final double fraction = (clampedDx / width).clamp(0.0, 1.0).toDouble();
    final targetTime = dayStart.add(
      Duration(milliseconds: (fraction * totalMs).round()),
    );

    HeartRateSample closest = samples.first;
    int minDiff = (closest.timestamp.difference(
      targetTime,
    )).abs().inMilliseconds;
    for (final sample in samples.skip(1)) {
      final diff = (sample.timestamp.difference(
        targetTime,
      )).abs().inMilliseconds;
      if (diff < minDiff) {
        closest = sample;
        minDiff = diff;
      }
    }

    if (!_cursorActive) {
      _setCursor(closest, clampedDx);
    } else {
      setState(() {
        _cursorSample = closest;
        _cursorPosition = Offset(clampedDx, 0);
      });
    }
  }

  void _updateAxisForRange(Duration range) {
    final totalSeconds = range.inSeconds.abs();
    DateTimeIntervalType type;
    double interval;

    if (totalSeconds <= 30) {
      type = DateTimeIntervalType.seconds;
      interval = 1;
    } else if (totalSeconds <= 120) {
      type = DateTimeIntervalType.seconds;
      interval = 5;
    } else if (totalSeconds <= 300) {
      type = DateTimeIntervalType.seconds;
      interval = 15;
    } else if (totalSeconds <= 600) {
      type = DateTimeIntervalType.seconds;
      interval = 30;
    } else if (totalSeconds <= 1800) {
      type = DateTimeIntervalType.minutes;
      interval = 1;
    } else if (totalSeconds <= 3600) {
      type = DateTimeIntervalType.minutes;
      interval = 5;
    } else if (totalSeconds <= 7200) {
      type = DateTimeIntervalType.minutes;
      interval = 15;
    } else if (totalSeconds <= 14400) {
      type = DateTimeIntervalType.minutes;
      interval = 30;
    } else if (totalSeconds <= 28800) {
      type = DateTimeIntervalType.hours;
      interval = 1;
    } else if (totalSeconds <= 43200) {
      type = DateTimeIntervalType.hours;
      interval = 2;
    } else {
      type = DateTimeIntervalType.hours;
      interval = 3;
    }

    if (type != _intervalType || interval != _interval) {
      setState(() {
        _intervalType = type;
        _interval = interval;
      });
    }
  }

  DateFormat _buildDateFormat() {
    switch (_intervalType) {
      case DateTimeIntervalType.seconds:
        return DateFormat('HH:mm:ss');
      case DateTimeIntervalType.minutes:
        return DateFormat('HH:mm');
      case DateTimeIntervalType.hours:
      case DateTimeIntervalType.days:
      case DateTimeIntervalType.auto:
      default:
        return DateFormat.Hm();
    }
  }

  int _labelRotation() {
    switch (_intervalType) {
      case DateTimeIntervalType.hours:
      case DateTimeIntervalType.days:
      case DateTimeIntervalType.auto:
        return -45;
      case DateTimeIntervalType.seconds:
      case DateTimeIntervalType.minutes:
      default:
        return 0;
    }
  }
}

class _CursorPainter extends CustomPainter {
  const _CursorPainter({required this.x, required this.color});

  final double x;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2;
    canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
  }

  @override
  bool shouldRepaint(_CursorPainter oldDelegate) {
    return oldDelegate.x != x || oldDelegate.color != color;
  }
}

class _CursorLabel extends StatelessWidget {
  const _CursorLabel({required this.sample});

  final HeartRateSample sample;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textStyle = theme.textTheme.bodyMedium?.copyWith(
      color: Colors.white,
      fontWeight: FontWeight.w600,
    );
    final timestamp = DateFormat('HH:mm:ss').format(sample.timestamp);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E).withAlpha((0.92 * 255).round()),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Text('$timestamp • ${sample.bpm} bpm', style: textStyle),
    );
  }
}
