import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/route_service.dart';
import '../constants.dart';

class GuardianTrackingScreen extends StatefulWidget {
  final String userId; // The ID of the user being tracked

  const GuardianTrackingScreen({super.key, required this.userId});

  @override
  State<GuardianTrackingScreen> createState() => _GuardianTrackingScreenState();
}

class _GuardianTrackingScreenState extends State<GuardianTrackingScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  GoogleMapController? _mapController;
  LatLng? _lastKnownPosition;
  final RouteService _routeService = RouteService();
  List<LatLng> _routePoints = [];
  LatLng? _destination;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        title: const Text("Guardian View (Live)"),
        backgroundColor: kBackgroundColor,
        foregroundColor: kTextColor,
        elevation: 0,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _firestore
            .collection('live_locations')
            .doc(widget.userId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: kTextColor)));
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text("Waiting for live location...", style: TextStyle(color: kTextColor)));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final bool isSharing = data['isSharing'] ?? false;

          if (!isSharing) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.location_off, size: 60, color: kHintColor),
                  SizedBox(height: 10),
                  Text(
                    "No Active Journey",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: kTextColor),
                  ),
                ],
              ),
            );
          }

          // ROBUST PARSING: num instead of double to handle Firestore int mappings
          final lat = (data['latitude'] as num?)?.toDouble();
          final lng = (data['longitude'] as num?)?.toDouble();
          final dLat = (data['destinationLat'] as num?)?.toDouble();
          final dLng = (data['destinationLng'] as num?)?.toDouble();

          if (lat == null || lng == null) {
            return const Center(child: Text("Invalid location data", style: TextStyle(color: kTextColor)));
          }

          final currentPos = LatLng(lat, lng);
          
          // RE-INTEGRATE LOGIC: Check for new destination or significant movement to refresh route
          // This must happen inside build for StreamBuilder responsiveness
          if (dLat != null && dLng != null) {
            final newDest = LatLng(dLat, dLng);
            if (_destination != newDest || _routePoints.isEmpty) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _routeService.getRoute(currentPos, newDest).then((points) {
                  if (mounted && points.isNotEmpty) {
                    setState(() {
                      _destination = newDest;
                      _routePoints = points;
                    });
                  }
                });
              });
            }
          }

          // Move map if position changed
          if (_lastKnownPosition == null || _lastKnownPosition != currentPos) {
            _lastKnownPosition = currentPos;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _mapController?.animateCamera(CameraUpdate.newLatLngZoom(currentPos, 15.0));
            });
          }
          
          return Stack(
            children: [
              GoogleMap(
                initialCameraPosition: CameraPosition(target: currentPos, zoom: 15.0),
                onMapCreated: (controller) => _mapController = controller,
                myLocationButtonEnabled: false,
                style: '''[{"elementType":"geometry","stylers":[{"color":"#242f3e"}]},{"elementType":"labels.text.fill","stylers":[{"color":"#746855"}]},{"elementType":"labels.text.stroke","stylers":[{"color":"#242f3e"}]},{"featureType":"administrative.locality","elementType":"labels.text.fill","stylers":[{"color":"#d59563"}]},{"featureType":"poi","elementType":"labels.text.fill","stylers":[{"color":"#d59563"}]},{"featureType":"poi.park","elementType":"geometry","stylers":[{"color":"#263c3f"}]},{"featureType":"poi.park","elementType":"labels.text.fill","stylers":[{"color":"#6b9a76"}]},{"featureType":"road","elementType":"geometry","stylers":[{"color":"#38414e"}]},{"featureType":"road","elementType":"geometry.stroke","stylers":[{"color":"#212a37"}]},{"featureType":"road","elementType":"labels.text.fill","stylers":[{"color":"#9ca5b3"}]},{"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#746855"}]},{"featureType":"road.highway","elementType":"geometry.stroke","stylers":[{"color":"#1f2835"}]},{"featureType":"road.highway","elementType":"labels.text.fill","stylers":[{"color":"#f3d19c"}]},{"featureType":"transit","elementType":"geometry","stylers":[{"color":"#2f3948"}]},{"featureType":"transit.station","elementType":"labels.text.fill","stylers":[{"color":"#d59563"}]},{"featureType":"water","elementType":"geometry","stylers":[{"color":"#17263c"}]},{"featureType":"water","elementType":"labels.text.fill","stylers":[{"color":"#515c6d"}]},{"featureType":"water","elementType":"labels.text.stroke","stylers":[{"color":"#17263c"}]}]''',
                polylines: _routePoints.isNotEmpty 
                  ? {
                      Polyline(
                        polylineId: const PolylineId('route'),
                        points: _routePoints,
                        color: kAccentColor,
                        width: 5,
                      ),
                    } 
                  : _destination != null ? {
                      Polyline(
                        polylineId: const PolylineId('fallback'),
                        points: [currentPos, _destination!],
                        color: kAccentColor.withValues(alpha: 0.5),
                        width: 4,
                        patterns: [PatternItem.dash(10), PatternItem.gap(10)],
                      ),
                    } : {},
                markers: {
                  Marker(
                    markerId: const MarkerId('tracked_user'),
                    position: currentPos,
                    icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
                  ),
                  if (_destination != null)
                    Marker(
                      markerId: const MarkerId('destination'),
                      position: _destination!,
                      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
                    ),
                },
              ),
              // Glassmorphism Overlay
              Positioned(
                top: 20,
                left: 15,
                right: 15,
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
                                color: kAccentColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.location_on_outlined, color: kAccentColor),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "LIVE TRACKING",
                                    style: TextStyle(
                                      color: kHintColor,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                  Text(
                                    "Active Journey View",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: kTextColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 30,
                left: 20,
                right: 20,
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 56,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: kAccentColor.withValues(alpha: 0.2),
                              blurRadius: 15,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: ElevatedButton.icon(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close, color: Colors.white),
                          label: const Text(
                            "CLOSE VIEW",
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kCardColor,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () {
                         _mapController?.animateCamera(CameraUpdate.newLatLngZoom(currentPos, 15.0));
                      },
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: kPrimaryColor,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: kPrimaryColor.withValues(alpha: 0.3),
                              blurRadius: 15,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.center_focus_strong_outlined, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
