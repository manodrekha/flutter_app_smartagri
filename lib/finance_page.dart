import 'package:flutter/material.dart';
import 'package:math_expressions/math_expressions.dart';
import 'package:fl_chart/fl_chart.dart';

class FinancePage extends StatefulWidget {
  const FinancePage({super.key});

  @override
  State<FinancePage> createState() => _FinancePageState();
}

class _FinancePageState extends State<FinancePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Calculator
  String input = '';
  String output = '0';
  bool isRad = true;

  // ROI calculator
  final TextEditingController principalController = TextEditingController();
  final TextEditingController gainController = TextEditingController();
  final TextEditingController timeController = TextEditingController();
  String roiResult = '';
  double? principal;
  double? gain;
  double? roi;
  double? annualizedROI;

  final List<String> buttons = [
    'Rad', 'x!', '(', ')', '%', 'CLEAR',
    'sin', 'cos', 'tan', '√', 'ln', '÷',
    '7', '8', '9', '×',
    '4', '5', '6', '−',
    '1', '2', '3', '+',
    'π', 'e', 'x^y', 'log', '=', '0'
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  // --- Calculator Logic ---
  void _onButtonPressed(String value) {
    setState(() {
      if (value == 'CLEAR') {
        input = '';
        output = '0';
      } else if (value == '=') {
        _calculate();
      } else if (value == 'Rad') {
        isRad = !isRad;
      } else {
        input += value;
      }
    });
  }

  void _calculate() {
    try {
      String finalInput = input
          .replaceAll('×', '*')
          .replaceAll('÷', '/')
          .replaceAll('−', '-')
          .replaceAll('√', 'sqrt')
          .replaceAll('π', 'pi')
          .replaceAll('e', 'e')
          .replaceAll('^', '^');

      Parser p = Parser();
      Expression exp = p.parse(finalInput);
      ContextModel cm = ContextModel();
      double eval = exp.evaluate(EvaluationType.REAL, cm);

      output = eval.toString();
    } catch (e) {
      output = 'Error';
    }
  }

  // --- ROI Logic ---
  void _calculateROI() {
    principal = double.tryParse(principalController.text);
    gain = double.tryParse(gainController.text);
    double? time = double.tryParse(timeController.text);

    if (principal == null || gain == null || time == null || principal! <= 0 || time <= 0) {
      setState(() {
        roiResult = 'Please enter valid values';
        roi = null;
      });
      return;
    }

    roi = ((gain! - principal!) / principal!) * 100;
    annualizedROI = roi! / time;

    setState(() {
      roiResult =
          'Total ROI: ${roi!.toStringAsFixed(2)}%\nAnnualized ROI: ${annualizedROI!.toStringAsFixed(2)}%';
    });
  }

  void _resetROI() {
    setState(() {
      principalController.clear();
      gainController.clear();
      timeController.clear();
      roiResult = '';
      roi = null;
      principal = null;
      gain = null;
    });
  }

  // --- ROI Chart ---
  Widget _buildROIChart() {
    if (roi == null || principal == null || gain == null) {
      return const SizedBox.shrink();
    }

    return Container(
      height: 250,
      padding: const EdgeInsets.all(12),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: true, reservedSize: 40)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  switch (value.toInt()) {
                    case 0:
                      return const Text('Initial');
                    case 1:
                      return const Text('Final');
                    default:
                      return const SizedBox.shrink();
                  }
                },
              ),
            ),
          ),
          gridData: const FlGridData(show: true),
          barGroups: [
            BarChartGroupData(x: 0, barRods: [
              BarChartRodData(toY: principal!, color: Colors.blue, width: 40)
            ]),
            BarChartGroupData(x: 1, barRods: [
              BarChartRodData(toY: gain!, color: Colors.green, width: 40)
            ]),
          ],
        ),
      ),
    );
  }

  // --- UI ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Finance Tools'),
        backgroundColor: const Color(0xFF0D3A5C),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Calculator'),
            Tab(text: 'ROI Calculator'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // --- Calculator Tab ---
          Column(
            children: [
              Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.all(16),
                child: Text(
                  input,
                  style: const TextStyle(fontSize: 24, color: Colors.grey),
                ),
              ),
              Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.all(16),
                child: Text(
                  output,
                  style: const TextStyle(
                      fontSize: 36, fontWeight: FontWeight.bold),
                ),
              ),
              const Divider(),
              Expanded(
                child: GridView.builder(
                  itemCount: buttons.length,
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 6,
                    mainAxisSpacing: 4,
                    crossAxisSpacing: 4,
                  ),
                  padding: const EdgeInsets.all(8),
                  itemBuilder: (context, index) {
                    final btn = buttons[index];
                    return ElevatedButton(
                      onPressed: () => _onButtonPressed(btn),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: btn == '='
                            ? Colors.blue
                            : btn == 'CLEAR'
                                ? Colors.redAccent
                                : Colors.grey[300],
                        foregroundColor: btn == '=' || btn == 'CLEAR'
                            ? Colors.white
                            : Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      child: Text(
                        btn,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),

          // --- ROI Calculator Tab ---
          SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                const Text(
                  'ROI Calculator',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0D3A5C),
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: principalController,
                  decoration: const InputDecoration(
                    labelText: 'Initial Investment (₹)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: gainController,
                  decoration: const InputDecoration(
                    labelText: 'Final Amount (₹)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: timeController,
                  decoration: const InputDecoration(
                    labelText: 'Duration (in years)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _calculateROI,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0D3A5C),
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 50),
                        ),
                        child: const Text(
                          'CALCULATE',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _resetROI,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[300],
                          foregroundColor: Colors.black,
                          minimumSize: const Size(double.infinity, 50),
                        ),
                        child: const Text(
                          'RESET',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  roiResult,
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                _buildROIChart(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
