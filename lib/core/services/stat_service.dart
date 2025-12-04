import '../../core/models/stat.dart';
import '../../core/services/supabase_service.dart';

/// Servicio para la tabla `stats`.
class StatService {
  static const table = 'stats';

  static Future<List<Stat>> obtenerStatsPorUsuario(int idUsuario) async {
    final data = await SupabaseService.client
        .from(table)
        .select()
        .eq('id_usuario', idUsuario);

    return (data as List).map((e) => Stat.fromMap(e)).toList();
  }

  static Future<Stat?> crearStat(Stat stat) async {
    final response = await SupabaseService.insert(table, stat.toMap());
    if (response.isNotEmpty) return Stat.fromMap(response.first);
    return null;
  }

  static Future<void> eliminarStat(int idStat) async {
    await SupabaseService.delete(table, 'id_stat', idStat);
  }


    // En stat_service.dart
  static Future<void> incrementarTiempoUso(int idUsuario, int segundos) async {
    await SupabaseService.client.rpc(
      'increment_app_time',
      params: {
        'p_id_usuario': idUsuario,
        'p_seconds': segundos,
      },
    );
  }

  static Future<bool> registrarEstadistica({
    required int idUsuario,
    required int idSesion,
    required int tiempoTotalSegundos,
    required int ciclosCompletados,
  }) async {
    try {
      print('📊 Registrando estadística en BD...');
      print('   - Usuario: $idUsuario');
      print('   - Sesión: $idSesion');
      print('   - Tiempo: $tiempoTotalSegundos seg');
      print('   - Ciclos: $ciclosCompletados');

      final nuevaStat = Stat(
        idUsuario: idUsuario,
        idSesion: idSesion,
        fechaRegistro: DateTime.now(),
        tiempoTotalEstudio: tiempoTotalSegundos,
        ciclosCompletados: ciclosCompletados,
      );

      final resultado = await crearStat(nuevaStat);

      if (resultado != null) {
        print('✅ Estadística guardada exitosamente (ID: ${resultado.idStat})');
        return true;
      } else {
        print('❌ Error: crearStat() retornó null');
        return false;
      }
    } catch (e, stackTrace) {
      print('❌ Error en registrarEstadistica(): $e');
      print('Stack trace: $stackTrace');
      return false;
    }
  }

  static Future<Map<String, dynamic>> obtenerEstadisticasAgregadas({
    required int idUsuario,
    DateTime? fechaInicio,
    DateTime? fechaFin,
  }) async {
    try {
      final response = await SupabaseService.client.rpc(
        'obtener_estadisticas_agregadas',
        params: {
          'p_id_usuario': idUsuario,
          'p_fecha_inicio': (fechaInicio ?? DateTime(2000)).toIso8601String(),
          'p_fecha_fin': (fechaFin ?? DateTime.now()).toIso8601String(),
        },
      );
      return response.first as Map<String, dynamic>;
    } catch (e) {
      print('Error obteniendo estadísticas agregadas: $e');
      return {'total_tiempo': 0, 'total_sesiones': 0, 'promedio_tiempo': 0.0};
    }
  }

}
