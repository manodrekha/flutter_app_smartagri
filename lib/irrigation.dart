import 'package:flutter/material.dart';

class IrrigationPage extends StatefulWidget {
  const IrrigationPage({super.key});

  @override
  State<IrrigationPage> createState() => _IrrigationPageState();
}

class _IrrigationPageState extends State<IrrigationPage> {
  bool isPumpOn = false;
  bool isValveOn = false;
  bool isDripOn = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D3A5C),
        title: const Text('Irrigation Control'),
        centerTitle: true,
      ),
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/bg.jpg'),
            fit: BoxFit.cover,
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildControlSwitch(
                  title: 'Pump Control',
                  value: isPumpOn,
                  onChanged: (val) {
                    setState(() => isPumpOn = val);
                  },
                ),
                const SizedBox(height: 30),
                _buildControlSwitch(
                  title: 'Valve Control',
                  value: isValveOn,
                  onChanged: (val) {
                    setState(() => isValveOn = val);
                  },
                ),
                const SizedBox(height: 30),
                _buildControlSwitch(
                  title: 'Drip System',
                  value: isDripOn,
                  onChanged: (val) {
                    setState(() => isDripOn = val);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildControlSwitch({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Card(
      color: Colors.white.withOpacity(0.9),
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: Icon(
          value ? Icons.power : Icons.power_off,
          color: value ? Colors.green : Colors.red,
          size: 40,
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        trailing: Switch(
          value: value,
          activeColor: Colors.green,
          inactiveThumbColor: Colors.red,
          onChanged: onChanged,
        ),
      ),
    );
  }
}
