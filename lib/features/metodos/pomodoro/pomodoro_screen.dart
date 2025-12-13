import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/services/sesion_service.dart'; 
import '../../../core/services/mood_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/stat_service.dart'; 
import '../../../core/models/sesion.dart';

class PomodoroScreen extends StatefulWidget {
  final int? idSesion; // ✅ AGREGADO
  
  const PomodoroScreen({Key? key, this.idSesion}) : super(key: key); // ✅ MODIFICADO


  @override
  State<PomodoroScreen> createState() => _PomodoroScreenState();
}


class _PomodoroScreenState extends State<PomodoroScreen> {
  final AudioPlayer _player = AudioPlayer();

  int studyTime = 25 * 60;
  int shortBreak = 5 * 60;
  int longBreak = 15 * 60;
  int remainingTime = 25 * 60;
  int completedCycles = 0;
  bool isRunning = false;
  String phase = "Enfoque";
  String _previousPhase = "Enfoque";
  int? _sesionRapidaId;
  DateTime? _sesionInicioFecha; // ✅ NUEVA VARIABLE para guardar cuándo inició
  bool _skipInfoPomodoro = false;
  bool _isShowingError = false; // 🚨 Flag para evitar mensajes repetidos
  int? duracionEstipulada; // En segundos
  int tiempoTranscurrido = 0; // Tiempo total transcurrido
  bool tiempoEstipuladoCumplido = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _cargarDuracionEstipulada();
    _crearSesionRapidaSiNoExiste(); // ✅ AGREGAR ESTA LÍNEA
    _cargarPreferenciaInfo();
  }

  Future<void> _cargarPreferenciaInfo() async {
    final prefs = await SharedPreferences.getInstance();
    _skipInfoPomodoro = prefs.getBool('skip_info_pomodoro') ?? false;
    if (!_skipInfoPomodoro && mounted) {
      // mostrar una sola vez al abrir
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showInfoDialog(forced: true);
      });
    }
  }

  void _showPhaseDisabledMessage(String buttonPhase) {
    if (_isShowingError) return; // ya se está mostrando

    _isShowingError = true;
    final msg = _getPhaseDisabledMessage(buttonPhase);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.redAccent,
        duration: const Duration(seconds: 2),
      ),
    );

    // Reset flag después de que el SnackBar desaparece
    Future.delayed(const Duration(seconds: 2), () {
      _isShowingError = false;
    });
  }

  bool _canGoToPhase(String buttonPhase) {
    switch (phase) {
      case "Enfoque":
        return buttonPhase == "Descanso Corto" || (completedCycles % 4 == 0 && buttonPhase == "Descanso Largo");
      case "Descanso Corto":
        return buttonPhase == "Enfoque";
      case "Descanso Largo":
        return buttonPhase == "Enfoque";
      default:
        return false;
    }
  }

  void _onPhaseButtonPressed(String buttonPhase, int buttonTime) async {
    if (phase == buttonPhase) return; // ya está en esa fase

    // Verificar si puede ir a esa fase según la lógica del ciclo
    if (_canChangePhase(buttonPhase)) {
      // Mostrar diálogo de confirmación si el temporizador está corriendo
      await _onChangePhase(buttonPhase, buttonTime);
    } else {
      // Mostrar mensaje de retroalimentación
      final msg = _getPhaseDisabledMessage(buttonPhase);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg, style: const TextStyle(color: Colors.white)),
          backgroundColor: Colors.redAccent,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }



    // ✅ AGREGAR: Cargar duración de la sesión
  Future<void> _cargarDuracionEstipulada() async {
    if (widget.idSesion == null) return;
    
    try {
      final response = await Supabase.instance.client
          .from('sesiones')
          .select('duracion_total')
          .eq('id_sesion', widget.idSesion!)
          .single();
      
      duracionEstipulada = response['duracion_total'] as int?;
      
      if (duracionEstipulada != null) {
        print('⏱️ Duración estipulada: ${duracionEstipulada! ~/ 60} minutos');
      }
    } catch (e) {
      print('❌ Error cargando duración: $e');
    }
  }

  void startTimer() {
    if (isRunning) return;

    setState(() => isRunning = true);

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (remainingTime > 0) {
          remainingTime--;
          if (phase == "Enfoque") tiempoTranscurrido++;
        } else {
          timer.cancel();
          isRunning = false;
          _handlePhaseCompletion(); // transición automática
        }
      });
    });
  }


 // ✅ AGREGAR ESTE MÉTODO COMPLETO
  Future<void> _crearSesionRapidaSiNoExiste() async {
    if (widget.idSesion != null) {
      print('📅 Sesión programada: ${widget.idSesion}');
      return;
    }
    
    print('🚀 Creando sesión rápida de Pomodoro...');
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('user_id');
      
      if (userId == null) {
        print('❌ No hay userId');
        return;
      }
      
      _sesionInicioFecha = DateTime.now(); // ✅ Guardar hora de inicio
      
      final nuevaSesion = Sesion(
        idUsuario: userId,
        nombreSesion: 'Sesión Rápida (Pomodoro)',
        fecha: _sesionInicioFecha!, // ✅ Usar fecha de inicio
        esRapida: true,
        estado: 'programada',
        duracionTotal: 0,
      );
      
      final sesionCreada = await SesionService.crearSesion(nuevaSesion);
      
      if (sesionCreada != null) {
        setState(() {
          _sesionRapidaId = sesionCreada.idSesion;
        });
        print('✅ Sesión rápida creada con ID: ${sesionCreada.idSesion}');
      }
    } catch (e) {
      print('❌ Error creando sesión rápida: $e');
    }
  }

  Future<void> _mostrarDialogoTiempoCumplido() async {
    final tp = Provider.of<ThemeProvider>(context, listen: false);
    
    _playSound(); // Reproducir sonido de alerta
    
    final continuar = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: tp.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '¡Tiempo cumplido!',
                style: TextStyle(
                  color: tp.primaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'Has completado los ${duracionEstipulada! ~/ 60} minutos estipulados para esta sesión.\n\n¿Deseas continuar estudiando o finalizar?',
          style: TextStyle(color: tp.primaryColor, height: 1.5),
        ),
        actions: [
          OutlinedButton.icon(
            onPressed: () => Navigator.pop(context, false),
            icon: const Icon(Icons.stop, size: 18),
            label: const Text('Finalizar'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              side: const BorderSide(color: Colors.red),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.play_arrow, size: 18),
            label: const Text('Continuar'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
    
    if (continuar == true) {
      // Continuar estudiando
      startTimer();
    } else {
      // Finalizar sesión
      await _finalizarSesion();
      if (mounted) Navigator.of(context).pop(true);
    }
  }

  Future<bool> _isSoundEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('sound') ?? true;
  }

  Future<void> _playSound() async {
    if (await _isSoundEnabled()) {
      await _player.play(AssetSource('sounds/alert_finish.mp3'));
    } else {
      print('🔇 Sonido desactivado en ajustes');
    }
  }

  Future<void> _finalizarSesion() async {
    print('\n╔════════════════════════════════════════════════╗');
    print('║   INICIANDO FINALIZACIÓN DE SESIÓN POMODORO    ║');
    print('╚════════════════════════════════════════════════╝');
    
    final sesionId = _sesionRapidaId ?? widget.idSesion;
    
    print('📋 DATOS INICIALES:');
    print('   _sesionRapidaId: $_sesionRapidaId');
    print('   widget.idSesion: ${widget.idSesion}');
    print('   sesionId final: $sesionId');
    print('   Es sesión rápida: ${_sesionRapidaId != null}');
    
    if (sesionId == null) {
      print('❌ ERROR: sesionId es null, abortando...\n');
      return;
    }
    
    try {
      print('\n📊 CALCULANDO DATOS:');
      final duracionTotal = completedCycles * (studyTime + shortBreak);
      print('   completedCycles: $completedCycles');
      print('   studyTime: $studyTime');
      print('   shortBreak: $shortBreak');
      print('   duracionTotal: $duracionTotal segundos');
      
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('user_id');
      print('   userId: $userId');
      
      if (userId != null) {
        print('\n😊 Actualizando estado de ánimo...');
        await MoodService.calcularYActualizarEstadoAnimo(userId);
        print('   ✅ Estado de ánimo actualizado');
      }
      
      print('\n🔄 ACTUALIZANDO SESIÓN EN BD...');
      print('   Sesión ID: $sesionId');
      print('   Datos a actualizar:');
      print('   - estado: finalizada');
      print('   - duracion_total: $duracionTotal');
      print('   - fecha: ${DateTime.now().toIso8601String()}');
      
      try {
        await SesionService.actualizarSesion(
          sesionId,
          {
            'estado': 'finalizada',
            'duracion_total': duracionTotal,
            'fecha': DateTime.now().toIso8601String(),
          },
        );
        print('   ✅ Sesión actualizada en BD');
      } catch (errorUpdate) {
        print('   ❌ ERROR al actualizar sesión: $errorUpdate');
        rethrow;
      }
      
      print('\n📊 GUARDANDO ESTADÍSTICA...');
      if (userId != null) {
        try {
          final statGuardada = await StatService.registrarEstadistica(
            idUsuario: userId,
            idSesion: sesionId,
            tiempoTotalSegundos: duracionTotal,
            ciclosCompletados: completedCycles,
          );
          
          if (statGuardada) {
            print('   ✅ Estadística guardada correctamente');
          } else {
            print('   ⚠️ Estadística retornó false');
          }
        } catch (errorStat) {
          print('   ❌ ERROR guardando estadística: $errorStat');
        }
      }
      
      print('\n╔════════════════════════════════════════════════╗');
      print('║          ✅ FINALIZACIÓN EXITOSA               ║');
      print('╚════════════════════════════════════════════════╝\n');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Sesión completada correctamente'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e, stackTrace) {
      print('\n╔════════════════════════════════════════════════╗');
      print('║             ❌ ERROR CRÍTICO                   ║');
      print('╚════════════════════════════════════════════════╝');
      print('Error: $e');
      print('Stack trace:');
      print(stackTrace);
      print('════════════════════════════════════════════════\n');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar sesión: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  
  // ✅ Botón "Completar Sesión"
  Widget _buildCompletarButton() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final primary = themeProvider.primaryColor;
    final cardColor = themeProvider.cardColor;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: ElevatedButton.icon(
        onPressed: () async {
          // Confirmar si quiere finalizar
          final confirmar = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: cardColor, // ✅ Adaptado al tema
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Text(
                '¿Completar sesión?',
                style: TextStyle(
                  color: primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: Text(
                'Has completado $completedCycles ciclos de Pomodoro.\n\n'
                '¿Deseas marcar esta sesión como finalizada?',
                style: TextStyle(color: primary),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(
                    'Cancelar',
                    style: TextStyle(color: primary),
                  ),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Completar'),
                ),
              ],
            ),
          );
          
          if (confirmar == true) {
            await _finalizarSesion();
            if (mounted) {
              Navigator.of(context).pop(true); // Regresar con señal de éxito
            }
          }
        },
        icon: const Icon(Icons.check_circle),
        label: const Text('Completar Sesión'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }


  void _handlePhaseCompletion() {
    _playSound(); // sonar al finalizar fase

    // Determinar siguiente fase
    setState(() {
      if (phase == "Enfoque") {
        completedCycles++;
        if (completedCycles % 4 == 0) {
          phase = "Descanso Largo";
          remainingTime = longBreak;
        } else {
          phase = "Descanso Corto";
          remainingTime = shortBreak;
        }
      } else {
        // Si estaba en descanso corto o largo
        phase = "Enfoque";
        remainingTime = studyTime;
      }
    });

    // Mostrar diálogo indicando fase siguiente
    _showPhaseDialog();
  }



  void pauseTimer() {
    if (isRunning) {
      _timer?.cancel();
      setState(() => isRunning = false);
    }
  }

  void resetTimer() {
    _timer?.cancel();
    setState(() {
      isRunning = false;
      phase = "Enfoque";
      remainingTime = studyTime;
    });
  }

  String _formatTime(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return "$minutes:$secs";
  }

  void _showInfoDialog({bool forced = false}) {
    final tp = Provider.of<ThemeProvider>(context, listen: false);

    showDialog(
      context: context,
      barrierDismissible: !forced, // si es obligado, no se cierra tocando afuera
      builder: (_) => AlertDialog(
        backgroundColor: tp.backgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          "Técnica Pomodoro",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: tp.primaryColor,
          ),
        ),
        content: Text(
          "La técnica Pomodoro divide tu tiempo en bloques:\n\n"
          "• 25 min de enfoque\n"
          "• 5 min de descanso corto\n"
          "• 15 min de descanso largo (cada 4 ciclos)\n\n"
          "Sirve para mantener la concentración sin agotarte.",
          style: TextStyle(color: tp.primaryColor, height: 1.4),
        ),
        actions: [
          if (!_skipInfoPomodoro)        // 👈 solo si aún no lo ha marcado
            TextButton(
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('skip_info_pomodoro', true);
                setState(() => _skipInfoPomodoro = true);
                if (mounted) Navigator.pop(context);
              },
              child: Text(
                "No volver a mostrar",
                style: TextStyle(color: tp.primaryColor),
              ),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              "Entendido",
              style: TextStyle(color: tp.primaryColor),
            ),
          ),
        ],
      ),
    );
  }


  Future<bool> _confirmarSalida() async {
    final salir = await showDialog<bool>(
      context: context,
      builder: (_) {
        final tp = Provider.of<ThemeProvider>(context, listen: false);
        return AlertDialog(
          backgroundColor: tp.backgroundColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            "¿Deseas terminar tu sesión?",
            style: TextStyle(color: tp.primaryColor),
          ),
          content: Text(
            widget.idSesion != null
                ? "Si sales ahora, esta sesión se marcará como finalizada."
                : "Si retrocedes, tu sesión de pomodoro terminará.",
            style: TextStyle(color: tp.primaryColor),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text("No", style: TextStyle(color: tp.primaryColor)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text("Sí", style: TextStyle(color: tp.primaryColor)),
            ),
          ],
        );
      },
    );
    
    // ✅ FINALIZAR SESIÓN SI CONFIRMA SALIR
    if (salir == true) {
      final sesionId = _sesionRapidaId ?? widget.idSesion;
      
      if (sesionId != null) {
        try {
          print('🔄 Usuario confirmó salir, finalizando sesión...');
          
          // ✅ CAMBIO: Llamar al método completo que guarda estadísticas
          await _finalizarSesion();
          
          print('✅ Sesión finalizada correctamente');
          
          // Pequeño delay para asegurar que todo se guarde
          await Future.delayed(const Duration(milliseconds: 300));
        } catch (e) {
          print('❌ Error finalizando sesión: $e');
        }
      }
    }
    
    return salir == true;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _player.dispose();
    super.dispose();
  }

  Color _getPhaseButtonColor(String buttonPhase) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final primary = themeProvider.primaryColor;

    if (phase == buttonPhase) return primary; // fase actual

    // Usar la lógica real de cambio de fase
    if (_canChangePhase(buttonPhase)) return Colors.orange; // siguiente fase lógica
    return Colors.grey; // bloqueada
  }



  Future<void> _showPhaseDialog() async {
    final tp = Provider.of<ThemeProvider>(context, listen: false);

    String message;
    if (phase == "Enfoque") {
      message = "¡Hora de enfocarte! Comienza tu sesión de ${studyTime ~/ 60} minutos.";
    } else if (phase == "Descanso Corto") {
      message = "¡Tiempo de descanso corto! Relájate por ${shortBreak ~/ 60} minutos.";
    } else {
      message = "¡Tiempo de descanso largo! Relájate por ${longBreak ~/ 60} minutos.";
    }


    final continuar = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: tp.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          phase,
          style: TextStyle(color: tp.primaryColor, fontWeight: FontWeight.bold),
        ),
        content: Text(message, style: TextStyle(color: tp.primaryColor)),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Iniciar"),
          ),
        ],
      ),
    );

    if (continuar == true) {
      startTimer(); // iniciar la fase automáticamente
    }
  }

  Future<void> _onChangePhase(String newPhase, int newTime) async {
    if (!_canChangePhase(newPhase)) {
      final tp = Provider.of<ThemeProvider>(context, listen: false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "No puedes ir a $newPhase todavía. Debes seguir el ciclo correcto.",
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.redAccent,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    // Confirmación si el temporizador está activo
    if (isRunning) {
      final confirm = await _showConfirmDialog(newPhase);
      if (confirm != true) return;
      pauseTimer();
    }

    // Cambiar fase
    setState(() {
      phase = newPhase;
      remainingTime = newTime;

      if (newPhase == "Enfoque" && _previousPhase == "Descanso Corto") {
        completedCycles++;
      }

      _previousPhase = newPhase;
    });

    // Mostrar diálogo de fase siempre
    await _showPhaseDialog();
  }

  // Método helper para el diálogo de confirmación
  Future<bool?> _showConfirmDialog(String newPhase) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    String message = "";
    if (newPhase == "Enfoque") {
      message = "¡Hora de enfocarte! Comienza tu sesión de estudio.";
    } else if (newPhase == "Descanso Corto") {
      message = "¡Tiempo de descanso corto! Relájate un momento.";
    } else {
      message = "¡Tiempo de descanso largo! Relájate más tiempo.";
    }

    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: themeProvider.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          "¿Cambiar fase a $newPhase?",
          style: TextStyle(color: themeProvider.primaryColor, fontWeight: FontWeight.bold),
        ),
        content: Text(
          "El Pomodoro está activo.\n\n$message\n\n¿Deseas terminar la fase actual y pasar a $newPhase?",
          style: TextStyle(color: themeProvider.primaryColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text("Cancelar", style: TextStyle(color: themeProvider.primaryColor)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text("Confirmar"),
          ),
        ],
      ),
    );
  }





  bool _canChangePhase(String newPhase) {
    // Primera fase obligatoria
    if (completedCycles == 0 && phase != "Enfoque" && newPhase != "Enfoque") {
      return false; // No permite ir a descanso al inicio
    }

    switch (phase) {
      case "Enfoque":
        // Solo puede ir a descanso corto siempre o descanso largo solo si completó 4 ciclos
        if (newPhase == "Descanso Corto") return true;
        if (completedCycles > 0 && completedCycles % 4 == 0 && newPhase == "Descanso Largo") return true;
        return false;
      case "Descanso Corto":
      case "Descanso Largo":
        return newPhase == "Enfoque";
      default:
        return false;
    }
  }



  Widget _actionButton(String text, VoidCallback onPressed) {
    final canPress = _canChangePhase(text);
    final color = _getPhaseButtonColor(text);
    
    return ElevatedButton(
      onPressed: canPress
          ? onPressed
          : () => _showPhaseDisabledMessage(text),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        elevation: 0,
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  String _getPhaseDisabledMessage(String buttonPhase) {
    switch (phase) {
      case "Enfoque":
        if (buttonPhase == "Descanso Largo") return "No puedes tomar descanso largo aún. Completa 4 ciclos de enfoque primero.";
        break;
      case "Descanso Corto":
        if (buttonPhase == "Descanso Largo") return "Debes volver a Enfoque antes de tomar descanso largo.";
        if (buttonPhase == "Descanso Corto") return "Ya estás en descanso corto.";
        break;
      case "Descanso Largo":
        if (buttonPhase != "Enfoque") return "Después del descanso largo debes volver a Enfoque.";
        break;
    }
    return "No puedes ir a $buttonPhase en este momento.";
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final bg = themeProvider.backgroundColor;
    final primary = themeProvider.primaryColor;
    final bar = themeProvider.appBarColor ?? primary;
    final cardColor = themeProvider.cardColor;
    
    final colors = themeProvider.isDarkMode
        ? [
            const Color(0xFF212C36),
            const Color(0xFF313940),
            themeProvider.backgroundColor
          ]
        : [
            const Color(0xFFB6C9D6),
            const Color(0xFFE6DACA),
            themeProvider.backgroundColor
          ];

    return WillPopScope(
      onWillPop: _confirmarSalida,
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          elevation: 0,
          centerTitle: true,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: primary),
            onPressed: () async {
              final salir = await _confirmarSalida();
              if (salir) Navigator.pop(context);
            },
          ),
          title: Text(
            "Pomodoro",
            style: TextStyle(
              color: primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          actions: [
            IconButton(
              icon: Icon(Icons.info_outline, color: primary),
              onPressed: _showInfoDialog,
            ),
          ],
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: colors,
                stops: const [0.0, 0.35, 1.0],
              ),
            ),
          ),
        ),

        body: SingleChildScrollView( // ✅ Agregado para evitar overflow
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 20),

                // Temporizador
                Text(
                  _formatTime(remainingTime),
                  style: TextStyle(
                    fontSize: 74,
                    fontWeight: FontWeight.bold,
                    color: primary,
                  ),
                ),

                const SizedBox(height: 10),

                // Fase actual
                Text(
                  phase,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: primary,
                  ),
                ),

                const SizedBox(height: 40),

                // Info de ciclos y modo
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _infoText("Foco", "$completedCycles/4 ciclos", Icons.access_time),
                      const SizedBox(width: 20),
                      _infoText("Modo", phase, Icons.track_changes),
                    ],
                  ),
                ),

                const SizedBox(height: 60),

                // ----------------- BOTONES DE FASE -----------------
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _actionButton("Enfoque", () => _onPhaseButtonPressed("Enfoque", studyTime)),
                    const SizedBox(width: 10),
                    _actionButton("Descanso Corto", () => _onPhaseButtonPressed("Descanso Corto", shortBreak)),
                    const SizedBox(width: 10),
                    _actionButton("Descanso Largo", () => _onPhaseButtonPressed("Descanso Largo", longBreak)),
                  ],
                ),

                const SizedBox(height: 40),

                // Controles del temporizador
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (!isRunning)
                      _controlButton(Icons.play_arrow, "Iniciar", primary, startTimer)
                    else
                      _controlButton(Icons.pause, "Pausar", Colors.redAccent, pauseTimer),
                    const SizedBox(width: 16),
                    _controlButton(Icons.refresh, "Reiniciar", bar, resetTimer),
                  ],
                ),

                const SizedBox(height: 40),

                // ✅ BOTÓN COMPLETAR SESIÓN (solo si hay ciclos completados)
                if (completedCycles > 0 && widget.idSesion != null)
                  _buildCompletarButton(),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoText(String title, String value, IconData icon) {
    final primary = Provider.of<ThemeProvider>(context).primaryColor;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: primary, size: 22),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                color: primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              value,
              style: TextStyle(color: primary, fontSize: 14),
            ),
          ],
        ),
      ],
    );
  }

  Widget _controlButton(
    IconData icon,
    String label,
    Color color,
    VoidCallback onPressed,
  ) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    Color bg = color;
    if (themeProvider.isDarkMode && color == Colors.white) {
      bg = themeProvider.primaryColor;
    }
    
    return ElevatedButton.icon(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      ),
      icon: Icon(icon, color: Colors.white),
      label: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
