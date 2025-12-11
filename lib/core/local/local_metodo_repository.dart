import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class LocalMetodoRepository {
  static const _keyMetodos = 'metodos_usuario';

  // modelo mínimo de método
  // { id: int, nombre: String }
  static Future<List<Map<String, dynamic>>> getMetodos() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyMetodos);
    if (raw == null) return [];

    try {
      final List list = jsonDecode(raw);
      return list.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveMetodos(List<Map<String, dynamic>> metodos) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyMetodos, jsonEncode(metodos));
  }

  // helper para agregar/actualizar un método
  static Future<void> upsertMetodo(Map<String, dynamic> metodo) async {
    final list = await getMetodos();
    final id = metodo['id'] as int;
    final idx = list.indexWhere((m) => m['id'] == id);
    if (idx >= 0) {
      list[idx] = metodo;
    } else {
      list.add(metodo);
    }
    await saveMetodos(list);
  }
}
