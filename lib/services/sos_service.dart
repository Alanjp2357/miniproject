import 'package:url_launcher/url_launcher_string.dart';
import 'location_service.dart';

class SosService {
  final LocationService _locationService = LocationService();

  Future<void> sendSOS(List<String> phoneNumbers) async {
    final position = await _locationService.getCurrentLocation();
    String message = "SOS! I need help. ";
    if (position != null) {
      message +=
          "Here is my location: https://www.google.com/maps/search/?api=1&query=${position.latitude},${position.longitude}";
    } else {
      message += "I am unable to fetch my location.";
    }

    // Attempt to open SMS app with pre-filled message
    // Note: On Android, multiple recipients can be separated by ';' or ',' depending on the device/app.
    // Making it simple for now, targeting one by one or using a loop if needed in UI.
    // For a single number: sms:1234567890?body=Hello

    // If we have contacts, we can try to launch for the first one or prompt user
    if (phoneNumbers.isNotEmpty) {
      final String uri =
          'sms:${phoneNumbers.join(';')}?body=${Uri.encodeComponent(message)}';
      if (await canLaunchUrlString(uri)) {
        await launchUrlString(uri);
      } else {
        throw 'Could not launch SMS';
      }
    }
  }
}
