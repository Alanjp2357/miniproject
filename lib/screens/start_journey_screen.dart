import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
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

  LatLng? _currentLocation;
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _initCurrentLocation();
  }

  Future<void> _initCurrentLocation() async {
    final pos = await _journeyService.getCurrentLocationForSearch();
    if (pos != null && mounted) {
      setState(() {
        _currentLocation = LatLng(pos.latitude, pos.longitude);
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), () async {
      if (query.trim().length > 2) {
        setState(() {
          _isSearching = true;
          _selectedDestination = null; // reset if user starts typing again
        });
        final results = await _searchService.searchLocation(
          query,
          lat: _currentLocation?.latitude,
          lng: _currentLocation?.longitude,
        );
        debugPrint('Searching for "$query" with bias: ${_currentLocation?.latitude}, ${_currentLocation?.longitude}');
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

  Future<void> _selectDestination(Map<String, dynamic> location) async {
    FocusScope.of(context).unfocus(); // hide keyboard

    if (location.containsKey('place_id')) {
      setState(() {
        _isLoading = true;
        _searchResults = [];
      });

      final details = await _searchService.getPlaceDetails(location['place_id']);
      if (details != null && mounted) {
        setState(() {
          _destinationName = details['name'];
          _searchController.text = _destinationName;
          _selectedDestination = LatLng(details['lat'], details['lon']);
          _isLoading = false;
        });
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Failed to get location details.")),
          );
        }
      }
    } else {
      setState(() {
        _destinationName = location['name'];
        _searchController.text = _destinationName;
        _selectedDestination = LatLng(location['lat'], location['lon']);
        _searchResults = [];
      });
    }
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
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Destination Search Area
            Container(
              padding: const EdgeInsets.all(20),
              color: Colors.grey[100],
              child: Column(
                mainAxisSize: MainAxisSize.min,
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
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_searchController.text.isNotEmpty)
                            IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _searchResults = [];
                                  _selectedDestination = null;
                                });
                              },
                            ),
                        ],
                      ),
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
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Container(
                        constraints: const BoxConstraints(maxHeight: 250),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: const [
                            BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4)),
                          ],
                        ),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: _searchResults.length,
                          padding: EdgeInsets.zero,
                          separatorBuilder: (context, index) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final loc = _searchResults[index];
                            return ListTile(
                              leading: const CircleAvatar(
                                backgroundColor: Color(0xFFF5F5F5),
                                radius: 18,
                                child: Icon(Icons.place_outlined, color: kPrimaryColor, size: 18),
                              ),
                              title: Text(
                                loc['name'],
                                style: const TextStyle(fontSize: 14),
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
                    Padding(
                      padding: const EdgeInsets.only(top: 15),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.check_circle, color: Colors.green, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _destinationName,
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 15),
                          Container(
                            height: 200,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: const [
                                BoxShadow(color: Colors.black12, blurRadius: 10),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: GoogleMap(
                                initialCameraPosition: CameraPosition(
                                  target: _selectedDestination!,
                                  zoom: 15,
                                ),
                                markers: {
                                  Marker(
                                    markerId: const MarkerId('dest'),
                                    position: _selectedDestination!,
                                  ),
                                },
                                myLocationButtonEnabled: false,
                                zoomControlsEnabled: false,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            // Guardian Selection
            if (_selectedDestination != null)
              Container(
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
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Select Guardian",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  StreamBuilder<QuerySnapshot>(
                    stream: _contactService.getContacts(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(20.0),
                            child: CircularProgressIndicator(),
                          ),
                        );
                      }
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: Text(
                            "No contacts found. Please add trusted contacts in the settings.",
                          ),
                        );
                      }

                      final contacts = snapshot.data!.docs;

                      return ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
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
                  const SizedBox(height: 20),
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
          ],
        ),
      ),
    );
  }
}
