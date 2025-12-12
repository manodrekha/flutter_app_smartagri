// dashboard_page.dart
import 'dart:typed_data';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'farm_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'map_picker_page.dart';


const String OPENWEATHER_API_KEY = '9fe0fffc423415be0b52229540367576'; // <-- PUT YOUR KEY

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}
bool isEditingCoordinates = false;

// NOTE: keys are Firestore document IDs (siteId)
Map<String, List<Map<String, dynamic>>> siteInvestments = {};
Map<String, List<Map<String, dynamic>>> siteIncomes = {};

class _DashboardPageState extends State<DashboardPage>

    with SingleTickerProviderStateMixin {
  // ---------- CONTROLLERS ----------
  String selectedSiteId = "";

  TextEditingController investmentController = TextEditingController();
  TextEditingController incomeController = TextEditingController();
  TextEditingController latController = TextEditingController();
  TextEditingController lonController = TextEditingController();

  late TabController _tabController;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> _sites = []; // stores docs with 'id' and fields

  int? _selectedIndex;

  // weather + location state
  Map<String, dynamic>? _weather; // holds weather JSON
  Position? _position;
  bool _loadingWeather = false;
  String? _weatherError;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadSitesFromFirebase();
  }
Future<void> fetchSiteData(String siteId) async {
  try {
    DocumentSnapshot siteSnapshot = await FirebaseFirestore.instance
        .collection('farm_data')
        .doc(siteId)
        .get();

    if (!siteSnapshot.exists) {
      print("❌ Site not found in Firestore: $siteId");
      return;
    }

    Map<String, dynamic>? data =
        siteSnapshot.data() as Map<String, dynamic>?;

    if (data == null) return;

    if (!mounted) return;

    setState(() {
      investmentController.text = data['investment']?.toString() ?? '';
      incomeController.text = data['income']?.toString() ?? '';

    });

    print("✅ fetchSiteData loaded successfully for $siteId");

  } catch (e) {
    print("🔥 Error in fetchSiteData: $e");
  }
}

