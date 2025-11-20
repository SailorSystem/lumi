import 'dart:async';
import 'package:flutter/material.dart';

class FlashcardsScreen extends StatefulWidget {
  const FlashcardsScreen({Key? key}) : super(key: key);

  @override
  State<FlashcardsScreen> createState() => _FlashcardsScreenState();
}

class Flashcard {
  final String front;
  final String back;
  Flashcard({required this.front, required this.back});
}

class _FlashcardsScreenState extends State<FlashcardsScreen> {
  static const _bg = Color(0xFFD9CBBE);
  static const _bar = Color(0xFFB49D87);
  static const _primary = Color(0xFF2C4459);

  final List<Flashcard> _flashcards = [];
  final List<Flashcard> _incorrect = [];
  List<Flashcard> _studyDeck = [];
  int _current = 0;
  bool _isFront = true;
  bool _isStudying = false;
  bool _isResting = false;

  // Para el descanso
  int _restSeconds = 0;
  Timer? _restTimer;

  void _showInfoDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text(
          "¿Cómo funciona?",
          style: TextStyle(fontWeight: FontWeight.bold, color: _primary),
        ),
        content: const Text(
          "Crea cartas con términos o preguntas. Estudia volteando cada carta. Si te equivocas, la carta se repite más adelante. Descansa si lo necesitas, y vuelve cuando estés listo.",
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

  void _showCreateCardDialog() {
    final frontController = TextEditingController();
    final backController = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text("Crear nueva carta", style: TextStyle(color: _primary, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: frontController,
              maxLength: 24,
              decoration: const InputDecoration(
                labelText: "Palabra (frontal)",
                hintText: "Máximo 2 palabras",
                labelStyle: TextStyle(color: _primary),
              ),
            ),
            TextField(
              controller: backController,
              minLines: 2,
              maxLines: 3,
              maxLength: 80,
              decoration: const InputDecoration(
                labelText: "Definición (reverso)",
                labelStyle: TextStyle(color: _primary),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancelar", style: TextStyle(color: _primary)),
          ),
          TextButton(
            onPressed: () {
              if (frontController.text.trim().isNotEmpty && backController.text.trim().isNotEmpty) {
                setState(() {
                  _flashcards.add(Flashcard(
                    front: frontController.text.trim(),
                    back: backController.text.trim(),
                  ));
                });
                Navigator.pop(context);
              }
            },
            child: const Text("Crear", style: TextStyle(color: _primary)),
          ),
        ],
      ),
    );
  }

