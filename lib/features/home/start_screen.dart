import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

import '../../core/models/sesion.dart';
import '../../core/services/supabase_service.dart';
import '../metodos/pomodoro/pomodoro_screen.dart';

class StartScreen extends StatefulWidget {
  final int? idSesion; // ← AHORA RECIBE SOLO EL ID

  const StartScreen({super.key, required this.idSesion});

  @override
  State<StartScreen> createState() => _StartScreenState();
}

class _StartScreenState extends State<StartScreen> {
  static const _bg = Color(0xFFD9CBBE);
  static const _bar = Color(0xFFB49D87);
  static const _primary = Color(0xFF2C4459);

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Sesion? sesion;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    cargarSesion();
  }

  Future<void> cargarSesion() async {
    if (widget.idSesion == null) {
      setState(() {
        loading = false;
      });
      return;
    }

    final data = await SupabaseService.client
        .from('sesiones')
        .select()
        .eq('id_sesion', widget.idSesion!)
        .maybeSingle();

    if (data != null) {
      sesion = Sesion.fromMap(data);
      await _initializeNotifications();
      await _scheduleNotifications();
    }

    setState(() {
      loading = false;
    });
  }

  Future<void> _initializeNotifications() async {
    const androidInitialize = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initializationSettings = InitializationSettings(android: androidInitialize);
    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
    tz.initializeTimeZones();
  }

  Future<void> _scheduleNotifications() async {
    if (sesion == null) return;

    final sessionDate = sesion!.fecha;
    final now = DateTime.now();

    if (sessionDate.isBefore(now)) return;

    final reminderDate = sessionDate.subtract(const Duration(minutes: 5));

    const androidDetails = AndroidNotificationDetails(
      'session_channel',
      'Sesiones',
      channelDescription: 'Recordatorios de sesiones',
      importance: Importance.high,
      priority: Priority.high,
    );

    const details = NotificationDetails(android: androidDetails);

    if (reminderDate.isAfter(now)) {
      await flutterLocalNotificationsPlugin.zonedSchedule(
        sessionDate.hashCode ^ 0x1000,
        'Sesión en 5 min',
        'Tu sesión "${sesion!.nombreSesion}" comienza en 5 minutos',
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
      'Es hora de: ${sesion!.nombreSesion}',
      tz.TZDateTime.from(sessionDate, tz.local),
      details,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  void _startSession() {
    if (sesion?.idMetodo == 1) {
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
    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (sesion == null) {
      return const Scaffold(
        body: Center(child: Text('Sesión no encontrada')),
      );
    }

    final hora = "${sesion!.fecha.hour.toString().padLeft(2, '0')}:${sesion!.fecha.minute.toString().padLeft(2, '0')}";

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bar,
        title: Text(sesion!.nombreSesion),
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
                  'Método: ${sesion!.idMetodo ?? "Sin método"}',
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
                  'Hora: $hora',
                  style: const TextStyle(fontSize: 13, color: Colors.black54),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
