import 'package:lumi_app/core/models/usuario.dart';
import 'package:lumi_app/core/services/supabase_service.dart';

/// Servicio para la tabla `usuarios`
class UsuarioService {
  static const table = 'usuarios';

  static Future<Usuario?> crearUsuario(Usuario usuario) async {
    final response = await SupabaseService.insert(table, usuario.toMap());
    if (response.isNotEmpty) {
      return Usuario.fromMap(response.first);
    }
    return null;
  }

  static Future<List<Usuario>> obtenerUsuarios() async {
    final data = await SupabaseService.getAll(table);
    return data.map((e) => Usuario.fromMap(e)).toList();
  }

  static Future<Usuario?> obtenerPorId(int id) async {
    final data = await SupabaseService.getById(table, 'id_usuario', id);
    return data != null ? Usuario.fromMap(data) : null;
  }

  static Future<void> eliminarUsuario(int id) async {
    await SupabaseService.delete(table, 'id_usuario', id);
  }
}
