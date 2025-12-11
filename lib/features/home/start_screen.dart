import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:provider/provider.dart';

import '../../core/models/sesion.dart';
import '../../core/services/supabase_service.dart';
import '../../core/providers/theme_provider.dart';
import '../metodos/pomodoro/pomodoro_screen.dart';
import '../metodos/flashcards/flashcards_screen.dart';
import '../metodos/mentalmaps/mentalmaps.screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';  


class StartScreen extends StatefulWidget {
  final int? idSesion; // ← AHORA RECIBE SOLO EL ID

  const StartScreen({super.key, required this.idSesion});

  @override
  State<StartScreen> createState() => _StartScreenState();
}

class _StartScreenState extends State<StartScreen> {
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Sesion? sesion;
  bool loading = true;
  String? metodoNombre; // nombre del método para mostrar

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

      // obtener nombre del método si existe id_metodo
      if (sesion?.idMetodo != null) {
        final int metodoId = sesion!.idMetodo!;
        try {
          final prefs = await SharedPreferences.getInstance();
          final stored = prefs.getStringList('metodos') ?? [];
          final metodos = stored.map((s) => Map<String, dynamic>.from(json.decode(s))).toList();
          final m = metodos.firstWhere(
            (m) => m['id_metodo'] == metodoId,
            orElse: () => {},
          );
          if (m.isNotEmpty) {
            metodoNombre = (m['nombre'] ?? '').toString();
          } else {
            metodoNombre = 'Método $metodoId';
          }
        } catch (e) {
          print('❌ Error obteniendo nombre de método local: $e');
          metodoNombre = 'Método $metodoId';
        }
      }


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

  // En start_screen.dart - método startSession()
  void startSession() {
    if (sesion == null || sesion!.idMetodo == null) return;
    
    switch (sesion!.idMetodo) {
      case 1: // Pomodoro
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => PomodoroScreen(idSesion: sesion!.idSesion),
          ),
        );
        break; // ✅ IMPORTANTE
        
      case 2: // Flashcards
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => FlashcardsScreen(idSesion: sesion!.idSesion),
          ),
        );
        break; // ✅ IMPORTANTE
        
      case 3: // Mapa Mental
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => MentalMapsScreen(idSesion: sesion!.idSesion),
          ),
        );
        break; // ✅ IMPORTANTE
        
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Método ${sesion!.idMetodo} no reconocido')),
        );
    }
  }


  @override
  Widget build(BuildContext context) {
    final tp = Provider.of<ThemeProvider>(context);
    final bgcolor = tp.backgroundColor;
    final primary = tp.primaryColor;
    final colors = tp.isDarkMode
        ? [const Color(0xFF212C36), const Color(0xFF313940), tp.backgroundColor]
        : [const Color(0xFFB6C9D6), const Color(0xFFE6DACA), tp.backgroundColor];

    if (loading) {
      return Scaffold(
        backgroundColor: bgcolor,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (sesion == null) {
      return Scaffold(
        backgroundColor: bgcolor,
        body: Center(child: Text('Sesión no encontrada', style: TextStyle(color: primary))),
      );
    }

    final hora = "${sesion!.fecha.hour.toString().padLeft(2, '0')}:${sesion!.fecha.minute.toString().padLeft(2, '0')}";

    final showName = (metodoNombre ?? (sesion!.idMetodo != null ? 'Método ${sesion!.idMetodo}' : 'Sin método'));

    return Scaffold(
      backgroundColor: bgcolor,
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        title: Text(sesion!.nombreSesion, style: TextStyle(color: primary)),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: colors,
              stops: const [0.0, 0.35, 1.0],
            ),
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: primary),
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
                    color: primary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 18),
                Text(
                  'Método: $showName',
                  style: TextStyle(fontSize: 14, color: primary.withOpacity(0.9)),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 140,
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: (sesion!.idMetodo != null) ? startSession : null,
                        icon: Icon(Icons.play_arrow, size: 20, color: Colors.white),
                        label: Text('Sí', style: const TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primary,
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
                        icon: Icon(Icons.close, size: 20, color: primary),
                        label: Text('No', style: TextStyle(color: primary)),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: tp.isDarkMode ? tp.cardColor : Colors.white,
                          foregroundColor: primary,
                          side: BorderSide(color: primary.withOpacity(0.18)),
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
                  style: TextStyle(fontSize: 13, color: primary.withOpacity(0.9)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
