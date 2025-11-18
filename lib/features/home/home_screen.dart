// lib/features/home/home_screen.dart

import 'dart:convert';
import 'dart:math' as math;
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'crear_sesion_screen.dart';
import 'start_screen.dart';
import 'sesion_rapida.dart';
import '../settings/settings_screen.dart';
import '../stats/stats_screen.dart';
import '../../widgets/lumi_char.dart';

// Importa el modelo Usuario correctamente
import '../../core/models/usuario.dart';
import '../../core/models/sesion.dart';
import '../../core/services/sesion_service.dart';
import '../../core/services/usuario_service.dart';
import 'firstre_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}


class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  static const _bg = Color(0xFFD9CBBE);
  static const _bar = Color(0xFFB49D87);
  static const _primary = Color(0xFF2C4459);
  static const _session = Color(0xFF80A6B3);

  List<Sesion> _completedSessions = [];
  late final AnimationController _pulse;

  int? _userId;
  String _userName = 'Usuario';

  final _quotes = <String>[
    'Un bloque a la vez.',
    '25 minutos. Todo tuyo.',
    'Pequeños pasos, grandes logros.',
    'Respira. Enfócate. Brilla.',
    'Hoy mejor que ayer.',
  ];
  bool _showQuote = false;
  String _quote = '';
  Timer? _quoteTimer;

  // 🔥 Nuevo estado para el filtro
  String _selectedFilter = "Más reciente";

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _loadUserData();          // 🔥 ESTE SÍ carga _userId y user_name
    _loadCompletedSessions();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkFirstTime();
    });
  }


  @override
  void dispose() {
    _pulse.dispose();
    _quoteTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt("user_id");

    if (userId == null) return;

    // 🔥 Leer desde Supabase (fuente real)
    final nombre = await UsuarioService.obtenerNombre(userId);

    if (nombre != null) {
      _userName = nombre;
      await prefs.setString("user_name", nombre);
    } else {
      // fallback
      _userName = prefs.getString("user_name") ?? "Nay";
    }

    if (mounted) setState(() {});
  }
  
  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    _userId = prefs.getInt('user_id');   // 🔥 carga el id real desde Supabase login

    if (_userId == null) {
      print("❌ No hay user_id en SharedPreferences");
      return;
    }

    final nombre = await UsuarioService.obtenerNombre(_userId!);

    if (nombre != null) {
      _userName = nombre;
      prefs.setString('user_name', nombre);
    } else {
      _userName = prefs.getString('user_name') ?? 'Usuario';
    }

    if (mounted) setState(() {});
  }



  Future<void> _loadCompletedSessions() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt("user_id");

    if (userId == null) return;

    final sesiones = await SesionService.obtenerSesionesProgramadas(userId);

    if (!mounted) return;

    setState(() {
      _completedSessions = sesiones;
      _applyFilter(); // 🔥 aplicar filtro inicial
    });
  }

  // ---------------------- FILTRO ----------------------
  void _applyFilter() {
    setState(() {
      if (_selectedFilter == "Más reciente") {
        _completedSessions.sort((a, b) => b.fecha.compareTo(a.fecha));
      } else if (_selectedFilter == "Más antiguo") {
        _completedSessions.sort((a, b) => a.fecha.compareTo(b.fecha));
      } else if (_selectedFilter == "A-Z") {
        _completedSessions.sort(
            (a, b) => a.nombreSesion.toLowerCase().compareTo(
                  b.nombreSesion.toLowerCase(),
                ));
      } else if (_selectedFilter == "Z-A") {
        _completedSessions.sort(
            (a, b) => b.nombreSesion.toLowerCase().compareTo(
                  a.nombreSesion.toLowerCase(),
                ));
      }
    });
  }

  void _onLumiTap() {
    _quoteTimer?.cancel();
    _quote = (_quotes..shuffle()).first;
    setState(() => _showQuote = true);
    _quoteTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _showQuote = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final maxBody = math.min(w * 0.92, 720.0);

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 16,
        title: Text(
          'Hola $_userName',
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: _primary,
          ),
        ),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart, color: _primary),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const StatsScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () async {
            if (_userId == null) {
              print("❌ Usuario NULL al abrir ajustes");
              return;
            }

            final refresh = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SettingsScreen(idUsuario: _userId!),
              ),
            );
              if (refresh == true) _loadUserData();
            },
          )

        ],
      ),
      extendBodyBehindAppBar: true,

      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              children: [
                _headerHero(),

                Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxBody),
                    child: Column(
                      children: [
                        const SizedBox(height: 4),

                        // ------------------------ BOTONES ------------------------
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            children: [
                              Expanded(
                                child: _pillButton(
                                  icon: Icons.flash_on,
                                  label: 'Sesión rápida',
                                  onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (_) =>
                                              const SesionRapidaScreen())),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _pillButton(
                                  icon: Icons.add_task,
                                  label: 'Nueva sesión',
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            const CrearNuevaSesionScreen()),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // ------------------- TÍTULO + FILTRO -------------------
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // TITULO
                              Text(
                                "Sesiones programadas",
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),

                              const SizedBox(height: 6),

                              // BOTÓN FILTRO – AHORA ABAJO DEL TEXTO
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.teal.shade100.withOpacity(0.4),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: const [
                                      Icon(Icons.filter_alt, size: 18, color: Colors.teal),
                                      SizedBox(width: 6),
                                      Text(
                                        "Filtrar",
                                        style: TextStyle(
                                          color: Colors.teal,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),
                            ],
                          )
                        ),

                        const SizedBox(height: 8),

                        // ---------------------- LISTA ----------------------
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: _completedSessions.isEmpty
                              ? _emptyState()
                              : Column(
                                  children: _completedSessions
                                      .take(50)
                                      .map((s) => _sessionTile(context, s))
                                      .toList(),
                                ),
                        ),

                        const SizedBox(height: 120),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------- HEADER -------------------------
  Widget _headerHero() {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(50),
        bottomRight: Radius.circular(50),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 90, 16, 30),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFB6C9D6), // mar
              Color(0xFFE6DACA), // arena clara
              Color(0xFFD9CBBE), // arena suave
            ],
            stops: [0.0, 0.35, 1.0],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Color(0xFFC6905B).withOpacity(0.28),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LumiChar(
                        size: 74,
                        onMessage: (msg) {
                          setState(() {
                            _quote = msg;
                            _showQuote = true;
                          });
                        },
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Material(
                          color: Colors.transparent,
                          child: _motivationalBubble(),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  const Text(
                    "Me llamo Lumi ✨",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --------------------- BURBUJA DE FRASE ------------------------
  Widget _motivationalBubble() {
    if (!_showQuote) return const SizedBox.shrink();

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 250),
      opacity: 1,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        constraints: const BoxConstraints(maxWidth: 210),
        decoration: BoxDecoration(
          color: const Color(0xFFC6905B).withOpacity(0.15),
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 6,
              offset: Offset(0, 2),
            )
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                _quote,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: () => setState(() => _showQuote = false),
              child: const Icon(Icons.close, size: 18, color: Colors.teal),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------ BOTÓN PASTILLA ------------------------
  Widget _pillButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFF6EFE9),
          border: Border.all(color: Colors.black26),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: _primary),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 14),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------- ITEM DE SESIÓN -------------------------
  Widget _sessionTile(BuildContext context, Sesion session) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.blueGrey.withOpacity(0.25),
          child:
              const Icon(Icons.access_time, color: Colors.black54, size: 22),
        ),
        title: Text(
          session.nombreSesion,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          session.fecha.toString().substring(0, 16),
          style: const TextStyle(color: Colors.black54),
        ),
        trailing: const Icon(Icons.chevron_right),

        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => StartScreen(idSesion: session.idSesion),
          ),
        ),
      ),
    );
  }

  // --------------------------- SIN SESIONES ---------------------------
  Widget _emptyState() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black12),
      ),
      child: Row(
        children: const [
          Icon(Icons.hourglass_empty, color: _primary),
          SizedBox(width: 10),
          Expanded(
            child: Text('Aún no hay sesiones. Crea tu primera sesión para comenzar.'),
          ),
        ],
      ),
    );
  }

  // ----------------- PRIMERA VEZ --------------------
  Future<void> _checkFirstTime() async {

    final prefs = await SharedPreferences.getInstance();
    final userName = prefs.getString("user_name");

    if (userName == null || userName.trim().isEmpty) {
      Future.microtask(() async {
        final nuevoUsuario = await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const FirstRegisterScreen()),
        );

        if (nuevoUsuario is Usuario) {
          setState(() {
            _userName = nuevoUsuario.nombre;
          });

          final prefs = await SharedPreferences.getInstance();
          await prefs.setString("user_name", nuevoUsuario.nombre);
          await prefs.setInt("user_id", nuevoUsuario.idUsuario);
        }
      });
    }
  }
}
