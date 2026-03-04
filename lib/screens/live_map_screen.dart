import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/journey_service.dart';
import '../constants.dart';

class LiveMapScreen extends StatefulWidget {
  final bool isJourney;
  final String? journeyId;

  const LiveMapScreen({super.key, required this.isJourney, this.journeyId});

  @override
  State<LiveMapScreen> createState() => _LiveMapScreenState();
}

class _LiveMapScreenState extends State<LiveMapScreen> {
  final JourneyService _journeyService = JourneyService();
  final MapController _mapController = MapController();
  StreamSubscription<DocumentSnapshot>? _journeySubscription;

  String? _activeJourneyId;
  bool _isLoading = true;
  bool _isFollowingUser = true;

  Map<String, dynamic>? _journeyData;
  bool _isJourneyCompleted = false;

  @override
  void initState() {
    super.initState();
    _initMapScreen();
  }

  Future<void> _initMapScreen() async {
    final String? journeyId =
        widget.journeyId ?? await _journeyService.getActiveJourneyId();
    if (mounted) {
      if (journeyId == null) {
        setState(() {
          _activeJourneyId = null;
          _isLoading = false;
        });
      } else {
        setState(() {
          _activeJourneyId = journeyId;
          _isLoading = false;
        });
        _startListeningToJourney(journeyId);
      }
    }
  }

  void _startListeningToJourney(String journeyId) {
    _journeySubscription = FirebaseFirestore.instance
        .collection('journeys')
        .doc(journeyId)
        .snapshots()
        .listen((snapshot) {
          if (!snapshot.exists) {
            if (mounted) {
              setState(() {
                _isJourneyCompleted = true; // or not found
              });
            }
            return;
          }

          final data = snapshot.data() as Map<String, dynamic>;
          final isActive = data['isActive'] as bool? ?? false;

          if (!isActive) {
            _journeySubscription?.cancel();
            if (mounted) {
              setState(() {
                _isJourneyCompleted = true;
                _journeyData = data;
              });
            }
            return;
          }

          if (mounted) {
            setState(() {
              _journeyData = data;
            });

            // Recenter
            if (_isFollowingUser) {
              final currentLat = data['currentLat'] as double?;
              final currentLng = data['currentLng'] as double?;
              if (currentLat != null && currentLng != null) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _mapController.move(
                    LatLng(currentLat, currentLng),
                    _mapController.camera.zoom,
                  );
                });
              }
            }
          }
        });
  }

  @override
  void dispose() {
    _journeySubscription?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: _buildAppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_activeJourneyId == null) {
      return Scaffold(
        appBar: _buildAppBar(),
        body: const Center(
          child: Text(
            "No Active Journey",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
      );
    }

    if (_isJourneyCompleted) {
      return Scaffold(
        appBar: _buildAppBar(),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 80),
              SizedBox(height: 16),
              Text(
                "Journey Completed",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      );
    }

    if (_journeyData == null) {
      return Scaffold(
        appBar: _buildAppBar(),
        body: const Center(child: Text("Waiting for location data...")),
      );
    }

    final currentLat = _journeyData!['currentLat'] as double?;
    final currentLng = _journeyData!['currentLng'] as double?;
    final destLat = _journeyData!['destinationLat'] as double?;
    final destLng = _journeyData!['destinationLng'] as double?;
    final riskLevel = _journeyData!['riskLevel'] as String? ?? 'LOW';
    final lastUpdated = _journeyData!['lastUpdated'] as Timestamp?;

    if (currentLat == null || currentLng == null) {
      return Scaffold(
        appBar: _buildAppBar(),
        body: const Center(child: Text("Waiting for location data...")),
      );
    }

    final currentLatLng = LatLng(currentLat, currentLng);
    LatLng? destLatLng;
    if (destLat != null && destLng != null) {
      destLatLng = LatLng(destLat, destLng);
    }

    Color riskColor = Colors.green;
    if (riskLevel == 'MEDIUM') riskColor = Colors.orange;
    if (riskLevel == 'HIGH') riskColor = Colors.red;

    return Scaffold(
      appBar: _buildAppBar(),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: currentLatLng,
              initialZoom: 15.0,
              onPositionChanged: (position, hasGesture) {
                if (hasGesture && _isFollowingUser) {
                  setState(() {
                    _isFollowingUser = false;
                  });
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.miniproject',
              ),
              if (destLatLng != null)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: [currentLatLng, destLatLng],
                      color: Colors.blueAccent,
                      strokeWidth: 4.0,
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  if (destLatLng != null)
                    Marker(
                      point: destLatLng,
                      width: 60,
                      height: 60,
                      child: const Icon(
                        Icons.location_on,
                        color: Colors.green,
                        size: 40,
                      ),
                    ),
                  Marker(
                    point: currentLatLng,
                    width: 80,
                    height: 80,
                    child: Icon(Icons.my_location, color: riskColor, size: 40),
                  ),
                ],
              ),
            ],
          ),

          // Top Info Box Inside Stack
          Positioned(
            top: 20,
            left: 20,
            right: 20,
            child: SafeArea(
              child: Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: const [
                    BoxShadow(color: Colors.black12, blurRadius: 10),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Risk Level:",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: riskColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            riskLevel,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: riskColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Last Updated:"),
                        Text(
                          lastUpdated != null
                              ? "${lastUpdated.toDate().hour.toString().padLeft(2, '0')}:${lastUpdated.toDate().minute.toString().padLeft(2, '0')}"
                              : "Waiting...",
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Recenter Button
          Positioned(
            bottom: 30,
            right: 20,
            child: FloatingActionButton(
              onPressed: () {
                setState(() {
                  _isFollowingUser = true;
                });
                _mapController.move(currentLatLng, 15.0);
              },
              backgroundColor: _isFollowingUser ? kPrimaryColor : Colors.grey,
              child: const Icon(Icons.my_location, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text("Live Journey"),
      backgroundColor: Colors.white,
      foregroundColor: kTextColor,
      elevation: 0,
      actions: [
        if (_activeJourneyId != null && !_isJourneyCompleted)
          IconButton(
            icon: const Icon(Icons.phone, color: Colors.blue),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Calling Guardian...')),
              );
            },
          ),
      ],
    );
  }
}
