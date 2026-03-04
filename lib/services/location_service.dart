import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';

class LocationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  StreamSubscription<Position>? _positionStreamSubscription;

  // Check and Request Location Permissions
  Future<bool> checkPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      return false;
    }
    return true;
  }

  // Get Current Location
  Future<Position?> getCurrentLocation() async {
    bool hasPermission = await checkPermission();
    if (!hasPermission) return null;

    return await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
  }

  // Stream of Location Updates (Internal Use)
  Stream<Position> get locationStream {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // Update every 10 meters
      ),
    );
  }

  // Start Sharing Location to Firestore
  Future<void> startSharing() async {
    final user = _auth.currentUser;
    if (user == null) return;
    bool hasPermission = await checkPermission();
    if (!hasPermission) throw Exception("Location permission denied");

    // Cancel existing stream if any
    await _positionStreamSubscription?.cancel();

    _positionStreamSubscription = locationStream.listen((Position position) {
      _firestore.collection('live_locations').doc(user.uid).set({
        'latitude': position.latitude,
        'longitude': position.longitude,
        'timestamp': FieldValue.serverTimestamp(),
        'riskLevel': 'low', // Default
        'isSharing': true,
      }, SetOptions(merge: true));
    });
  }

  // Stop Sharing Location
  Future<void> stopSharing() async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;

    await _firestore.collection('live_locations').doc(user.uid).set({
      'isSharing': false,
    }, SetOptions(merge: true));
  }
}
