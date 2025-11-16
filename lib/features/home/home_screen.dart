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
import 'firstre_screen.dart';

class HomeScreen extends StatefulWidget {
  final Usuario? usuario; // recibe usuario opcional

  const HomeScreen({super.key, this.usuario});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  static const _bg = Color(0xFFD9CBBE);
  static const _bar = Color(0xFFB49D87);
  static const _primary = Color(0xFF2C4459);
  static const _session = Color(0xFF80A6B3);

  List<Map<String, dynamic>> _completedSessions = [];
  late final AnimationController _pulse;

  // usamos el nombre real del modelo: 'nombre'
  String _userName = "Nay";

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

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);

    _loadUser();            // carga usuario desde parámetro o SharedPreferences
    _loadCompletedSessions();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkFirstTime();   // revisar registro sólo después del primer frame
    });
  }

  @override
  void dispose() {
    _pulse.dispose();
    _quoteTimer?.cancel();
    super.dispose();
  }

  // Cargar usuario: si viene por parámetro lo usamos, sino SharedPreferences
  Future<void> _loadUser() async {
    final prefs = await SharedPreferences.getInstance();

    if (widget.usuario != null) {
      // Atención: usamos las propiedades reales del modelo Usuario
      _userName = widget.usuario!.nombre;
      await prefs.setString("user_name", _userName);
      await prefs.setInt("user_id", widget.usuario!.idUsuario);
    } else {
      _userName = prefs.getString("user_name") ?? "Nay";
    }

    if (mounted) setState(() {});
  }

  Future<void> _loadCompletedSessions() async {
    final prefs = await SharedPreferences.getInstance();
    final sessionsJson = prefs.getStringList('completed_sessions') ?? [];
    if (!mounted) return;
    setState(() {
      _completedSessions = sessionsJson.map((s) => Map<String, dynamic>.from(json.decode(s))).toList();
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
    final lumiSize = w.clamp(320.0, 720.0) * 0.24; // 115–173 aprox

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bar,
        elevation: 0,
        titleSpacing: 16,
        title: Text('Hola $_userName', style: const TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          IconButton(icon: const Icon(Icons.bar_chart), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StatsScreen()))),
          IconButton(icon: const Icon(Icons.settings), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()))),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxBody),
                child: Column(
                  children: [
                    _headerHero(),
                    const SizedBox(height: 24),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Expanded(child: _pillButton(icon: Icons.flash_on, label: 'Sesión rápida', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SesionRapidaScreen())))),
                          const SizedBox(width: 12),
                          Expanded(child: _pillButton(icon: Icons.add_task, label: 'Nueva sesión', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CrearNuevaSesionScreen())))),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Recientes', style: TextStyle(color: Colors.black.withOpacity(0.7), fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _completedSessions.isEmpty ? _emptyState() : Column(children: _completedSessions.take(8).map((s) => _sessionTile(context, s)).toList()),
                    ),
                    const SizedBox(height: 120), // espacio para que el Lumi flotante no tape contenido al final
                  ],
                ),
              ),
            ),
          ),

          // ------- Lumi flotante inferior izquierda -------
          Positioned(
            left: 50,
            bottom: 320 + MediaQuery.of(context).viewPadding.bottom,
            child: GestureDetector(
              onTap: _onLumiTap,
              child: AnimatedBuilder(
                animation: _pulse,
                builder: (_, __) {
                  final glow = 16 + 8 * _pulse.value;
                  return Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: _primary.withOpacity(0.30), blurRadius: glow, spreadRadius: glow * 0.22)],
                    ),
                    child: LumiChar(size: lumiSize),
                  );
                },
              ),
            ),
          ),

          // Burbuja motivacional junto a Lumi
          if (_showQuote)
            Positioned(
              left: 16 + lumiSize * 0.66,
              bottom: 16 + MediaQuery.of(context).viewPadding.bottom + lumiSize * 0.58,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 180),
                opacity: 1,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 260),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.auto_awesome, color: _primary, size: 18),
                      const SizedBox(width: 8),
                      Flexible(child: Text(_quote, style: const TextStyle(fontWeight: FontWeight.w600),overflow: TextOverflow.ellipsis,maxLines: 1,)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _headerHero() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Container(
        height: 220,
        decoration: BoxDecoration(
          gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [_bar, Color(0xFFCBB6A4)]),
          borderRadius: BorderRadius.circular(28),
        ),
        child: const Padding(
          padding: EdgeInsets.fromLTRB(24, 24, 24, 24),
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 260,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Me llamo Lumi', style: TextStyle(fontSize: 20, color: _primary, fontWeight: FontWeight.w700)),
                  SizedBox(height: 6),
                  Text('Tu compañero para estudiar mejor', style: TextStyle(color: _primary)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _pillButton({required IconData icon, required String label, required VoidCallback onTap}) {
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
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sessionTile(BuildContext context, Map<String, dynamic> session) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _session.withOpacity(0.18),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _session.withOpacity(0.35)),
      ),
      child: ListTile(
        leading: CircleAvatar(backgroundColor: _session, child: const Icon(Icons.check, color: Colors.white)),
        title: Text(session['titulo'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text((session['fecha'] ?? '').toString().replaceAll('T', ' ').substring(0, 16), style: const TextStyle(color: Colors.black54)),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => StartScreen(session: session))),
      ),
    );
  }

  Widget _emptyState() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.75),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black12),
      ),
      child: Row(
        children: const [
          Icon(Icons.hourglass_empty, color: _primary),
          SizedBox(width: 10),
          Expanded(child: Text('Aún no hay sesiones. Crea tu primera sesión para comenzar.')),
        ],
      ),
    );
  }

  // ahora solo se abre FirstRegisterScreen si NO hay user
  Future<void> _checkFirstTime() async {
    if (widget.usuario != null) return; // Ya hay usuario, no mostrar registro

    final prefs = await SharedPreferences.getInstance();
    final userName = prefs.getString("user_name");

    if (userName == null || userName.trim().isEmpty) {
      Future.microtask(() async {
        // abrimos la pantalla de registro y esperamos el resultado
        final nuevoUsuario = await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const FirstRegisterScreen()),
        );

        // si FirstRegisterScreen devolvió un Usuario, lo usamos
        if (nuevoUsuario is Usuario) {
          setState(() {
            _userName = nuevoUsuario.nombre;
          });

          // guardamos en prefs por si acaso
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString("user_name", nuevoUsuario.nombre);
          await prefs.setInt("user_id", nuevoUsuario.idUsuario);
        }
      });
    }
  }
}
