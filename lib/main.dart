import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';

import 'features/home/home_screen.dart';
import 'features/home/splash_screen.dart';
import 'core/providers/theme_provider.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();

  await Supabase.initialize(
    url: 'https://poxheykxpublcwwodzpz.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBveGhleWt4cHVibGN3d29kenB6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjI3NzE4MjcsImV4cCI6MjA3ODM0NzgyN30.DZ2L7TxLWCPW65KNk4cHWol3vtipbladCG28D3oPros',
  );

  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  const initSettings = InitializationSettings(android: androidInit);
  await flutterLocalNotificationsPlugin.initialize(initSettings);

  final themeProvider = ThemeProvider();
  await themeProvider.initialize();

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
          background: ThemeProvider.lightBg,
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
        cardColor: Color(0xFF232323),
        colorScheme: const ColorScheme.dark(
          primary: ThemeProvider.darkPrimary,
          secondary: ThemeProvider.darkBar,
          background: ThemeProvider.darkBg,
        ),
      ),
      home: const SplashScreen(),
    );
  }
}