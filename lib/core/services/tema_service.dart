// lib/core/services/tema_service.dart
import '../../core/models/tema.dart';
import '../../core/services/supabase_service.dart';

class TemaService {
  static const table = 'temas';

  static Future<List<Tema>> obtenerTemasPorUsuario(int idUsuario) async {
    final data = await SupabaseService.client
        .from(table)
        .select()
        .eq('id_usuario', idUsuario);

    return (data as List).map((e) => Tema.fromMap(e)).toList();
  }
  
  static Future<void> eliminarTema(int idTema) async {
    await SupabaseService.client
        .from(table)
        .delete()
        .eq('id_tema', idTema);
  }

  static Future<Tema?> crearTema(Tema tema) async {
    final response = await SupabaseService.insert(table, tema.toMap());
    if (response.isNotEmpty) return Tema.fromMap(response.first);
    return null;
  }
}
