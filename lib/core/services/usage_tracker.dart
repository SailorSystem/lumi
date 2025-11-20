import 'dart:async';
import '../../core/services/stats_usage_service.dart';

class UsageTracker {
  static Timer? _timer;
  static int _idUsuario = 0;

  /// Inicializar el tracking
  static void iniciar(int idUsuario) {
    _idUsuario = idUsuario;

    // Si ya estaba corriendo, no duplicar el timer
    detener();

    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      StatsUsageService.incrementarTiempoUso(_idUsuario, 5);
    });

    print("⏳ Tracking de uso INICIADO para usuario $_idUsuario");
  }

  /// Detener tracking
  static void detener() {
    _timer?.cancel();
    _timer = null;
    print("⛔ Tracking DETENIDO");
  }
}
