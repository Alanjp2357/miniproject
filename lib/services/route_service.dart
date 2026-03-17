import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter/foundation.dart';
import '../constants.dart';

class RouteService {
  final String _orsUrl = 'https://api.openrouteservice.org/v2/directions';

  Future<List<LatLng>> getRoute(LatLng origin, LatLng destination, {String mode = 'driving-car'}) async {
    try {
      // OpenRouteService expects mode like 'driving-car' or 'foot-walking'
      // We'll map 'driving' to 'driving-car' and 'walking' to 'foot-walking'
      String profile = mode == 'walking' ? 'foot-walking' : 'driving-car';

      final response = await http.get(
        Uri.parse(
          '$_orsUrl/$profile?api_key=$kOrsApiKey&start=${origin.longitude},${origin.latitude}&end=${destination.longitude},${destination.latitude}',
        ),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data.containsKey('features') && data['features'].isNotEmpty) {
          final List<dynamic> coords = data['features'][0]['geometry']['coordinates'];
          
          // ORS returns points as [longitude, latitude]
          return coords.map((c) => LatLng(c[1].toDouble(), c[0].toDouble())).toList();
        } else {
          debugPrint('OpenRouteService Error ($profile): No features found in response.');
        }
      } else {
        final error = json.decode(response.body);
        debugPrint('OpenRouteService Error ($profile): Status ${response.statusCode} - ${error['error'] ?? 'Unknown error'}');
        
        // Fallback to walking if driving fails
        if (profile == 'driving-car') {
          debugPrint('Driving failed. Retrying with foot-walking mode...');
          return getRoute(origin, destination, mode: 'walking');
        }
      }
    } catch (e) {
      debugPrint('Error fetching route from ORS ($mode): $e');
    }
    return [];
  }
}
