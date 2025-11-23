// lib/features/home/home_screen.dart

import 'dart:convert';
import 'dart:math' as math;
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';

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
import '../../core/services/stat_service.dart';
import '../../core/providers/theme_provider.dart';
import '../../core/services/mood_service.dart';
import 'firstre_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  static const _bg = Color(0xFFD9CBBE);
  static const _bar = Color(0xFFB49D87);
  static const _primary = Color(0xFF2C4459);
  static const _session = Color(0xFF80A6B3);

  DateTime? _inicio;
  Timer? _tiempoUsoTimer;
  int _segundosAcumulados = 0;
  Timer? _verificadorSesiones; // ✅ Timer para verificar sesiones incompletas

  List<Sesion> _completedSessions = [];
  late final AnimationController _pulse;

  int? _userId;
  String _userName = 'Usuario';
  int _estadoAnimo = 2; // Estado de ánimo por defecto (neutral)

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
      lowerBound: 0.8, // ✅ Rango más pequeño
      upperBound: 1.0,
    )..repeat(reverse: true);

    _loadUserData();
    _loadCompletedSessions();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkFirstTime();
    });

    // ✅ AGREGAR: Verificador automático cada 1 minuto
    _verificadorSesiones = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _marcarSesionesIncompletas().then((_) => _loadCompletedSessions()),
    );

    // INICIO DE MEDICIÓN DE TIEMPO
    WidgetsBinding.instance.addObserver(this);
    _inicio = DateTime.now();
    _tiempoUsoTimer = Timer.periodic(const Duration(minutes: 1), _enviarTiempoUso);
  }

  @override
  void dispose() {
    _pulse.dispose();
    _quoteTimer?.cancel();
    _tiempoUsoTimer?.cancel();
    _verificadorSesiones?.cancel(); // ✅ Cancelar el verificador

    WidgetsBinding.instance.removeObserver(this);
    _enviarTiempoUsoFinal(); // Envía el tiempo pendiente al cerrar

    super.dispose();
  }

  void _enviarTiempoUso(Timer timer) async {
    if (_inicio != null && _userId != null) {
      final ahora = DateTime.now();
      final diff = ahora.difference(_inicio!).inSeconds;
      _segundosAcumulados += diff;
      _inicio = ahora;
      if (_userId != null && _segundosAcumulados > 0) {
        await StatService.incrementarTiempoUso(_userId!, _segundosAcumulados);
        _segundosAcumulados = 0;
      }
    }
  }

  void _enviarTiempoUsoFinal() async {
    if (_inicio != null && _userId != null) {
      final ahora = DateTime.now();
      final diff = ahora.difference(_inicio!).inSeconds;
      _segundosAcumulados += diff;
      if (_segundosAcumulados > 0) {
        try {
          await Supabase.instance.client.rpc('increment_app_time', params: {
            'p_id_usuario': _userId,
            'p_seconds': _segundosAcumulados,
          });
        } catch (e) {
          print('Error final supabase: $e');
        }
        _segundosAcumulados = 0;
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      _enviarTiempoUsoFinal();
    } else if (state == AppLifecycleState.resumed) {
      // ✅ AGREGAR: Recargar datos al volver
      print('📱 App resumida, recargando datos...');
      _loadCompletedSessions();
    }
  }


  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    _userId = prefs.getInt('user_id');

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

    // ✅ AGREGAR: Calcular y obtener estado de ánimo
    _estadoAnimo = await MoodService.calcularYActualizarEstadoAnimo(_userId!);
    print('😊 Estado de ánimo de Lumi: $_estadoAnimo');

    if (mounted) setState(() {});
  }


  /// Marca las sesiones pasadas como incompletas
  Future<void> _marcarSesionesIncompletas() async {
    if (_userId == null) return; // ✅ CORREGIDO: usar _userId con guion bajo
    
    try {
      final ahora = DateTime.now();
      
      // Obtener sesiones programadas que ya pasaron su hora
      final response = await Supabase.instance.client
          .from('sesiones')
          .select()
          .eq('id_usuario', _userId!) // ✅ CORREGIDO
          .eq('estado', 'programada')
          .lt('fecha', ahora.toIso8601String()); // Sesiones cuya fecha ya pasó
      
      final sesionesPasadas = (response as List)
          .map((json) => Sesion.fromMap(json))
          .toList();
      
      print('🔍 Sesiones pasadas encontradas: ${sesionesPasadas.length}');
      
      // Actualizar cada sesión pasada a "incompleta"
      for (final sesion in sesionesPasadas) {
        await SesionService.actualizarEstadoSesion(
          sesion.idSesion!,
          'incompleta',
        );
        print('⚠️ Sesión ${sesion.idSesion} marcada como incompleta');
      }
      
      if (sesionesPasadas.isNotEmpty) {
        print('✅ ${sesionesPasadas.length} sesiones marcadas como incompletas');
      }
    } catch (e) {
      print('❌ Error marcando sesiones incompletas: $e');
    }
  }

  Future<void> _loadCompletedSessions() async {
    print('🔄 Cargando sesiones programadas...');
    
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id');
    
    if (userId == null) {
      print('❌ No hay user_id en SharedPreferences');
      return;
    }

    print('👤 UserID: $userId');

    try {
      // ✅ PRIMERO: Marcar sesiones pasadas como incompletas
      await _marcarSesionesIncompletas();
      
      // ✅ SEGUNDO: Cargar solo sesiones programadas (presente y futuras)
      final ahora = DateTime.now();
      
      print('🌐 Cargando desde Supabase...');
      
      final response = await Supabase.instance.client
          .from('sesiones')
          .select()
          .eq('id_usuario', userId)
          .eq('estado', 'programada')
          .gte('fecha', ahora.toIso8601String()) // ✅ Solo sesiones futuras
          .order('fecha', ascending: true); // Ordenar por fecha ascendente
      
      print('📦 Respuesta de Supabase: ${response.length} sesiones programadas');

      final sesiones = (response as List)
          .map((json) => Sesion.fromMap(json))
          .toList();

      print('✅ Sesiones programadas parseadas: ${sesiones.length}');

      if (!mounted) return;

      setState(() {
        _completedSessions = sesiones;
      });

      print('📊 Sesiones mostradas en Home: ${_completedSessions.length}');
    } catch (e) {
      print('❌ Error cargando sesiones: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar sesiones: $e'),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'REINTENTAR',
              textColor: Colors.white,
              onPressed: _loadCompletedSessions,
            ),
          ),
        );
      }
    }
  }

  // ✅ NUEVO MÉTODO: Recargar sesiones con pull-to-refresh
  Future<void> _refreshSessions() async {
    print('🔃 Recargando sesiones (pull-to-refresh)...');
    await _loadCompletedSessions();
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
    final themeProvider = Provider.of<ThemeProvider>(context);
    final theme = Theme.of(context);
    final w = MediaQuery.of(context).size.width;
    final maxBody = math.min(w * 0.92, 720.0);

    return Scaffold(
      backgroundColor: themeProvider.backgroundColor,
      appBar: AppBar(
        elevation: 0,
        titleSpacing: 16,
        centerTitle: false,
        backgroundColor: Colors.transparent,
        automaticallyImplyLeading: false,
        title: Text(
          'Hola $_userName',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: themeProvider.primaryColor,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.bar_chart, color: themeProvider.primaryColor),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const StatsScreen())),
          ),
          IconButton(
            icon: Icon(Icons.settings, color: themeProvider.primaryColor),
            onPressed: () async {
              if (_userId == null) {
                print("❌ Usuario NULL al abrir ajustes");
                
                // ✅ INTENTAR RECUPERAR EL USER_ID
                final prefs = await SharedPreferences.getInstance();
                _userId = prefs.getInt('user_id');
                
                if (_userId == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Error: No se pudo cargar el usuario. Reinicia la app.'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
              }
              
              final refresh = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SettingsScreen(idUsuario: _userId!),
                ),
              );
              
              if (refresh == true) {
                _loadUserData();
                _loadCompletedSessions();
              }
            },
          ),
        ],
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: themeProvider.isDarkMode
                  ? [
                      const Color(0xFF212C36),
                      const Color(0xFF313940),
                      themeProvider.backgroundColor,
                    ]
                  : [
                      const Color(0xFFB6C9D6),
                      const Color(0xFFE6DACA),
                      themeProvider.backgroundColor,
                    ],
              stops: const [0.0, 0.35, 1.0],
            ),
          ),
        ),
      ),

      extendBodyBehindAppBar: true,

      body: Stack(
        children: [
          // ✅ AGREGADO: RefreshIndicator para pull-to-refresh
          RefreshIndicator(
            onRefresh: _refreshSessions,
            color: themeProvider.primaryColor,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(), // ✅ Importante para que funcione el refresh
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
                                    onTap: () async {
                                      await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => const SesionRapidaScreen(),
                                        ),
                                      );
                                      // ✅ Recargar al volver
                                      _loadCompletedSessions();
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _pillButton(
                                    icon: Icons.add_task,
                                    label: 'Nueva sesión',
                                    onTap: () async {
                                      await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => const CrearNuevaSesionScreen(),
                                        ),
                                      );
                                      // ✅ Recargar al volver
                                      _loadCompletedSessions();
                                    },
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
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      "Sesiones programadas",
                                      style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(context).textTheme.bodyLarge?.color,
                                      ),
                                    ),
                                    // ✅ Botón de recarga manual
                                    IconButton(
                                      icon: Icon(
                                        Icons.refresh,
                                        color: themeProvider.primaryColor,
                                      ),
                                      onPressed: _refreshSessions,
                                      tooltip: 'Recargar sesiones',
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 6),

                                // BOTÓN FILTRO
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: themeProvider.primaryColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<String>(
                                        value: _selectedFilter,
                                        icon: Icon(Icons.filter_alt, color: themeProvider.primaryColor),
                                        dropdownColor: themeProvider.cardColor,
                                        style: TextStyle(
                                          color: themeProvider.textColor,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        items: [
                                          "Más reciente",
                                          "Más antiguo",
                                          "A-Z",
                                          "Z-A"
                                        ].map((filter) {
                                          return DropdownMenuItem<String>(
                                            value: filter,
                                            child: Text(
                                              filter,
                                              style: TextStyle(
                                                color: themeProvider.primaryColor,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          );
                                        }).toList(),
                                        onChanged: (value) {
                                          setState(() {
                                            _selectedFilter = value!;
                                            _applyFilter();
                                          });
                                        },
                                      ),
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
          ),
        ],
      ),
    );
  }

  // ------------------------- HEADER -------------------------
  Widget _headerHero() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(50),
        bottomRight: Radius.circular(50),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 90, 16, 30),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [
                    const Color(0xFF212C36),
                    const Color(0xFF313940),
                    themeProvider.backgroundColor,
                  ]
                : [
                    const Color(0xFFB6C9D6),
                    const Color(0xFFE6DACA),
                    themeProvider.backgroundColor,
                  ],
            stops: const [0.0, 0.35, 1.0],
          ),
        ),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                // ✅ Color adaptativo según el modo
                color: isDark
                    ? Colors.white.withOpacity(0.08) // Más sutil en modo oscuro
                    : const Color(0xFFC6905B).withOpacity(0.20), // Más suave en modo claro
                borderRadius: BorderRadius.circular(22),
                // ✅ Agregar borde sutil
                border: Border.all(
                  color: isDark
                      ? Colors.white.withOpacity(0.1)
                      : Colors.black.withOpacity(0.05),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LumiChar(
                        size: 74,
                        estadoAnimo: _estadoAnimo,
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

                  // ✅ Texto con color adaptativo
                  Text(
                    "Me llamo Lumi ✨",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: isDark
                          ? Colors.white.withOpacity(0.95)
                          : Colors.white,
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
    
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final isDark = themeProvider.isDarkMode;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 250),
      opacity: 1,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        constraints: const BoxConstraints(maxWidth: 210),
        decoration: BoxDecoration(
          // ✅ Color adaptativo para la burbuja
          color: isDark
              ? Colors.white.withOpacity(0.15)
              : const Color(0xFFC6905B).withOpacity(0.25),
          borderRadius: BorderRadius.circular(16),
          // ✅ Sombra más sutil
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.3 : 0.15),
              blurRadius: 8,
              offset: const Offset(0, 3),
            )
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                _quote,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  // ✅ Color de texto adaptativo
                  color: isDark
                      ? Colors.white.withOpacity(0.95)
                      : Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: () => setState(() => _showQuote = false),
              child: Icon(
                Icons.close,
                size: 18,
                // ✅ Color del icono adaptativo
                color: isDark
                    ? themeProvider.primaryColor
                    : Colors.teal.shade700,
              ),
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
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
        decoration: BoxDecoration(
          color: themeProvider.cardColor.withOpacity(.95),
          border: Border.all(color: Colors.black26),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: themeProvider.primaryColor),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: themeProvider.primaryColor,
                ),
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
              Icon(Icons.access_time, color: Theme.of(context).textTheme.bodyLarge?.color, size: 22),
        ),
        title: Text(
          session.nombreSesion,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          session.fecha.toString().substring(0, 16),
          style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
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
