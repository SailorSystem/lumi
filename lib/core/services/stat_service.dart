import 'package:lumi_app/core/models/stat.dart';
import 'package:lumi_app/core/services/supabase_service.dart';

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
}
