import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';
import 'package:another_telephony/telephony.dart';
import 'location_service.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SosService {
  final LocationService _locationService = LocationService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> sendSOS(List<String> phoneNumbers, BuildContext context) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw 'User not logged in';
    }

    final position = await _locationService.getCurrentLocation();
    String message = "SOS! I need help. ";
    String mapLink = "";

    if (position != null) {
      // Use official Google Maps link for better compatibility
      mapLink = "https://www.google.com/maps/search/?api=1&query=${position.latitude},${position.longitude}";
      message += "Here is my location: $mapLink";
    } else {
      message += "I am unable to fetch my location.";
    }

    // 1. Save Alert to Firestore (Common for both Web and Mobile)
    await _firestore.collection('alerts').add({
      'userId': user.uid,
      'timestamp': FieldValue.serverTimestamp(),
      'riskLevel': 'high', // High Risk
      'location': position != null
          ? GeoPoint(position.latitude, position.longitude)
          : null,
      'status': 'active',
      'sentTo': phoneNumbers,
    });

    // 2. Update User Status (Common)
    await _firestore.collection('users').doc(user.uid).update({
      'riskStatus': 'high',
      'lastAlert': FieldValue.serverTimestamp(),
      'lastKnownLocation': position != null
          ? GeoPoint(position.latitude, position.longitude)
          : null,
    });

    // 3. Platform Specific notification
    if (kIsWeb) {
      // Web: Show Dialog with message to copy
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("SOS Alert"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "SMS is not supported on Web. Please copy the message below and send it manually to your trusted contacts.",
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
      // Mobile: Send SMS Directly
      if (phoneNumbers.isNotEmpty) {
        try {
          final Telephony telephony = Telephony.instance;
          
          for (String number in phoneNumbers) {
            await telephony.sendSms(
              to: number,
              message: message,
            );
          }
          
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Direct SOS SMS sent successfully')),
            );
          }
        } catch (e) {
          debugPrint('Direct SMS failed: $e. Falling back to URI.');
          // Fallback if Direct SMS fails
          final String uri = 'sms:${phoneNumbers.join(';')}?body=${Uri.encodeComponent(message)}';
          if (await canLaunchUrlString(uri)) {
            await launchUrlString(uri);
          }
        }
      }
    }
  }

  /// Initiates a direct phone call
  Future<void> initiateCall(String phoneNumber) async {
    try {
      await FlutterPhoneDirectCaller.callNumber(phoneNumber);
    } catch (e) {
      debugPrint("Could not initiate direct call to $phoneNumber: $e");
      // Fallback to dialer if direct call fails
      final String uri = 'tel:$phoneNumber';
      if (await canLaunchUrlString(uri)) {
        await launchUrlString(uri);
      }
    }
  }
}
