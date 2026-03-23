# SafeTrack Consolidated Source Code

This document contains a consolidated view of all major source files and configuration parts of the SafeTrack application.

---

## 🏗️ Configuration & Manifests

### [pubspec.yaml](file:///d:/miniproject-60-percent-additions/pubspec.yaml)
```yaml
name: miniproject
description: "A new Flutter project."
publish_to: 'none'
version: 1.0.0+1

environment:
  sdk: ^3.10.3

dependencies:
  flutter:
    sdk: flutter
  firebase_core: ^3.6.0
  firebase_auth: ^5.3.0
  google_sign_in: ^7.1.0
  cupertino_icons: ^1.0.8
  shared_preferences: ^2.5.4
  cloud_firestore: ^5.6.1
  geolocator: ^13.0.2
  url_launcher: ^6.3.1
  permission_handler: ^11.3.1
  audioplayers: ^6.5.1
  flutter_phone_direct_caller: ^2.1.0
  http: ^1.6.0
  firebase_messaging: ^15.2.10
  flutter_local_notifications: ^20.1.0
  google_maps_flutter: ^2.15.0
  another_telephony: ^0.2.0
  intl: ^0.18.1

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^6.0.0

flutter:
  uses-material-design: true
  assets:
    - assets/logo.png
```

### [AndroidManifest.xml](file:///d:/miniproject-60-percent-additions/android/app/src/main/AndroidManifest.xml)
```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.INTERNET"/>
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
    <uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION"/>
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_LOCATION"/>
    <uses-permission android:name="android.permission.WAKE_LOCK"/>
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
    <uses-permission android:name="android.permission.SEND_SMS"/>
    <uses-permission android:name="android.permission.CALL_PHONE"/>

    <application
        android:label="SafeTrack"
        android:name="${applicationName}"
        android:icon="@mipmap/ic_launcher">
        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:launchMode="singleTop"
            android:taskAffinity=""
            android:theme="@style/LaunchTheme"
            android:configChanges="orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode"
            android:hardwareAccelerated="true"
            android:windowSoftInputMode="adjustResize">
            <meta-data
              android:name="io.flutter.embedding.android.NormalTheme"
              android:resource="@style/NormalTheme"
              />
            <intent-filter>
                <action android:name="android.intent.action.MAIN"/>
                <category android:name="android.intent.category.LAUNCHER"/>
            </intent-filter>
        </activity>
        <meta-data
            android:name="flutterEmbedding"
            android:value="2" />
        <meta-data
            android:name="com.google.android.geo.API_KEY"
            android:value="AIzaSyB7L9NMxRT8dxS1ChKYnlFhHXMS9d7KbKA" />
    </application>
    <queries>
        <intent>
            <action android:name="android.intent.action.PROCESS_TEXT"/>
            <data android:mimeType="text/plain"/>
        </intent>
        <intent>
            <action android:name="android.intent.action.VIEW" />
            <data android:scheme="sms" />
        </intent>
        <intent>
            <action android:name="android.intent.action.VIEW" />
            <data android:scheme="tel" />
        </intent>
    </queries>
</manifest>
```

---

## ⚡ Cloud Functions