  void _startStudySession() {
    if (_flashcards.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Crea primero tus cartas."),
        duration: Duration(seconds: 2),
      ));
      return;
    }
    setState(() {
      _isStudying = true;
      _studyDeck = List.from(_flashcards);
      _studyDeck.shuffle();
      _incorrect.clear();
      _current = 0;
      _isFront = true;
    });
  }

  void _flipCard() => setState(() => _isFront = !_isFront);

  void _mark(bool correcto) {
    setState(() {
      if (!correcto) {
        _incorrect.add(_studyDeck[_current]);
      }
      if (_current == _studyDeck.length - 1) {
        if (_incorrect.isNotEmpty) {
          _studyDeck.clear();
          _studyDeck.addAll(_incorrect);
          _incorrect.clear();
          _current = 0;
          _isFront = true;
        } else {
          _isStudying = false;
          _studyDeck.clear();
        }
      } else {
        _current++;
        _isFront = true;
      }
    });
  }

  // Descanso con contador
  void _startRest() async {
    final option = await showDialog<String>(
      context: context,
      builder: (_) => SimpleDialog(
        title: const Text('¿Cómo deseas descansar?'),
        children: [
          SimpleDialogOption(
              child: const Text('Por periodo de tiempo'),
              onPressed: () => Navigator.pop(context, 'period')),
          SimpleDialogOption(
              child: const Text('Hasta cierta hora'),
              onPressed: () => Navigator.pop(context, 'hour'))
        ],
      ),
    );

    int seconds = 0;
    if (option == 'period') {
      Duration? picked = await showModalBottomSheet<Duration>(
        context: context,
        builder: (_) {
          int minutes = 5;
          return StatefulBuilder(
            builder: (ctx, setSheetState) => Container(
              padding: const EdgeInsets.all(18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("¿Cuántos minutos quieres descansar?", style: TextStyle(fontWeight: FontWeight.bold)),
                  Slider(
                    value: minutes.toDouble(),
                    divisions: 23,
                    min: 5,
                    max: 60,
                    label: "$minutes min",
                    onChanged: (v) => setSheetState(() => minutes = v.round()),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, Duration(minutes: minutes)),
                    child: const Text('Comenzar Descanso'),
                  )
                ],
              ),
            ),
          );
        },
      );
      if (picked != null) seconds = picked.inSeconds;
    } else if (option == 'hour') {
      TimeOfDay? t = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now().replacing(minute: TimeOfDay.now().minute + 5),
      );
      if (t != null) {
        final now = DateTime.now();
        DateTime target = DateTime(now.year, now.month, now.day, t.hour, t.minute);
        if (target.isBefore(now)) target = target.add(const Duration(days: 1));
        seconds = target.difference(now).inSeconds;
      }
    }

    if (seconds > 0) {
      setState(() {
        _isResting = true;
        _restSeconds = seconds;
      });
      _restTimer?.cancel();
      _restTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_restSeconds <= 1) {
          timer.cancel();
          setState(() => _isResting = false);
        } else {
          setState(() => _restSeconds--);
        }
      });
    }
  }

  void _finishRestEarly() {
    _restTimer?.cancel();
    setState(() => _isResting = false);
  }

  // Descanso: vista con contador
  Widget _restingView() {
    int mins = _restSeconds ~/ 60;
    int secs = _restSeconds % 60;
    String timeStr = '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.bedtime, color: _primary, size: 60),
          const SizedBox(height: 16),
          Text("Descansando...\nRelájate y respira :)", textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, color: _primary)),
          const SizedBox(height: 26),
          Text("Tiempo restante", style: const TextStyle(fontSize: 16, color: _primary, fontWeight: FontWeight.bold)),
          Text(
            timeStr,
            style: const TextStyle(fontSize: 34, color: _primary, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _finishRestEarly,
            icon: const Icon(Icons.play_arrow, color: _primary),
            label: const Text("Terminar descanso"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white.withOpacity(0.85),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  // Vista de la carta y botones
  Widget _studyView() {
    if (_studyDeck.isEmpty) {
      return const Center(child: Text("¡Bien hecho! Has terminado.", style: TextStyle(color: _primary, fontSize: 24)));
    }
    Flashcard card = _studyDeck[_current];
    final isFront = _isFront;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 10),
          GestureDetector(
            onTap: _flipCard,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 450),
              curve: Curves.easeInOut,
              width: 270,
              height: 160,
              decoration: BoxDecoration(
                color: isFront
                    ? const Color(0xFFF8F6F1)
                    : const Color(0xFFE8E0D2),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [BoxShadow(color: _primary.withOpacity(0.12), blurRadius: 11, offset: const Offset(0, 4))],
                border: Border.all(color: _primary, width: 2),
              ),
              alignment: Alignment.center,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      isFront ? card.front : card.back,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: isFront ? 27 : 19,
                        fontWeight: isFront ? FontWeight.bold : FontWeight.normal,
                        color: _primary,
                      ),
                    ),
                  if (!isFront)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _mark(true),
                            icon: const Icon(Icons.check, color: Colors.green),
                            label: const Text(
                              "Acerté",
                              style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis, // opción extra
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white.withOpacity(0.9),
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12), // Ajusta padding
                            ),
                          ),
                        ),
                        const SizedBox(width: 12), // Reduce el espacio entre botones
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _mark(false),
                            icon: const Icon(Icons.close, color: Colors.redAccent),
                            label: const Text(
                              "Fallé",
                              style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis, // opción extra
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white.withOpacity(0.9),
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12), // Ajusta padding
                            ),
                          ),
                        ),
                      ],
                    )
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
          Text(_isFront ? "Toca la carta para ver la definición." : "¿La sabías?", style: const TextStyle(color: _primary, fontSize: 16)),
          if (_studyDeck.isNotEmpty)
            Text(
              "Carta ${_current + 1} / ${_studyDeck.length}",
              style: const TextStyle(color: _primary),
            ),
          const SizedBox(height: 30),
          ElevatedButton.icon(
            onPressed: () {
              setState(() {
                _isStudying = false;
                _isResting = false;
                _isFront = true;
                _studyDeck.clear();
                _incorrect.clear();
                _current = 0;
              });
            },
            icon: const Icon(Icons.menu, color: _primary),
            label: const Text("Volver al menú", style: TextStyle(color: _primary, fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white.withOpacity(0.8),
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _mainMenuView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _flashcards.isEmpty
              ? const Text("No tienes cartas aún.", style: TextStyle(color: _primary, fontSize: 16))
              : Text(
                  "Tienes ${_flashcards.length} cartas creadas",
                  style: const TextStyle(color: _primary, fontWeight: FontWeight.bold),
                ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _showCreateCardDialog,
            icon: const Icon(Icons.add, color: _primary),
            label: const Text("Crear Cartas", style: TextStyle(color: _primary, fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white.withOpacity(0.8),
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              elevation: 0,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _startStudySession,
            icon: const Icon(Icons.play_arrow, color: _primary),
            label: const Text("Estudiar", style: TextStyle(color: _primary, fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white.withOpacity(0.8),
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              elevation: 0,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _startRest,
            icon: const Icon(Icons.coffee, color: _primary),
            label: const Text("Descansar", style: TextStyle(color: _primary, fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white.withOpacity(0.8),
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }

  Future<bool> _confirmarSalida() async {
    final salir = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("¿Deseas terminar tu sesión?"),
        content: const Text("Si retrocedes ahora, tu sesión de flashcards terminará."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("No"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Sí"),
          ),
        ],
      ),
    );
    return salir == true;
  }

  @override
  void dispose() {
    _restTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _confirmarSalida,
      child: Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(
          backgroundColor: _bar,
          elevation: 0,
          centerTitle: true,
          title: const Text("Flashcards", style: TextStyle(color: _primary, fontWeight: FontWeight.bold)),
          actions: [
            IconButton(
              icon: const Icon(Icons.info_outline, color: _primary),
              onPressed: _showInfoDialog,
            ),
          ],
        ),
        body: _isResting
            ? _restingView()
            : _isStudying
                ? _studyView()
                : _mainMenuView(),
      ),
    );
  }
}
