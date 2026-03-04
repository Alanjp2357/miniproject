import 'package:flutter/material.dart';

import '../services/sos_service.dart';
import '../services/contact_service.dart';
import '../services/sos_alarm_service.dart';
import '../widgets/custom_scaffold.dart';
import '../constants.dart';
import 'contacts_page.dart';
import 'live_map_screen.dart';
import 'start_journey_screen.dart';
import '../services/journey_service.dart';

import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final SosService _sosService = SosService();
  final ContactService _contactService = ContactService();
  final SosAlarmService _sosAlarmService = SosAlarmService(); // NEW

  // bool _isTracking = false; // logic moved to LiveMapScreen session
  bool _isSendingSOS = false;
  bool _isAlarmPlaying = false; // NEW

  Future<void> _sendSOS() async {
    setState(() {
      _isSendingSOS = true;
    });

    // Start Alarm Immediately
    await _sosAlarmService.startAlarm();
    setState(() {
      _isAlarmPlaying = true;
    });

    try {
      // 1. Get Trusted Contacts
      final snapshot = await _contactService.getContacts().first;
      final contacts = snapshot.docs
          .map((doc) => doc['phone'] as String)
          .toList();

      if (contacts.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                "No trusted contacts found! Please add contacts first.",
              ),
            ),
          );
          // Navigate to contacts page
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ContactsPage()),
          );
        }
        return;
      }

      // 2. Send SOS
      if (!mounted) return;
      await _sosService.sendSOS(contacts, context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "High Risk Alert Saved & SMS Sent to ${contacts.length} Contacts!",
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Failed to send SOS: $e")));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSendingSOS = false;
        });
      }
    }
  }

  void _stopAlarm() async {
    await _sosAlarmService.stopAlarm();
    setState(() {
      _isAlarmPlaying = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return CustomScaffold(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Column(
            children: [
              const SizedBox(height: 20),
              // Header: User Greeting & Battery
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Hello, User 👋',
                        style: TextStyle(
                          color: kTextColor,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'You are protected.',
                        style: TextStyle(
                          color: kTextColor.withValues(alpha: 0.7),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 30),

              // SOS BUTTON (Hero Feature)
              GestureDetector(
                onTap: _sendSOS,
                child: Container(
                  height: 180,
                  width: 180,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: kPrimaryColor.withValues(alpha: 0.1),
                    border: Border.all(
                      color: kPrimaryColor.withValues(alpha: 0.5),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: kPrimaryColor.withValues(alpha: 0.2),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Center(
                    child: _isSendingSOS
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Container(
                            height: 140,
                            width: 140,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: kPrimaryColor,
                              boxShadow: [
                                BoxShadow(
                                  color: kPrimaryColor,
                                  blurRadius: 15,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.warning_amber_rounded,
                                  color: Colors.white,
                                  size: 50,
                                ),
                                SizedBox(height: 5),
                                Text(
                                  'SOS',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),
                ),
              ),
              // Stop Alarm Button (Visible ONLY when alarm is playing)
              if (_isAlarmPlaying)
                Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _stopAlarm,
                      icon: const Icon(Icons.volume_off),
                      label: const Text(
                        "STOP ALARM",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black87,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                    ),
                  ),
                ),

              const SizedBox(height: 10),
              const Text(
                'Tap for Emergency Help',
                style: TextStyle(color: kHintColor),
              ),
              const SizedBox(height: 40),

              // Journey Controls
              Row(
                children: [
                  Expanded(
                    child: _actionCard(
                      title: 'Start Journey',
                      icon: Icons.navigation_outlined,
                      color: kAccentColor,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const StartJourneyScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: _actionCard(
                      title: 'Live Map',
                      icon: Icons.map_outlined,
                      color: Colors.purpleAccent,
                      onTap: () async {
                        final journeyService = JourneyService();
                        final journeyId = await journeyService
                            .getActiveJourneyId();

                        if (context.mounted) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  LiveMapScreen(isJourney: journeyId != null),
                            ),
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              Row(
                children: [
                  Expanded(
                    child: _actionCard(
                      title: 'Contacts',
                      icon: Icons.group_outlined,
                      color: Colors.orangeAccent,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ContactsPage(),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: _actionCard(
                      title: 'Settings',
                      icon: Icons.settings_outlined,
                      color: Colors.blueGrey,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SettingsScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionCard({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: kCardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: kInactiveCardColor),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(
                color: kTextColor,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