### [index.js](file:///d:/miniproject-60-percent-additions/functions/index.js)
```javascript
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");
const { logger } = require("firebase-functions");

admin.initializeApp();

exports.processNotification = onDocumentCreated("notifications/{notificationId}", async (event) => {
    const notificationData = event.data.data();
    if (!notificationData) {
        logger.error("No notification data found.");
        return;
    }

    const { recipientId, senderName, type, message, journeyId } = notificationData;

    if (!recipientId) {
        logger.info(`No recipientId for notification ${event.params.notificationId}`);
        return;
    }

    try {
        const recipientDoc = await admin.firestore().collection("users").doc(recipientId).get();
        if (!recipientDoc.exists) {
            logger.info(`Recipient ${recipientId} not found`);
            return;
        }

        const fcmToken = recipientDoc.data().fcmToken;
        if (!fcmToken) {
            logger.info(`Recipient ${recipientId} does not have an FCM token`);
            return;
        }

        let title = "SafeTrack Alert";
        if (type === "JOURNEY_START") {
            title = "Journey Started";
        } else if (type === "DEVIATION_ALERT") {
            title = "Safety Alert: Off Route";
        } else if (type === "JOURNEY_END") {
            title = "Safe Arrival";
        }

        const payload = {
            token: fcmToken,
            notification: {
                title: title,
                body: message || `${senderName} sent you an alert.`,
            },
            data: {
                journeyId: journeyId || "",
                type: type || "live_tracking",
                link: notificationData.link || "",
                click_action: "FLUTTER_NOTIFICATION_CLICK"
            },
            android: {
                priority: "high",
                notification: {
                    channelId: "high_importance_channel"
                }
            },
            apns: { payload: { aps: { sound: "default", badge: 1 } } }
        };

        const response = await admin.messaging().send(payload);
        logger.info(`Successfully sent unified notice (${type}) to ${recipientId}. MessageId: ${response}`);
    } catch (error) {
        logger.error(`Error processing unified notification for recipient ${recipientId}:`, error);
    }
});
```

---

## 📱 Flutter Application (lib/)

### [main.dart](file:///d:/miniproject-60-percent-additions/lib/main.dart)
```dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'constants.dart';
import 'screens/loginpage.dart';
import 'screens/home_screen.dart';
import 'screens/live_map_screen.dart';
import 'services/fcm_service.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint("Handling a background message: ${message.messageId}");
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseFirestore.instance.settings = const Settings(persistenceEnabled: true);
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    _setupFCM();
    _setupAuthListener();
  }

  void _setupAuthListener() {
    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) FcmService().setupToken(user.uid);
    });
  }

  Future<void> _setupFCM() async {
    await FcmService().initialize();
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.notification != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message.notification?.title ?? "Notification")),
        );
      }
    });
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) => _handleNotificationClick(message.data));
    FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) _handleNotificationClick(message.data);
    });
  }

  void _handleNotificationClick(Map<String, dynamic> data) {
    final String? type = data['type'];
    final String? journeyId = data['journeyId'];
    final bool shouldNavigate = type == 'live_tracking' || type == 'JOURNEY_START' || type == 'DEVIATION_ALERT' || type == 'JOURNEY_END';
    if (shouldNavigate && journeyId != null) {
      navigatorKey.currentState?.push(MaterialPageRoute(builder: (_) => LiveMapScreen(isJourney: true, journeyId: journeyId)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'SafeTrack',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: kPrimaryColor, brightness: Brightness.dark),
        useMaterial3: true,
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        if (snapshot.hasData) return const HomeScreen();
        return const LoginPage();
      },
    );
  }
}
```

### [constants.dart](file:///d:/miniproject-60-percent-additions/lib/constants.dart)
```dart
import 'package:flutter/material.dart';

const Color kBackgroundColor = Color(0xFF0A0E21);
const Color kCardColor = Color(0xFF1D1E33);
const Color kInactiveCardColor = Color(0xFF111328);
const Color kPrimaryColor = Color(0xFFEB1555);
const Color kAccentColor = Color(0xFF26C6DA);
const Color kTextColor = Colors.white;
const Color kHintColor = Color(0xFFAEB2BD);
const Color kInputColor = Color(0xFF1D1E33);
const String kWebBaseUrl = 'https://miniproject-fd595.web.app';
const String kGoogleMapsApiKey = 'AIzaSyB7L9NMxRT8dxS1ChKYnlFhHXMS9d7KbKA';
const String kOrsApiKey = 'eyJvcmciOiI1YjNjZTM1OTc4NTExMTAwMDFjZjYyNDgiLCJpZCI6IjQ0YjY5NzU1NzBiNjQ1Y2I5NmY2MTJmMjg0NWQyNzI4IiwiaCI6Im11cm11cjY0In0=';
```

