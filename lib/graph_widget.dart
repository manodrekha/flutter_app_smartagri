import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class GraphWidget extends StatefulWidget {
  final String siteId;
  final String sensorType;
  final int sensorId; // 1 sensor = individual chart, 0 = combined
  final int? totalSensors;

  const GraphWidget({
    super.key,
    required this.siteId,
    required this.sensorType,
    required this.sensorId,
    this.totalSensors,
  });

  @override
  State<GraphWidget> createState() => _GraphWidgetState();
}

class _GraphWidgetState extends State<GraphWidget> {
  String range = "daily";
  bool loading = true;
  String? error;
  List<Map<String, dynamic>> data = [];

  @override
  void initState() {
    super.initState();
    _loadForRange();
  }

  String _mapType(String t) {
    switch (t.toLowerCase()) {
      case "moisture":
        return "soil_moisture";
      case "ph":
        return "ph";
      case "nitrogen":
        return "nitrogen";
      case "phosphorus":
        return "phosphorus";
      case "potassium":
        return "potassium";
      case "npk":
        return "npk";
    }
    return t;
  }

  Future<void> _loadForRange() async {
    setState(() {
      loading = true;
      error = null;
      data = [];
    });

    try {
      final raw = await rootBundle.loadString("assets/sensors.json");
      final jsonData = jsonDecode(raw);

      final key = _mapType(widget.sensorType);

      if (key == "npk") {
        _loadNpk(jsonData);
      } else {
        _loadSingle(jsonData, key);
      }
    } catch (e) {
      error = e.toString();
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _loadSingle(dynamic jsonData, String key) {
    List raw = jsonData[key]?[range] ?? [];

    if (raw.isEmpty) {
      raw = jsonData[key]?["daily"] ?? [];
    }

    data = raw.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  void _loadNpk(dynamic jsonData) {
    final n = jsonData["nitrogen"]?[range] ?? [];
    final p = jsonData["phosphorus"]?[range] ?? [];
    final k = jsonData["potassium"]?[range] ?? [];
    _mergeNPK(n, p, k);
  }

  void _mergeNPK(List nList, List pList, List kList) {
    final maxLen = [nList.length, pList.length, kList.length].reduce((a, b) => a > b ? a : b);

    final out = <Map<String, dynamic>>[];

    for (int i = 0; i < maxLen; i++) {
      final row = <String, dynamic>{};
      row["date"] =
          (i < nList.length ? nList[i]["date"] : null) ??
          (i < pList.length ? pList[i]["date"] : null) ??
          (i < kList.length ? kList[i]["date"] : null) ??
          "$i";

      if (i < nList.length) {
        nList[i].forEach((k, v) {
          if (k.startsWith("sensor")) row["nitrogen_$k"] = v;
        });
      }
      if (i < pList.length) {
        pList[i].forEach((k, v) {
          if (k.startsWith("sensor")) row["phosphorus_$k"] = v;
        });
      }
      if (i < kList.length) {
        kList[i].forEach((k, v) {
          if (k.startsWith("sensor")) row["potassium_$k"] = v;
        });
      }

      out.add(row);
    }

    data = out;
  }

  @override
  Widget build(BuildContext context) {
    final isCombined = widget.sensorId == 0;

    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// ---------- HEADER ----------
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isCombined
                      ? "${widget.sensorType.toUpperCase()} (Combined)"
                      : "${widget.sensorType} Sensor ${widget.sensorId}",
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                DropdownButton(
                  value: range,
                  items: const [
                    DropdownMenuItem(value: "daily", child: Text("Daily")),
                    DropdownMenuItem(value: "weekly", child: Text("Weekly")),
                    DropdownMenuItem(value: "monthly", child: Text("Monthly")),
                  ],
                  onChanged: (v) async {
                    range = v!;
                    await _loadForRange();
                  },
                )
              ],
            ),

            const SizedBox(height: 8),

            if (loading) const Center(child: CircularProgressIndicator()),
            if (!loading && error != null)
              Center(child: Text(error!, style: const TextStyle(color: Colors.red))),
            if (!loading && error == null) _buildChart(),
          ],
        ),
      ),
    );
  }

  // ----------------------------------------------------------------------
  //  MAIN CHART BUILDER
  // ----------------------------------------------------------------------
  Widget _buildChart() {
    if (data.isEmpty) {
      return const Center(child: Text("No data available"));
    }

    if (widget.sensorId == 0) {
      return _buildCombinedChart();
    }

    if (_mapType(widget.sensorType) == "npk") return _buildSingleNpk();

    return _buildSingleNormal();
  }

  // ----------------------------------------------------------------------
  //  ⭐ SINGLE NORMAL SENSOR (moisture / ph)
  // ----------------------------------------------------------------------
  Widget _buildSingleNormal() {
    final key = "sensor${widget.sensorId}";

    final spots = <FlSpot>[];

    for (int i = 0; i < data.length; i++) {
      final row = data[i];
      if (row.containsKey(key)) {
        spots.add(FlSpot(i.toDouble(), (row[key] as num).toDouble()));
      }
    }

    return SizedBox(
      height: 220,
      child: LineChart(
        LineChartData(
          minY: 0,
          lineBarsData: [
            LineChartBarData(spots: spots, isCurved: true, barWidth: 2),
          ],
          titlesData: _titles(),
        ),
      ),
    );
  }

  // ----------------------------------------------------------------------
  // ⭐ COMBINED NORMAL (ALL sensors)
  // ----------------------------------------------------------------------
  Widget _buildCombinedChart() {
    final sensorCount = widget.totalSensors ?? 3;

    final lines = <LineChartBarData>[];

    for (int s = 1; s <= sensorCount; s++) {
      final spots = <FlSpot>[];

      for (int i = 0; i < data.length; i++) {
        final row = data[i];
        final key = "sensor$s";
        if (row.containsKey(key)) {
          spots.add(FlSpot(i.toDouble(), (row[key] as num).toDouble()));
        }
      }

      if (spots.isNotEmpty) {
        lines.add(LineChartBarData(spots: spots, isCurved: true, barWidth: 2));
      }
    }

    return SizedBox(
      height: 240,
      child: LineChart(
        LineChartData(
          minY: 0,
          lineBarsData: lines,
          titlesData: _titles(),
        ),
      ),
    );
  }

  // ----------------------------------------------------------------------
  // ⭐ SINGLE NPK SENSOR
  // ----------------------------------------------------------------------
  Widget _buildSingleNpk() {
    final id = widget.sensorId;

    final nKey = "nitrogen_sensor$id";
    final pKey = "phosphorus_sensor$id";
    final kKey = "potassium_sensor$id";

    final n = <FlSpot>[];
    final p = <FlSpot>[];
    final k = <FlSpot>[];

    for (int i = 0; i < data.length; i++) {
      final row = data[i];
      if (row.containsKey(nKey)) n.add(FlSpot(i.toDouble(), row[nKey].toDouble()));
      if (row.containsKey(pKey)) p.add(FlSpot(i.toDouble(), row[pKey].toDouble()));
      if (row.containsKey(kKey)) k.add(FlSpot(i.toDouble(), row[kKey].toDouble()));
    }

    return _buildNpkChart(n, p, k);
  }

  // ----------------------------------------------------------------------
  // ⭐ COMBINED NPK (ALL sensors)
  // ----------------------------------------------------------------------
  Widget _buildCombinedNpk() {
    final sensorCount = widget.totalSensors ?? 3;

    final lines = <LineChartBarData>[];

    for (int s = 1; s <= sensorCount; s++) {
      final n = <FlSpot>[];
      final p = <FlSpot>[];
      final k = <FlSpot>[];

      for (int i = 0; i < data.length; i++) {
        final row = data[i];
        if (row.containsKey("nitrogen_sensor$s"))
          n.add(FlSpot(i.toDouble(), row["nitrogen_sensor$s"].toDouble()));
        if (row.containsKey("phosphorus_sensor$s"))
          p.add(FlSpot(i.toDouble(), row["phosphorus_sensor$s"].toDouble()));
        if (row.containsKey("potassium_sensor$s"))
          k.add(FlSpot(i.toDouble(), row["potassium_sensor$s"].toDouble()));
      }

      if (n.isNotEmpty) lines.add(LineChartBarData(spots: n, barWidth: 2, isCurved: true));
      if (p.isNotEmpty) lines.add(LineChartBarData(spots: p, barWidth: 2, isCurved: true));
      if (k.isNotEmpty) lines.add(LineChartBarData(spots: k, barWidth: 2, isCurved: true));
    }

    return SizedBox(
      height: 240,
      child: LineChart(
        LineChartData(
          minY: 0,
          lineBarsData: lines,
          titlesData: _titles(),
        ),
      ),
    );
  }

  // ----------------------------------------------------------------------
  // ⭐ NPK CHART BUILDER (missing earlier)
  // ----------------------------------------------------------------------
  Widget _buildNpkChart(
      List<FlSpot> n, List<FlSpot> p, List<FlSpot> k) {
    return SizedBox(
      height: 240,
      child: LineChart(
        LineChartData(
          minY: 0,
          lineBarsData: [
            LineChartBarData(spots: n, isCurved: true, barWidth: 2),
            LineChartBarData(spots: p, isCurved: true, barWidth: 2),
            LineChartBarData(spots: k, isCurved: true, barWidth: 2),
          ],
          titlesData: _titles(),
        ),
      ),
    );
  }

  // ----------------------------------------------------------------------
  // ⭐ FIXED TITLES (correct FL Chart 0.68.0)
  // ----------------------------------------------------------------------
  FlTitlesData _titles() {
    return FlTitlesData(
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          getTitlesWidget: (value, _) {
            final i = value.toInt();
            if (i >= 0 && i < data.length) {
              return Text(
                data[i]["date"].toString(),
                style: const TextStyle(fontSize: 10),
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ),
      leftTitles: AxisTitles(
        sideTitles: SideTitles(showTitles: true),
      ),
      topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
      rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
    );
  }
}
