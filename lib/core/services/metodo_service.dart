import 'package:lumi_app/core/models/metodo.dart';
import 'package:lumi_app/core/services/supabase_service.dart';

/// Servicio para la tabla `metodos`.
class MetodoService {
  static const table = 'metodos';

  static Future<List<Metodo>> obtenerMetodos() async {
    final data = await SupabaseService.getAll(table);
    return data.map((e) => Metodo.fromMap(e)).toList();
  }

  static Future<Metodo?> crearMetodo(Metodo metodo) async {
    final response = await SupabaseService.insert(table, metodo.toMap());
    if (response.isNotEmpty) return Metodo.fromMap(response.first);
    return null;
  }
}
