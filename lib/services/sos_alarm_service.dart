import 'package:audioplayers/audioplayers.dart';

class SosAlarmService {
  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;

  bool get isPlaying => _isPlaying;

  Future<void> startAlarm() async {
    if (_isPlaying) return;

    // Using a direct URL for the siren sound for now.
    // Ideally this should be a local asset like 'assets/sounds/siren.mp3'
    // Ensure to update pubspec.yaml assets if using local file.
    String url =
        'https://www.soundjy.com/upload/aaaaa.mp3'; // Placeholder siren URL

    try {
      await _player.setSourceUrl(url);
      await _player.setReleaseMode(ReleaseMode.loop); // Loop the alarm
      await _player.resume();
      _isPlaying = true;
    } catch (e) {
      print("Error playing alarm: $e");
    }
  }

  Future<void> stopAlarm() async {
    if (!_isPlaying) return;

    try {
      await _player.stop();
      _isPlaying = false;
    } catch (e) {
      print("Error stopping alarm: $e");
    }
  }
}
