import '../../core/services/supabase_service.dart';

class StatsUsageService {
  static final client = SupabaseService.client;

  /// Incrementa el tiempo total de uso de app en segundos
  static Future<bool> incrementarTiempoUso(int idUsuario, int segundos) async {
    if (idUsuario <= 0 || segundos <= 0) return false;

    try {
      print('📤 Enviando tiempo a Supabase: $segundos segundos para usuario $idUsuario');
      
      // ✅ OPCIÓN 1: Intentar usar función RPC (más eficiente)
      try {
        await client.rpc(
          'incrementar_tiempo_uso',
          params: {
            'p_id_usuario': idUsuario,
            'p_segundos': segundos,
          },
        );
        print('✅ Tiempo registrado vía RPC');
        return true;
      } catch (rpcError) {
        print('⚠️ RPC no disponible: $rpcError');
        
        // ✅ OPCIÓN 2: Obtener valor actual, sumar y actualizar
        final response = await client
            .from('usuarios')
            .select('tiempo_uso_segundos')
            .eq('id_usuario', idUsuario)
            .maybeSingle();
        
        int tiempoActual = 0;
        if (response != null) {
          tiempoActual = response['tiempo_uso_segundos'] as int? ?? 0;
        }
        
        final nuevoTiempo = tiempoActual + segundos;
        
        await client
            .from('usuarios')
            .update({'tiempo_uso_segundos': nuevoTiempo})
            .eq('id_usuario', idUsuario);
        
        print('✅ Tiempo registrado vía UPDATE: $tiempoActual → $nuevoTiempo');
        return true;
      }
    } catch (e) {
      print('❌ Error incrementando tiempo de uso: $e');
      return false;
    }
  }

  /// Obtener tiempo total de uso de un usuario
  static Future<int> obtenerTiempoUso(int idUsuario) async {
    try {
      final response = await client
          .from('usuarios')
          .select('tiempo_uso_segundos')
          .eq('id_usuario', idUsuario)
          .maybeSingle();
      
      if (response != null) {
        return response['tiempo_uso_segundos'] as int? ?? 0;
      }
      
      return 0;
    } catch (e) {
      print('❌ Error obteniendo tiempo de uso: $e');
      return 0;
    }
  }

  /// Convertir segundos a formato legible
  static String formatearTiempo(int segundos) {
    final horas = segundos ~/ 3600;
    final minutos = (segundos % 3600) ~/ 60;
    final segs = segundos % 60;
    
    if (horas > 0) {
      return '${horas}h ${minutos}m';
    } else if (minutos > 0) {
      return '${minutos}m ${segs}s';
    } else {
      return '${segs}s';
    }
  }
}