Future<void> _loadSitesFromFirebase() async {
  try {
    final querySnapshot =
        await FirebaseFirestore.instance.collection('sites').get();

    final sites = querySnapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'id': doc.id,
        'name': data['name'] ?? '',
'plotSize': data['plotSize'],   // <-- FIXED
        'crop': data['crop'] ?? '',
        'cycle': data['cycle'] ?? '',
        'plantedDate': (data['plantedDate'] as Timestamp?)?.toDate(),
        'harvestDate': (data['harvestDate'] as Timestamp?)?.toDate(),
        'imageBytes':
            data['imageBytes'] != null ? base64Decode(data['imageBytes']) : null,
        'latitude': data['latitude']?.toString() ?? '',
        'longitude': data['longitude']?.toString() ?? '',
      };
    }).toList();

    if (!mounted) return;

    // update sites list first
    setState(() {
      _sites = sites;
    });

    // prevent invalid index crash
    if (_selectedIndex != null &&
        (_selectedIndex! < 0 || _selectedIndex! >= _sites.length)) {
      _selectedIndex = null;
    }

    // restore last selected site if available
    final prefs = await SharedPreferences.getInstance();
    final lastId = prefs.getString("last_selected_site");

    if (lastId != null && _sites.isNotEmpty) {
      final idx = _sites.indexWhere((s) => s['id'] == lastId);

      if (idx >= 0) {
        setState(() => _selectedIndex = idx);

        final siteId = _sites[idx]['id'];

        await fetchSiteData(siteId);

        latController.text = _sites[idx]['latitude'] ?? '';
        lonController.text = _sites[idx]['longitude'] ?? '';

        await _updateWeatherForSelectedSite();
        return;
      }
    }

    // Default to first site ONLY IF exists
    if (_selectedIndex == null && _sites.isNotEmpty) {
      setState(() => _selectedIndex = 0);

      final firstId = _sites[0]['id'];

      await fetchSiteData(firstId);

      latController.text = _sites[0]['latitude'] ?? '';
      lonController.text = _sites[0]['longitude'] ?? '';

      await _updateWeatherForSelectedSite();
    }
  } catch (e) {
    debugPrint('❌ Error loading sites: $e');
  }
}


  // ---------------- Load investments/incomes + lat/lon into controllers ----------------
  Future<void> _loadDataFromFirestore(String siteId) async {
    try {
      final docRef = FirebaseFirestore.instance.collection('sites').doc(siteId);
      final doc = await docRef.get();

      if (!doc.exists) {
        debugPrint('⚠️ No Firestore document found for siteId=$siteId');
        if (!mounted) return;
        setState(() {
          siteInvestments[siteId] = [];
          siteIncomes[siteId] = [];
        });
        return;
      }

      final data = doc.data() ?? {};
      final rawInvestments = data['investments'] ?? [];
      final rawIncomes = data['incomes'] ?? [];

      // convert lists safely and normalize types
      List<Map<String, dynamic>> investments = [];
      for (var i in rawInvestments) {
        investments.add({
          'item': i['item'] ?? '',
          'vendor': i['vendor'] ?? '',
          'date': (i['date'] is Timestamp)
              ? (i['date'] as Timestamp).toDate()
              : (i['date'] ?? DateTime.now()),
          'amount': (i['amount'] is int)
              ? (i['amount'] as int).toDouble()
              : (i['amount'] ?? 0.0),
        });
      }

      List<Map<String, dynamic>> incomes = [];
      for (var i in rawIncomes) {
        incomes.add({
          'item': i['item'] ?? '',
          'remarks': i['remarks'] ?? '',
          'date': (i['date'] is Timestamp)
              ? (i['date'] as Timestamp).toDate()
              : (i['date'] ?? DateTime.now()),
          'amount': (i['amount'] is int)
              ? (i['amount'] as int).toDouble()
              : (i['amount'] ?? 0.0),
        });
      }

      // set lat/lon controllers from doc if present
      final lat = data['latitude']?.toString() ?? '';
      final lon = data['longitude']?.toString() ?? '';

      if (!mounted) return;
      setState(() {
        siteInvestments[siteId] = investments;
        siteIncomes[siteId] = incomes;
        latController.text = lat;
        lonController.text = lon;
      });

      debugPrint('✅ Data loaded successfully for siteId=$siteId');
    } catch (e) {
      debugPrint('❌ Error loading data from Firestore for $siteId: $e');
    }
  }

  // ---------------- Save investments/incomes under siteId ----------------
  Future<void> _saveDataToFirestore(String siteId) async {
    try {
      final docRef =
          FirebaseFirestore.instance.collection('sites').doc(siteId);

      await docRef.set({
        'investments': siteInvestments[siteId] ?? [],
        'incomes': siteIncomes[siteId] ?? [],
        'timestamp': FieldValue.serverTimestamp(),
        'latitude': latController.text,
        'longitude': lonController.text,
      }, SetOptions(merge: true));

      debugPrint('✅ Data saved to Firestore for siteId=$siteId');
    } catch (e) {
      debugPrint('❌ Error saving to Firestore: $e');
    }
  }

  // ---------------- Show add/edit dialog (unchanged) ----------------
  Future<Map<String, dynamic>?> _showAddEntryDialog(String title,
      {Map<String, dynamic>? existing}) async {
    final isEditing = existing != null;

    final itemController = TextEditingController(text: existing?['item'] ?? '');
    final vendorController =
        TextEditingController(text: existing?['vendor'] ?? existing?['remarks'] ?? '');
    final amountController =
        TextEditingController(text: (existing?['amount']?.toString() ?? ''));
    DateTime selectedDate = existing?['date'] ?? DateTime.now();

    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEditing ? "Edit $title" : "Add $title"),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: itemController,
                decoration: const InputDecoration(labelText: "Item"),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: vendorController,
                decoration: const InputDecoration(labelText: "Vendor / Remarks"),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "Amount (₹)"),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text("Date: "),
                  TextButton(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) {
                        selectedDate = picked;
                      }
                    },
                    child: Text(DateFormat('dd/MM/yyyy').format(selectedDate)),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              final amount = double.tryParse(amountController.text) ?? 0.0;
              Navigator.pop(ctx, {
                'item': itemController.text,
                'vendor': vendorController.text,
                'date': selectedDate,
                'amount': amount,
              });
            },
            child: Text(isEditing ? "Update" : "Add"),
          ),
        ],
      ),
    );
  }

  // ---------------- Save or update site metadata (name/crop/plot/image/lat/lon) ----------------
  Future<void> _saveSiteToFirebase(Map<String, dynamic> site) async {
    try {
      final imageString = site['imageBytes'] != null
          ? base64Encode(site['imageBytes'])
          : null;

      if (site['id'] != null) {
        // update existing document
        await _firestore.collection('sites').doc(site['id']).update({
          'name': site['name'],
          'crop': site['crop'],
'plotSize': site['plotSize'],   // <-- FIXED
          'cycle': site['cycle'],
          'plantedDate': site['plantedDate'],
          'harvestDate': site['harvestDate'],
          'imageBytes': imageString,
          'latitude': site['latitude'],
          'longitude': site['longitude'],
        });
      } else {
        final doc = await _firestore.collection('sites').add({
          'name': site['name'],
          'crop': site['crop'],
'plotSize': site['plotSize'],   // <-- FIXED
          'cycle': site['cycle'],
          'plantedDate': site['plantedDate'],
          'harvestDate': site['harvestDate'],
          'imageBytes': imageString,
          'latitude': site['latitude'],
          'longitude': site['longitude'],
        });
        site['id'] = doc.id;
      }

      // after saving site metadata, refresh the site list
      await _loadSitesFromFirebase();
    } catch (e) {
      debugPrint("❌ Error saving site to Firestore: $e");
    }
  }

  // ---------------- Pick image and create site entries ----------------
  Future<void> _pickImage() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.image,
      withData: true,
    );

    if (result != null) {
      for (var file in result.files) {
        final newName = 'SITE-${_sites.length + 1}';

        // skip if name exists
        bool exists = _sites.any((s) => s['name'] == newName);
        if (exists) continue;

        final newSite = {
          'name': newName,
          'imageBytes': file.bytes,
          'crop': null,
          'plotsize': null,
          'plantedDate': null,
          'harvestDate': null,
          'latitude': '',
          'longitude': '',
        };
        await _saveSiteToFirebase(newSite);
      }

      // refresh list and select the last added site
      await _loadSitesFromFirebase();
      if (!mounted) return;
      setState(() {
        _selectedIndex = _sites.isNotEmpty ? _sites.length - 1 : null;
      });
    }
  }

  // ---------------- date pickers ----------------
  Future<void> _pickDate(int index, String type) async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _sites[index][type] ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      if (!mounted) return;
      setState(() => _sites[index][type] = picked);
      await _saveSiteToFirebase(_sites[index]);
    }
  }

  Future<void> _confirmDeleteSite(int index) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Site"),
        content: Text(
            "Are you sure you want to delete ${_sites[index]['name']}? This action cannot be undone."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final siteId = _sites[index]['id'];
      if (siteId != null) {
        await _firestore.collection('sites').doc(siteId).delete();
        // clear cached data
        siteInvestments.remove(siteId);
        siteIncomes.remove(siteId);
      }
      if (!mounted) return;
      setState(() {
        _sites.removeAt(index);
        _selectedIndex = _sites.isEmpty ? null : 0;
      });
    }
  }

  // ---------------- WEATHER & GEO functions ----------------

  Future<void> _updateWeatherForSelectedSite() async {
    // if lat/lon present in controllers, fetch using them
    if (latController.text.isEmpty || lonController.text.isEmpty) return;

    final lat = double.tryParse(latController.text);
    final lon = double.tryParse(lonController.text);

    if (lat == null || lon == null) return;

    await _fetchWeather(lat, lon);

    // also save the lat/lon into the selected site document (cache)
    if (_selectedIndex != null) {
      final siteId = _sites[_selectedIndex!]['id'];
      if (siteId != null) {
        await _firestore.collection('sites').doc(siteId).set({
          'latitude': latController.text,
          'longitude': lonController.text,
        }, SetOptions(merge: true));
      }
    }
  }

  Future<void> _fetchWeather(double lat, double lon) async {
    if (!mounted) return;
    setState(() {
      _loadingWeather = true;
      _weatherError = null;
    });

    final url =
        'https://api.openweathermap.org/data/2.5/weather?lat=$lat&lon=$lon&units=metric&appid=$OPENWEATHER_API_KEY';

    try {
      final res = await http.get(Uri.parse(url));
      if (res.statusCode == 200) {
        _weather = json.decode(res.body) as Map<String, dynamic>;
      } else {
        _weatherError =
            'Weather API error: ${res.statusCode} ${res.reasonPhrase}';
      }
    } catch (e) {
      _weatherError = 'Failed to fetch weather: $e';
    } finally {
      if (!mounted) return;
      setState(() {
        _loadingWeather = false;
      });
    }
  }

  void _showPlotSizeDialog(Map<String, dynamic> site) {
    TextEditingController controller =
        TextEditingController(text: site['plotSize']?.toString() ?? "");

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Enter Plot Size (sq.ft)"),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: "e.g., 1200",
              border: OutlineInputBorder(),
            ),
            onChanged: (value) {
              setState(() {
                site['plotSize'] = int.tryParse(value) ?? 0;
              });
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // close dialog only
              },
              child: const Text("OK"),
            ),
          ],
        );
      },
    );
  }

  void _showCropDialog(Map<String, dynamic> site) {
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text("Select Crop"),
        children: ["Ginger", "Tomato", "Paddy", "Banana"].map((crop) {
          return SimpleDialogOption(
            onPressed: () async {
              if (!mounted) return;
              setState(() => site['crop'] = crop);
              await _saveSiteToFirebase(site);
              Navigator.pop(context);
            },
            child: Text(crop),
          );
        }).toList(),
      ),
    );
  }

  // ---------------- UI build ----------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Dashboard"),
        backgroundColor: const Color(0xFF0D3A5C),
      ),
      body: Row(
        children: [
          // LEFT PANEL
          Container(
            width: 260,
            color: Colors.grey.shade200,
            child: _buildLeftPanel(),
          ),

          // RIGHT PANEL WITH TABS
          Expanded(
            child: Column(
              children: [
                // TAB BAR
                Container(
                  color: const Color(0xFF0D3A5C),
                  child: TabBar(
                    controller: _tabController,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white70,
                    indicatorColor: Colors.white,
                    tabs: const [
                      Tab(text: "SITE INFO"),
                      Tab(text: "FARM DATA"),
                      Tab(text: "INVESTMENT"),
                    ],
                  ),
                ),

                // TAB CONTENT
Expanded(
  child: TabBarView(
    controller: _tabController,
    children: [
      _buildRightSiteInfo(),

      // ------------ FIXED FARMPAGE TAB ------------
if (_selectedIndex != null && _sites.isNotEmpty)
FarmPage(
  siteId: _sites[_selectedIndex!]['id'],   // FIXED
  siteName: _sites[_selectedIndex!]['name'],
)


else
  Center(child: Text("No site selected")),


      // ------------ THIRD TAB ------------
      _buildInvestment(),
    ],
  ),
)





              ],
            ),
          ),
        ],
      ),
    );
  }
