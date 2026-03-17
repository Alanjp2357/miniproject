import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'location_service.dart';

class JourneyService {
  final LocationService _locationService = LocationService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  StreamSubscription<Position>? _positionStreamSubscription;

  // Start Journey
  Future<void> startJourney({
    required BuildContext context,
    required double destinationLat,
    required double destinationLng,
    required String destinationName,
    required String guardianId,
    required String guardianPhone,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("User not logged in");

    // 1. Get current location
    final position = await _locationService.getCurrentLocation();
    if (position == null) throw Exception("Could not get current location");

    // 1b. Fetch User Profile
    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    final userData = userDoc.data();
    final String userName = userData?['name'] ?? user.displayName ?? "Your Friend";
    final String userPhone = userData?['mobile'] ?? "";

    // 2. Create Firestore document
    final journeyRef = _firestore.collection('journeys').doc();
    final journeyId = journeyRef.id;

    await journeyRef.set({
      'userId': user.uid,
      'userName': userName,
      'userPhone': userPhone,
      'destinationLat': destinationLat,
      'destinationLng': destinationLng,
      'destinationName': destinationName,
      'currentLat': position.latitude,
      'currentLng': position.longitude,
      'riskLevel': 'LOW',
      'isActive': true,
      'selectedGuardianId': guardianId,
      'guardianPhone': guardianPhone, // Store for owner to call back
      'lastUpdated': FieldValue.serverTimestamp(),
    });

    // 3. Save activeJourneyId locally
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('activeJourneyId', journeyId);


    // 4. (REMOVED) Send SMS - Transitioned to In-App Notifications

    // 5. Lookup Guardian UID by Phone Number
    String recipientId = guardianId; // Fallback to current (contact doc ID)
    try {
      final guardianQuery = await _firestore
          .collection('users')
          .where('mobile', isEqualTo: guardianPhone)
          .limit(1)
          .get();

      if (guardianQuery.docs.isNotEmpty) {
        recipientId = guardianQuery.docs.first.id;
        // Also update journey doc with the actual guardian UID for tracking permissions
        await journeyRef.update({'selectedGuardianId': recipientId});
      }
    } catch (e) {
      debugPrint("Error looking up guardian UID: $e");
    }

    // 6. Create In-App Notification for Guardian
    await _firestore.collection('notifications').add({
      'recipientId': recipientId,
      'senderId': user.uid,
      'senderName': userName,
      'type': 'JOURNEY_START',
      'journeyId': journeyId,
      'message': '$userName has started a journey to $destinationName.',
      'createdAt': FieldValue.serverTimestamp(),
      'isRead': false,
    });

    // 7. Start Background Tracking
    _startBackgroundTracking(journeyId);
  }

  // Stop Journey
  Future<void> stopJourney() async {
    final prefs = await SharedPreferences.getInstance();
    final journeyId = prefs.getString('activeJourneyId');

    if (journeyId != null) {
      await _firestore.collection('journeys').doc(journeyId).update({
        'isActive': false,
        'riskLevel': 'SAFE',
        'lastUpdated': FieldValue.serverTimestamp(),
      });
      await prefs.remove('activeJourneyId');
    }

    await _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;
  }

  void _startBackgroundTracking(String journeyId) {
    _positionStreamSubscription?.cancel();

    _positionStreamSubscription =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 20, // 20 meters
          ),
        ).listen((Position position) {
          // Update Firestore
          _firestore.collection('journeys').doc(journeyId).update({
            'currentLat': position.latitude,
            'currentLng': position.longitude,
            'lastUpdated': FieldValue.serverTimestamp(),
          });

          // Basic risk monitoring can be added here
          // For example, if user is too far off route, or if stopped for too long, escalate risk
        });
  }


  Future<String?> getActiveJourneyId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('activeJourneyId');
  }

  String? getCurrentUserId() {
    return _auth.currentUser?.uid;
  }

  Future<Position?> getCurrentLocationForSearch() async {
    return await _locationService.getCurrentLocation();
  }
}
