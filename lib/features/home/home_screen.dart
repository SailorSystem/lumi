// lib/features/home/home_screen.dart

import 'dart:convert';
import 'dart:math' as math;
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import '../../core/services/connectivity_service.dart';

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
import '../../core/services/notification_service.dart';
import '../../core/services/usage_tracker.dart';
import '../../core/services/stats_usage_service.dart';
import 'crear_sesion_screen.dart';



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
    _iniciarTrackingTiempo();


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
    UsageTracker.detener();
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
    super.didChangeAppLifecycleState(state);
    
    if (state == AppLifecycleState.paused) {
      // App minimizada
      UsageTracker.detener();
      print('📱 App pausada, tracking detenido');
    } else if (state == AppLifecycleState.resumed) {
      // App restaurada
      _iniciarTrackingTiempo();
      print('📱 App resumida, tracking reiniciado');
    }
  }

  Future<void> _iniciarTrackingTiempo() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id');
    
    if (userId != null) {
      UsageTracker.iniciar(userId);
      print('✅ Tracking iniciado automáticamente para usuario $userId');
    } else {
      print('⚠️ No se pudo iniciar tracking: userId es null');
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
    if (_userId == null) return;

    try {
      final ahora = DateTime.now();

      // Obtener SOLO sesiones programadas (no rápidas) que ya pasaron
      final response = await Supabase.instance.client
          .from('sesiones')
          .select()
          .eq('id_usuario', _userId!)
          .eq('estado', 'programada')
          .eq('es_rapida', false) // ✅ Ignorar sesiones rápidas
          .lt('fecha', ahora.toIso8601String());

      final sesionesPasadas = (response as List)
          .map((json) => Sesion.fromMap(json))
          .toList();

      print('⏰ Sesiones programadas pasadas: ${sesionesPasadas.length}');

      for (final sesion in sesionesPasadas) {
        await SesionService.actualizarEstadoSesion(
          sesion.idSesion!,
          'incompleta',
        );
        print('⚠️ Sesión ${sesion.idSesion} marcada como incompleta');
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
      // ✅ Verificar conectividad primero
      final hayConexion = await ConnectivityService.verificarConexion();
      
      if (!hayConexion) {
        print('❌ Sin conexión a internet');
        if (mounted) {
          setState(() {
            _completedSessions = [];
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('⚠️ Sin conexión. Verifica tu red.'),
              backgroundColor: Colors.orange,
              action: SnackBarAction(
                label: 'REINTENTAR',
                textColor: Colors.white,
                onPressed: _loadCompletedSessions,
              ),
            ),
          );
        }
        return;
      }
      
      // ✅ Marcar sesiones pasadas como incompletas
      await _marcarSesionesIncompletas();
      
      // ✅ Cargar sesiones con retry
      print('🌐 Cargando desde Supabase...');
      
      final ahora = DateTime.now();
      
      final response = await ConnectivityService.ejecutarConReintento(
        operacion: () => Supabase.instance.client
            .from('sesiones')
            .select()
            .eq('id_usuario', userId)
            .eq('estado', 'programada')
            .gte('fecha', ahora.toIso8601String())
            .order('fecha', ascending: true),
        intentosMaximos: 3,
      );
      
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
        setState(() {
          _completedSessions = [];
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar sesiones: ${e.toString().substring(0, 50)}...'),
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

  Future<void> _eliminarSesion(Sesion sesion) async {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: themeProvider.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          '¿Eliminar sesión?',
          style: TextStyle(
            color: themeProvider.primaryColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          '¿Estás seguro de que quieres eliminar "${sesion.nombreSesion}"?\n\nEsta acción no se puede deshacer.',
          style: TextStyle(color: themeProvider.primaryColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar', style: TextStyle(color: themeProvider.primaryColor)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    try {
      print('🗑️ Eliminando sesión ${sesion.idSesion}...');

      // 1. Cancelar notificaciones
      await NotificationService.cancelarNotificacionesSesion(sesion.idSesion!);
      print('✅ Notificaciones canceladas');

      // 2. Eliminar de BD
      await SesionService.eliminarSesion(sesion.idSesion!);
      print('✅ Sesión eliminada de BD');

      // 3. Recargar
      await _loadCompletedSessions();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sesión "${sesion.nombreSesion}" eliminada'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('❌ Error eliminando sesión: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  final _formKeyEdit = GlobalKey<FormState>();

  Future<void> _editarSesionModal(Sesion sesion) async {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);

    final nombreCtrl = TextEditingController(text: sesion.nombreSesion);
    DateTime selectedDate = sesion.fecha;
    TimeOfDay selectedTime = TimeOfDay.fromDateTime(sesion.fecha);

    bool errorHora = false; // ✅ estado local de error en hora

    final editado = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            // helper local para validar fecha/hora (mínimo 5 min en el futuro)
            bool fechaHoraValida() {
              final nuevaFecha = DateTime(
                selectedDate.year,
                selectedDate.month,
                selectedDate.day,
                selectedTime.hour,
                selectedTime.minute,
              );
              final diff = nuevaFecha.difference(DateTime.now());
              return diff.inMinutes >= 5;
            }

            return AlertDialog(
              backgroundColor: themeProvider.cardColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Row(
                children: [
                  Icon(Icons.edit, color: themeProvider.primaryColor),
                  const SizedBox(width: 12),
                  Text(
                    'Editar Sesión',
                    style: TextStyle(
                      color: themeProvider.primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Form(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Advertencia si la sesión original ya pasó
                      if (sesion.fecha.isBefore(DateTime.now()))
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.1),
                            border: Border.all(
                              color: Colors.orange,
                              width: 1.5,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.warning,
                                  color: Colors.orange, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Esta sesión ya pasó. Actualiza la fecha.',
                                  style: TextStyle(
                                    color: Colors.orange.shade800,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Campo nombre con validator
                      TextFormField(
                        controller: nombreCtrl,
                        style: TextStyle(color: themeProvider.textColor),
                        maxLength: 50,
                        decoration: InputDecoration(
                          labelText: 'Nombre de la sesión *',
                          labelStyle:
                              TextStyle(color: themeProvider.primaryColor),
                          hintText: 'Ej: Estudiar Matemáticas',
                          hintStyle: TextStyle(
                            color: themeProvider.textColor.withOpacity(0.5),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color:
                                  themeProvider.primaryColor.withOpacity(0.3),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: themeProvider.primaryColor,
                              width: 2,
                            ),
                          ),
                        ),
                        validator: (value) {
                          final text = value?.trim() ?? '';
                          if (text.isEmpty) {
                            return 'El nombre no puede estar vacío';
                          }
                          if (text.length > 50) {
                            return 'Máximo 50 caracteres';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 16),

                      // Selector de fecha (sin error visual porque no se permiten fechas pasadas)
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color:
                                themeProvider.primaryColor.withOpacity(0.3),
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          leading: Icon(Icons.calendar_today,
                              color: themeProvider.primaryColor),
                          title: Text(
                            'Fecha *',
                            style: TextStyle(
                              color: themeProvider.primaryColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                            style: TextStyle(
                              color: themeProvider.textColor,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          trailing: Icon(Icons.edit,
                              color: themeProvider.primaryColor, size: 20),
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: selectedDate.isAfter(DateTime.now())
                                  ? selectedDate
                                  : DateTime.now(),
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now()
                                  .add(const Duration(days: 365)),
                              builder: (context, child) {
                                return Theme(
                                  data: Theme.of(context).copyWith(
                                    colorScheme: ColorScheme.light(
                                      primary: themeProvider.primaryColor,
                                    ),
                                  ),
                                  child: child!,
                                );
                              },
                            );
                            if (picked != null) {
                              setState(() {
                                selectedDate = picked;
                                // recalcular error de hora completo
                                errorHora = !fechaHoraValida();
                              });
                            }
                          },
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Selector de hora con error visual
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: errorHora
                                ? Colors.redAccent
                                : themeProvider.primaryColor
                                    .withOpacity(0.3),
                            width: errorHora ? 2 : 1,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          leading: Icon(
                            Icons.access_time,
                            color: errorHora
                                ? Colors.redAccent
                                : themeProvider.primaryColor,
                          ),
                          title: Text(
                            'Hora *',
                            style: TextStyle(
                              color: errorHora
                                  ? Colors.redAccent
                                  : themeProvider.primaryColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}',
                                style: TextStyle(
                                  color: themeProvider.textColor,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (errorHora)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.redAccent.withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      'Debes elegir una hora al menos 5 min en el futuro',
                                      style: TextStyle(
                                        color: Colors.redAccent.withOpacity(0.9),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          trailing: Icon(Icons.edit,
                              color: themeProvider.primaryColor, size: 20),
                          onTap: () async {
                            final picked = await showTimePicker(
                              context: context,
                              initialTime: selectedTime,
                              builder: (context, child) {
                                return Theme(
                                  data: Theme.of(context).copyWith(
                                    colorScheme: ColorScheme.light(
                                      primary: themeProvider.primaryColor,
                                    ),
                                  ),
                                  child: child!,
                                );
                              },
                            );
                            if (picked != null) {
                              setState(() {
                                selectedTime = picked;
                                errorHora = !fechaHoraValida();
                              });
                            }
                          },
                        ),
                      ),

                      const SizedBox(height: 16),

                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(
                    'Cancelar',
                    style: TextStyle(color: themeProvider.primaryColor),
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    // Validar nombre (pinta error en el TextFormField)
                    final form = Form.of(context);
                    final okNombre = form?.validate() ?? true;

                    // Validar fecha/hora
                    final esValida = fechaHoraValida();

                    if (!okNombre || !esValida) {
                      setState(() {
                        errorHora = !esValida;
                      });
                      return;
                    }

                    // Si todo está bien → guardar cambios
                    final nuevaFecha = DateTime(
                      selectedDate.year,
                      selectedDate.month,
                      selectedDate.day,
                      selectedTime.hour,
                      selectedTime.minute,
                    );

                    try {
                      print('✏️ Actualizando sesión ${sesion.idSesion}...');

                      // 1. Cancelar notificaciones antiguas
                      await NotificationService.cancelarNotificacionesSesion(
                          sesion.idSesion!);
                      print('✅ Notificaciones antiguas canceladas');

                      // 2. Actualizar sesión
                      await SesionService.actualizarSesion(
                        sesion.idSesion!,
                        {
                          'nombre_sesion': nombreCtrl.text.trim(),
                          'fecha': nuevaFecha.toIso8601String(),
                        },
                      );
                      print('✅ Sesión actualizada en BD');

                      // 3. Re-programar notificaciones
                      await NotificationService.programarRecordatorio(
                        idSesion: sesion.idSesion!,
                        nombreSesion: nombreCtrl.text.trim(),
                        fechaSesion: nuevaFecha,
                      );
                      await NotificationService.programarNotificacionInicio(
                        idSesion: sesion.idSesion!,
                        nombreSesion: nombreCtrl.text.trim(),
                        fechaSesion: nuevaFecha,
                      );
                      print('✅ Notificaciones re-programadas');

                      Navigator.pop(context, true);
                    } catch (e) {
                      print('❌ Error: $e');
                      if (mounted) {
                        ScaffoldMessenger.of(this.context).showSnackBar(
                          SnackBar(
                            content: Text('❌ Error al actualizar: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  child: const Text('💾 Guardar Cambios'),
                ),
              ],
            );
          },
        );
      },
    );

    if (editado == true) {
      await _loadCompletedSessions();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Sesión actualizada correctamente'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
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
          // ✅ TEMPORAL: Botón para probar notificaciones
          // ✅ Botón de prueba de notificación (con protección de crashes)
          /*IconButton(
            icon: const Icon(Icons.notifications_active, color: Colors.orange),
            tooltip: 'Probar notificación',
            onPressed: () async {
              try {
                final ahora = DateTime.now();
                final testDate = ahora.add(const Duration(seconds: 10));
                
                print('🧪 ==== PRUEBA DE NOTIFICACIÓN ====');
                print('   - Ahora: $ahora');
                print('   - Fecha test: $testDate');
                
                final exito = await NotificationService.programarNotificacionInicio(
                  idSesion: 99999,
                  nombreSesion: 'Prueba de Notificación',
                  fechaSesion: testDate,
                );
                
                if (exito) {
                  await NotificationService.listarPendientes();
                  
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('⏰ Notificación de prueba en 10 segundos'),
                        duration: Duration(seconds: 3),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } else {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('❌ Error programando notificación'),
                        duration: Duration(seconds: 3),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
                
                print('🧪 ================================');
              } catch (e, stackTrace) {
                print('❌ CRASH en botón de prueba: $e');
                print('Stack trace: $stackTrace');
                
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: ${e.toString().substring(0, 50)}'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
          ),*/

          // TEMPORAL: Botón para probar tracking
          /*IconButton(
            icon: const Icon(Icons.timer, color: Colors.blue),
            tooltip: 'Probar tracking',
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              final userId = prefs.getInt('user_id');
              
              if (userId != null) {
                final exito = await StatsUsageService.incrementarTiempoUso(userId, 10);
                
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        exito 
                          ? '✅ 10 segundos agregados' 
                          : '❌ Error al agregar tiempo'
                      ),
                      backgroundColor: exito ? Colors.green : Colors.red,
                    ),
                  );
                }
                
                // Mostrar tiempo total
                final tiempoTotal = await StatsUsageService.obtenerTiempoUso(userId);
                print('⏱️ Tiempo total: ${StatsUsageService.formatearTiempo(tiempoTotal)}');
              }
            },
          ),*/



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
                                ? emptyState(themeProvider.cardColor, themeProvider.textColor, themeProvider.primaryColor)
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
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.blueGrey.withOpacity(0.25),
          child: Icon(
            Icons.access_time,
            color: Theme.of(context).textTheme.bodyLarge?.color,
            size: 22,
          ),
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
        // ✅ AGREGAR ESTOS BOTONES
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Botón editar
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
              onPressed: () => _editarSesionModal(session),
              tooltip: 'Editar',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            const SizedBox(width: 4),
            // Botón eliminar
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red, size: 20),
              onPressed: () => _eliminarSesion(session),
              tooltip: 'Eliminar',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            const SizedBox(width: 4),
            // Flecha original
            const Icon(Icons.chevron_right),
          ],
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => StartScreen(idSesion: session.idSesion),
            ),
          );
        },
      ),
    );
  }


  // --------------------------- SIN SESIONES ---------------------------
  Widget emptyState(Color cardColor, Color textColor, Color primary) {  // ✅ AGREGAR PARÁMETROS
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor.withOpacity(0.92),  // ✅ Usar cardColor del tema
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primary.withOpacity(0.2)),  // ✅ Usar primary del tema
      ),
      child: Row(
        children: [
          Icon(
            Icons.hourglass_empty,
            color: primary,  // ✅ Usar primary del tema
            size: 28,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Aún no hay sesiones. Crea tu primera sesión para comenzar.',
              style: TextStyle(
                color: textColor,  // ✅ Usar textColor del tema
                fontSize: 14,
              ),
            ),
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