Widget _buildLeftPanel() {
  // ---------- SAFE DROPDOWN VALUE ----------
  int? safeDropdownValue;
  if (_selectedIndex != null &&
      _selectedIndex! >= 0 &&
      _selectedIndex! < _sites.length) {
    safeDropdownValue = _selectedIndex;
  }
  // -----------------------------------------

  const cycleOptions = ["Cycle 1", "Cycle 2", "Cycle 3", "Cycle 4"];

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SizedBox(height: 10),

      // ---------- SITE DROPDOWN ----------
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            const Text(
              "Select Site:",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 8),

            Expanded(
              child: DropdownButton<int>(
                value: safeDropdownValue,
                isExpanded: true,
                hint: const Text("Choose a site"),

                items: List.generate(_sites.length, (index) {
                  return DropdownMenuItem(
                    value: index,
                    child: Text(_sites[index]['name'] ?? "Unnamed"),
                  );
                }),

onChanged: (newIndex) async {
  if (newIndex == null || !mounted) return;

  final site = _sites[newIndex];
  final siteId = site['id'];

  setState(() {
    _selectedIndex = newIndex;
    selectedSiteId = siteId;        // <-- FIX
  });

  final prefs = await SharedPreferences.getInstance();
  await prefs.setString("last_selected_site", siteId);

  await fetchSiteData(siteId);

  latController.text = site['latitude']?.toString() ?? '';
  lonController.text = site['longitude']?.toString() ?? '';

  await _updateWeatherForSelectedSite();
},

              ),
            ),
          ],
        ),
      ),
      // -----------------------------------

      const SizedBox(height: 10),

      // ---------- BROWSE BUTTON ----------
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: ElevatedButton.icon(
          onPressed: _pickImage,
          icon: const Icon(Icons.image),
          label: const Text("Browse Sites"),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0D3A5C),
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 48),
          ),
        ),
      ),
      // -----------------------------------

      const SizedBox(height: 10),

      // ---------- SCROLLABLE SITES LIST ----------
      Expanded(
        child: SingleChildScrollView(
          child: Column(
            children: List.generate(_sites.length, (index) {
              final site = _sites[index];

              // SAFETY: guarantee cycle value is valid
              String? cycleValue =
                  cycleOptions.contains(site['cycle']) ? site['cycle'] : null;

              return Container(
                margin:
                    const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(
                    color: _selectedIndex == index
                        ? Colors.green
                        : Colors.grey.shade400,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),

                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (site['imageBytes'] != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.memory(
                          site['imageBytes'],
                          height: 100,
                          width: double.infinity,
                          fit: BoxFit.contain,
                        ),
                      ),

                    const SizedBox(height: 8),

                    // ---------- SITE NAME ----------
                    TextField(
                      controller: TextEditingController(text: site['name']),
                      decoration: const InputDecoration(
                        labelText: "Site Name",
                        border: OutlineInputBorder(),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                      onChanged: (value) => site['name'] = value,
                      onEditingComplete: () async =>
                          await _saveSiteToFirebase(site),
                    ),

                    const SizedBox(height: 8),

                    // ---------- CYCLE DROPDOWN ----------
                    DropdownButtonFormField<String>(
                      value: cycleValue,
                      decoration: const InputDecoration(
                        labelText: "Cycle",
                        border: OutlineInputBorder(),
                      ),
                      items: cycleOptions
                          .map(
                            (c) => DropdownMenuItem(
                              value: c,
                              child: Text(c),
                            ),
                          )
                          .toList(),
                      onChanged: (value) async {
                        if (value != null) {
                          site['cycle'] = value;
                          await _saveSiteToFirebase(site);
                        }
                      },
                    ),
                    // ----------------------------------

                    const SizedBox(height: 8),

                    // ---------- GO & DELETE BUTTONS ----------
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _selectedIndex == index
                                ? Colors.green
                                : Colors.grey.shade500,
                            shape: const CircleBorder(),
                          ),
                          onPressed: () async {
                            if (!mounted) return;

                            setState(() => _selectedIndex = index);

                            final siteId = site['id'];
                            if (siteId != null) {
                              final prefs =
                                  await SharedPreferences.getInstance();
                              prefs.setString("last_selected_site", siteId);

                              await _loadDataFromFirestore(siteId);

                              latController.text =
                                  site['latitude']?.toString() ?? '';
                              lonController.text =
                                  site['longitude']?.toString() ?? '';

                              await _updateWeatherForSelectedSite();
                            }
                          },
                          child: const Text(
                            "GO",
                            style: TextStyle(color: Colors.white),
                          ),
                        ),

                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _confirmDeleteSite(index),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
          ),
        ),
      ),
      // -----------------------------------------
    ],
  );
}


  Widget _buildRightSiteInfo() {
    if (_selectedIndex == null) {
      return const Center(child: Text("Select a site"));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSiteDetail(_selectedIndex!),
          const SizedBox(height: 16),
          _buildWeatherSection(),
          const SizedBox(height: 16),

          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildSiteDetail(int index) {
    final site = _sites[index];

    String plantedDateText = site['plantedDate'] != null
        ? DateFormat('dd/MM/yyyy').format(site['plantedDate'])
        : "Select";

    String harvestDateText = site['harvestDate'] != null
        ? DateFormat('dd/MM/yyyy').format(site['harvestDate'])
        : "Select";

    DateTime? start = site['plantedDate'];
    DateTime? end = site['harvestDate'];

    if (start == null && end != null) {
      start = DateTime(end.year - 1, end.month, end.day);
    }

    return SingleChildScrollView(
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Site Image
              Expanded(
                flex: 3,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade400),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: site['imageBytes'] != null
                      ? Image.memory(
                          site['imageBytes'],
                          height: 250,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          filterQuality: FilterQuality.high,
                        )
                      : Container(
                          height: 250,
                          color: Colors.grey[300],
                          alignment: Alignment.center,
                          child: const Text("No Image Selected"),
                        ),
                ),
              ),

              const SizedBox(width: 10),

              // Info Fields
              Expanded(
                flex: 2,
                child: Column(
                  children: [
                    _plotSizeField(site),
                    const SizedBox(height: 8),
                    _infoBox(
                      "CROP",
                      site['crop'] ?? "Select",
                      icon: Icons.agriculture,
                      onTap: () => _showCropDialog(site),
                    ),
                    const SizedBox(height: 8),
                    _infoBox(
                      "PLANTED",
                      plantedDateText,
                      icon: Icons.event,
                      onTap: () => _pickDate(index, 'plantedDate'),
                    ),
                    const SizedBox(height: 8),
                    _infoBox(
                      "HARVEST",
                      harvestDateText,
                      icon: Icons.calendar_today,
                      onTap: () => _pickDate(index, 'harvestDate'),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (start != null)
            _buildTimelineWidget(
              start,
              end ?? start.add(const Duration(days: 365)),
            ),
        ],
      ),
    );
  }

  Widget _plotSizeField(Map<String, dynamic> site) {
    return _infoBox(
      "PLOT SIZE",
      "${site['plotSize'] ?? '0'} sq.ft",
      icon: Icons.square_foot,
      onTap: () => _showPlotSizeDialog(site),
    );
  }

  Widget _infoBox(String title, String value,
      {IconData? icon, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.green.shade200),
        ),
        child: Row(
          children: [
            Icon(icon, size: 22, color: Colors.green.shade700),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 12)),
                Text(value,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.black)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // WEATHER UI (unchanged apart from using latController/lonController)
Widget _buildWeatherSection() {
  return Card(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    elevation: 2,
    margin: const EdgeInsets.all(8),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Smart Agriculture Weather",
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.green),
          ),
          const SizedBox(height: 12),

          if (_weather != null) _buildTemperatureSummary(),

          const SizedBox(height: 20),

          _weather == null
              ? const Text("Enter coordinates to fetch weather data")
              : Column(
                  children: [
                    _buildAgriStatsRow(),
                    const SizedBox(height: 16),

                    _buildHumidityCircle(),
                    const SizedBox(height: 16),

                    _buildForecastRow(),
                    const SizedBox(height: 20),

                    _buildWeatherTrendGraph(),
                  ],
                ),

          // -----------------------------------------
          // LAT / LON MOVED TO BOTTOM
          // -----------------------------------------
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 16),
          const Text(
            "Update Coordinates",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),

          _buildLatLonInputs(),
          const SizedBox(height: 16),

          _buildFetchButton(),
        ],
      ),
    ),
  );
}


  Widget _buildTemperatureSummary() {
    final temp = _weather!['main']['temp']?.toDouble() ?? 0.0;
    final desc = _weather!['weather'][0]['description'];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.green.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Text(
            "${temp.toStringAsFixed(1)}°C",
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  desc.toString().toUpperCase(),
                  style: TextStyle(fontSize: 14, color: Colors.green.shade800),
                ),
                const SizedBox(height: 4),
                const Text("Ideal for crop monitoring"),
              ],
            ),
          )
        ],
      ),
    );
  }
