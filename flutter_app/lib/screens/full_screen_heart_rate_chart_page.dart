import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/heart_rate_sample.dart';
import '../widgets/heart_rate_chart.dart';

class FullScreenHeartRateChartPage extends StatefulWidget {
  const FullScreenHeartRateChartPage({
    super.key,
    required this.samples,
    required this.selectedDay,
  });

  final List<HeartRateSample> samples;
  final DateTime selectedDay;

  @override
  State<FullScreenHeartRateChartPage> createState() =>
      _FullScreenHeartRateChartPageState();
}

class _FullScreenHeartRateChartPageState
    extends State<FullScreenHeartRateChartPage> {
  final GlobalKey<HeartRateChartState> _chartKey =
      GlobalKey<HeartRateChartState>();

  @override
  void initState() {
    super.initState();
    _lockLandscape();
  }

  @override
  void dispose() {
    _restoreOrientations();
    super.dispose();
  }

  Future<void> _lockLandscape() async {
    await SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  Future<void> _restoreOrientations() async {
    await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: HeartRateChart(
                key: _chartKey,
                samples: widget.samples,
                selectedDay: widget.selectedDay,
                interactive: true,
                enableSelectionZoom: true,
                enableCursor: false,
              ),
            ),
            Positioned(
              bottom: 36,
              right: 16,
              child: IconButton.filledTonal(
                icon: const Icon(Icons.fullscreen_exit),
                color: Colors.white,
                onPressed: () async {
                  final navigator = Navigator.of(context);
                  await _restoreOrientations();
                  navigator.maybePop();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
