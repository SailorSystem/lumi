import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../home/home_screen.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

class PomodoroScreen extends StatefulWidget {
  const PomodoroScreen({Key? key}) : super(key: key);

  @override
  State<PomodoroScreen> createState() => _PomodoroScreenState();
}

class _PomodoroScreenState extends State<PomodoroScreen> {
  static const _bg = Color(0xFFD9CBBE);
  static const _bar = Color(0xFFB49D87);
  static const _primary = Color(0xFF2C4459);

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

  void _playSound() async {
    // Usa un sonido corto al finalizar
    await _player.play(AssetSource('sounds/finish.mp3')); // agrega tu archivo en assets/sounds/
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
    startTimer(); // inicia siguiente fase automáticamente
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
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Técnica Pomodoro", style: TextStyle(fontWeight: FontWeight.bold, color: _primary)),
        content: const Text(
          "La técnica Pomodoro divide tu tiempo en bloques:\n\n"
          "• 25 min de enfoque\n"
          "• 5 min de descanso corto\n"
          "• 15 min de descanso largo (cada 4 ciclos)\n\n"
          "Sirve para mantener la concentración sin agotarte.",
          style: TextStyle(color: _primary, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Entendido", style: TextStyle(color: _primary)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bar,
        elevation: 0,
        centerTitle: true,
        title: const Text("Pomodoro", style: TextStyle(color: _primary, fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline, color: _primary),
            onPressed: _showInfoDialog,
          ),
        ],
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 20),

          // Temporizador
          Text(
            _formatTime(remainingTime),
            style: const TextStyle(fontSize: 74, fontWeight: FontWeight.bold, color: _primary),
          ),

          const SizedBox(height: 10),

          // Fase actual
          Text(
            phase,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: _primary),
          ),

          const SizedBox(height: 40),

          // Tarjetas de estado
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _infoCard("Foco", "$completedCycles/4 ciclos", Icons.access_time),
              const SizedBox(width: 20),
              _infoCard("Modo", phase, Icons.track_changes),
            ],
          ),

          const SizedBox(height: 60),

          // Botones inferiores (centrados)
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
                _controlButton(Icons.play_arrow, "Iniciar", _primary, startTimer)
              else
                _controlButton(Icons.pause, "Pausar", Colors.redAccent, pauseTimer),
              const SizedBox(width: 16),
              _controlButton(Icons.refresh, "Reiniciar", _bar, resetTimer),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoCard(String title, String value, IconData icon) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.6),
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Icon(icon, color: _primary, size: 26),
          const SizedBox(height: 6),
          Text(title, style: const TextStyle(color: _primary, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(color: _primary, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _actionButton(String text, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white.withOpacity(0.7),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        elevation: 0,
      ),
      child: Text(text, style: const TextStyle(color: _primary, fontWeight: FontWeight.w600)),
    );
  }

  Widget _controlButton(IconData icon, String label, Color color, VoidCallback onPressed) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      ),
      icon: Icon(icon, color: Colors.white),
      label: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
    );
  }
}
