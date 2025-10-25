import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'crear_sesion_screen.dart';
import 'start_screen.dart';
import 'sesion_rapida.dart';
import '../settings/settings_screen.dart';
import '../stats/stats_screen.dart';
import 'dart:convert';
import '../../widgets/lumi_char.dart';  // Update this import path

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Map<String, dynamic>> _completedSessions = [];

  @override
  void initState() {
    super.initState();
    _loadCompletedSessions();
  }

  Future<void> _loadCompletedSessions() async {
    final prefs = await SharedPreferences.getInstance();
    final sessionsJson = prefs.getStringList('completed_sessions') ?? [];
    setState(() {
      _completedSessions = sessionsJson
          .map((s) => Map<String, dynamic>.from(json.decode(s)))
          .toList();
    });
  }

  Future<void> saveCompletedSession(Map<String, dynamic> session) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _completedSessions.add(session);
    });
    final sessionsJson = _completedSessions
        .map((s) => json.encode(s))
        .toList();
    await prefs.setStringList('completed_sessions', sessionsJson);
  }

  static const _bg = Color(0xFFD9CBBE);
  static const _bar = Color(0xFFB49D87);
  static const _primary = Color(0xFF2C4459);
  static const _session = Color(0xFF80A6B3);

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final buttonWidth = screenSize.width * 0.8; // 80% del ancho de pantalla

    return Scaffold(
      backgroundColor: _bg,
      endDrawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: _bar),
              child: Text('Menú', style: TextStyle(fontSize: 20)),
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Configuración'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
              },
            ),
          ],
        ),
      ),
      appBar: AppBar(
        backgroundColor: _bar,
        elevation: 0,
        centerTitle: false,
        title: FutureBuilder<SharedPreferences>(
          future: SharedPreferences.getInstance(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Text('Hola\nMe llamo Lumi');
            }
            final userName = snapshot.data!.getString('user_name') ?? 'Naye';
            return Text(
              'Hola $userName\nMe llamo Lumi',
              style: const TextStyle(height: 1.2),
            );
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.bar_chart),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const StatsScreen()),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 120), // Ajuste para Lumi
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: 600, // Máximo ancho para tablets/desktop
                    ),
                    child: Column(
                      children: [
                        // Botón principal
                        SizedBox(
                          width: buttonWidth.clamp(240.0, 400.0), // Min 240, max 400
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const CrearNuevaSesionScreen(),
                                ),
                              );
                            },
                            icon: const Icon(Icons.add_circle_outline),
                            label: const Text('Nueva Sesión de Estudio'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 14,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(25),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // Botón sesión rápida
                        SizedBox(
                          width: (buttonWidth * 0.85).clamp(200.0, 320.0), // Más pequeño que el principal
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const SesionRapidaScreen(),
                                ),
                              );
                            },
                            icon: const Icon(Icons.add_circle_outline, size: 20),
                            label: const Text('Sesión Rápida'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(22),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Lista de sesiones
                        ..._completedSessions.map((session) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: SizedBox(
                            width: (buttonWidth * 0.7).clamp(180.0, 280.0),
                            height: 44,
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => StartScreen(session: session),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _session,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                              child: Text(session['titulo'] as String),
                            ),
                          ),
                        )).toList(),
                        
                        const SizedBox(height: 24),
                        
                        // Botón tres puntos
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: _session,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.more_vert),
                            color: Colors.white,
                            onPressed: () {
                              showModalBottomSheet(
                                context: context,
                                builder: (_) => SafeArea(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: const [
                                      ListTile(
                                        leading: Icon(Icons.history),
                                        title: Text('Historial'),
                                      ),
                                      ListTile(
                                        leading: Icon(Icons.help_outline),
                                        title: Text('Ayuda'),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          
          // Lumi fijo abajo-izquierda
          Positioned(
            left: 16,
            bottom: 16,
            child: LumiChar(
              size: 84,
              onTap: () {
                // Additional custom behavior if needed
              },
            ),
          ),
        ],
      ),
    );
  }
}