### [services/auth_service.dart](file:///d:/miniproject-60-percent-additions/lib/services/auth_service.dart)
```dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'fcm_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<User?> signUp(String email, String password, String mobile, BuildContext context) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(email: email, password: password);
      await _firestore.collection('users').doc(result.user!.uid).set({
        'email': email,
        'mobile': mobile,
        'createdAt': FieldValue.serverTimestamp(),
      });
      await FcmService().setupToken(result.user!.uid);
      return result.user;
    } on FirebaseAuthException catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? 'Sign up failed')));
      return null;
    }
  }

  Future<User?> signIn(String input, String password, BuildContext context) async {
    try {
      String email = input;
      final isMobile = RegExp(r'^[0-9+]+$').hasMatch(input);
      if (isMobile) {
        final querySnapshot = await _firestore.collection('users').where('mobile', isEqualTo: input).limit(1).get();
        if (querySnapshot.docs.isEmpty) throw FirebaseAuthException(code: 'user-not-found', message: 'No account found with this mobile number.');
        email = querySnapshot.docs.first['email'];
      }
      UserCredential result = await _auth.signInWithEmailAndPassword(email: email, password: password);
      if (result.user != null) await FcmService().setupToken(result.user!.uid);
      return result.user;
    } on FirebaseAuthException catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? 'Login failed')));
      return null;
    }
  }

  Future<void> signOut() async => await _auth.signOut();

  Future<void> sendPasswordResetEmail(String input, BuildContext context) async {
    try {
      String email = input.trim();
      final isMobile = RegExp(r'^[0-9+]+$').hasMatch(input);
      if (isMobile) {
        final querySnapshot = await _firestore.collection('users').where('mobile', isEqualTo: input).limit(1).get();
        if (querySnapshot.docs.isEmpty) throw FirebaseAuthException(code: 'user-not-found', message: 'No account found with this mobile number.');
        email = querySnapshot.docs.first['email'];
      }
      await _auth.sendPasswordResetEmail(email: email);
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Password reset link sent to $email'), backgroundColor: Colors.green));
    } on FirebaseAuthException catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? 'Failed to send reset email'), backgroundColor: Colors.red));
    }
  }
}
```

### [services/contact_service.dart](file:///d:/miniproject-60-percent-additions/lib/services/contact_service.dart)
```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class ContactService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference get _contactsCollection {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not logged in');
    return _firestore.collection('users').doc(user.uid).collection('contacts');
  }

  Future<void> addContact(String name, String phone, {String? email}) async {
    String? userUid;
    try {
      final userQuery = await _firestore.collection('users').where('mobile', isEqualTo: phone).limit(1).get();
      if (userQuery.docs.isNotEmpty) userUid = userQuery.docs.first.id;
    } catch (e) { debugPrint('Error searching for user by phone: $e'); }
    await _contactsCollection.add({'name': name, 'phone': phone, 'email': email ?? '', 'userUid': userUid, 'createdAt': DateTime.now()});
  }

  Stream<QuerySnapshot> getContacts() => _contactsCollection.orderBy('createdAt', descending: true).snapshots(includeMetadataChanges: true);
  Future<void> deleteContact(String id) async => await _contactsCollection.doc(id).delete();
}
```

