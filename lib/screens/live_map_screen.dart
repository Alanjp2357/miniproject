import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/journey_service.dart';
import '../services/sos_service.dart';
import '../services/route_service.dart';
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
  final SosService _sosService = SosService();
  GoogleMapController? _mapController;
  StreamSubscription<DocumentSnapshot>? _journeySubscription;

  String? _activeJourneyId;
  bool _isLoading = true;
  bool _isFollowingUser = true;

  Map<String, dynamic>? _journeyData;
  bool _isJourneyCompleted = false;
  List<LatLng> _routePoints = [];
  final RouteService _routeService = RouteService();

  @override
  void initState() {
    super.initState();
    _initMapScreen();
  }

  Future<void> _initMapScreen() async {
    String? journeyId = widget.journeyId;

    if (kIsWeb && journeyId == null) {
      // Check URL parameters for journeyId
      final uri = Uri.base;
      if (uri.queryParameters.containsKey('journeyId')) {
        journeyId = uri.queryParameters['journeyId'];
      }
    }

    if (journeyId == null) {
      journeyId = await _journeyService.getActiveJourneyId();
    }
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
              final prevData = _journeyData;
              setState(() {
                _journeyData = data;
              });

              // Fetch Route
              final currentLat = data['currentLat'] as double?;
              final currentLng = data['currentLng'] as double?;
              final destLat = data['destinationLat'] as double?;
              final destLng = data['destinationLng'] as double?;

              if (currentLat != null && currentLng != null && destLat != null && destLng != null) {
                bool shouldFetchRoute = false;
                
                if (_routePoints.isEmpty) {
                  shouldFetchRoute = true;
                } else if (prevData != null) {
                  final prevLat = prevData['currentLat'] as double?;
                  final prevLng = prevData['currentLng'] as double?;
                  
                  if (prevLat != null && prevLng != null) {
                    // Simple distance check: ~100 meters (approx 0.001 degrees)
                    final double latDiff = (currentLat - prevLat).abs();
                    final double lngDiff = (currentLng - prevLng).abs();
                    if (latDiff > 0.001 || lngDiff > 0.001) {
                      shouldFetchRoute = true;
                    }
                  } else {
                    shouldFetchRoute = true;
                  }
                }

                if (shouldFetchRoute) {
                  _routeService.getRoute(
                    LatLng(currentLat, currentLng),
                    LatLng(destLat, destLng),
                  ).then((points) {
                    if (mounted && points.isNotEmpty) {
                      setState(() {
                        _routePoints = points;
                      });
                    }
                  });
                }
              }

              // Recenter
              if (_isFollowingUser) {
                if (currentLat != null && currentLng != null) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _mapController?.animateCamera(
                      CameraUpdate.newLatLng(LatLng(currentLat, currentLng)),
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
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: _buildAppBar(false),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_activeJourneyId == null) {
      return Scaffold(
        appBar: _buildAppBar(false),
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
        appBar: _buildAppBar(false),
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
        appBar: _buildAppBar(false),
        body: const Center(child: Text("Waiting for location data...")),
      );
    }

    final currentUserId = JourneyService().getCurrentUserId();
    final journeyUserId = _journeyData!['userId'] as String?;
    final isOwner = currentUserId == journeyUserId;

    final currentLat = _journeyData!['currentLat'] as double?;
    final currentLng = _journeyData!['currentLng'] as double?;
    final destLat = _journeyData!['destinationLat'] as double?;
    final destLng = _journeyData!['destinationLng'] as double?;
    final riskLevel = _journeyData!['riskLevel'] as String? ?? 'LOW';
    final lastUpdated = _journeyData!['lastUpdated'] as Timestamp?;
    final destinationName = _journeyData!['destinationName'] as String? ?? "Destination";

    if (currentLat == null || currentLng == null) {
      return Scaffold(
        appBar: _buildAppBar(isOwner),
        body: const Center(child: Text("Waiting for location data...")),
      );
    }

    final currentLatLng = LatLng(currentLat, currentLng);
    LatLng? destLatLng;
    if (destLat != null && destLng != null) {
      destLatLng = LatLng(destLat, destLng);
    }

    Color riskColor = Colors.green;
    String riskTitle = "Safe";
    String riskDesc = "Movement looks normal. On route.";

    if (riskLevel == 'MEDIUM') {
      riskColor = Colors.orange;
      riskTitle = "Caution";
      riskDesc = "Some deviations detected or progress is slow.";
    } else if (riskLevel == 'HIGH') {
      riskColor = Colors.red;
      riskTitle = "DANGER";
      riskDesc = "Significant deviation or SOS triggered!";
    }

    return Scaffold(
      appBar: _buildAppBar(isOwner),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: currentLatLng,
              zoom: 15.0,
            ),
            onMapCreated: (controller) => _mapController = controller,
            onCameraMoveStarted: () {
              if (_isFollowingUser) {
                setState(() => _isFollowingUser = false);
              }
            },
            polylines: _routePoints.isNotEmpty
                ? {
                    Polyline(
                      polylineId: const PolylineId('route'),
                      points: _routePoints,
                      color: kAccentColor,
                      width: 5,
                    ),
                  }
                : destLatLng != null
                    ? {
                        Polyline(
                          polylineId: const PolylineId('fallback_route'),
                          points: [currentLatLng, destLatLng],
                          color: kAccentColor.withValues(alpha: 0.5),
                          width: 4,
                        ),
                      }
                    : {},
            markers: {
              if (destLatLng != null)
                Marker(
                  markerId: const MarkerId('destination'),
                  position: destLatLng,
                  icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
                  infoWindow: InfoWindow(title: destinationName),
                ),
              Marker(
                markerId: const MarkerId('current_location'),
                position: currentLatLng,
                icon: BitmapDescriptor.defaultMarkerWithHue(
                  riskLevel == 'HIGH'
                      ? BitmapDescriptor.hueRed
                      : riskLevel == 'MEDIUM'
                          ? BitmapDescriptor.hueOrange
                          : BitmapDescriptor.hueAzure,
                ),
                infoWindow: InfoWindow(title: isOwner ? 'You' : 'Friend'),
              ),
            },
          ),

          // Top Info Box Inside Stack (Risk Analysis)
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
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: riskColor.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isOwner ? Icons.security : Icons.visibility,
                            color: riskColor,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isOwner ? "Your Journey Status" : "Friend's Progress",
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                "To: $destinationName",
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: riskColor,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            riskTitle,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 20),
                    Row(
                      children: [
                        const Icon(Icons.analytics_outlined, size: 16, color: Colors.blue),
                        const SizedBox(width: 8),
                        const Text(
                          "Risk Analysis:",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            riskDesc,
                            style: const TextStyle(fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Last sync: ${lastUpdated != null ? "${lastUpdated.toDate().hour.toString().padLeft(2, '0')}:${lastUpdated.toDate().minute.toString().padLeft(2, '0')}" : "Pending..."}",
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                        if (!isOwner)
                          const Text(
                            "LIVE DATA",
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Role-specific Action Buttons
          Positioned(
            bottom: 30,
            left: 20,
            child: isOwner
                ? Row(
                    children: [
                      FloatingActionButton.extended(
                        onPressed: () async {
                          await _journeyService.stopJourney();
                          if (mounted) Navigator.pop(context);
                        },
                        heroTag: 'end_journey',
                        backgroundColor: Colors.green,
                        icon: const Icon(Icons.check, color: Colors.white),
                        label: const Text("I'M SAFE", style: TextStyle(color: Colors.white)),
                      ),
                      const SizedBox(width: 10),
                      FloatingActionButton(
                        onPressed: () {
                          final phoneNumbers = _journeyData!['guardianPhone'] != null
                              ? [_journeyData!['guardianPhone'] as String]
                              : <String>[];
                          _sosService.sendSOS(phoneNumbers, context);
                        },
                        heroTag: 'sos_journey',
                        backgroundColor: Colors.red,
                        child: const Icon(Icons.emergency, color: Colors.white),
                      ),
                    ],
                  )
                : FloatingActionButton.extended(
                    onPressed: () {
                      final phone = _journeyData!['userPhone'] as String?;
                      if (phone != null && phone.isNotEmpty) {
                        _sosService.initiateCall(phone);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Phone number not available")),
                        );
                      }
                    },
                    backgroundColor: Colors.blue,
                    icon: const Icon(Icons.phone, color: Colors.white),
                    label: const Text("CALL FRIEND", style: TextStyle(color: Colors.white)),
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
                _mapController?.animateCamera(CameraUpdate.newLatLngZoom(currentLatLng, 15.0));
              },
              backgroundColor: _isFollowingUser ? kPrimaryColor : Colors.grey,
              child: const Icon(Icons.my_location, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(bool isOwner) {
    return AppBar(
      title: Text(isOwner ? "My Journey" : "Tracking Friend"),
      backgroundColor: Colors.white,
      foregroundColor: kTextColor,
      elevation: 0,
      centerTitle: true,
    );
  }
}