Widget _buildLatLonInputs() {
  if (_selectedIndex == null) return SizedBox();

  final site = _sites[_selectedIndex!];

  bool isNewSite =
      (site['latitude'] == '' || site['latitude'] == null) &&
      (site['longitude'] == '' || site['longitude'] == null);

  bool showEditable = isNewSite || isEditingCoordinates;

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [

      // ----------- READ ONLY MODE -----------
      if (!showEditable)
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Latitude: ${latController.text}",
                      style: TextStyle(fontSize: 15)),
                  SizedBox(height: 6),
                  Text("Longitude: ${lonController.text}",
                      style: TextStyle(fontSize: 15)),
                ],
              ),
            ),
            SizedBox(height: 10),

            ElevatedButton.icon(
              onPressed: () {
                setState(() => isEditingCoordinates = true);
              },
              icon: Icon(Icons.edit_location),
              label: Text("Edit Coordinates"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),

      // ----------- EDIT MODE -----------
      if (showEditable)
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // Manual entry (unchanged)
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: latController,
                    decoration: InputDecoration(
                      labelText: "Latitude",
                      filled: true,
                      fillColor: Colors.green.shade50,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: lonController,
                    decoration: InputDecoration(
                      labelText: "Longitude",
                      filled: true,
                      fillColor: Colors.green.shade50,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            SizedBox(height: 12),

            // GPS Location Button
            ElevatedButton.icon(
              onPressed: () async {
                Position pos = await Geolocator.getCurrentPosition(
                    desiredAccuracy: LocationAccuracy.high);
                setState(() {
                  latController.text = pos.latitude.toString();
                  lonController.text = pos.longitude.toString();
                });
              },
              icon: Icon(Icons.my_location),
              label: Text("Use My GPS Location"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
              ),
            ),

            SizedBox(height: 10),

            // Google Maps Picker Button
            ElevatedButton.icon(
              onPressed: () async {
                final LatLng? newPos = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MapPickerPage(
                      initialLat: double.tryParse(latController.text) ?? 0,
                      initialLon: double.tryParse(lonController.text) ?? 0,
                    ),
                  ),
                );

                if (newPos != null) {
                  setState(() {
                    latController.text = newPos.latitude.toString();
                    lonController.text = newPos.longitude.toString();
                  });
                }
              },
              icon: Icon(Icons.map),
              label: Text("Pick on Google Map"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
            ),

            SizedBox(height: 15),

            // Save + Cancel Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      final siteId = site['id'];

                      await FirebaseFirestore.instance
                          .collection('sites')
                          .doc(siteId)
                          .set({
                        'latitude': latController.text,
                        'longitude': lonController.text,
                      }, SetOptions(merge: true));

                      setState(() => isEditingCoordinates = false);

                      await _updateWeatherForSelectedSite();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: EdgeInsets.all(14),
                    ),
                    child: Text("Save",
                        style: TextStyle(color: Colors.white)),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() => isEditingCoordinates = false);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: EdgeInsets.all(14),
                    ),
                    child: Text("Cancel",
                        style: TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            )
          ],
        ),
    ],
  );
}


