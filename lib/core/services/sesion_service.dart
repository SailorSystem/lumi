import '../../core/models/sesion.dart';
import '../../core/services/supabase_service.dart';

/// Servicio para la tabla `sesiones`.
class SesionService {
  static const table = 'sesiones';

  static Future<List<Sesion>> obtenerSesionesPorUsuario(int idUsuario) async {
    final data = await SupabaseService.client
        .from(table)
        .select()
        .eq('id_usuario', idUsuario);

    return (data as List).map((e) => Sesion.fromMap(e)).toList();
  }

  static Future<Sesion?> crearSesion(Sesion sesion) async {
    final response = await SupabaseService.insert(table, sesion.toMap());
    if (response.isNotEmpty) return Sesion.fromMap(response.first);
    return null;
  }

  static Future<void> eliminarSesion(int idSesion) async {
    await SupabaseService.delete(table, 'id_sesion', idSesion);
  }
}
