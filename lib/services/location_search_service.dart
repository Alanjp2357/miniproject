import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../constants.dart';

class LocationSearchService {
  final String _autocompleteUrl = 'https://maps.googleapis.com/maps/api/place/autocomplete/json';
  final String _detailsUrl = 'https://maps.googleapis.com/maps/api/place/details/json';
  final String _osmUrl = 'https://nominatim.openstreetmap.org/search';

  /// Gets suggestions. Tries Google Places first, falls back to OSM if it fails.
  Future<List<Map<String, dynamic>>> searchLocation(String query, {double? lat, double? lng}) async {
    if (query.trim().isEmpty) return [];

    // 1. Try Google Places
    try {
      String biasing = '';
      if (lat != null && lng != null) {
        // location and radius provide stronger biasing than locationbias alone
        biasing = '&location=$lat,$lng&radius=50000&locationbias=circle:50000@$lat,$lng';
      }
      
      // Add country restriction to India for more relevant local results
      final String countryFilter = '&components=country:in';

      final response = await http.get(
        Uri.parse(
          '$_autocompleteUrl?input=${Uri.encodeComponent(query)}$biasing$countryFilter&key=$kGoogleMapsApiKey',
        ),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          final List<dynamic> predictions = data['predictions'];
          return predictions
              .map(
                (item) => {
                  'name': item['description'] as String,
                  'place_id': item['place_id'] as String,
                  'is_google': true,
                },
              )
              .toList();
        } else {
          debugPrint('Google Places API Error (Status: ${data['status']}). Falling back to OSM.');
        }
      }
    } catch (e) {
      debugPrint('Google Places Search Failed: $e. Falling back to OSM.');
    }

    // 2. Fallback to OpenStreetMap (Nominatim)
    try {
      final response = await http.get(
        Uri.parse('$_osmUrl?q=${Uri.encodeComponent(query)}&format=json&limit=5'),
        headers: {'User-Agent': 'SafeNightApp/1.0'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data
            .map(
              (item) => {
                'name': item['display_name'] as String,
                'lat': double.parse(item['lat']),
                'lon': double.parse(item['lon']),
                'is_google': false,
              },
            )
            .toList();
      }
    } catch (e) {
      debugPrint('OSM Search Fallback also failed: $e');
    }

    return [];
  }

  /// Gets Lat/Lng from a Place ID (Google) or handles OSM data
  Future<Map<String, dynamic>?> getPlaceDetails(String placeId) async {
    try {
      final response = await http.get(
        Uri.parse(
          '$_detailsUrl?place_id=$placeId&fields=geometry,name&key=$kGoogleMapsApiKey',
        ),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          final result = data['result'];
          final location = result['geometry']['location'];
          return {
            'name': result['name'] as String,
            'lat': location['lat'] as double,
            'lon': location['lng'] as double,
          };
        }
      }
    } catch (e) {
      debugPrint('Error getting place details: $e');
    }
    return null;
  }
}
