import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class LocalTemaRepository {
  static const _keyTemas = 'temas_usuario';

  // Cada tema: { id_tema: int, nombre: String, color: int? ... }
  static Future<List<Map<String, dynamic>>> getTemas() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_keyTemas);
    if (raw == null) return [];

    try {
      return raw
          .map((s) => Map<String, dynamic>.from(json.decode(s)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveTemas(
      List<Map<String, dynamic>> temas) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = temas.map((m) => json.encode(m)).toList();
    await prefs.setStringList(_keyTemas, raw);
  }

  static Future<void> upsertTema(Map<String, dynamic> tema) async {
    final list = await getTemas();
    final id = tema['id_tema'] as int;
    final idx = list.indexWhere((t) => t['id_tema'] == id);
    if (idx >= 0) {
      list[idx] = tema;
    } else {
      list.add(tema);
    }
    await saveTemas(list);
  }
}
