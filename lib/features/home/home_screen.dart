// lib/features/home/home_screen.dart

import 'dart:convert';
import 'dart:math' as math;
import 'dart:async';
import 'dart:ui';
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
import '../../widgets/no_connection_dialog.dart';
import '../../widgets/sesion_time_dialog.dart';  


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
  Timer? _checkTimer;
  List<Sesion> _completedSessions = [];
  late final AnimationController _pulse;
  List<Sesion> _sesionesProgramadas = [];
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
  String _selectedFilter = "Más reciente";

  DateTime _asLocalIgnoringZone(DateTime dt) {
    // Toma los componentes (Y/M/D/H/M/S) y crea una fecha LOCAL con eso.
    return DateTime(dt.year, dt.month, dt.day, dt.hour, dt.minute, dt.second);
  }

  @override
  void initState() {
    super.initState();

    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
      lowerBound: 0.8,
      upperBound: 1.0,
    )..repeat(reverse: true);

    _loadUserData();
    _loadCompletedSessions();     // ⬅️ ESTA ES LA ÚNICA QUE DEBE CARGAR SESIONES
    _iniciarTrackingTiempo();
    _iniciarVerificacionSesiones();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkFirstTime();
    });

    _verificadorSesiones = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _marcarSesionesIncompletas().then((_) => _loadCompletedSessions()),
    );

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
    _checkTimer?.cancel();

    WidgetsBinding.instance.removeObserver(this);
    _enviarTiempoUsoFinal(); // Envía el tiempo pendiente al cerrar
    UsageTracker.detener();
    super.dispose();
  }

  Future<void> _loadSesionesProgramadas() async {
    if (_userId == null) return;

    try {
      final sesiones = await SesionService.obtenerSesionesProgramadas(_userId!);

      setState(() {
        _sesionesProgramadas = sesiones;
      });

      print("📌 Sesiones programadas cargadas: ${_sesionesProgramadas.length}");
    } catch (e) {
      print("❌ Error cargando sesiones programadas: $e");
    }
  }

  void _iniciarVerificacionSesiones() {
    _checkTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _verificarSesionesProgramadas();
    });
  }

  void _verificarSesionesProgramadas() {
    if (!mounted) return;
    if (_dialogOpen) return;

    final ahoraLocal = DateTime.now();

    for (final sesion in _sesionesProgramadas) {
      if (sesion.idSesion == null) continue;

      if (sesion.esRapida == true) continue;
      if (!["programada", "incompleta"].contains(sesion.estado)) continue;
      if (_shownSesionIds.contains(sesion.idSesion)) continue;

      // ✅ Interpretar lo guardado como HORA LOCAL (ignorando +00)
      final fechaLocalLogica = _asLocalIgnoringZone(sesion.fecha);
      final diffSec = fechaLocalLogica.difference(ahoraLocal).inSeconds;

      // (debug temporal)
      print('⏱ ahora=$ahoraLocal | fechaLocalLogica=$fechaLocalLogica | diffSec=$diffSec | id=${sesion.idSesion}');

      if (diffSec <= 60 && diffSec > 0) {
        _shownSesionIds.add(sesion.idSesion!);
        _mostrarRecordatorioSesion(sesion, fechaLocalLogica);
        break;
      }

      if (diffSec <= 0) {
        _shownSesionIds.add(sesion.idSesion!);
      }
    }
  }

  final Set<int> _shownSesionIds = <int>{}; 
  bool _dialogOpen = false;

  void _mostrarRecordatorioSesion(Sesion sesion, DateTime fechaLocalLogica) async {
    if (!mounted) return;
    if (_dialogOpen) return;
    _dialogOpen = true;

    try {
      await showSesionTimeDialog(
        context,
        nombreSesion: sesion.nombreSesion,
        fechaLocal: fechaLocalLogica, // ✅ ya corregida
        onSnooze: () => _posponerSesion(sesion),
        onStart: () => _iniciarSesion(sesion),
      );
    } finally {
      _dialogOpen = false;
    }
  }


  void _iniciarSesion(Sesion sesion) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StartScreen(idSesion: sesion.idSesion),
      ),
    );
  }

  void _posponerSesion(Sesion sesion) async {
    _shownSesionIds.remove(sesion.idSesion); // Permitir futuros recordatorios
    final nuevaFecha = sesion.fecha.add(const Duration(minutes: 5));

    try {
      // 1. Actualizar en BD (idSesion es int?, usamos !)
      await SesionService.actualizarFechaSesion(sesion.idSesion!, nuevaFecha);

      // 2. Crear nueva sesión actualizada
      final nuevaSesion = Sesion(
        idSesion: sesion.idSesion,
        idUsuario: sesion.idUsuario,
        idMetodo: sesion.idMetodo,
        idTema: sesion.idTema,
        nombreSesion: sesion.nombreSesion,
        fecha: nuevaFecha,
        esRapida: sesion.esRapida,
        duracionTotal: sesion.duracionTotal,
        estado: sesion.estado,
      );

      // 3. Reemplazarla en _sesionesProgramadas
      setState(() {
        final index = _sesionesProgramadas.indexWhere(
            (s) => s.idSesion == sesion.idSesion);
        if (index != -1) {
          _sesionesProgramadas[index] = nuevaSesion;
        }
      });

      // 4. Mostrar mensaje
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sesión pospuesta 5 minutos'),
          backgroundColor: Colors.orange,
        ),
      );
    } catch (e) {
      print('❌ Error posponiendo sesión: $e');
    }
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

  void _confirmarInicioSesion(Sesion session) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text("¿Iniciar sesión programada?"),
          content: Text(
            "¿Quieres empezar ahora tu sesión programada para \"${session.nombreSesion}\"?",
          ),
          actions: [
            TextButton(
              child: const Text("Cancelar"),
              onPressed: () => Navigator.pop(context),
            ),
            ElevatedButton(
              child: const Text("Iniciar ahora"),
              onPressed: () {
                Navigator.pop(context);

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => StartScreen(idSesion: session.idSesion),
                  ),
                );
              },
            )
          ],
        );
      },
    );
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
        _sesionesProgramadas = sesiones; // 🔥 ESTA LÍNEA ARREGLA TODO
      });


      print('📊 Sesiones mostradas en Home: ${_completedSessions.length}');
    } catch (e) {
        print('❌ Error cargando sesiones: $e');
        if (!mounted) return;
        setState(() => _completedSessions = []);
        // sin SnackBar aquí, el usuario ya verá el modal cuando realmente no haya internet
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

    bool errorHora = false;
    final formKeyEdit = GlobalKey<FormState>(); // ✅ clave del Form

    print('📝 Abriendo modal de edición para sesión ${sesion.idSesion}');

    final editado = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            bool fechaHoraValida() {
              final nuevaFecha = DateTime(
                selectedDate.year,
                selectedDate.month,
                selectedDate.day,
                selectedTime.hour,
                selectedTime.minute,
              );
              final diff = nuevaFecha.difference(DateTime.now());
              final ok = diff.inMinutes >= 5;
              print(
                  '⏰ Validando fecha/hora nueva: $nuevaFecha | diff min=${diff.inMinutes} | ok=$ok');
              return ok;
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
                  key: formKeyEdit, // ✅ aquí
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Nombre
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

                      // FECHA
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
                            );
                            if (picked != null) {
                              setState(() {
                                selectedDate = picked;
                                errorHora = !fechaHoraValida();
                              });
                            }
                          },
                        ),
                      ),

                      const SizedBox(height: 12),

                      // HORA
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
                                const Padding(
                                  padding: EdgeInsets.only(top: 4),
                                  child: Text(
                                    'La hora debe ser al menos 5 min en el futuro',
                                    style: TextStyle(
                                      color: Colors.redAccent,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
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
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: Text(
                    'Cancelar',
                    style: TextStyle(color: themeProvider.primaryColor),
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final okNombre =
                        formKeyEdit.currentState?.validate() ?? true;
                    final esValida = fechaHoraValida();

                    print(
                        '✅ Validación modal editar -> nombre=$okNombre, fechaHora=$esValida');

                    if (!okNombre || !esValida) {
                      setState(() {
                        errorHora = !esValida;
                      });
                      return;
                    }

                    final nuevaFecha = DateTime(
                      selectedDate.year,
                      selectedDate.month,
                      selectedDate.day,
                      selectedTime.hour,
                      selectedTime.minute,
                    );

                    try {
                      print(
                          '✏️ Actualizando sesión ${sesion.idSesion} en Supabase...');
                      print(
                          '   Nuevo nombre: ${nombreCtrl.text.trim()} | Nueva fecha: $nuevaFecha');

                      await NotificationService.cancelarNotificacionesSesion(
                          sesion.idSesion!);
                      print('✅ Notificaciones antiguas canceladas');

                      await SesionService.actualizarSesion(
                        sesion.idSesion!,
                        {
                          'nombre_sesion': nombreCtrl.text.trim(),
                          'fecha': nuevaFecha.toIso8601String(),
                        },
                      );
                      print('✅ Sesión actualizada en BD');

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

                      Navigator.pop(dialogContext, true);
                    } catch (e, st) {
                      print('❌ Error actualizando sesión: $e');
                      print('STACK: $st');
                      if (mounted) {
                        ScaffoldMessenger.of(this.context).showSnackBar(
                          SnackBar(
                            content: Text(
                                '❌ Error al actualizar: ${e.toString().substring(0, 80)}'),
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
      print('🔁 Recargando sesiones tras editar...');
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
    } else {
      print('ℹ️ Edición cancelada o sin cambios');
    }
  }


    // ✅ NUEVO MÉTODO: Recargar sesiones con pull-to-refresh
  Future<void> _refreshSessions() async {
    // Antes de llamar al servicio
    final conectado = await ConnectivityService.verificarConexion();
    if (!conectado) {
      await showNoConnectionDialog(context);
      // tras cerrar el modal, el usuario puede tocar de nuevo el botón
      return;
    }
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
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    "Sesiones programadas",
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context).textTheme.bodyLarge?.color,
                                    ),
                                  ),
                                ),
                                // Filtro compacto
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: themeProvider.primaryColor.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: _selectedFilter,
                                      icon: Icon(Icons.filter_alt, color: themeProvider.primaryColor, size: 18),
                                      dropdownColor: themeProvider.cardColor,
                                      style: TextStyle(
                                        color: themeProvider.textColor,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                      items: const [
                                        "Más reciente",
                                        "Más antiguo",
                                        "A-Z",
                                        "Z-A",
                                      ].map((filter) {
                                        return DropdownMenuItem(
                                          value: filter,
                                          child: Text(filter),
                                        );
                                      }).toList(),
                                      onChanged: (value) {
                                        if (value == null) return;
                                        setState(() {
                                          _selectedFilter = value;
                                          _applyFilter();
                                        });
                                      },
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                // Botón recargar compacto
                                IconButton(
                                  icon: Icon(Icons.refresh, color: themeProvider.primaryColor, size: 20),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                  onPressed: _refreshSessions,
                                  tooltip: 'Recargar sesiones',
                                ),
                              ],
                            ),
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
        bottomLeft: Radius.circular(40),
        bottomRight: Radius.circular(40),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 100, 16, 40),
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
                    const Color(0xFFBCAEDC),       // lavanda suave
                    const Color(0xFFE6DACA).withOpacity(0.25), // tierra suave
                    themeProvider.backgroundColor,
                  ],
            stops: const [0.0, 0.35, 1.0],
          ),
        ),
        child: Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(26),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutQuad,
                  width: 420,
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withOpacity(0.05)
                        : const Color(0xFFC6905B).withOpacity(0.25), // tierra suave
                    borderRadius: BorderRadius.circular(26),
                    boxShadow: [
                      BoxShadow(
                        color: isDark
                            ? Colors.black.withOpacity(0.15)
                            : Colors.black.withOpacity(0.08), // sombra ligera
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withOpacity(0.05)
                          : Colors.black.withOpacity(0.08), // borde sutil
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      LumiChar(
                        size: 90,
                        estadoAnimo: _estadoAnimo,
                        onMessage: (msg) {
                          setState(() {
                            _quote = msg;
                            _showQuote = true;
                          });
                        },
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Me llamo Lumi ✨',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? Colors.white.withOpacity(0.9)
                              : Colors.black.withOpacity(0.8), // gris neutro
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (_showQuote)
                        _motivationalBubbleCentered(isDark, themeProvider),
                    ],
                  ),
                ),
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

  //---------------------- BURBUJA CENTRADA ------------------------
  Widget _motivationalBubbleCentered(bool isDark, ThemeProvider themeProvider) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 250),
      opacity: 1,
      child: Container(
        margin: const EdgeInsets.only(top: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        constraints: const BoxConstraints(maxWidth: 260),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withOpacity(0.15)
              : const Color(0xFFC6905B).withOpacity(0.25),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Expanded(
              child: Text(
                _quote,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white.withOpacity(0.95) : Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: () => setState(() => _showQuote = false),
              child: Icon(
                Icons.close,
                size: 18,
                color: isDark ? themeProvider.primaryColor : Colors.teal.shade700,
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
    final textColor = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;
    final primary = themeProvider.primaryColor;
    final fechaLocalLogica = _asLocalIgnoringZone(session.fecha);

    return GestureDetector(
      onTap: () => _confirmarInicioSesion(session),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: themeProvider.cardColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: primary.withOpacity(0.12), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            // --- icono ---
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: primary.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.event, color: primary, size: 22),
            ),

            const SizedBox(width: 12),

            // --- info ---
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    session.nombreSesion,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.calendar_today,
                          size: 14, color: textColor.withOpacity(0.6)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '${fechaLocalLogica .day.toString().padLeft(2, '0')}/'
                          '${fechaLocalLogica .month.toString().padLeft(2, '0')}/'
                          '${fechaLocalLogica .year}',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 12, color: textColor.withOpacity(0.75)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(Icons.access_time,
                          size: 14, color: textColor.withOpacity(0.6)),
                      const SizedBox(width: 4),
                      Text(
                        '${fechaLocalLogica .hour.toString().padLeft(2, '0')}:'
                        '${fechaLocalLogica .minute.toString().padLeft(2, '0')}',
                        style: TextStyle(
                            fontSize: 12, color: textColor.withOpacity(0.75)),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(width: 6),

            // --- Botones ---
            SizedBox(
              width: 100,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    icon: Icon(Icons.edit, color: primary, size: 20),
                    onPressed: () => _editarSesionModal(session),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                    onPressed: () => _eliminarSesion(session),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                ],
              ),
            ),
          ],
        ),
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

