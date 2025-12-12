import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapPickerPage extends StatefulWidget {
  final double initialLat;
  final double initialLon;

  MapPickerPage({required this.initialLat, required this.initialLon});

  @override
  _MapPickerPageState createState() => _MapPickerPageState();
}

class _MapPickerPageState extends State<MapPickerPage> {
  LatLng? pickedLocation;

  @override
  void initState() {
    super.initState();
    pickedLocation = LatLng(widget.initialLat, widget.initialLon);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Pick Location on Map"),
        backgroundColor: Colors.green,
      ),
      body: GoogleMap(
        initialCameraPosition: CameraPosition(
          target: pickedLocation!,
          zoom: 15,
        ),
        onTap: (pos) {
          setState(() {
            pickedLocation = pos;
          });
        },
        markers: {
          Marker(
            markerId: MarkerId("picked"),
            position: pickedLocation!,
          )
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.green,
        child: Icon(Icons.check, color: Colors.white),
        onPressed: () {
          Navigator.pop(context, pickedLocation);
        },
      ),
    );
  }
}
