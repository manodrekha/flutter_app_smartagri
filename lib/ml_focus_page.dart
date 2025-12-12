import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

class MLFocusPage extends StatefulWidget {
  const MLFocusPage({super.key});

  @override
  State<MLFocusPage> createState() => _MLFocusPageState();
}

class _MLFocusPageState extends State<MLFocusPage> {
  Uint8List? _imageBytes;
  String _result = "";

  // Pick image for both web and mobile
  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true, // required for web
    );

    if (result != null && result.files.isNotEmpty) {
      final file = result.files.first;
      setState(() {
        _imageBytes = file.bytes;
        _result = "";
      });

      // Simulate ML detection delay
      await Future.delayed(const Duration(seconds: 2));

      // Dummy result for demonstration
      setState(() {
        _result = _mockDiseaseDetection(file.name);
      });
    }
  }

  // Mock function: Replace this with your real ML model output
  String _mockDiseaseDetection(String filename) {
    final diseases = [
      'Healthy Leaf',
      'Powdery Mildew',
      'Leaf Spot Disease',
      'Bacterial Blight',
      'Rust Infection',
    ];
    // Simple pseudo-random selection
    return diseases[filename.hashCode.abs() % diseases.length];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'ML Focus - Leaf Disease Detection',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF0D3A5C),
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/bg.jpg'),
            fit: BoxFit.cover,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset('assets/ml.png', height: 100),
                const SizedBox(height: 20),
                const Text(
                  'Leaf Disease Detection',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0D3A5C),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Upload a photo of a leaf to detect possible diseases using AI.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 30),

                // Browse button
                ElevatedButton.icon(
                  onPressed: _pickImage,
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Browse Leaf Image'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D3A5C),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        vertical: 12, horizontal: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),

                const SizedBox(height: 30),

                // Show selected image
                if (_imageBytes != null)
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [
                        BoxShadow(
                            color: Colors.black26,
                            offset: Offset(2, 2),
                            blurRadius: 5),
                      ],
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Image.memory(
                      _imageBytes!,
                      width: 250,
                      height: 250,
                      fit: BoxFit.cover,
                    ),
                  ),

                const SizedBox(height: 20),

                // Display ML result
                if (_result.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Detected Result: $_result',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0D3A5C),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                const SizedBox(height: 40),
                ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Back to Home'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[300],
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(
                        vertical: 10, horizontal: 20),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
