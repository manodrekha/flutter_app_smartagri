import 'package:flutter/material.dart';
import 'combined_graph_widget.dart';

class SensorGraphPage extends StatelessWidget {
  final String siteId;
  final String sensorType;
  final int sensorCount;

  const SensorGraphPage({
    super.key,
    required this.siteId,
    required this.sensorType,
    required this.sensorCount,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("$sensorType - Combined Graph")),

      body: SingleChildScrollView(
        child: CombinedGraphWidget(
          siteId: siteId,
          sensorType: sensorType,
          sensorCount: sensorCount,
        ),
      ),
    );
  }
}
