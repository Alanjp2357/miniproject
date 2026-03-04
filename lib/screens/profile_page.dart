import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/custom_scaffold.dart';
import '../widgets/custom_textfield.dart';
import '../constants.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  bool _isLoading = false;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _fetchUserData() async {
    setState(() => _isLoading = true);
    try {
      final user = _auth.currentUser;
      if (user != null) {
        final doc = await _firestore.collection('users').doc(user.uid).get();
        if (doc.exists) {
          final data = doc.data() as Map<String, dynamic>;
          _nameController.text = data['name'] ?? '';
          _mobileController.text = data['mobile'] ?? '';
          _emailController.text = user.email ?? data['email'] ?? '';
        } else {
          _emailController.text = user.email ?? '';
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading profile: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateProfile() async {
    setState(() => _isLoading = true);
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await _firestore.collection('users').doc(user.uid).set({
          'name': _nameController.text.trim(),
          'mobile': _mobileController.text.trim(),
          'email': _emailController.text.trim(), // Keep email in sync
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile updated successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          setState(() {
            _isEditing = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to update profile: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CustomScaffold(
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: kTextColor),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'My Profile',
                        style: TextStyle(
                          color: kTextColor,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  // Edit Button
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _isEditing = !_isEditing;
                      });
                    },
                    icon: Icon(
                      _isEditing ? Icons.close : Icons.edit,
                      color: kPrimaryColor,
                    ),
                    tooltip: _isEditing ? 'Cancel Edit' : 'Edit Profile',
                  ),
                ],
              ),
            ),

            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: kPrimaryColor),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        children: [
                          const CircleAvatar(
                            radius: 50,
                            backgroundColor: kCardColor,
                            child: Icon(
                              Icons.person,
                              size: 50,
                              color: kPrimaryColor,
                            ),
                          ),
                          const SizedBox(height: 30),
                          CustomTextField(
                            hint: "Full Name",
                            icon: Icons.person_outline,
                            controller: _nameController,
                            readOnly: !_isEditing,
                          ),
                          const SizedBox(height: 20),
                          CustomTextField(
                            hint: "Mobile Number",
                            icon: Icons.phone_android,
                            controller: _mobileController,
                            keyboardType: TextInputType.phone,
                            readOnly: !_isEditing,
                          ),
                          const SizedBox(height: 20),
                          // Email is always read-only (identity)
                          TextField(
                            controller: _emailController,
                            readOnly: true,
                            style: const TextStyle(color: kHintColor),
                            decoration: InputDecoration(
                              prefixIcon: const Icon(
                                Icons.email_outlined,
                                color: kHintColor,
                              ),
                              filled: true,
                              fillColor: kInactiveCardColor,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                          const SizedBox(height: 40),

                          // Save Button (Only visible in Edit Mode)
                          if (_isEditing)
                            SizedBox(
                              width: double.infinity,
                              height: 55,
                              child: ElevatedButton(
                                onPressed: _updateProfile,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: kPrimaryColor,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                ),
                                child: const Text(
                                  'Save Changes',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),

                          const SizedBox(height: 20),
                          if (!_isEditing)
                            SizedBox(
                              width: double.infinity,
                              height: 55,
                              child: OutlinedButton.icon(
                                onPressed: () async {
                                  await _auth.signOut();
                                  if (context.mounted) {
                                    Navigator.of(
                                      context,
                                      rootNavigator: true,
                                    ).popUntil((route) => route.isFirst);
                                  }
                                },
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.redAccent,
                                  side: const BorderSide(
                                    color: Colors.redAccent,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                ),
                                icon: const Icon(Icons.logout),
                                label: const Text(
                                  'Log Out',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
