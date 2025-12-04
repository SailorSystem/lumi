import 'dart:async';
import '../../core/services/stats_usage_service.dart';

class UsageTracker {
  static Timer? _timer;
  static int _idUsuario = 0;
  static int _segundosAcumulados = 0;
  static const int _intervaloEnvio = 30; // Enviar cada 30 segundos

  /// Inicializar el tracking
  static void iniciar(int idUsuario) {
    if (_idUsuario == idUsuario && _timer != null) {
      print('⚠️ Tracking ya está activo para usuario $idUsuario');
      return;
    }
    
    _idUsuario = idUsuario;
    _segundosAcumulados = 0;
    
    // Cancelar timer anterior si existe
    _timer?.cancel();
    
    // Crear nuevo timer que envía cada 30 segundos
    _timer = Timer.periodic(const Duration(seconds: _intervaloEnvio), (_) {
      _enviarTiempo();
    });
    
    print('✅ Tracking de uso INICIADO para usuario $_idUsuario');
  }

  /// Enviar tiempo acumulado a la base de datos
  static Future<void> _enviarTiempo() async {
    if (_idUsuario <= 0) return;
    
    _segundosAcumulados += _intervaloEnvio;
    
    print('📊 Enviando tiempo de uso: $_segundosAcumulados segundos');
    
    final exito = await StatsUsageService.incrementarTiempoUso(
      _idUsuario,
      _intervaloEnvio,
    );
    
    if (exito) {
      print('✅ Tiempo registrado exitosamente');
    } else {
      print('❌ Error registrando tiempo');
    }
  }

  /// Detener tracking y enviar tiempo final
  static Future<void> detener() async {
    if (_timer == null) return;
    
    _timer?.cancel();
    _timer = null;
    
    // Enviar tiempo restante antes de cerrar
    if (_segundosAcumulados > 0) {
      await _enviarTiempo();
    }
    
    print('🛑 Tracking DETENIDO. Total: $_segundosAcumulados segundos');
    _segundosAcumulados = 0;
  }
}
