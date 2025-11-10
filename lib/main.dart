import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:lumi_app/test/testsupa.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'features/home/home_screen.dart';

// Notificaciones
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializa zonas horarias (para notificaciones programadas)
  tz.initializeTimeZones();

  // 🔹 Inicializa Supabase
  await Supabase.initialize(
    url: 'https://poxheykxpublcwwodzpz.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBveGhleWt4cHVibGN3d29kenB6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjI3NzE4MjcsImV4cCI6MjA3ODM0NzgyN30.DZ2L7TxLWCPW65KNk4cHWol3vtipbladCG28D3oPros', // <-- Reemplaza con la clave "anon public" de tu panel Supabase
  );

  // 🔹 Inicializa notificaciones locales
  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  const initSettings = InitializationSettings(android: androidInit);
  await flutterLocalNotificationsPlugin.initialize(initSettings);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Lumi',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.deepPurple,
      ),
      home: const TestSupa(),
    );
  }
}
