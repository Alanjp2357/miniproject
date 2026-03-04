import 'dart:async';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/contact_service.dart';
import '../services/journey_service.dart';
import '../services/location_search_service.dart';
import '../constants.dart';

class StartJourneyScreen extends StatefulWidget {
  const StartJourneyScreen({super.key});

  @override
  State<StartJourneyScreen> createState() => _StartJourneyScreenState();
}

class _StartJourneyScreenState extends State<StartJourneyScreen> {
  final ContactService _contactService = ContactService();
  final JourneyService _journeyService = JourneyService();
  final LocationSearchService _searchService = LocationSearchService();

  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  LatLng? _selectedDestination;
  String _destinationName = "";

  String? _selectedGuardianId;
  String? _selectedGuardianPhone;
  bool _isLoading = false;

  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      if (query.length > 2) {
        setState(() {
          _isSearching = true;
          _selectedDestination = null; // reset if user starts typing again
        });
        final results = await _searchService.searchLocation(query);
        if (mounted) {
          setState(() {
            _searchResults = results;
            _isSearching = false;
          });
        }
      } else {
        setState(() {
          _searchResults = [];
          _isSearching = false;
        });
      }
    });
  }

  void _selectDestination(Map<String, dynamic> location) {
    FocusScope.of(context).unfocus(); // hide keyboard
    setState(() {
      _destinationName = location['name'];
      _searchController.text = _destinationName;
      _selectedDestination = LatLng(location['lat'], location['lon']);
      _searchResults = [];
    });
  }

  Future<void> _startJourney() async {
    if (_selectedDestination == null || _selectedGuardianPhone == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await _journeyService.startJourney(
        context: context,
        destinationLat: _selectedDestination!.latitude,
        destinationLng: _selectedDestination!.longitude,
        destinationName: _destinationName,
        guardianId: _selectedGuardianId ?? 'unknown',
        guardianPhone: _selectedGuardianPhone!,
      );

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Journey Started!")));
        Navigator.pop(context); // Go back to Home
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error starting journey: $e")));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    bool canStart =
        _selectedDestination != null && _selectedGuardianPhone != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Start Journey"),
        backgroundColor: Colors.white,
        foregroundColor: kTextColor,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Destination Search Area
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.all(20),
              color: Colors.grey[100],
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Where are you going?",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    decoration: InputDecoration(
                      hintText: "Search destination...",
                      prefixIcon: const Icon(
                        Icons.search,
                        color: kPrimaryColor,
                      ),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _searchResults = [];
                                  _selectedDestination = null;
                                });
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Search Results Dropdown-like list
                  if (_isSearching)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(10.0),
                        child: CircularProgressIndicator(),
                      ),
                    ),

                  if (_searchResults.isNotEmpty && _selectedDestination == null)
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: const [
                            BoxShadow(color: Colors.black12, blurRadius: 4),
                          ],
                        ),
                        child: ListView.separated(
                          itemCount: _searchResults.length,
                          separatorBuilder: (context, index) =>
                              const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final loc = _searchResults[index];
                            return ListTile(
                              leading: const Icon(
                                Icons.location_on,
                                color: Colors.grey,
                              ),
                              title: Text(
                                loc['name'],
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              onTap: () => _selectDestination(loc),
                            );
                          },
                        ),
                      ),
                    ),

                  if (_selectedDestination != null)
                    Expanded(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.check_circle,
                              color: Colors.green,
                              size: 50,
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              "Destination Selected",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                            Text(
                              _destinationName,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Guardian Selection
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(30),
                  topRight: Radius.circular(30),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 10,
                    offset: Offset(0, -5),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Select Guardian",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: _contactService.getContacts(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                          return const Text(
                            "No contacts found. Please add trusted contacts in the settings.",
                          );
                        }

                        final contacts = snapshot.data!.docs;

                        return ListView.builder(
                          itemCount: contacts.length,
                          itemBuilder: (context, index) {
                            final contact = contacts[index];
                            final id = contact.id;
                            final name = contact['name'];
                            final phone = contact['phone'];

                            bool isSelected = _selectedGuardianId == id;

                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: isSelected
                                    ? kPrimaryColor
                                    : Colors.grey[300],
                                child: Icon(
                                  Icons.person,
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.grey[700],
                                ),
                              ),
                              title: Text(name),
                              subtitle: Text(phone),
                              trailing: isSelected
                                  ? const Icon(
                                      Icons.check_circle,
                                      color: kPrimaryColor,
                                    )
                                  : null,
                              onTap: () {
                                setState(() {
                                  _selectedGuardianId = id;
                                  _selectedGuardianPhone = phone;
                                });
                              },
                            );
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: canStart && !_isLoading ? _startJourney : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kPrimaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              "START JOURNEY",
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
    );
  }
}
