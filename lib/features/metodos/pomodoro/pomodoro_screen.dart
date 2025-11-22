import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/services/sesion_service.dart'; // ✅ AGREGADO


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

  Timer? _timer;

  void startTimer() {
    if (isRunning) return;
    setState(() => isRunning = true);

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (remainingTime > 0) {
        setState(() => remainingTime--);
      } else {
        _timer?.cancel();
        _playSound();
        _handlePhaseCompletion();
      }
    });
  }

  Future<bool> _isSoundEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('sound') ?? true;
  }

  void _playSound() async {
    if (await _isSoundEnabled()) {
      await _player.play(AssetSource('sounds/alert_finish.mp3'));
    }
  }

  // ✅ Método para finalizar sesión
  Future<void> _finalizarSesion() async {
    if (widget.idSesion == null) {
      print('⚠️ No hay idSesion para actualizar');
      return;
    }
    
    try {
      print('🔄 Finalizando sesión ${widget.idSesion}...');
      
      // Calcular duración total en segundos
      final duracionTotal = completedCycles * (studyTime + shortBreak);
      
      await SesionService.actualizarSesion(
        widget.idSesion!,
        {
          'estado': 'finalizada',
          'duracion_total': duracionTotal,
        },
      );
      
      print('✅ Sesión ${widget.idSesion} marcada como finalizada');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Sesión completada correctamente'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('❌ Error finalizando sesión: $e');
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
        phase = "Enfoque";
        remainingTime = studyTime;
      }
    });
    startTimer();
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

  void _showInfoDialog() {
    final tp = Provider.of<ThemeProvider>(context, listen: false);
    showDialog(
      context: context,
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
    if (salir == true && widget.idSesion != null) {
      try {
        print('🔄 Finalizando sesión Pomodoro ${widget.idSesion}...');
        
        await SesionService.actualizarEstadoSesion(
          widget.idSesion!,
          'finalizada',
        );
        
        print('✅ Sesión ${widget.idSesion} finalizada automáticamente');
        
        // Pequeño delay para que Supabase procese
        await Future.delayed(const Duration(milliseconds: 300));
      } catch (e) {
        print('❌ Error finalizando sesión: $e');
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

                // Botones de fase
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _actionButton("Enfoque", () {
                      setState(() {
                        phase = "Enfoque";
                        remainingTime = studyTime;
                      });
                    }),
                    const SizedBox(width: 10),
                    _actionButton("Desc. Corto", () {
                      setState(() {
                        phase = "Descanso Corto";
                        remainingTime = shortBreak;
                      });
                    }),
                    const SizedBox(width: 10),
                    _actionButton("Desc. Largo", () {
                      setState(() {
                        phase = "Descanso Largo";
                        remainingTime = longBreak;
                      });
                    }),
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

  Widget _actionButton(String text, VoidCallback onPressed) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final primary = themeProvider.primaryColor;
    final btnBg = themeProvider.isDarkMode
        ? themeProvider.cardColor
        : Colors.white.withOpacity(0.7);
    
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: btnBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        elevation: 0,
      ),
      child: Text(
        text,
        style: TextStyle(
          color: primary,
          fontWeight: FontWeight.w600,
        ),
      ),
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
