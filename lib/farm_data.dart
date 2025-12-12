import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FarmSensorConfigPage extends StatefulWidget {
  final String siteId; // pass selected site ID

  const FarmSensorConfigPage({super.key, required this.siteId});

  @override
  State<FarmSensorConfigPage> createState() => _FarmSensorConfigPageState();
}

class _FarmSensorConfigPageState extends State<FarmSensorConfigPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  int moistureCount = 0;
  int phCount = 0;
  int npkCount = 0;

  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadSensorCounts();
  }

  // ---------------- Load saved counts from Firestore ----------------
  Future<void> _loadSensorCounts() async {
    final doc = await _firestore.collection('sites').doc(widget.siteId).get();

    if (doc.exists) {
      var data = doc.data()!;
      setState(() {
        moistureCount = data['moistureSensors'] ?? 0;
        phCount = data['phSensors'] ?? 0;
        npkCount = data['npkSensors'] ?? 0;
      });
    }

    setState(() => loading = false);
  }

  // ---------------- Save counts to Firestore ----------------
  Future<void> _saveSensorCounts() async {
    await _firestore.collection('sites').doc(widget.siteId).update({
      'moistureSensors': moistureCount,
      'phSensors': phCount,
      'npkSensors': npkCount,
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Sensor counts saved successfully")),
    );
  }

  DropdownButton<int> _buildDropdown(int current, Function(int) onChanged) {
    return DropdownButton<int>(
      value: current,
      items: List.generate(10, (index) => index)
          .map((value) => DropdownMenuItem(value: value, child: Text("$value")))
          .toList(),
      onChanged: (value) => onChanged(value!),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Sensor Configuration")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            const Text("Moisture Sensors:", style: TextStyle(fontSize: 18)),
            _buildDropdown(moistureCount, (v) {
              setState(() => moistureCount = v);
            }),

            const SizedBox(height: 20),

            const Text("pH Sensors:", style: TextStyle(fontSize: 18)),
            _buildDropdown(phCount, (v) {
              setState(() => phCount = v);
            }),

            const SizedBox(height: 20),

            const Text("NPK Sensors:", style: TextStyle(fontSize: 18)),
            _buildDropdown(npkCount, (v) {
              setState(() => npkCount = v);
            }),

            const SizedBox(height: 30),

            ElevatedButton(
              onPressed: _saveSensorCounts,
              child: const Text("Save"),
            )
          ],
        ),
      ),
    );
  }
}
