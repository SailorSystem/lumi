// lib/core/services/usuario_service.dart

import '../../core/models/usuario.dart';
import '../../core/services/supabase_service.dart';

class UsuarioService {
  static final _client = SupabaseService.client;

  /// Obtener usuario por ID
  static Future<Usuario?> getUsuario(int idUsuario) async {
    final response = await _client
        .from('usuarios')
        .select()
        .eq('id_usuario', idUsuario)
        .maybeSingle();

    if (response == null) return null;
    return Usuario.fromMap(response);
  }

  /// Crear usuario
  static Future<Usuario?> crearUsuario(String nombre) async {
    final response = await _client
        .from('usuarios')
        .insert({'nombre': nombre})
        .select()
        .maybeSingle();

    if (response == null) return null;
    return Usuario.fromMap(response);
  }

  static Future<bool> actualizarNombre(int idUsuario, String nuevoNombre) async {
      try {
        final res = await _client
            .from('usuarios')
            .update({'nombre': nuevoNombre})
            .eq('id_usuario', idUsuario);

        return true;
      } catch (e) {
        print("❌ Error actualizando nombre: $e");
        return false;
      }
    }
    /// Actualizar estado de ánimo (0, 1, 2)
  static Future<bool> actualizarEstadoAnimo(int idUsuario, int nuevoEstado) async {
    if (nuevoEstado < 0 || nuevoEstado > 2) {
      throw Exception("El estado de ánimo debe ser 0, 1 o 2");
    }

    final response = await _client
        .from('usuarios')
        .update({'estado_animo': nuevoEstado})
        .eq('id_usuario', idUsuario);

    return response.error == null;
  }

  /// 🔥 OBTENER nombre del usuario por ID
  static Future<String?> obtenerNombre(int idUsuario) async {
    try {
      final res = await _client
          .from('usuarios')
          .select('nombre')
          .eq('id_usuario', idUsuario)
          .maybeSingle();

      if (res == null) return null;
      return res['nombre'] as String?;
    } catch (e) {
      print("❌ Error obteniendo nombre: $e");
      return null;
    }
  }
  /// Obtener todos los usuarios
  static Future<List<Usuario>> getTodos() async {
    final response = await _client.from('usuarios').select();

    return (response as List)
        .map((e) => Usuario.fromMap(e))
        .toList();
  }
}