### [services/journey_service.dart](file:///d:/miniproject-60-percent-additions/lib/services/journey_service.dart)
```dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'location_service.dart';
import '../constants.dart';

class JourneyService {
  final LocationService _locationService = LocationService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance; 
  StreamSubscription<Position>? _positionStreamSubscription;
  Position? _lastPosition;
  DateTime? _lastMoveTime;

  Future<void> startJourney({required BuildContext context, required double destinationLat, required double destinationLng, required String destinationName, required String guardianId, required String guardianPhone, required String transportMode}) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("User not logged in");
    final position = await _locationService.getCurrentLocation();
    if (position == null) throw Exception("Could not get current location");
    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    final String userName = userDoc.data()?['name'] ?? user.displayName ?? "Your Friend";
    final String userPhone = userDoc.data()?['mobile'] ?? "";
    String recipientId = guardianId;
    try {
      final contactDoc = await _firestore.collection('users').doc(user.uid).collection('contacts').doc(guardianId).get();
      if (contactDoc.exists && contactDoc.data()?.containsKey('userUid') == true) recipientId = contactDoc.data()?['userUid'] ?? guardianId;
      if (recipientId == guardianId) {
        final userQuery = await _firestore.collection('users').where('mobile', isEqualTo: guardianPhone).limit(1).get();
        if (userQuery.docs.isNotEmpty) {
          recipientId = userQuery.docs.first.id;
          await _firestore.collection('users').doc(user.uid).collection('contacts').doc(guardianId).update({'userUid': recipientId});
        }
      }
    } catch (e) { debugPrint("Guardian lookup error: $e"); }
    final journeyRef = _firestore.collection('journeys').doc();
    final journeyId = journeyRef.id;
    final String trackingLink = "$kWebBaseUrl/?journeyId=$journeyId";
    await journeyRef.set({'userId': user.uid, 'userName': userName, 'userPhone': userPhone, 'destinationLat': destinationLat, 'destinationLng': destinationLng, 'destinationName': destinationName, 'currentLat': position.latitude, 'currentLng': position.longitude, 'riskLevel': _calculateInitialRisk(), 'isActive': true, 'selectedGuardianId': recipientId, 'guardianPhone': guardianPhone, 'transportMode': transportMode, 'lastUpdated': FieldValue.serverTimestamp()});
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('activeJourneyId', journeyId);
    await _firestore.collection('notifications').add({'recipientId': recipientId, 'senderId': user.uid, 'senderName': userName, 'type': 'JOURNEY_START', 'journeyId': journeyId, 'message': '$userName started a journey to $destinationName.', 'link': trackingLink, 'createdAt': FieldValue.serverTimestamp(), 'isRead': false});
    _startBackgroundTracking(journeyId: journeyId, destination: LatLng(destinationLat, destinationLng), transportMode: transportMode, destinationName: destinationName, recipientId: recipientId);
  }

  Future<void> stopJourney() async {
    final prefs = await SharedPreferences.getInstance();
    final journeyId = prefs.getString('activeJourneyId');
    if (journeyId != null) {
      await _firestore.collection('journeys').doc(journeyId).update({'isActive': false, 'riskLevel': 'SAFE', 'lastUpdated': FieldValue.serverTimestamp()});
      await prefs.remove('activeJourneyId');
    }
    await _positionStreamSubscription?.cancel();
  }

  void _startBackgroundTracking({required String journeyId, required LatLng destination, required String transportMode, required String destinationName, required String recipientId}) {
    final user = _auth.currentUser;
    if (user == null) return;
    _positionStreamSubscription = Geolocator.getPositionStream(locationSettings: AndroidSettings(accuracy: LocationAccuracy.high, distanceFilter: 5, foregroundNotificationConfig: const ForegroundNotificationConfig(notificationText: "Tracking your journey for your safety", notificationTitle: "SafeTrack Active"))).listen((Position position) async {
      _firestore.collection('journeys').doc(journeyId).update({'currentLat': position.latitude, 'currentLng': position.longitude, 'lastUpdated': FieldValue.serverTimestamp()});
      if (Geolocator.distanceBetween(position.latitude, position.longitude, destination.latitude, destination.longitude) < 50.0) {
        await stopJourney();
        await _firestore.collection('notifications').add({'recipientId': recipientId, 'senderId': user.uid, 'type': 'JOURNEY_END', 'message': 'Friend arrived safely.', 'createdAt': FieldValue.serverTimestamp(), 'isRead': false});
      }
    });
  }

  String _calculateInitialRisk() {
    final hour = DateTime.now().hour;
    return (hour >= 22 || hour < 5) ? 'MEDIUM' : 'LOW';
  }

  Future<String?> getActiveJourneyId() async => (await SharedPreferences.getInstance()).getString('activeJourneyId');
  String? getCurrentUserId() => _auth.currentUser?.uid;
  Future<Position?> getCurrentLocationForSearch() async => await _locationService.getCurrentLocation();
}
```

---

*Note: Due to size constraints, additional screen files (LiveMapScreen, HomeScreen, etc.) and widget files (CustomScaffold) follow the same architecture in the repository.*
