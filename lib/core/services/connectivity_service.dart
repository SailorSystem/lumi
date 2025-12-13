import 'package:supabase_flutter/supabase_flutter.dart';

class ConnectivityService {
  /// Ejecutar una operación de Supabase con retry automático
  static Future<T> ejecutarConReintento<T>({
    required Future<T> Function() operacion,
    int intentosMaximos = 3,
    Duration delayEntreIntentos = const Duration(seconds: 2),
  }) async {
    int intentos = 0;
    
    while (intentos < intentosMaximos) {
      try {
        return await operacion();
      } catch (e) {
        intentos++;
        print('⚠️ Intento $intentos/$intentosMaximos falló: $e');
        
        if (intentos >= intentosMaximos) {
          print('❌ Se alcanzó el máximo de intentos');
          rethrow;
        }
        
        // Esperar antes del siguiente intento
        await Future.delayed(delayEntreIntentos);
      }
    }
    
    throw Exception('No se pudo completar la operación después de $intentosMaximos intentos');
  }
  
  /// Verificar si hay conexión
  static Future<bool> verificarConexion() async {
    try {
      await Supabase.instance.client
          .from('usuarios')
          .select('id_usuario')
          .limit(1);
      return true;
    } catch (e) {
      print('❌ Sin conexión: $e');
      return false;
    }
  }
}
