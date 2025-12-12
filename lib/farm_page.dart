// lib/farm_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'sensor_graph_page.dart';
import 'graph_widget.dart';

class FarmPage extends StatefulWidget {
  final String siteId;
  final String siteName;

  const FarmPage({
    super.key,
    required this.siteId,
    required this.siteName,
  });

  @override
  State<FarmPage> createState() => _FarmPageState();
}

class _FarmPageState extends State<FarmPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  int moisture = 0;
  int ph = 0;
  int npk = 0;
  bool loading = true;

  final TextEditingController moistureCtrl = TextEditingController();
  final TextEditingController phCtrl = TextEditingController();
  final TextEditingController npkCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    try {
      final doc = await _firestore.collection("farm_config").doc(widget.siteId).get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;

        // robustly parse ints even if Firestore stored strings
        moisture = int.tryParse("${data['moistureSensors'] ?? 0}") ?? 0;
        ph = int.tryParse("${data['phSensors'] ?? 0}") ?? 0;
        npk = int.tryParse("${data['npkSensors'] ?? 0}") ?? 0;

        moistureCtrl.text = moisture.toString();
        phCtrl.text = ph.toString();
        npkCtrl.text = npk.toString();
      } else {
        // defaults remain 0
      }
    } catch (e) {
      debugPrint("🔥 Error loading config: $e");
    }

    if (mounted) setState(() => loading = false);
  }

  Future<void> saveConfig() async {
    try {
      await _firestore.collection("farm_config").doc(widget.siteId).set({
        "moistureSensors": moisture,
        "phSensors": ph,
        "npkSensors": npk,
        "updatedAt": DateTime.now(),
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Saved successfully")),
        );
      }
    } catch (e) {
      debugPrint("🔥 Save error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.siteName)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(widget.siteName)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Sensor Configuration",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              numberField("Moisture Sensors", moistureCtrl),
              numberField("pH Sensors", phCtrl),
              numberField("NPK Sensors", npkCtrl),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    moisture = int.tryParse(moistureCtrl.text) ?? 0;
                    ph = int.tryParse(phCtrl.text) ?? 0;
                    npk = int.tryParse(npkCtrl.text) ?? 0;
                  });
                  saveConfig();
                },
                child: const Text("Save"),
              ),
              const SizedBox(height: 30),
              const Text(
                "Sensor Graphs",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              // Cards with expand + inline graphs
              sensorCard("Moisture Sensors", moisture, "moisture"),
              sensorCard("pH Sensors", ph, "ph"),
              sensorCard("NPK Sensors", npk, "npk"),
            ],
          ),
        ),
      ),
    );
  }

  Widget numberField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

Widget sensorCard(String title, int count, String type) {
  return Card(
    margin: const EdgeInsets.symmetric(vertical: 8),
    child: ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),

      // Disable default tapping on the header
      initiallyExpanded: false,
      maintainState: true,
      onExpansionChanged: (_) {},

      // ---------- HEADER ----------
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Tapping TITLE opens full combined graph
          GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SensorGraphPage(
                    siteId: widget.siteId,
                    sensorType: type,
                    sensorCount: count, // combined
                  ),
                ),
              );
            },
            child: Text(title, style: const TextStyle(fontSize: 16)),
          ),

          // Show sensor count
          Text(
            "$count sensors",
            style: const TextStyle(color: Colors.grey),
          ),
        ],
      ),

      // ---------- CHILDREN ----------
      childrenPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 8),

      children: [
        if (count <= 0)
          const Center(child: Padding(
            padding: EdgeInsets.all(12),
            child: Text("No sensors configured"),
          ))
        else
          for (int i = 1; i <= count; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GraphWidget(
                siteId: widget.siteId,
                sensorType: type,
                sensorId: i, // separate sensor graph
              ),
            ),
      ],
    ),
  );
}


}
