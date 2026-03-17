import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/custom_scaffold.dart';
import '../constants.dart';
import 'profile_page.dart';
import 'guardian_tracking_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;

  @override
  Widget build(BuildContext context) {
    return CustomScaffold(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: Column(
          children: [
            const SizedBox(height: 20),
            // Header
            const Row(
              children: [
                BackButton(color: kTextColor),
                Text(
                  'Settings',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: kTextColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30),

            // Profile Section
            _buildSettingsTile(
              icon: Icons.person_outline,
              title: 'Profile',
              subtitle: 'Manage your account details',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ProfilePage()),
                );
              },
            ),

            const SizedBox(height: 15),

            // Notifications Section
            Container(
              decoration: BoxDecoration(
                color: kCardColor,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: kInactiveCardColor),
              ),
              child: SwitchListTile(
                secondary: const Icon(
                  Icons.notifications_outlined,
                  color: kPrimaryColor,
                ),
                title: const Text(
                  'Notifications',
                  style: TextStyle(
                    color: kTextColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: const Text(
                  'Enable push notifications',
                  style: TextStyle(color: kHintColor),
                ),
                value: _notificationsEnabled, // Mock state
                onChanged: (bool value) {
                  setState(() {
                    _notificationsEnabled = value;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        value
                            ? "Notifications Enabled"
                            : "Notifications Disabled",
                      ),
                      duration: const Duration(seconds: 1),
                    ),
                  );
                },
                activeThumbColor: kPrimaryColor,
              ),
            ),

            const SizedBox(height: 15),

            // About Section
            _buildSettingsTile(
              icon: Icons.info_outline,
              title: 'About',
              subtitle: 'Version 1.0.0',
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text("About Safe Night Companion"),
                    content: const Text(
                      "Safe Night Companion\nVersion 1.0.0\n\nYour personal safety assistant.",
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text("OK"),
                      ),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 15),

            // Debug: Track Self
            _buildSettingsTile(
              icon: Icons.bug_report,
              title: 'Guardian View (Test)',
              subtitle: 'Simulate what a guardian sees during your journey',
              onTap: () {
                final user = FirebaseAuth.instance.currentUser;
                if (user != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          GuardianTrackingScreen(userId: user.uid),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Not logged in")),
                  );
                }
              },
            ),

            const Spacer(),

            // Logout Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () async {
                  // Show confirmation dialog
                  final shouldLogout = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text("Logout"),
                      content: const Text("Are you sure you want to logout?"),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text("Cancel"),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text(
                            "Logout",
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  );

                  if (shouldLogout == true) {
                    await FirebaseAuth.instance.signOut();
                    // AuthGate will handle navigation, but popping just in case
                    if (context.mounted) {
                      Navigator.popUntil(context, (route) => route.isFirst);
                    }
                  }
                },
                icon: const Icon(Icons.logout, color: Colors.white),
                label: const Text(
                  "Logout",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: kCardColor,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: kInactiveCardColor),
        ),
        child: Row(
          children: [
            Icon(icon, color: kPrimaryColor, size: 28),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: kTextColor,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(color: kHintColor, fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: kHintColor, size: 16),
          ],
        ),
      ),
    );
  }
}
