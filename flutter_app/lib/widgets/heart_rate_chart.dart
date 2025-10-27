import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../models/heart_rate_sample.dart';

class HeartRateChart extends StatefulWidget {
  const HeartRateChart({
    super.key,
    required this.samples,
    required this.selectedDay,
    required this.interactive,
    required this.enableCursor, // retained for API compatibility
    this.enableSelectionZoom = false,
    this.onTrackballActive,
  });

  final List<HeartRateSample> samples;
  final DateTime selectedDay;
  final bool interactive;
  final bool enableCursor;
  final bool enableSelectionZoom;
  final ValueChanged<bool>? onTrackballActive;

  @override
  HeartRateChartState createState() => HeartRateChartState();
}

class HeartRateChartState extends State<HeartRateChart> {
  ZoomPanBehavior _zoomPanBehavior = ZoomPanBehavior(zoomMode: ZoomMode.x);

  DateTimeIntervalType _intervalType = DateTimeIntervalType.hours;
  double _interval = 1;

  DateTime? _visibleMin;
  DateTime? _visibleMax;
  late DateTime _dayStart;
  late DateTime _dayEnd;

  void resetView() {
    _zoomPanBehavior.reset();
    setState(() {
      _intervalType = DateTimeIntervalType.hours;
      _interval = 1;
      _visibleMin = null;
      _visibleMax = null;
    });
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
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    return LayoutBuilder(
      builder: (context, constraints) {
        _dayStart = dayStart;
        _dayEnd = dayEnd;
        _visibleMin ??= dayStart;
        _visibleMax ??= dayEnd;

        final series = _buildSeries(points);

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
          enablePanning: widget.interactive,
          enablePinching: widget.interactive && widget.enableSelectionZoom,
          enableDoubleTapZooming: widget.interactive,
          enableSelectionZooming: widget.interactive && widget.enableSelectionZoom,
        );

        return SfCartesianChart(
          primaryXAxis: xAxis,
          primaryYAxis: yAxis,
          plotAreaBorderWidth: 0,
          zoomPanBehavior: widget.interactive ? _zoomPanBehavior : null,
          series: series,
          onActualRangeChanged: (args) {
            if (!widget.interactive) return;
            _handleRangeChanged(args);
          },
        );
      },
    );
  }

  void _handleRangeChanged(ActualRangeChangedArgs args) {
    final min = args.visibleMin;
    final max = args.visibleMax;
    if (min is! DateTime || max is! DateTime) return;

    _updateAxisForRange(max.difference(min));

    DateTime newMin = min.isBefore(_dayStart) ? _dayStart : min;
    DateTime newMax = max.isAfter(_dayEnd) ? _dayEnd : max;
    if (!newMax.isAfter(newMin)) {
      newMax = newMin.add(const Duration(seconds: 1));
    }

    args.visibleMin = newMin;
    args.visibleMax = newMax;

    if (_visibleMin != newMin || _visibleMax != newMax) {
      setState(() {
        _visibleMin = newMin;
        _visibleMax = newMax;
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

  List<CartesianSeries<dynamic, DateTime>> _buildSeries(
    List<HeartRateSample> points,
  ) {
    if (points.isEmpty) return const [];

    final List<List<HeartRateSample>> solidSegments = [];
    final List<List<_GapPoint>> gapSegments = [];

    List<HeartRateSample> current = [points.first];
    for (int i = 1; i < points.length; i++) {
      final prev = points[i - 1];
      final curr = points[i];
      if (curr.timestamp.difference(prev.timestamp).abs() > const Duration(seconds: 30)) {
        if (current.isNotEmpty) {
          solidSegments.add(List<HeartRateSample>.from(current));
          current.clear();
        }
        gapSegments.add([
          _GapPoint(prev.timestamp, prev.bpm.toDouble()),
          _GapPoint(curr.timestamp, curr.bpm.toDouble()),
        ]);
      }
      current.add(curr);
    }
    if (current.isNotEmpty) {
      solidSegments.add(List<HeartRateSample>.from(current));
    }

    final Color strokeColor = const Color(0xFFEC5766);
    final Color fillColor = const Color.fromRGBO(236, 87, 102, 0.18);
    final List<CartesianSeries<dynamic, DateTime>> series = [];

    for (final segment in solidSegments) {
      series
        ..add(
          AreaSeries<HeartRateSample, DateTime>(
            dataSource: segment,
            xValueMapper: (sample, _) => sample.timestamp,
            yValueMapper: (sample, _) => sample.bpm,
            color: fillColor,
            borderWidth: 0,
          ),
        )
        ..add(
          LineSeries<HeartRateSample, DateTime>(
            dataSource: segment,
            xValueMapper: (sample, _) => sample.timestamp,
            yValueMapper: (sample, _) => sample.bpm,
            color: strokeColor,
            width: 2,
          ),
        );
    }

    for (final gap in gapSegments) {
      series.add(
        LineSeries<_GapPoint, DateTime>(
          dataSource: gap,
          xValueMapper: (point, _) => point.timestamp,
          yValueMapper: (point, _) => point.bpm,
          color: strokeColor.withValues(alpha: 0.75),
          dashArray: const [8, 4],
          width: 2,
        ),
      );
    }

    return series;
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

class _GapPoint {
  _GapPoint(this.timestamp, this.bpm);

  final DateTime timestamp;
  final double bpm;
}
