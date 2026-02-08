import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/contact_service.dart';
import '../widgets/custom_scaffold.dart';
import '../widgets/custom_textfield.dart';
import '../constants.dart';

class ContactsPage extends StatefulWidget {
  const ContactsPage({super.key});

  @override
  State<ContactsPage> createState() => _ContactsPageState();
}

class _ContactsPageState extends State<ContactsPage> {
  final ContactService _contactService = ContactService();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  void _showAddContactDialog() {
    _nameController.clear();
    _phoneController.clear();
    _emailController.clear();

    showDialog(
      context: context,
      builder: (context) {
        String selectedCountryCode = '+91'; // Default
        // List of Countries
        final List<Map<String, String>> countries = [
          {'name': 'India', 'code': '+91'},
          {'name': 'USA', 'code': '+1'},
          {'name': 'UK', 'code': '+44'},
          {'name': 'Japan', 'code': '+81'},
          {'name': 'China', 'code': '+86'},
          {'name': 'Australia', 'code': '+61'},
          {'name': 'UAE', 'code': '+971'},
          {'name': 'France', 'code': '+33'},
          {'name': 'Germany', 'code': '+49'},
        ];

        return StatefulBuilder(
          // Use StatefulBuilder to update dialog state
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: kCardColor,
              title: const Text(
                'Add Trusted Contact',
                style: TextStyle(color: kTextColor),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CustomTextField(
                      hint: 'Name',
                      icon: Icons.person,
                      controller: _nameController,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            color: kInputColor,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: kInactiveCardColor),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: selectedCountryCode,
                              dropdownColor: kCardColor,
                              style: const TextStyle(
                                color: kTextColor,
                                fontSize: 16,
                              ),
                              icon: const Icon(
                                Icons.arrow_drop_down,
                                color: kTextColor,
                              ),
                              onChanged: (String? newValue) {
                                setState(() {
                                  selectedCountryCode = newValue!;
                                });
                              },
                              items: countries.map<DropdownMenuItem<String>>((
                                Map<String, String> country,
                              ) {
                                return DropdownMenuItem<String>(
                                  value: country['code'],
                                  child: Text(
                                    "${country['name']} (${country['code']})",
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: CustomTextField(
                            hint: 'Phone Number',
                            icon: Icons.phone,
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    CustomTextField(
                      hint: 'Email (Optional)',
                      icon: Icons.email,
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: kHintColor),
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (_nameController.text.isNotEmpty &&
                        _phoneController.text.isNotEmpty) {
                      try {
                        final fullNumber =
                            "$selectedCountryCode${_phoneController.text.trim()}";
                        await _contactService.addContact(
                          _nameController.text.trim(),
                          fullNumber,
                          email: _emailController.text.trim().isNotEmpty
                              ? _emailController.text.trim()
                              : null,
                        );
                        if (context.mounted) Navigator.pop(context);
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Failed to save contact: $e'),
                            ),
                          );
                        }
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimaryColor,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return CustomScaffold(
      child: SafeArea(
        // Ensures content respects notches and system bars
        child: Column(
          children: [
            // Custom AppBar Area
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: kTextColor),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Trusted Contacts',
                    style: TextStyle(
                      color: kTextColor,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            // Helpful Text
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.0),
              child: Text(
                'These contacts will receive your SOS message and live location.',
                style: TextStyle(color: kHintColor, fontSize: 14),
              ),
            ),
            const SizedBox(height: 20),

            // Contacts List
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _contactService.getContacts(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Center(
                      child: Text(
                        'Error loading contacts',
                        style: TextStyle(color: Colors.red),
                      ),
                    );
                  }
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: kPrimaryColor),
                    );
                  }

                  final data = snapshot.requireData;

                  if (data.size == 0) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.group_off,
                            size: 60,
                            color: kHintColor.withOpacity(0.3),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'No contacts added yet',
                            style: TextStyle(color: kHintColor),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: data.size,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemBuilder: (context, index) {
                      var contact = data.docs[index];
                      var contactData = contact.data() as Map<String, dynamic>;
                      String? email = contactData.containsKey('email')
                          ? contactData['email'] as String?
                          : null;
                      return Card(
                        color: kCardColor,
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: kPrimaryColor.withOpacity(0.2),
                            child: const Icon(
                              Icons.person,
                              color: kPrimaryColor,
                            ),
                          ),
                          title: Text(
                            contact['name'],
                            style: const TextStyle(
                              color: kTextColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                contact['phone'],
                                style: const TextStyle(color: kHintColor),
                              ),
                              if (email != null && email.isNotEmpty)
                                Text(
                                  email,
                                  style: const TextStyle(color: kHintColor),
                                ),
                            ],
                          ),
                          trailing: IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Colors.redAccent,
                            ),
                            onPressed: () =>
                                _contactService.deleteContact(contact.id),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddContactDialog,
        backgroundColor: kPrimaryColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
