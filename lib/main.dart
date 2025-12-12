import 'package:flutter/material.dart';
import 'dashboard_page.dart';
import 'finance_page.dart'; // <-- Added import
import 'irrigation_page.dart';
import 'ml_focus_page.dart';
import 'alarm_page.dart';
import 'notification_page.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const CelestialHilllandApp());
}

class CelestialHilllandApp extends StatelessWidget {
  const CelestialHilllandApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
home: const HomePage(),
    );
  }
}


class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/bg.jpg',
              fit: BoxFit.cover,
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- Top logo and title ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Image.asset('assets/logo.png', height: 60, width: 60),
                          const SizedBox(width: 8),
                          Container(
                            color: const Color(0xFF0D3A5C),
                            padding: const EdgeInsets.symmetric(
                                vertical: 10, horizontal: 8),
                            child: const Text(
                              'CELESTIAL\nHILLLAND TECH',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                height: 1.2,
                              ),
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.home, color: Colors.black),
                        iconSize: 32,
                        onPressed: () {},
                      ),
                    ],
                  ),

                  const SizedBox(height: 40),

                  // --- Notifications & Alarms ---
                  Align(
                    alignment: Alignment.centerRight,
                    child: Column(
                      children: [
ElevatedButton(
  onPressed: () {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const NotificationPage()),
    );
  },
  style: ElevatedButton.styleFrom(
    backgroundColor: Colors.grey[200],
    foregroundColor: Colors.black,
    minimumSize: const Size(200, 45),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(4),
    ),
  ),
  child: const Text(
    'NOTIFICATIONS',
    style: TextStyle(fontWeight: FontWeight.bold),
  ),
),

                        const SizedBox(height: 10),
ElevatedButton(
  onPressed: () {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AlarmPage()),
    );
  },
  style: ElevatedButton.styleFrom(
    backgroundColor: Colors.grey[200],
    foregroundColor: Colors.black,
    minimumSize: const Size(200, 45),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(4),
    ),
  ),
  child: const Text(
    'ALARMS',
    style: TextStyle(fontWeight: FontWeight.bold),
  ),
),

                      ],
                    ),
                  ),

                  const Spacer(),

                  // --- Bottom Buttons ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildFeatureButton(
                        context,
                        'DASHBOARD',
                        'assets/dashboard.png',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const DashboardPage(),
                            ),
                          );
                        },
                      ),
_buildFeatureButton(
  context,
  'ML FOCUS',
  'assets/ml.png',
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const MLFocusPage()),
    );
  },
),

_buildFeatureButton(
  context,
  'IRRIGATION',
  'assets/irrigation.jpg',
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const IrrigationPage()),
    );
  },
),

_buildFeatureButton(
  context,
  'FINANCE',
  'assets/finance.png',
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const FinancePage()),
    );
  },
),

                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureButton(
    BuildContext context,
    String title,
    String imagePath, {
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 120,
        width: 120,
        decoration: BoxDecoration(
          color: const Color(0xFF0D3A5C),
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              offset: Offset(2, 2),
              blurRadius: 5,
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Image.asset(imagePath, fit: BoxFit.contain),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
