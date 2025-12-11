import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/models/flashcard.dart';

class FlashcardStorageService {
  static const String setsKey = "flashcard_sets_list";

  /// Guarda un set de flashcards bajo un nombre dado
  static Future<void> saveSet(String name, List<Flashcard> cards) async {
    final prefs = await SharedPreferences.getInstance();

    // 1. Guardar lista individual
    final key = "flashcards_set_$name";
    final jsonList = cards.map((c) => c.toJson()).toList();
    await prefs.setString(key, jsonEncode(jsonList));

    // 2. Registrar en la lista de sets guardados
    final listString = prefs.getString(setsKey);
    List<String> sets = listString != null ? List<String>.from(jsonDecode(listString)) : [];

    if (!sets.contains(name)) {
      sets.add(name);
      await prefs.setString(setsKey, jsonEncode(sets));
    }
  }

  /// Cargar un set de flashcards según su nombre
  static Future<List<Flashcard>> loadSet(String name) async {
    final prefs = await SharedPreferences.getInstance();
    final key = "flashcards_set_$name";
    final data = prefs.getString(key);

    if (data == null) return [];

    final decoded = jsonDecode(data);
    return (decoded as List).map((e) => Flashcard.fromJson(e)).toList();
  }

  /// Devuelve todos los nombres de sets guardados
  static Future<List<String>> loadAvailableSets() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(setsKey);
    if (data == null) return [];
    return List<String>.from(jsonDecode(data));
  }

  /// Eliminar un set completamente
  static Future<void> deleteSet(String name) async {
    final prefs = await SharedPreferences.getInstance();
    final key = "flashcards_set_$name";
    await prefs.remove(key);

    final listString = prefs.getString(setsKey);
    if (listString != null) {
      List<String> sets = List<String>.from(jsonDecode(listString));
      sets.remove(name);
      await prefs.setString(setsKey, jsonEncode(sets));
    }
  }
}
