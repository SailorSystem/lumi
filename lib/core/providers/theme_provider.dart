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

  // Colores
  static const Color _lightBg = Color(0xFFD9CBBE);
  static const Color _darkBg = Color(0xFF1E1E1E);
  static const Color _lightPrimary = Color(0xFF2C4459);
  static const Color _darkPrimary = Color(0xFFB49D87);
  static const Color _lightBar = Color(0xFFB49D87);
  static const Color _darkBar = Color(0xFF2C4459);

  // Inicializar el proveedor
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();

    // Si _userId ya se estableció desde HomeScreen, no lo leemos de prefs aquí.
    if (_userId == null) {
      _userId = prefs.getInt('user_id');
    }

    if (_userId != null) {
      await _loadConfigFromSupabase();
    } else {
      // Fallback si no hay usuario (ej. antes del primer registro)
      _isDarkMode = prefs.getBool('dark_mode') ?? false;
    }
    notifyListeners();
  }

  // Cargar configuración desde Supabase
  Future<void> _loadConfigFromSupabase() async {
    final config = await ConfiguracionService.obtenerPorUsuario(_userId!);

    if (config != null) {
      _isDarkMode = config.modoOscuro;
    } else {

      _isDarkMode = false;
    }
  }

  // Guardar configuración en Supabase y aplicar cambio
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

  // Getter para los colores (ajustarás tus pantallas para usarlos)
  Color get backgroundColor => _isDarkMode ? _darkBg : _lightBg;
  Color get primaryColor => _isDarkMode ? _darkPrimary : _lightPrimary;
  Color get appBarColor => _isDarkMode ? _darkBar : _lightBar;
  Color get textColor => _isDarkMode ? Colors.white70 : Colors.black87;
  Color get cardColor => _isDarkMode ? Color(0xFF333333) : Colors.white;
}