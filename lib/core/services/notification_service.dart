import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  
  static bool _isInitialized = false;

  /// Inicializar notificaciones
  static Future<bool> init() async {
    try {
      // Inicializar timezones
      tzdata.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation('America/Bogota')); // ✅ Zona horaria Colombia
      
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const initSettings = InitializationSettings(android: androidSettings);
      
      final initialized = await _notifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (details) {
          debugPrint('📲 Notificación tocada: ${details.payload}');
        },
      );
      
      _isInitialized = initialized ?? false;
      print('✅ NotificationService inicializado: $_isInitialized');
      return _isInitialized;
    } catch (e) {
      print('❌ Error inicializando NotificationService: $e');
      _isInitialized = false;
      return false;
    }
  }
  
  /// Solicitar permisos
  static Future<bool> solicitarPermisos() async {
    if (!_isInitialized) {
      print('⚠️ NotificationService no inicializado');
      return false;
    }
    
    try {
      final androidImplementation =
          _notifications.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      
      if (androidImplementation != null) {
        final notificationGranted = await androidImplementation
            .requestNotificationsPermission();
        
        final alarmGranted = await androidImplementation
            .requestExactAlarmsPermission();
        
        print('✅ Permiso notificaciones: $notificationGranted');
        print('✅ Permiso alarmas exactas: $alarmGranted');
        
        return notificationGranted == true;
      }
      
      return true;
    } catch (e) {
      print('❌ Error solicitando permisos: $e');
      return false;
    }
  }

  /// Verificar si están activas
  static Future<bool> estanActivas() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('notifications') ?? true;
  }

  /// Guardar estado
  static Future<void> setActivas(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications', value);
  }

  /// Programar recordatorio 5 minutos antes
  static Future<bool> programarRecordatorio({
    required int idSesion,
    required String nombreSesion,
    required DateTime fechaSesion,
  }) async {
    if (!_isInitialized) {
      print('❌ NotificationService no inicializado');
      return false;
    }
    
    print('🔔 =================================');
    print('🔔 PROGRAMAR RECORDATORIO');
    print('🔔 =================================');
    print('   - ID Sesión: $idSesion');
    print('   - Nombre: $nombreSesion');
    print('   - Fecha sesión: $fechaSesion');
    
    try {
      if (!await estanActivas()) {
        print('⚠️ Notificaciones desactivadas');
        return false;
      }

      final ahora = DateTime.now();
      final recordatorioFecha = fechaSesion.subtract(const Duration(minutes: 5));
      
      print('   - Ahora: $ahora');
      print('   - Recordatorio para: $recordatorioFecha');
      print('   - Diferencia: ${recordatorioFecha.difference(ahora)}');

      if (recordatorioFecha.isBefore(ahora)) {
        print('⚠️ La sesión es muy pronta');
        return false;
      }

      final tzDateTime = tz.TZDateTime.from(recordatorioFecha, tz.local);
      print('   - TZ DateTime: $tzDateTime');

      await _notifications.zonedSchedule(
        idSesion * 10 + 1,
        '⏰ Sesión próxima',
        '¡Prepárate! En 5 minutos te toca: $nombreSesion',
        tzDateTime,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'session_reminder',
            'Recordatorios de Sesiones',
            channelDescription: 'Notificaciones 5 minutos antes de una sesión',
            importance: Importance.max,
            priority: Priority.max,
            playSound: true,
            enableVibration: true,
            enableLights: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );

      print('✅ Recordatorio programado (ID: ${idSesion * 10 + 1})');
      print('🔔 =================================');
      return true;
    } catch (e, stackTrace) {
      print('❌ ERROR programando recordatorio: $e');
      print('Stack trace: $stackTrace');
      print('🔔 =================================');
      return false;
    }
  }

  /// Programar notificación de inicio
  static Future<bool> programarNotificacionInicio({
    required int idSesion,
    required String nombreSesion,
    required DateTime fechaSesion,
  }) async {
    if (!_isInitialized) {
      print('❌ NotificationService no inicializado');
      return false;
    }
    
    try {
      if (!await estanActivas()) {
        print('⚠️ Notificaciones desactivadas');
        return false;
      }

      final ahora = DateTime.now();
      if (fechaSesion.isBefore(ahora)) {
        print('⚠️ La sesión ya pasó');
        return false;
      }

      final tzDateTime = tz.TZDateTime.from(fechaSesion, tz.local);

      await _notifications.zonedSchedule(
        idSesion * 10 + 2,
        '🚀 ¡Es ahora!',
        'Realiza tu sesión de estudio: $nombreSesion',
        tzDateTime,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'session_start',
            'Inicio de Sesiones',
            channelDescription: 'Notificaciones cuando inicia una sesión',
            importance: Importance.max,
            priority: Priority.max,
            playSound: true,
            enableVibration: true,
            enableLights: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );

      print('✅ Notificación de inicio programada (ID: ${idSesion * 10 + 2})');
      return true;
    } catch (e) {
      print('❌ Error programando inicio: $e');
      return false;
    }
  }

  /// Cancelar notificaciones de una sesión
  static Future<void> cancelarNotificacionesSesion(int idSesion) async {
    try {
      await _notifications.cancel(idSesion * 10 + 1);
      await _notifications.cancel(idSesion * 10 + 2);
      print('✅ Notificaciones canceladas para sesión $idSesion');
    } catch (e) {
      print('❌ Error cancelando notificaciones: $e');
    }
  }

  /// Cancelar todas
  static Future<void> cancelarTodas() async {
    try {
      await _notifications.cancelAll();
      print('✅ Todas las notificaciones canceladas');
    } catch (e) {
      print('❌ Error cancelando todas: $e');
    }
  }
  
  /// Listar pendientes
  static Future<void> listarPendientes() async {
    try {
      final pending = await _notifications.pendingNotificationRequests();
      print('📋 Notificaciones pendientes: ${pending.length}');
      for (var notif in pending) {
        print('   - ID: ${notif.id}, Título: ${notif.title}');
      }
    } catch (e) {
      print('❌ Error listando pendientes: $e');
    }
  }
}
