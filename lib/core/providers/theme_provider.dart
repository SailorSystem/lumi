import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider with ChangeNotifier {
  bool _isDarkMode = false;

  bool get isDarkMode => _isDarkMode;

  // 🎨 Colores base
  static const Color lightBg = Color(0xFFD9CBBE);
  static const Color darkBg = Color(0xFF1E1E1E);
  static const Color lightPrimary = Color(0xFF2C4459);
  static const Color darkPrimary = Color(0xFFB49D87);
  static const Color lightBar = Color(0xFFB49D87);
  static const Color darkBar = Color(0xFF2C4459);

  // 🎯 Getters según modo
  Color get backgroundColor => _isDarkMode ? darkBg : lightBg;
  Color get primaryColor => _isDarkMode ? darkPrimary : lightPrimary;
  Color get appBarColor => _isDarkMode ? darkBar : lightBar;
  Color get textColor => _isDarkMode ? Colors.white70 : Colors.black87;
  Color get cardColor =>
      _isDarkMode ? const Color(0xFF333333) : Colors.white;

  /// 🔄 Inicializa desde almacenamiento local
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool('dark_mode') ?? false;
    notifyListeners();
  }

  /// 🌙 Cambia y guarda el tema
  Future<void> toggleTheme(bool value) async {
    _isDarkMode = value;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dark_mode', value);
  }
}
