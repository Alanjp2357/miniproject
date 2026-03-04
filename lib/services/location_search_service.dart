import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class LocationSearchService {
  final String _baseUrl = 'https://nominatim.openstreetmap.org/search';

  Future<List<Map<String, dynamic>>> searchLocation(String query) async {
    if (query.isEmpty) return [];

    try {
      final response = await http.get(
        Uri.parse(
          '$_baseUrl?q=${Uri.encodeComponent(query)}&format=json&limit=5',
        ),
        headers: {
          // Nominatim requires a user-agent
          'User-Agent': 'SafeNightApp/1.0 (Contact: info@example.com)',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data
            .map(
              (item) => {
                'name': item['display_name'] as String,
                'lat': double.parse(item['lat']),
                'lon': double.parse(item['lon']),
              },
            )
            .toList();
      }
    } catch (e) {
      debugPrint('Error searching location: $e');
    }
    return [];
  }
}
