import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../home/home_screen.dart';
import 'dart:convert';

class PomodoroScreen extends StatefulWidget {
  const PomodoroScreen({super.key});
  @override
  State<PomodoroScreen> createState() => _PomodoroScreenState();
}

enum _Phase { focus, shortBreak, longBreak }

class _PomodoroScreenState extends State<PomodoroScreen> {
  // Paleta de la app
  static const _bg = Color(0xFFD9CBBE);
  static const _bar = Color(0xFFB49D87);
  static const _primary = Color(0xFF2C4459);

  // Tiempos por defecto
  static const int _focusMin = 25;
  static const int _shortMin = 5;
  static const int _longMin = 15;
  static const int _cyclesBeforeLong = 4;

  _Phase _phase = _Phase.focus;
  int _cycle = 0; // pomodoros completados dentro del set
  int _totalSeconds = _focusMin * 60;
  int _remaining = _focusMin * 60;
  bool _isRunning = false;
  Timer? _timer;

  // Métrica para guardar sesión
  int _accFocusSeconds = 0;

  // ---- Lógica ----
  void _start() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_remaining > 0) {
        setState(() {
          _remaining--;
          if (_phase == _Phase.focus) _accFocusSeconds++;
        });
      } else {
        _nextPhase();
      }
    });
    setState(() => _isRunning = true);
  }

  void _pause() {
    _timer?.cancel();
    setState(() => _isRunning = false);
  }

  void _resetCurrentPhase() {
    _timer?.cancel();
    setState(() {
      _isRunning = false;
      _remaining = _totalSecondsFor(_phase);
      _totalSeconds = _remaining;
    });
  }

  void _nextPhase() {
    _timer?.cancel();
    if (_phase == _Phase.focus) {
      _cycle++;
      if (_cycle % _cyclesBeforeLong == 0) {
        _setPhase(_Phase.longBreak);
      } else {
        _setPhase(_Phase.shortBreak);
      }
    } else {
      _setPhase(_Phase.focus);
    }
    _start();
  }

  void _setPhase(_Phase p) {
    setState(() {
      _phase = p;
      _totalSeconds = _totalSecondsFor(p);
      _remaining = _totalSeconds;
      _isRunning = false;
    });
  }

  int _totalSecondsFor(_Phase p) {
    switch (p) {
      case _Phase.focus:
        return _focusMin * 60;
      case _Phase.shortBreak:
        return _shortMin * 60;
      case _Phase.longBreak:
        return _longMin * 60;
    }
  }

  // ---- Persistencia ----
  Future<void> _saveSession(Map<String, dynamic> session) async {
    final prefs = await SharedPreferences.getInstance();
    final sessions = prefs.getStringList('completed_sessions') ?? [];
    sessions.add(json.encode(session));
    await prefs.setStringList('completed_sessions', sessions);
  }

  Future<void> _endSession() async {
    _timer?.cancel();
    final sessionData = {
      'titulo': 'Sesión ${DateTime.now().toString().substring(0, 16)}',
      'metodo': 'Pomodoro',
      'ciclos_completados': _cycle,
      'foco_total_min': (_accFocusSeconds / 60).floor(),
      'fecha': DateTime.now().toIso8601String(),
    };
    await _saveSession(sessionData);
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (_) => false,
    );
  }

  // ---- Util ----
  static String _mmss(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Color get _ringColor => _phase == _Phase.focus ? _primary : _bar;
  String get _phaseLabel {
    switch (_phase) {
      case _Phase.focus:
        return 'Foco';
      case _Phase.shortBreak:
        return 'Descanso corto';
      case _Phase.longBreak:
        return 'Descanso largo';
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // ---- UI ----
  @override
  Widget build(BuildContext context) {
    final progress = 1 - (_remaining / _totalSeconds);
    final title = 'Pomodoro';

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bar,
        title: Text(title),
        centerTitle: true,
        elevation: 0,
        foregroundColor: _primary,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Chip de fase y ciclos
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    Chip(
                      label: Text(_phaseLabel, style: const TextStyle(fontWeight: FontWeight.w600)),
                      backgroundColor: Colors.white.withOpacity(0.8),
                      side: BorderSide(color: _ringColor),
                    ),
                    Chip(
                      label: Text('Ciclos ${_cycle % _cyclesBeforeLong}/$_cyclesBeforeLong',
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      backgroundColor: Colors.white.withOpacity(0.8),
                      side: BorderSide(color: _primary.withOpacity(0.5)),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Reloj con anillo de progreso
                SizedBox(
                  width: 260,
                  height: 260,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 240,
                        height: 240,
                        child: CircularProgressIndicator(
                          value: progress.clamp(0, 1),
                          strokeWidth: 16,
                          backgroundColor: Colors.white.withOpacity(0.6),
                          valueColor: AlwaysStoppedAnimation<Color>(_ringColor),
                          strokeCap: StrokeCap.round,
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 250),
                            transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
                            child: Text(
                              _mmss(_remaining),
                              key: ValueKey(_remaining),
                              style: const TextStyle(
                                fontSize: 56,
                                fontWeight: FontWeight.w800,
                                color: _primary,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _phase == _Phase.focus ? 'Enfócate en la tarea' : 'Respira y mueve el cuerpo',
                            style: const TextStyle(color: Colors.black54),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // Próxima fase
                Text(
                  _phase == _Phase.focus
                      ? 'Luego: descanso ${_shortMin}m (largo cada $_cyclesBeforeLong ciclos)'
                      : 'Luego: foco ${_focusMin}m',
                  style: const TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 24),
                // Controles
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Iniciar / Pausar
                    SizedBox(
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: _isRunning ? _pause : _start,
                        icon: Icon(_isRunning ? Icons.pause : Icons.play_arrow, size: 22),
                        label: Text(_isRunning ? 'Pausar' : 'Iniciar',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 26),
                          shape: const StadiumBorder(),
                          elevation: 2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Reiniciar
                    SizedBox(
                      height: 52,
                      child: OutlinedButton.icon(
                        onPressed: _resetCurrentPhase,
                        icon: const Icon(Icons.refresh, size: 20),
                        label: const Text('Reiniciar',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _primary,
                          side: BorderSide(color: _primary.withOpacity(0.45)),
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          shape: const StadiumBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Saltar descanso
                    if (_phase != _Phase.focus)
                      SizedBox(
                        height: 52,
                        child: OutlinedButton.icon(
                          onPressed: _nextPhase,
                          icon: const Icon(Icons.skip_next, size: 20),
                          label: const Text('Saltar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _bar,
                            side: BorderSide(color: _bar.withOpacity(0.6)),
                            padding: const EdgeInsets.symmetric(horizontal: 18),
                            shape: const StadiumBorder(),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 28),
                // Terminar sesión
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _endSession,
                    icon: const Icon(Icons.exit_to_app),
                    label: const Text('Terminar sesión',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent.shade400,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      // Acción rápida para cambiar fase manualmente si hace falta
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Row(
          children: [
            Expanded(
              child: _phaseSwitchButton(_Phase.focus, 'Foco', Icons.school),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _phaseSwitchButton(_Phase.shortBreak, 'Descanso corto', Icons.free_breakfast),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _phaseSwitchButton(_Phase.longBreak, 'Descanso largo', Icons.nightlight_round),
            ),
          ],
        ),
      ),
    );
  }

  Widget _phaseSwitchButton(_Phase p, String text, IconData icon) {
    final active = _phase == p;
    final bg = active ? (_phase == _Phase.focus ? _primary : _bar) : Colors.white.withOpacity(0.85);
    final fg = active ? Colors.white : _primary;
    return SizedBox(
      height: 44,
      child: TextButton.icon(
        onPressed: () {
          _timer?.cancel();
          _setPhase(p);
        },
        icon: Icon(icon, size: 18, color: fg),
        label: Text(text, style: TextStyle(color: fg, fontWeight: FontWeight.w600)),
        style: TextButton.styleFrom(
          backgroundColor: bg,
          shape: const StadiumBorder(),
        ),
      ),
    );
  }
}
