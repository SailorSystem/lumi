import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/configuracion_service.dart';
import '../models/configuracion.dart';

class ThemeProvider with ChangeNotifier {
  bool _isDarkMode = false;
  int? _userId;

  set userId(int? id) {
    _userId = id;
  }

  bool get isDarkMode => _isDarkMode;

  // Constantes base (pueden ser const porque no dependen de lógica)
  static const Color lightBg = Color(0xFFD9CBBE);
  static const Color darkBg = Color(0xFF1E1E1E);
  static const Color lightPrimary = Color(0xFF2C4459);
  static const Color darkPrimary = Color(0xFFB49D87);
  static const Color lightBar = Color(0xFFB49D87);
  static const Color darkBar = Color(0xFF2C4459);

  // Getters para colores según modo
  Color get backgroundColor => _isDarkMode ? darkBg : lightBg;
  Color get primaryColor => _isDarkMode ? darkPrimary : lightPrimary;
  Color get appBarColor  => _isDarkMode ? darkBar : lightBar;
  Color get textColor    => _isDarkMode ? Colors.white70 : Colors.black87;
  Color get cardColor    => _isDarkMode ? const Color(0xFF333333) : Colors.white;

  // Inicializar el proveedor
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();

    if (_userId == null) {
      _userId = prefs.getInt('user_id');
    }

    if (_userId != null) {
      await _loadConfigFromSupabase();
    } else {
      _isDarkMode = prefs.getBool('dark_mode') ?? false;
    }
    notifyListeners();
  }

  Future<void> _loadConfigFromSupabase() async {
    final config = await ConfiguracionService.obtenerPorUsuario(_userId!);

    if (config != null) {
      _isDarkMode = config.modoOscuro;
    } else {
      _isDarkMode = false;
    }
  }

  Future<void> toggleTheme(bool newValue) async {
    _isDarkMode = newValue;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dark_mode', newValue);

    if (_userId != null) {
      final existingConfig = await ConfiguracionService.obtenerPorUsuario(_userId!);

      if (existingConfig != null) {
        await ConfiguracionService.actualizarConfiguracion(
          existingConfig.idConfig!, {'modo_oscuro': newValue});
      } else {
        final newConfig = Configuracion(
          idUsuario: _userId!,
          modoOscuro: newValue,
          notificacionesActivadas: true,
          sonido: true,
        );
        await ConfiguracionService.crearConfiguracion(newConfig);
      }
    }
  }
}
