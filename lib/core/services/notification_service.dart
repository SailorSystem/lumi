import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  /// Verificar si las notificaciones están activas
  static Future<bool> estanActivas() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('notifications') ?? true;
  }

  /// Programar notificación de recordatorio (15 minutos antes)
  static Future<void> programarRecordatorio({
    required int idSesion,
    required String nombreSesion,
    required DateTime fechaSesion,
  }) async {
    print('🔔 Intentando programar recordatorio...');
    print('   - ID Sesión: $idSesion');
    print('   - Nombre: $nombreSesion');
    print('   - Fecha sesión: $fechaSesion');
    
    if (!await estanActivas()) {
      print('⚠️ Notificaciones desactivadas, no se programará recordatorio');
      return;
    }

    final ahora = DateTime.now();
    final recordatorioFecha = fechaSesion.subtract(const Duration(minutes: 15));
    
    print('   - Ahora: $ahora');
    print('   - Recordatorio programado para: $recordatorioFecha');
    print('   - Diferencia: ${recordatorioFecha.difference(ahora)}');

    if (recordatorioFecha.isBefore(ahora)) {
      print('⚠️ La sesión es muy pronta, no se programa recordatorio de 15 min');
      return;
    }

    const androidDetails = AndroidNotificationDetails(
      'session_reminder',
      'Recordatorios de Sesiones',
      channelDescription: 'Notificaciones 15 minutos antes de una sesión',
      importance: Importance.max, // ✅ Cambiar a max
      priority: Priority.max, // ✅ Cambiar a max
      icon: '@mipmap/ic_launcher',
      playSound: true,
      enableVibration: true,
    );

    const details = NotificationDetails(android: androidDetails);

    try {
      await _notifications.zonedSchedule(
        idSesion * 10 + 1,
        '⏰ Sesión próxima',
        'Prepárate! En 15 minutos te toca: $nombreSesion',
        tz.TZDateTime.from(recordatorioFecha, tz.local),
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );

      print('✅ Recordatorio programado exitosamente');
      print('   - Notification ID: ${idSesion * 10 + 1}');
    } catch (e) {
      print('❌ Error programando recordatorio: $e');
    }
  }


  /// Programar notificación de inicio (en el momento exacto)
  static Future<void> programarNotificacionInicio({
    required int idSesion,
    required String nombreSesion,
    required DateTime fechaSesion,
  }) async {
    if (!await estanActivas()) {
      print('⚠️ Notificaciones desactivadas, no se programará inicio');
      return;
    }

    final ahora = DateTime.now();

    // Solo programar si la fecha es futura
    if (fechaSesion.isBefore(ahora)) {
      print('⚠️ La sesión ya pasó, no se programa notificación de inicio');
      return;
    }

    const androidDetails = AndroidNotificationDetails(
      'session_start',
      'Inicio de Sesiones',
      channelDescription: 'Notificaciones cuando inicia una sesión programada',
      importance: Importance.max,
      priority: Priority.max,
      icon: 'mipmap/ic_launcher',
      playSound: true,
    );

    const details = NotificationDetails(android: androidDetails);

    try {
      await _notifications.zonedSchedule(
        idSesion * 10 + 2, // ID único para inicio
        '🎯 ¡Es ahora!',
        'Realiza tu sesión de estudio: $nombreSesion',
        tz.TZDateTime.from(fechaSesion, tz.local),
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );

      print('✅ Notificación de inicio programada para: $fechaSesion');
    } catch (e) {
      print('❌ Error programando notificación de inicio: $e');
    }
  }

  /// Cancelar todas las notificaciones de una sesión
  static Future<void> cancelarNotificacionesSesion(int idSesion) async {
    try {
      await _notifications.cancel(idSesion * 10 + 1); // Recordatorio
      await _notifications.cancel(idSesion * 10 + 2); // Inicio
      print('✅ Notificaciones canceladas para sesión $idSesion');
    } catch (e) {
      print('❌ Error cancelando notificaciones: $e');
    }
  }

  /// Cancelar todas las notificaciones pendientes
  static Future<void> cancelarTodas() async {
    try {
      await _notifications.cancelAll();
      print('✅ Todas las notificaciones canceladas');
    } catch (e) {
      print('❌ Error cancelando todas las notificaciones: $e');
    }
  }
}
