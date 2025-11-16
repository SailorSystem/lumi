//lib/core/services/supabase_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';

/// Servicio global para manejar la conexión y operaciones básicas con Supabase.
/// Usado por otros servicios (usuarios, configuraciones, etc.).
class SupabaseService {
  static SupabaseClient get client => Supabase.instance.client;

  /// Inserta un registro en una tabla y devuelve la lista de filas insertadas.
  static Future<List<Map<String, dynamic>>> insert(
      String table, Map<String, dynamic> data) async {
    final response = await client.from(table).insert(data).select();
    return List<Map<String, dynamic>>.from(response);
  }

  /// Obtiene todos los registros de una tabla.
  static Future<List<Map<String, dynamic>>> getAll(String table) async {
    final response = await client.from(table).select();
    return List<Map<String, dynamic>>.from(response);
  }

  /// Obtiene un registro por su ID.
  static Future<Map<String, dynamic>?> getById(
      String table, String idField, int id) async {
    final response =
        await client.from(table).select().eq(idField, id).maybeSingle();
    return response;
  }

  /// Actualiza un registro existente y devuelve la fila modificada.
  static Future<List<Map<String, dynamic>>> update(
      String table, String idField, int id, Map<String, dynamic> data) async {
    final response =
        await client.from(table).update(data).eq(idField, id).select();
    return List<Map<String, dynamic>>.from(response);
  }

  /// Elimina un registro por ID.
  static Future<void> delete(String table, String idField, int id) async {
    await client.from(table).delete().eq(idField, id);
  }
}