Widget _buildFetchButton() {
  return SizedBox(
    width: double.infinity,
    child: ElevatedButton.icon(
      onPressed: _updateWeatherForSelectedSite,
      icon: const Icon(Icons.cloud),
      label: const Text("Get Weather"),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.green,      // SAME AS Edit Coordinates
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    ),
  );
}


  Widget _buildAgriStatsRow() {
    return Row(
      children: [
        _statCard(Icons.water_drop, "Humidity", "${_weather!['main']['humidity']}%"),
        _statCard(Icons.air, "Wind", "${_weather!['wind']['speed']} m/s"),
        _statCard(Icons.speed, "Pressure", "${_weather!['main']['pressure']} hPa"),
        _statCard(Icons.cloudy_snowing, "Rain", "25%"),
      ],
    );
  }

  Widget _statCard(IconData icon, String title, String value) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: Colors.green),
            const SizedBox(height: 6),
            Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(fontSize: 15)),
          ],
        ),
      ),
    );
  }

  Widget _buildHumidityCircle() {
    final humidity = _weather!['main']['humidity']?.toDouble() ?? 0.0;

    return Column(
      children: [
        const Text("Humidity Utilization", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 10),
        SizedBox(
          height: 120,
          width: 120,
          child: CircularProgressIndicator(
            value: humidity / 100,
            strokeWidth: 10,
            backgroundColor: Colors.green.shade100,
            color: Colors.green,
          ),
        ),
        const SizedBox(height: 8),
        Text("${humidity.toInt()} %", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildForecastRow() {
    return Row(
      children: [
        _forecastCard("Sunrise", "6:20 AM", Icons.wb_sunny),
        _forecastCard("Sunset", "6:55 PM", Icons.nightlight),
      ],
    );
  }

  Widget _forecastCard(String title, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.orange),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                Text(value, style: const TextStyle(fontSize: 12)),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildWeatherTrendGraph() {
    final temp = _weather!['main']['temp']?.toDouble() ?? 0.0;
    final humidity = _weather!['main']['humidity']?.toDouble() ?? 0.0;
    final wind = _weather!['wind']['speed']?.toDouble() ?? 0.0;

    return SizedBox(
      height: 200,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: 2,
          minY: 0,
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 1,
                reservedSize: 32,
                getTitlesWidget: (value, meta) {
                  switch (value.toInt()) {
                    case 0:
                      return const Text("Temp");
                    case 1:
                      return const Text("Humidity");
                    case 2:
                      return const Text("Wind");
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: [
                FlSpot(0, temp),
                FlSpot(1, humidity),
                FlSpot(2, wind),
              ],
              isCurved: true,
              color: Colors.green,
              barWidth: 4,
              dotData: FlDotData(show: true),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGeoSection() {
    final pos = _position;
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.grey.shade300)),
      child: Row(
        children: [
          const Icon(Icons.location_on),
          const SizedBox(width: 8),
          Expanded(
            child: Text(pos != null
                ? 'Latitude: ${pos.latitude.toStringAsFixed(5)}, Longitude: ${pos.longitude.toStringAsFixed(5)}'
                : 'Location not available'),
          ),
          ElevatedButton(
            onPressed: _updateWeatherForSelectedSite,
            child: const Text('Get Location'),
          )
        ],
      ),
    );
  }

  // TIMELINE helpers (unchanged)
Widget _buildTimelineWidget(DateTime start, DateTime end) {
  if (end.isBefore(start)) {
    end = start.add(const Duration(days: 30));
  }

  // TOTAL DAYS
  final totalDays = end.difference(start).inDays;
  final completedDays = DateTime.now().difference(start).inDays.clamp(0, totalDays);
  final remainingDays = totalDays - completedDays;

  final completedPercent = ((completedDays / totalDays) * 100).clamp(0, 100).toStringAsFixed(1);
  final remainingPercent = ((remainingDays / totalDays) * 100).clamp(0, 100).toStringAsFixed(1);

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SizedBox(height: 8),

      // ---------------- DATE BARS (MATCH PROGRESS EXACTLY) ----------------
      Row(
        children: [
          Expanded(
            flex: max(1, completedDays),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade400),
                borderRadius: BorderRadius.circular(6),
                color: Colors.white,
              ),
              alignment: Alignment.center,
              child: Text(
                DateFormat("M/d/yy").format(start),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
          ),
          Expanded(
            flex: max(1, remainingDays),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 6),
              margin: const EdgeInsets.only(left: 6),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade400),
                borderRadius: BorderRadius.circular(6),
                color: Colors.white,
              ),
              alignment: Alignment.center,
              child: Text(
                DateFormat("M/d/yy").format(end),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
          ),
        ],
      ),

      const SizedBox(height: 10),

      // ---------------- PROGRESS BAR (MATCHES DATE BAR EXACTLY) ----------------
      Row(
        children: [
          Expanded(
            flex: max(1, completedDays),
            child: Container(
              height: 26,
              color: Colors.lightGreen,
            ),
          ),
          Expanded(
            flex: max(1, remainingDays),
            child: Container(
              height: 26,
              color: Colors.blue.shade900,
            ),
          ),
        ],
      ),

      const SizedBox(height: 10),

      // ---------------- PERCENTAGE ----------------
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            "Completed: $completedPercent%",
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.green),
          ),
          Text(
            "Remaining: $remainingPercent%",
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blue),
          ),
        ],
      ),
    ],
  );
}



  List<DateTime> _monthsBetween(DateTime start, DateTime end) {
    final list = <DateTime>[];
    DateTime current = DateTime(start.year, start.month, 1);
    final last = DateTime(end.year, end.month, 1);
    while (!current.isAfter(last) && list.length < 120) {
      list.add(current);
      current = DateTime(current.year, current.month + 1, 1);
    }
    return list;
  }

  // ---------------- INVESTMENT TAB (uses siteId keys) ----------------
  Widget _buildInvestment() {
    if (_selectedIndex == null) {
      return const Center(child: Text("Select a site to view investments"));
    }

    final siteId = _sites[_selectedIndex!]['id'];
    final siteDisplayName = _sites[_selectedIndex!]['name'] ?? 'Site';
    final investments = siteInvestments[siteId] ?? [];
    final incomes = siteIncomes[siteId] ?? [];
    final totalInvestment = investments.fold<double>(0, (sum, e) => sum + (e['amount'] ?? 0));
    final totalIncome = incomes.fold<double>(0, (sum, e) => sum + (e['amount'] ?? 0));
    final netProfit = totalIncome - totalInvestment;

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _buildTable("Investment", siteId, siteDisplayName)),
              const SizedBox(width: 10),
              Expanded(child: _buildTable("Income", siteId, siteDisplayName)),
            ],
          ),
          const Divider(thickness: 1),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              "Net Profit: ₹${netProfit.toStringAsFixed(2)}",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: netProfit >= 0 ? Colors.green : Colors.red,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTable(String title, String siteId, String siteDisplayName) {
    final isInvestment = title == "Investment";
    final data = isInvestment ? (siteInvestments[siteId] ?? []) : (siteIncomes[siteId] ?? []);

    final total = data.fold<double>(0, (sum, item) => sum + (item['amount'] ?? 0));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              onPressed: () async {
                final newEntry = await _showAddEntryDialog(title);
                if (newEntry != null) {
                  if (!mounted) return;
                  setState(() {
                    if (isInvestment) {
                      siteInvestments[siteId] = [...data, newEntry];
                    } else {
                      siteIncomes[siteId] = [...data, newEntry];
                    }
                  });
                  await _saveDataToFirestore(siteId);
                }
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        data.isEmpty
            ? Text("No $title data added yet.")
            : SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text("Item")),
                    DataColumn(label: Text("Vendor / Remarks")),
                    DataColumn(label: Text("Date")),
                    DataColumn(label: Text("Amount (₹)")),
                    DataColumn(label: Text("Actions")),
                  ],
                  rows: data.asMap().entries.map((entry) {
                    final index = entry.key;
                    final item = entry.value;
                    return DataRow(cells: [
                      DataCell(Text(item['item'] ?? '')),
                      DataCell(Text(item['vendor'] ?? item['remarks'] ?? '')),
                      DataCell(Text(DateFormat('dd/MM/yyyy').format(item['date']))),
                      DataCell(Text(item['amount'].toString())),
                      DataCell(Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue),
                            onPressed: () async {
                              final updatedEntry = await _showAddEntryDialog(title, existing: item);
                              if (updatedEntry != null) {
                                if (!mounted) return;
                                setState(() {
                                  data[index] = updatedEntry;
                                  if (isInvestment) {
                                    siteInvestments[siteId] = data;
                                  } else {
                                    siteIncomes[siteId] = data;
                                  }
                                });
                                await _saveDataToFirestore(siteId);
                              }
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text("Delete Entry"),
                                  content: const Text("Are you sure you want to delete this entry?"),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
                                    TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Delete")),
                                  ],
                                ),
                              );

                              if (confirm == true) {
                                if (!mounted) return;
                                setState(() {
                                  data.removeAt(index);
                                  if (isInvestment) {
                                    siteInvestments[siteId] = data;
                                  } else {
                                    siteIncomes[siteId] = data;
                                  }
                                });
                                await _saveDataToFirestore(siteId);
                              }
                            },
                          ),
                        ],
                      )),
                    ]);
                  }).toList(),
                ),
              ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            "Total $title: ₹${total.toStringAsFixed(2)}",
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
} // end of _DashboardPageState

// helpful extension
extension StringCasingExtension on String {
  String capitalizeFirst() {
    if (isEmpty) return this;
    return this[0].toUpperCase() + substring(1);
  }
}
