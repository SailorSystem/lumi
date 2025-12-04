import 'package:flutter/material.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'core/services/notification_service.dart';
import 'features/home/splash_screen.dart';
import 'core/providers/theme_provider.dart';

Future<void> main() async {
  // ✅ Capturar errores globales
  WidgetsFlutterBinding.ensureInitialized();
  
  // ✅ Inicializar Timezones PRIMERO
  try {
    tz.initializeTimeZones();
    print('✅ Timezones inicializados');
  } catch (e) {
    print('❌ Error inicializando timezones: $e');
  }
  
  // ✅ Inicializar Notificaciones
  try {
    await NotificationService.init();
    print('✅ Notificaciones inicializadas');
    
    // ✅ Solicitar permisos (no crash si falla)
    final permisos = await NotificationService.solicitarPermisos();
    print('✅ Permisos de notificaciones: $permisos');
  } catch (e) {
    print('❌ Error inicializando notificaciones: $e');
  }
  
  // ✅ Inicializar Supabase
  try {
    await Supabase.initialize(
      url: 'https://poxheykxpublcwwodzpz.supabase.co',
      anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBveGhleWt4cHVibGN3d29kenB6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjI3NzE4MjcsImV4cCI6MjA3ODM0NzgyN30.DZ2L7TxLWCPW65KNk4cHWol3vtipbladCG28D3oPros',
    );
    print('✅ Supabase inicializado');
  } catch (e) {
    print('❌ Error inicializando Supabase: $e');
  }
  
  // ✅ Inicializar tema
  final themeProvider = ThemeProvider();
  await themeProvider.initialize();
  
  // ✅ Iniciar aplicación
  runApp(
    ChangeNotifierProvider.value(
      value: themeProvider,
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Lumi',
      themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: ThemeProvider.lightBg,
        primaryColor: ThemeProvider.lightPrimary,
        appBarTheme: const AppBarTheme(
          backgroundColor: ThemeProvider.lightBar,
          foregroundColor: ThemeProvider.lightPrimary,
        ),
        cardColor: Colors.white,
        colorScheme: const ColorScheme.light(
          primary: ThemeProvider.lightPrimary,
          secondary: ThemeProvider.lightBar,
          surface: ThemeProvider.lightBg,
        ),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: ThemeProvider.darkBg,
        primaryColor: ThemeProvider.darkPrimary,
        appBarTheme: const AppBarTheme(
          backgroundColor: ThemeProvider.darkBar,
          foregroundColor: ThemeProvider.darkPrimary,
        ),
        cardColor: const Color(0xFF232323),
        colorScheme: const ColorScheme.dark(
          primary: ThemeProvider.darkPrimary,
          secondary: ThemeProvider.darkBar,
          surface: ThemeProvider.darkBg,
        ),
      ),
      home: const SplashScreen(),
    );
  }
}
