import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class IrrigationPage extends StatefulWidget {
  const IrrigationPage({super.key});

  @override
  State<IrrigationPage> createState() => _IrrigationPageState();
}

class _IrrigationPageState extends State<IrrigationPage>
    with SingleTickerProviderStateMixin {
  bool isTankOn = true;
  bool isDripOn = false;
  bool isAutoOn = false;

  List<String> siteNames = [];
  String? selectedSite;

  late TabController tabController;

  @override
  void initState() {
    super.initState();
    tabController = TabController(length: 2, vsync: this);
    loadSitesFromFirebase();
  }

  // ------------------------------------------------------------
  //   LOAD SITES FROM FIREBASE
  // ------------------------------------------------------------
  Future<void> loadSitesFromFirebase() async {
    try {
      final snapshot =
          await FirebaseFirestore.instance.collection('sites').get();

      List<String> names =
          snapshot.docs.map((doc) => doc.data()['name'].toString()).toList();

      if (names.isNotEmpty) {
        setState(() {
          siteNames = names;
          selectedSite = siteNames.first; // default
        });
      }
    } catch (e) {
      debugPrint("Error loading sites: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      // ---------------- HEADER -----------------
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text(
          "DRIP IRRIGATION",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        centerTitle: true,
        bottom: TabBar(
          controller: tabController,
          tabs: const [
            Tab(text: "TANK FILLING"),
            Tab(text: "IRRIGATION"),
          ],
          indicatorColor: Colors.green,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
        ),

        actions: [
          Container(
            color: Colors.green.shade300,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: selectedSite,
                hint: const Text("Loading..."),
                dropdownColor: Colors.white,
                items: siteNames
                    .map((s) => DropdownMenuItem(
                          value: s,
                          child: Text(
                            s,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => selectedSite = v),
              ),
            ),
          ),
        ],
      ),

      body: Column(
        children: [
          Expanded(
            child: TabBarView(
              controller: tabController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                tankFillingTab(),
                irrigationTab(),
              ],
            ),
          ),
        ],
      ),

      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.white,
        onPressed: () => Navigator.pop(context),
        child: const Icon(Icons.home, color: Colors.black),
      ),
    );
  }

  // ------------------------------------------------------------
  //                       TANK FILLING TAB
  // ------------------------------------------------------------
  Widget tankFillingTab() {
    return Column(
      children: [
        SizedBox(
          height: 260,
          child: Center(
            child: _buildControlCard(
              title: "TANK FILLING",
              imagePath: "assets/tank.png",
              statusText: "75%",
              switchValue: isTankOn,
              onChanged: (val) => setState(() => isTankOn = val),
            ),
          ),
        ),
        Expanded(child: bottomHistorySection()),
      ],
    );
  }

  // ------------------------------------------------------------
  //                       IRRIGATION TAB
  // ------------------------------------------------------------
  Widget irrigationTab() {
    return Column(
      children: [
        SizedBox(
          height: 260,
          child: Row(
            children: [
              Expanded(
                child: _buildControlCard(
                  title: "IRRIGATION",
                  imagePath: "assets/drip_irrigation.png",
                  switchValue: isDripOn,
                  onChanged: (val) => setState(() => isDripOn = val),
                ),
              ),

            ],
          ),
        ),
        Expanded(child: bottomHistorySection()),
      ],
    );
  }

  // ------------------------------------------------------------
  //              IRRIGATION HISTORY COMMON SECTION
  // ------------------------------------------------------------
  Widget bottomHistorySection() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          color: const Color(0xFF0D3A5C),
          padding: const EdgeInsets.symmetric(vertical: 12),
          alignment: Alignment.center,
          child: const Text(
            "IRRIGATION HISTORY",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 20,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
        Expanded(
          child: Container(
            width: double.infinity,
            color: const Color(0xFF0D3A5C),
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------
  //                   CONTROL CARD WIDGET
  // ------------------------------------------------------------
  Widget _buildControlCard({
    required String title,
    required String imagePath,
    bool? switchValue,
    required Function(bool) onChanged,
    String? statusText,
  }) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Container(
          color: Colors.black,
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Center(
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),

        if (statusText != null)
          Stack(
            alignment: Alignment.center,
            children: [
              Image.asset(imagePath, height: 140, fit: BoxFit.contain),
              Positioned(
                right: 10,
                child: Container(
                  width: 40,
                  height: 100,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.blue.shade800,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    statusText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          )
        else
          Image.asset(imagePath, height: 140, fit: BoxFit.contain),

        const SizedBox(height: 12),

        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _customSwitch(switchValue!, onChanged),
            const SizedBox(width: 6),
            Text(
              switchValue ? "ON" : "OFF",
              style: TextStyle(
                color: switchValue ? Colors.green : Colors.red,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),

        const SizedBox(height: 6),
        const Text(
          "MANUAL MODE",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            decoration: TextDecoration.underline,
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------
  //                     CUSTOM SWITCH
  // ------------------------------------------------------------
  Widget _customSwitch(bool value, Function(bool) onChanged) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 60,
        height: 30,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: value ? Colors.green : Colors.red,
          borderRadius: BorderRadius.circular(20),
        ),
        alignment: value ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: 25,
          height: 25,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}
