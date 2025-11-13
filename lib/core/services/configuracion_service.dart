import 'package:lumi_app/core/models/configuracion.dart';
import 'package:lumi_app/core/services/supabase_service.dart';

/// Servicio para la tabla `configuraciones`.
class ConfiguracionService {
  static const table = 'configuraciones';

  static Future<Configuracion?> crearConfiguracion(Configuracion config) async {
    final response = await SupabaseService.insert(table, config.toMap());
    if (response.isNotEmpty) return Configuracion.fromMap(response.first);
    return null;
  }

  static Future<Configuracion?> obtenerPorUsuario(int idUsuario) async {
    final data = await SupabaseService.client
        .from(table)
        .select()
        .eq('id_usuario', idUsuario)
        .maybeSingle();

    return data != null ? Configuracion.fromMap(data) : null;
  }

  static Future<void> actualizarConfiguracion(int idConfig, Map<String, dynamic> cambios) async {
    await SupabaseService.update(table, 'id_config', idConfig, cambios);
  }
}
