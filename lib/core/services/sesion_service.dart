import '../../core/models/sesion.dart';
import '../../core/services/supabase_service.dart';

/// Servicio para la tabla `sesiones`.
class SesionService {
  static const table = 'sesiones';

  static Future<List<Sesion>> obtenerSesionesProgramadas(int idUsuario) async {
    final data = await SupabaseService.client
        .from(table)
        .select()
        .eq('id_usuario', idUsuario)
        .eq('estado', 'programada')
        .order('fecha', ascending: false);

    return (data as List).map((e) => Sesion.fromMap(e)).toList();
  }

  static Future<List<Sesion>> obtenerSesionesConcluidas(int idUsuario) async {
    final data = await SupabaseService.client
        .from(table)
        .select()
        .eq('id_usuario', idUsuario)
        .eq('estado', 'concluida')
        .order('fecha', ascending: false);

    return (data as List).map((e) => Sesion.fromMap(e)).toList();
  }

  static Future<Sesion?> crearSesion(Sesion sesion) async {
    final response = await SupabaseService.insert(table, sesion.toMap());
    if (response.isNotEmpty) return Sesion.fromMap(response.first);
    return null;
  }

  static Future<void> eliminarSesion(int idSesion) async {
    try {
      print('🗑️ Eliminando sesión $idSesion...');
      
      await SupabaseService.delete('sesiones', 'id_sesion', idSesion);
      
      print('✅ Sesión $idSesion eliminada de BD');
    } catch (e) {
      print('❌ Error eliminando sesión: $e');
      rethrow;
    }
  }


    // ✅ NUEVO: Actualizar estado de sesión
  static Future<void> actualizarEstadoSesion(int idSesion, String nuevoEstado) async {
    try {
      print('🔄 Actualizando sesión $idSesion a estado: $nuevoEstado');
      
      final response = await SupabaseService.client
          .from(table)
          .update({'estado': nuevoEstado})
          .eq('id_sesion', idSesion)
          .select(); // ✅ IMPORTANTE: Agregar .select()
      
      print('✅ Respuesta de Supabase: $response');
      print('✅ Sesión $idSesion actualizada a estado: $nuevoEstado');
    } catch (e) {
      print('❌ Error actualizando estado de sesión: $e');
      rethrow;
    }
  }

  
  // ✅ NUEVO: Actualizar sesión completa con múltiples campos
  static Future<void> actualizarSesion(int idSesion, Map<String, dynamic> cambios) async {
    try {
      await SupabaseService.update(table, 'id_sesion', idSesion, cambios);
      print('✅ Sesión $idSesion actualizada: $cambios');
    } catch (e) {
      print('❌ Error actualizando sesión: $e');
      rethrow;
    }
  }

    // ✅ NUEVO: Actualizar solo la fecha de la sesión (para posponer)
  static Future<void> actualizarFechaSesion(int idSesion, DateTime nuevaFecha) async {
    try {
      final response = await SupabaseService.client
          .from(table)
          .update({'fecha': nuevaFecha.toIso8601String()})
          .eq('id_sesion', idSesion)
          .select();

      print('⏰ Nueva fecha guardada para sesión $idSesion -> $nuevaFecha');
      print('Respuesta Supabase: $response');
    } catch (e) {
      print('❌ Error al actualizar fecha de sesión: $e');
      rethrow;
    }
  }

}
