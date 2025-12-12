import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:csv/csv.dart';

class SiteDetailPage extends StatefulWidget {
  final String siteName;
  const SiteDetailPage({super.key, required this.siteName});

  @override
  State<SiteDetailPage> createState() => _SiteDetailPageState();
}

class _SiteDetailPageState extends State<SiteDetailPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Lists to store Investment/Income
  List<Map<String, dynamic>> investmentData = [];
  List<Map<String, dynamic>> incomeData = [];

  double totalInvestment = 0;
  double totalIncome = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  // Show dialog to add new item
  void _addItem(String type) async {
    TextEditingController controller = TextEditingController();

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("Enter $type amount"),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(hintText: "₹0"),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel")),
          TextButton(
              onPressed: () {
                double value = double.tryParse(controller.text) ?? 0;
                if (value > 0) {
                  setState(() {
                    if (type == "Investment") {
                      investmentData
                          .add({"amount": value, "time": DateTime.now()});
                      totalInvestment += value;
                    } else {
                      incomeData.add({"amount": value, "time": DateTime.now()});
                      totalIncome += value;
                    }
                  });
                  _saveToCSV(type, value);
                }
                Navigator.pop(context);
              },
              child: const Text("Add")),
        ],
      ),
    );
  }

  // Save data to CSV file
  Future<void> _saveToCSV(String type, double value) async {
    final directory = await getApplicationDocumentsDirectory();
    final path = "${directory.path}/investment_income.csv";
    final file = File(path);

    List<List<dynamic>> rows = [];
    if (await file.exists()) {
      final content = await file.readAsString();
      if (content.isNotEmpty) {
        rows = const CsvToListConverter().convert(content);
      }
    }

    rows.add([DateTime.now().toIso8601String(), type, value]);

    String csv = const ListToCsvConverter().convert(rows);
    await file.writeAsString(csv);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.siteName),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: "Site"),
            Tab(text: "Farm Data"),
            Tab(text: "Investment"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          Center(child: Text("${widget.siteName} Overview")),
          Center(child: Text("Farm Data for ${widget.siteName}")),
          _buildInvestmentTable(),
        ],
      ),
    );
  }

  Widget _buildInvestmentTable() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const Text(
            "Investment / Income",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: Row(
              children: [
                Expanded(child: _buildTable("Investment")),
                const SizedBox(width: 12),
                Expanded(child: _buildTable("Income")),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTable(String title) {
    List<Map<String, dynamic>> data =
        title == "Investment" ? investmentData : incomeData;
    double total = title == "Investment" ? totalInvestment : totalIncome;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          color: Colors.yellow,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16)),
              InkWell(
                onTap: () => _addItem(title),
                child: const Icon(Icons.add_box),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: data.length,
            itemBuilder: (context, i) {
              final item = data[i];
              return ListTile(
                leading: Text("${i + 1}"),
                title: Text("₹${item['amount']}"),
                subtitle: Text(item['time'].toString()),
              );
            },
          ),
        ),
        const Divider(),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text("Total : ₹$total",
              style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
