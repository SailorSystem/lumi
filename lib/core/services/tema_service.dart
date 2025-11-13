import 'package:lumi_app/core/models/tema.dart';
import 'package:lumi_app/core/services/supabase_service.dart';

/// Servicio para la tabla `temas`.
class TemaService {
  static const table = 'temas';

  static Future<List<Tema>> obtenerTemas() async {
    final data = await SupabaseService.getAll(table);
    return data.map((e) => Tema.fromMap(e)).toList();
  }

  static Future<Tema?> crearTema(Tema tema) async {
    final response = await SupabaseService.insert(table, tema.toMap());
    if (response.isNotEmpty) return Tema.fromMap(response.first);
    return null;
  }
}
