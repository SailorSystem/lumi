import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';

import 'features/home/home_screen.dart';
import 'core/providers/theme_provider.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();

  // 🔥 Supabase DEBE inicializarse ANTES de usar cualquier servicio
  await Supabase.initialize(
    url: 'https://poxheykxpublcwwodzpz.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBveGhleWt4cHVibGN3d29kenB6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjI3NzE4MjcsImV4cCI6MjA3ODM0NzgyN30.DZ2L7TxLWCPW65KNk4cHWol3vtipbladCG28D3oPros',
  );

  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  const initSettings = InitializationSettings(android: androidInit);
  await flutterLocalNotificationsPlugin.initialize(initSettings);

  final themeProvider_instance = ThemeProvider();
  await themeProvider_instance.initialize();

  runApp(
    ChangeNotifierProvider.value(
      value: themeProvider_instance,
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Escuchar cambios en el ThemeProvider
    final themeProvider = Provider.of<ThemeProvider>(context);

    // lib/main.dart (Fragmento corregido dentro de MyApp)

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Lumi',
      theme: ThemeData(
          brightness: themeProvider.isDarkMode ? Brightness.dark : Brightness.light,

          scaffoldBackgroundColor: themeProvider.backgroundColor,

          colorScheme: ColorScheme(
            brightness: themeProvider.isDarkMode ? Brightness.dark : Brightness.light,
            primary: themeProvider.primaryColor,
            onPrimary: Colors.white,
            secondary: themeProvider.appBarColor,
            onSecondary: themeProvider.textColor,
            surface: themeProvider.cardColor,
            onSurface: themeProvider.textColor,
            background: themeProvider.backgroundColor,
            onBackground: themeProvider.textColor,
            error: Colors.red,
            onError: Colors.white,
          ),

          appBarTheme: AppBarTheme(
            backgroundColor: themeProvider.appBarColor,
            foregroundColor: themeProvider.textColor,
          )
      ),
      home: const HomeScreen(),
    );
  }
}
