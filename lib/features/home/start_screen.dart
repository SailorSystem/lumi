import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../metodos/pomodoro/pomodoro_screen.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import '../../main.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class StartScreen extends StatefulWidget {
  final Map<String, dynamic>? session;

  const StartScreen({super.key, this.session});

  @override
  State<StartScreen> createState() => _StartScreenState();
}

class _StartScreenState extends State<StartScreen> {
  static const _bg = Color(0xFFD9CBBE);
  static const _bar = Color(0xFFB49D87);
  static const _primary = Color(0xFF2C4459);

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    if (widget.session != null) {
      _initializeNotifications();
      _scheduleNotifications();
    }
  }

  Future<void> _initializeNotifications() async {
    const androidInitialize = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initializationSettings = InitializationSettings(android: androidInitialize);
    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
    tz.initializeTimeZones();
  }

  Future<void> _scheduleNotifications() async {
    if (widget.session == null) return;
    final sessionDate = DateTime.parse(widget.session!['fecha'] as String);
    final now = DateTime.now();
    if (sessionDate.isBefore(now)) return;

    final reminderDate = sessionDate.subtract(const Duration(minutes: 5));
    final androidDetails = AndroidNotificationDetails(
      'session_channel',
      'Sesiones',
      channelDescription: 'Recordatorios de sesiones',
      importance: Importance.high,
      priority: Priority.high,
    );
    final details = NotificationDetails(android: androidDetails);

    if (reminderDate.isAfter(now)) {
      await flutterLocalNotificationsPlugin.zonedSchedule(
        sessionDate.hashCode ^ 0x1000,
        'Sesión en 5 min',
        'Tu sesión "${widget.session!['titulo']}" comienza en 5 minutos',
        tz.TZDateTime.from(reminderDate, tz.local),
        details,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    }

    await flutterLocalNotificationsPlugin.zonedSchedule(
      sessionDate.hashCode ^ 0x1001,
      'Sesión iniciando',
      'Es hora de: ${widget.session!['titulo']}',
      tz.TZDateTime.from(sessionDate, tz.local),
      details,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  void _startSession() {
    if (widget.session?['metodo'] == 'Pomodoro') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const PomodoroScreen(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.session?['titulo'] ?? 'Sesión';

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bar,
        title: Text(title),
        centerTitle: true,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '¿Desea iniciar?',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: _primary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 18),
                Text(
                  widget.session?['metodo'] != null
                      ? 'Método: ${widget.session!['metodo']}'
                      : '',
                  style: TextStyle(fontSize: 14, color: _primary.withOpacity(0.9)),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 140,
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: _startSession,
                        icon: const Icon(Icons.play_arrow, size: 20),
                        label: const Text('Sí'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28),
                          ),
                          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    SizedBox(
                      width: 140,
                      height: 48,
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close, size: 20),
                        label: const Text('No'),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          side: BorderSide(color: Colors.grey.shade300),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28),
                          ),
                          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  widget.session?['fecha'] != null
                      ? 'Hora: ${DateTime.parse(widget.session!['fecha']).hour.toString().padLeft(2, '0')}:${DateTime.parse(widget.session!['fecha']).minute.toString().padLeft(2, '0')}'
                      : '',
                  style: TextStyle(fontSize: 13, color: Colors.black54),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> scheduleSessionNotifications(Map<String, dynamic> session) async {
  if (session == null) return;
  try {
    final sessionDate = DateTime.parse(session['fecha'] as String);
    final now = DateTime.now();
    if (sessionDate.isBefore(now)) return;

    final reminderDate = sessionDate.subtract(const Duration(minutes: 5));
    final androidDetails = AndroidNotificationDetails(
      'session_channel',
      'Sesiones',
      channelDescription: 'Recordatorios de sesiones',
      importance: Importance.high,
      priority: Priority.high,
    );
    final details = NotificationDetails(android: androidDetails);

    if (reminderDate.isAfter(now)) {
      await flutterLocalNotificationsPlugin.zonedSchedule(
        sessionDate.hashCode ^ 0x1000,
        'Sesión en 5 min',
        'Tu sesión "${session['titulo']}" comienza en 5 minutos',
        tz.TZDateTime.from(reminderDate, tz.local),
        details,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    }

    await flutterLocalNotificationsPlugin.zonedSchedule(
      sessionDate.hashCode ^ 0x1001,
      'Sesión iniciando',
      'Es hora de: ${session['titulo']}',
      tz.TZDateTime.from(sessionDate, tz.local),
      details,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  } catch (e) {
    debugPrint('Error scheduling session notifications: $e');
  }
}

Future<void> scheduleTestNotification() async {
  final when = tz.TZDateTime.now(tz.local).add(const Duration(seconds: 10));
  final details = NotificationDetails(
    android: AndroidNotificationDetails(
      'test',
      'Pruebas',
      channelDescription: 'Canal de pruebas',
      importance: Importance.max,
      priority: Priority.high,
    ),
  );
  await flutterLocalNotificationsPlugin.zonedSchedule(
    99999,
    'Prueba',
    'Notificación de prueba en 10s',
    when,
    details,
    uiLocalNotificationDateInterpretation:
        UILocalNotificationDateInterpretation.absoluteTime,
    androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
  );
}
