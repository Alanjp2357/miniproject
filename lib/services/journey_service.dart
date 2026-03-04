import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

    // 2. Create Firestore document
    final journeyRef = _firestore.collection('journeys').doc();
    final journeyId = journeyRef.id;

    await journeyRef.set({
      'userId': user.uid,
      'destinationLat': destinationLat,
      'destinationLng': destinationLng,
      'destinationName': destinationName,
      'currentLat': position.latitude,
      'currentLng': position.longitude,
      'riskLevel': 'LOW',
      'isActive': true,
      'selectedGuardianId': guardianId,
      'lastUpdated': FieldValue.serverTimestamp(),
    });

    // 3. Save activeJourneyId locally
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('activeJourneyId', journeyId);

    // 4. Send SMS
    if (context.mounted) {
      await _sendJourneySMS(
        context: context,
        phone: guardianPhone,
        destinationName: destinationName,
        lat: position.latitude,
        lng: position.longitude,
      );
    }

    // 5. Start Background Tracking
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

  Future<void> _sendJourneySMS({
    required BuildContext context,
    required String phone,
    required String destinationName,
    required double lat,
    required double lng,
  }) async {
    String mapLink =
        "https://www.openstreetmap.org/?mlat=$lat&mlon=$lng#map=15/$lat/$lng";
    String message =
        "I'm starting a journey to $destinationName. Track my location here: $mapLink";

    if (kIsWeb) {
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("Journey Started"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "SMS is not supported on Web. Please copy the message below and send it manually to your guardian.",
                  style: TextStyle(color: Colors.red),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(message),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: message));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Message copied to clipboard"),
                    ),
                  );
                },
                child: const Text("Copy Message"),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Close"),
              ),
            ],
          ),
        );
      }
    } else {
      final String uri = 'sms:$phone?body=${Uri.encodeComponent(message)}';
      if (await canLaunchUrlString(uri)) {
        await launchUrlString(uri);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not launch SMS app')),
          );
        }
      }
    }
  }

  Future<String?> getActiveJourneyId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('activeJourneyId');
  }
}
