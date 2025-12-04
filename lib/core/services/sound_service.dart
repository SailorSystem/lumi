import 'package:shared_preferences/shared_preferences.dart';

class SoundService {
  static const String soundKey = "sound_enabled";

  static Future<bool> isSoundEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(soundKey) ?? true; // Activado por defecto
  }

  static Future<void> setSoundEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(soundKey, value);
  }
}