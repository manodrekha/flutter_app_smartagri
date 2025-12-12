import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ExcelUploader extends StatefulWidget {
  // If you want the user to enter a site name when the file doesn't contain it:
  final String? defaultSiteName;
  const ExcelUploader({Key? key, this.defaultSiteName}) : super(key: key);

  @override
  State<ExcelUploader> createState() => _ExcelUploaderState();
}

class _ExcelUploaderState extends State<ExcelUploader> {
  bool _busy = false;
  String? _status;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ElevatedButton.icon(
          icon: const Icon(Icons.upload_file),
          label: const Text("Pick Excel and Upload to Firebase"),
          onPressed: _busy ? null : _pickAndUpload,
        ),
        if (_status != null) Padding(
          padding: const EdgeInsets.only(top:8.0),
          child: Text(_status!),
        )
      ],
    );
  }

  Future<void> _pickAndUpload() async {
    setState(() {
      _busy = true;
      _status = "Picking file...";
    });

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
      );

      if (result == null) {
        setState(() { _status = "File pick cancelled."; _busy = false; });
        return;
      }

      final path = result.files.single.path!;
      final fileBytes = File(path).readAsBytesSync();

      setState(() { _status = "Parsing Excel..."; });

      final excel = Excel.decodeBytes(fileBytes);

      // We'll assume data is in first sheet
      final sheetName = excel.sheets.keys.first;
      final sheet = excel.sheets[sheetName]!;
      if (sheet.maxRows == 0) {
        setState(() { _status = "Empty sheet."; _busy = false; });
        return;
      }

      // Read header row (assume row 0 is header)
      final headerRow = sheet.row(0).map((cell) => cell == null ? null : cell.value?.toString()).toList();

      // Normalize header names and find columns index
      final headers = <int, String>{};
      for (int c = 0; c < headerRow.length; c++) {
        final h = headerRow[c];
        if (h != null && h.trim().isNotEmpty) {
          headers[c] = h.trim();
        }
      }

      // If there's a 'Site' column, we will use it, otherwise we'll use defaultSiteName
      final siteColumnIndex = headers.entries
          .firstWhere(
            (e) => e.value.toLowerCase() == 'site' || e.value.toLowerCase() == 'site_name' || e.value.toLowerCase() == 'sitename',
            orElse: () => MapEntry(-1, ''),
          ).key;

      // Identify Timestamp column index (try common names)
      final timestampIndex = headers.entries
          .firstWhere(
            (e) {
              final v = e.value.toLowerCase();
              return v.contains('time') || v == 'timestamp' || v.contains('date');
            },
            orElse: () => MapEntry(-1, ''),
          ).key;

      // Sensor columns: detect pattern like "SoilMoisture_Sensor1"
      // We'll parse each header into sensorType and sensorId using "_" delimiter
      final sensorColumnMap = <int, Map<String,String>>{}; // colIndex -> {type:..., id:...}
      headers.forEach((col, name) {
        if (col == siteColumnIndex || col == timestampIndex) return;
        final parts = name.split(RegExp(r'[_\s]')); // split by underscore or space
        if (parts.length >= 2) {
          // e.g. ["SoilMoisture", "Sensor1"] -> type=SoilMoisture, id=Sensor1
          final type = parts[0];
          final id = parts.sublist(1).join('_'); // join remainder as id
          sensorColumnMap[col] = {'type': type, 'id': id};
        } else {
          // If header doesn't follow pattern, put everything under 'Unknown'
          sensorColumnMap[col] = {'type': 'Unknown', 'id': name};
        }
      });

      if (sensorColumnMap.isEmpty) {
        setState(() { _status = "No sensor columns detected."; _busy = false; });
        return;
      }

      setState(() { _status = "Uploading ${sheet.maxRows - 1} rows..."; });

      final firestore = FirebaseFirestore.instance;

      // Iterate rows starting from 1 (row 0 = header)
      for (int r = 1; r < sheet.maxRows; r++) {
        final row = sheet.row(r);

        // Determine siteName for this row
        String siteName = widget.defaultSiteName ?? 'SITE-1';
        if (siteColumnIndex != -1 && siteColumnIndex < row.length) {
          final val = row[siteColumnIndex]?.value;
          if (val != null && val.toString().trim().isNotEmpty) siteName = val.toString().trim();
        }

        // Parse timestamp
        DateTime? ts;
        if (timestampIndex != -1 && timestampIndex < row.length) {
          final v = row[timestampIndex]?.value;
          if (v is DateTime) ts = v;
          else if (v != null) {
            try { ts = DateTime.parse(v.toString()); } catch (_) {}
          }
        }
        ts ??= DateTime.now();

        // Build sensors map grouped by sensor type
        final Map<String, Map<String, dynamic>> sensors = {};

        sensorColumnMap.forEach((colIndex, meta) {
          if (colIndex >= row.length) return;
          final raw = row[colIndex]?.value;
          if (raw == null) return;
          final type = meta['type'] ?? 'Unknown';
          final id = meta['id'] ?? 'sensor';

          sensors.putIfAbsent(type, () => <String, dynamic>{});
          // try numeric parse
          dynamic val = raw;
          if (raw is num) val = raw;
          else {
            final s = raw.toString().trim();
            final numVal = num.tryParse(s);
            if (numVal != null) val = numVal;
          }
          sensors[type]![id] = val;
        });

        // Upload to Firestore:
        final siteDocRef = firestore.collection('sites').doc(siteName);
        final readingsCol = siteDocRef.collection('sensor_readings');

        await readingsCol.add({
          'timestamp': Timestamp.fromDate(ts),
          'sensors': sensors,
        });

        // optional: update site's metadata if missing
        await siteDocRef.set({'name': siteName}, SetOptions(merge: true));
      }

      setState(() { _status = "Upload complete."; _busy = false; });
    } catch (e, st) {
      setState(() { _status = "Error: $e"; _busy = false; });
      debugPrint(st.toString());
    }
  }
}
