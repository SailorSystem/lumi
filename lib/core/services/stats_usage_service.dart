import '../../core/services/supabase_service.dart';

class StatsUsageService {
  static final _client = SupabaseService.client;

  /// Incrementa el tiempo total de uso de app (en segundos)
  static Future<bool> incrementarTiempoUso(int idUsuario, int segundos) async {
    if (idUsuario <= 0 || segundos <= 0) return false;

    try {
      final response = await _client.rpc(
        'increment_app_time',
        params: {
          'p_id_usuario': idUsuario,
          'p_seconds': segundos,
        },
      );

      // `response` ya es el resultado, no necesitas `.execute()`
      return response != null; 
    } catch (e) {
      print("❌ Error incrementando tiempo de uso: $e");
      return false;
    }
  }
}
