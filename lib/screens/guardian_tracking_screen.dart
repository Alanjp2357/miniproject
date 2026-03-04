import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants.dart';

class GuardianTrackingScreen extends StatefulWidget {
  final String userId; // The ID of the user being tracked

  const GuardianTrackingScreen({super.key, required this.userId});

  @override
  State<GuardianTrackingScreen> createState() => _GuardianTrackingScreenState();
}

class _GuardianTrackingScreenState extends State<GuardianTrackingScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final MapController _mapController = MapController();
  LatLng? _lastKnownPosition;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Guardian Tracking"),
        backgroundColor: Colors.white,
        foregroundColor: kTextColor,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _firestore
            .collection('live_locations')
            .doc(widget.userId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text("Waiting for live location..."));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final bool isSharing = data['isSharing'] ?? false;

          if (!isSharing) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.location_off, size: 60, color: Colors.grey),
                  SizedBox(height: 10),
                  Text(
                    "Journey Ended",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            );
          }

          final double? lat = data['latitude'];
          final double? lng = data['longitude'];

          if (lat == null || lng == null) {
            return const Center(child: Text("Invalid location data"));
          }

          final currentPos = LatLng(lat, lng);

          // Move map if position changed significantly or first load
          if (_lastKnownPosition == null || _lastKnownPosition != currentPos) {
            _lastKnownPosition = currentPos;
            // Use addPostFrameCallback to move map safely during build
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _mapController.move(currentPos, 15.0);
            });
          }

          return FlutterMap(
            mapController: _mapController,
            options: MapOptions(initialCenter: currentPos, initialZoom: 15.0),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.miniproject',
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: currentPos,
                    width: 80,
                    height: 80,
                    child: const Icon(
                      Icons.person_pin_circle,
                      color: Colors.red,
                      size: 40,
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
