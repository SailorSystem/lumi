import 'package:supabase_flutter/supabase_flutter.dart';

class MoodService {
  /// Obtener el estado de ánimo actual del usuario
  static Future<int> obtenerEstadoAnimo(int idUsuario) async {
    try {
      final response = await Supabase.instance.client
          .from('usuarios')
          .select('estado_animo')
          .eq('id_usuario', idUsuario)
          .single();
      
      return response['estado_animo'] as int? ?? 2; // Default: neutral
    } catch (e) {
      print('❌ Error obteniendo estado de ánimo: $e');
      return 2; // Default: neutral
    }
  }
  
  /// Calcular y actualizar el estado de ánimo basado en sesiones
  static Future<int> calcularYActualizarEstadoAnimo(int idUsuario) async {
    try {
      // Llamar a la función SQL que calcula el estado
      final response = await Supabase.instance.client
          .rpc('calcular_estado_animo', params: {'p_id_usuario': idUsuario});
      
      final nuevoEstado = response as int;
      print('✅ Estado de ánimo calculado: $nuevoEstado');
      
      return nuevoEstado;
    } catch (e) {
      print('❌ Error calculando estado de ánimo: $e');
      return 2; // Default: neutral
    }
  }
  
  /// Obtener imagen según el estado de ánimo
  static String obtenerImagenAnimo(int estado) {
    switch (estado) {
      case 0:
        return 'assets/images/lumi_animo0.png';
      case 1:
        return 'assets/images/lumi_animo1.png';
      case 2:
        return 'assets/images/lumi.png'; // Neutral - imagen original
      case 3:
        return 'assets/images/lumi_animo3.png';
      default:
        return 'assets/images/lumi.png';
    }
  }
  
  /// Obtener mensajes según el estado de ánimo
  static List<String> obtenerMensajesAnimo(int estado) {
    switch (estado) {
      case 0: // Desanimado
        return [
          '¡Vamos! Tú puedes hacerlo 💪',
          'Cada pequeño paso cuenta ✨',
          'No te rindas, confío en ti 🌟',
          'Hoy es un buen día para empezar 🚀',
          'Eres más fuerte de lo que crees 💙',
        ];
      case 1: // Triste
        return [
          'Vas por buen camino, sigue así 📚',
          'Un esfuerzo más y lo lograrás ⭐',
          'Creo en tu potencial 💫',
          'Paso a paso llegarás lejos 🎯',
          'Cada sesión te acerca a tu meta 🌈',
        ];
      case 2: // Neutral
        return [
          'Un bloque a la vez 📝',
          '25 minutos. Todo tuyo ⏰',
          'Pequeños pasos, grandes logros 🎓',
          'Respira. Enfócate. Brilla ✨',
          'Hoy mejor que ayer 🌟',
        ];
      case 3: // Feliz
        return [
          '¡Increíble progreso! 🎉',
          '¡Eres imparable! 🚀',
          '¡Sigue brillando así! ⭐',
          '¡Lo estás haciendo genial! 🌟',
          '¡Eres un campeón! 🏆',
        ];
      default:
        return [
          'Un bloque a la vez 📝',
          'Pequeños pasos, grandes logros 🎓',
        ];
    }
  }
}
