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
              final currentLat = (data['currentLat'] as num?)?.toDouble();
              final currentLng = (data['currentLng'] as num?)?.toDouble();
              final destLat = (data['destinationLat'] as num?)?.toDouble();
              final destLng = (data['destinationLng'] as num?)?.toDouble();

              if (currentLat != null && currentLng != null && destLat != null && destLng != null) {
                bool shouldFetchRoute = false;
                
                // CRITICAL FIX: If route is empty, ALWAYS try to fetch.
                // Otherwise check distance from LAST FETCH position.
                if (_routePoints.isEmpty) {
                  shouldFetchRoute = true;
                } else if (prevData != null) {
                  final prevLat = (prevData['currentLat'] as num?)?.toDouble();
                  final prevLng = (prevData['currentLng'] as num?)?.toDouble();
                  
                  if (prevLat != null && prevLng != null) {
                    final double latDiff = (currentLat - prevLat).abs();
                    final double lngDiff = (currentLng - prevLng).abs();
                    if (latDiff > 0.0003 || lngDiff > 0.0003) {
                      shouldFetchRoute = true;
                    }
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
                          patterns: [PatternItem.dash(10), PatternItem.gap(10)],
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

          // Top Info Box Inside Stack (Risk Analysis) - Professional Glassmorphism
          Positioned(
            top: 20,
            left: 15,
            right: 15,
            child: SafeArea(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: kCardColor.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: riskColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              isOwner ? Icons.shield_outlined : Icons.visibility_outlined,
                              color: riskColor,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isOwner ? "TRACKING ACTIVE" : "FRIEND'S JOURNEY",
                                  style: TextStyle(
                                    color: riskColor.withValues(alpha: 0.8),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  destinationName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: kTextColor,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: riskColor.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: riskColor.withValues(alpha: 0.5)),
                            ),
                            child: Text(
                              riskTitle.toUpperCase(),
                              style: TextStyle(
                                color: riskColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Divider(color: Colors.white10, height: 1),
                      ),
                      Row(
                        children: [
                          Icon(Icons.insights_outlined, size: 16, color: kAccentColor.withValues(alpha: 0.7)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              riskDesc,
                              style: const TextStyle(color: kHintColor, fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.sync, size: 12, color: kHintColor),
                              const SizedBox(width: 4),
                              Text(
                                "Live update: ${lastUpdated != null ? "${lastUpdated.toDate().hour.toString().padLeft(2, '0')}:${lastUpdated.toDate().minute.toString().padLeft(2, '0')}" : "In sync"}",
                                style: const TextStyle(fontSize: 11, color: kHintColor),
                              ),
                            ],
                          ),
                          if (!isOwner)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.red.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                "LIVE",
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.redAccent,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Role-specific Action Buttons - Sleek & Professional
          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: Row(
              children: [
                if (isOwner) ...[
                  Expanded(
                    flex: 3,
                    child: Container(
                      height: 56,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.green.withValues(alpha: 0.2),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          await _journeyService.stopJourney();
                          if (mounted) Navigator.pop(context);
                        },
                        icon: const Icon(Icons.verified_user_outlined, color: Colors.white, size: 20),
                        label: const Text(
                          "I'M SAFE",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade600,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () {
                      final phoneNumbers = _journeyData!['guardianPhone'] != null
                          ? [_journeyData!['guardianPhone'] as String]
                          : <String>[];
                      _sosService.sendSOS(phoneNumbers, context);
                    },
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFF44336), Color(0xFFB71C1C)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.red.withValues(alpha: 0.4),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.emergency_outlined, color: Colors.white, size: 28),
                    ),
                  ),
                ] else
                  Expanded(
                    child: Container(
                      height: 56,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.withValues(alpha: 0.2),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: ElevatedButton.icon(
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
                        icon: const Icon(Icons.phone_in_talk_outlined, color: Colors.white),
                        label: const Text(
                          "CALL FRIEND",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade600,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ),
                const SizedBox(width: 12),
                // Compact Recenter
                GestureDetector(
                  onTap: () {
                    setState(() => _isFollowingUser = true);
                    _mapController?.animateCamera(CameraUpdate.newLatLngZoom(currentLatLng, 15.0));
                  },
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: _isFollowingUser ? kPrimaryColor : kCardColor,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _isFollowingUser ? Colors.transparent : Colors.white12,
                      ),
                    ),
                    child: Icon(
                      Icons.center_focus_strong_outlined,
                      color: _isFollowingUser ? Colors.white : kHintColor,
                      size: 24,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(bool isOwner) {
    return AppBar(
      title: Text(
        (isOwner ? "My Journey" : "Tracking Friend").toUpperCase(),
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w900,
          letterSpacing: 2,
        ),
      ),
      backgroundColor: kBackgroundColor,
      foregroundColor: kTextColor,
      elevation: 0,
      centerTitle: true,
      leading: const BackButton(color: kTextColor),
    );
  }
}
