import 'package:flutter/material.dart';
import 'graph_widget.dart';

class CombinedGraphWidget extends StatelessWidget {
  final String siteId;
  final String sensorType;
  final int sensorCount;

  const CombinedGraphWidget({
    super.key,
    required this.siteId,
    required this.sensorType,
    required this.sensorCount,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: GraphWidget(
          siteId: siteId,
          sensorType: sensorType,
          sensorId: 0,        // special mode → combined
          totalSensors: sensorCount, // tell graph to draw multiple sensors
        ),
      ),
    );
  }
}
