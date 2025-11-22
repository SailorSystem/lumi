import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/services/sesion_service.dart'; 
import '../../../core/models/sesion.dart';

class FlashcardsScreen extends StatefulWidget {
  final int? idSesion; // ✅ AGREGAR
  const FlashcardsScreen({super.key, this.idSesion});

  @override
  State<FlashcardsScreen> createState() => _FlashcardsScreenState();
}

class Flashcard {
  final String front;
  final String back;
  Flashcard({required this.front, required this.back});
}

class _FlashcardsScreenState extends State<FlashcardsScreen> {
  final List<Flashcard> _flashcards = [];
  final List<Flashcard> _incorrect = [];
  List<Flashcard> _studyDeck = [];
  int _current = 0;
  bool _isFront = true;
  bool _isStudying = false;
  bool _isResting = false;
  int _cardsStudied = 0;
  
  // Para el descanso
  int _restSeconds = 0;
  Timer? _restTimer;

  void _showInfoDialog() {
    final tp = Provider.of<ThemeProvider>(context, listen: false);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: tp.backgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          "¿Cómo funciona?",
          style: TextStyle(fontWeight: FontWeight.bold, color: tp.primaryColor),
        ),
        content: Text(
          "Crea cartas con términos o preguntas. Estudia volteando cada carta. Si te equivocas, la carta se repite más adelante. Descansa si lo necesitas, y vuelve cuando estés listo.",
          style: TextStyle(color: tp.primaryColor, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Entendido", style: TextStyle(color: tp.primaryColor)),
          ),
        ],
      ),
    );
  }

  Future<void> _finalizarSesion() async {
    if (widget.idSesion == null) {
      print('⚠️ No hay idSesion para actualizar');
      return;
    }
    
    try {
      print('🔄 Finalizando sesión de Flashcards ${widget.idSesion}...');
      
      await SesionService.actualizarEstadoSesion(
        widget.idSesion!,
        'finalizada',
      );
      
      print('✅ Sesión ${widget.idSesion} marcada como finalizada');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Sesión de Flashcards completada'),
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

  // ✅ AGREGAR TODO ESTE MÉTODO
  Widget _buildCompletarButton() {
    final tp = Provider.of<ThemeProvider>(context);
    final btnBg = tp.isDarkMode ? tp.cardColor : Colors.white.withOpacity(0.8);
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
      child: ElevatedButton.icon(
        onPressed: () async {
          final confirmar = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: tp.cardColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Text(
                '¿Completar sesión?',
                style: TextStyle(
                  color: tp.primaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: Text(
                'Has estudiado $_cardsStudied cartas en esta sesión.\n\n'
                '¿Deseas marcar esta sesión como finalizada?',
                style: TextStyle(color: tp.primaryColor),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(
                    'Cancelar',
                    style: TextStyle(color: tp.primaryColor),
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
              Navigator.of(context).pop(true);
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
  void _showCreateCardDialog() {
    final tp = Provider.of<ThemeProvider>(context, listen: false);
    final frontController = TextEditingController();
    final backController = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: tp.backgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text("Crear nueva carta", style: TextStyle(color: tp.primaryColor, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: frontController,
              maxLength: 24,
              decoration: InputDecoration(
                labelText: "Palabra (frontal)",
                hintText: "Máximo 2 palabras",
                labelStyle: TextStyle(color: tp.primaryColor),
              ),
            ),
            TextField(
              controller: backController,
              minLines: 2,
              maxLines: 3,
              maxLength: 80,
              decoration: InputDecoration(
                labelText: "Definición (reverso)",
                labelStyle: TextStyle(color: tp.primaryColor),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Cancelar", style: TextStyle(color: tp.primaryColor)),
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
            child: Text("Crear", style: TextStyle(color: tp.primaryColor)),
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
      _cardsStudied = 0; // ✅ AGREGAR ESTA LÍNEA
    });
  }


  void _flipCard() => setState(() => _isFront = !_isFront);

  void _mark(bool correcto) {
    setState(() {
      if (!correcto) {
        _cardsStudied++; // ✅ AGREGAR ESTA LÍNEA
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
    final tp = Provider.of<ThemeProvider>(context, listen: false);
    final option = await showDialog<String>(
      context: context,
      builder: (_) => SimpleDialog(
        title: Text('¿Cómo deseas descansar?', style: TextStyle(color: tp.primaryColor)),
        children: [
          SimpleDialogOption(
              child: Text('Por periodo de tiempo', style: TextStyle(color: tp.primaryColor)),
              onPressed: () => Navigator.pop(context, 'period')),
          SimpleDialogOption(
              child: Text('Hasta cierta hora', style: TextStyle(color: tp.primaryColor)),
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
            builder: (ctx, setSheetState) {
              final tpSheet = Provider.of<ThemeProvider>(ctx, listen: false);
              return Container(
                padding: const EdgeInsets.all(18),
                color: tpSheet.backgroundColor,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text("¿Cuántos minutos quieres descansar?", style: TextStyle(fontWeight: FontWeight.bold, color: tpSheet.primaryColor)),
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
                      child: Text('Comenzar Descanso', style: TextStyle(color: tpSheet.primaryColor)),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.white.withOpacity(0.9)),
                    )
                  ],
                ),
              );
            },
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
    final tp = Provider.of<ThemeProvider>(context);
    int mins = _restSeconds ~/ 60;
    int secs = _restSeconds % 60;
    String timeStr = '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bedtime, color: tp.primaryColor, size: 60),
          const SizedBox(height: 16),
          Text("Descansando...\nRelájate y respira :)", textAlign: TextAlign.center, style: TextStyle(fontSize: 22, color: tp.primaryColor)),
          const SizedBox(height: 26),
          Text("Tiempo restante", style: TextStyle(fontSize: 16, color: tp.primaryColor, fontWeight: FontWeight.bold)),
          Text(
            timeStr,
            style: TextStyle(fontSize: 34, color: tp.primaryColor, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _finishRestEarly,
            icon: Icon(Icons.play_arrow, color: tp.primaryColor),
            label: Text("Terminar descanso", style: TextStyle(color: tp.primaryColor)),
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
    final tp = Provider.of<ThemeProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (_studyDeck.isEmpty) {
      final btnBg = tp.isDarkMode ? tp.cardColor : Colors.white.withOpacity(0.8);
      
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.celebration, color: tp.primaryColor, size: 80),
            const SizedBox(height: 20),
            Text(
              "¡Bien hecho!",
              style: TextStyle(
                color: tp.primaryColor,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              "Has terminado de estudiar",
              style: TextStyle(color: tp.primaryColor, fontSize: 18),
            ),
            Text(
              "$_cardsStudied cartas completadas",
              style: TextStyle(
                color: tp.primaryColor.withOpacity(0.7),
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 40),
            
            if (widget.idSesion != null && _cardsStudied > 0)
              _buildCompletarButton(),
            
            const SizedBox(height: 16),
            
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
              icon: Icon(Icons.menu, color: tp.primaryColor),
              label: Text(
                "Volver al menú",
                style: TextStyle(
                  color: tp.primaryColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: btnBg,
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                elevation: 0,
              ),
            ),
          ],
        ),
      );
    }
    Flashcard card = _studyDeck[_current];
    final isFront = _isFront;

    final frontColor = isDark ? Colors.grey.shade800 : const Color(0xFFF8F6F1);
    final backColor = isDark ? Colors.grey.shade700 : const Color(0xFFE8E0D2);
    final largeBtnBg = tp.isDarkMode ? tp.cardColor : Colors.white.withOpacity(0.8);
    final smallBtnBg = tp.isDarkMode ? tp.cardColor : Colors.white.withOpacity(0.9);

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
                color: isFront ? frontColor : backColor,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [BoxShadow(color: tp.primaryColor.withOpacity(0.12), blurRadius: 11, offset: const Offset(0, 4))],
                border: Border.all(color: tp.primaryColor, width: 2),
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
                        color: tp.primaryColor,
                      ),
                    ),
                    if (!isFront)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => _mark(true),
                                icon: const Icon(Icons.check, color: Colors.green),
                                label: Text(
                                  "Acerté",
                                  style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: smallBtnBg,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => _mark(false),
                                icon: const Icon(Icons.close, color: Colors.redAccent),
                                label: Text(
                                  "Fallé",
                                  style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: smallBtnBg,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
          Text(_isFront ? "Toca la carta para ver la definición." : "¿La sabías?", style: TextStyle(color: tp.primaryColor, fontSize: 16)),
          if (_studyDeck.isNotEmpty)
            Text(
              "Carta ${_current + 1} / ${_studyDeck.length}",
              style: TextStyle(color: tp.primaryColor),
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
            icon: Icon(Icons.menu, color: tp.primaryColor),
            label: Text("Volver al menú", style: TextStyle(color: tp.primaryColor, fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(
              backgroundColor: largeBtnBg,
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
    final tp = Provider.of<ThemeProvider>(context);
    final btnBg = tp.isDarkMode ? tp.cardColor : Colors.white.withOpacity(0.8);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _flashcards.isEmpty
              ? Text("No tienes cartas aún.", style: TextStyle(color: tp.primaryColor, fontSize: 16))
              : Text(
                  "Tienes ${_flashcards.length} cartas creadas",
                  style: TextStyle(color: tp.primaryColor, fontWeight: FontWeight.bold),
                ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _showCreateCardDialog,
            icon: Icon(Icons.add, color: tp.primaryColor),
            label: Text("Crear Cartas", style: TextStyle(color: tp.primaryColor, fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(
              backgroundColor: btnBg,
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              elevation: 0,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _startStudySession,
            icon: Icon(Icons.play_arrow, color: tp.primaryColor),
            label: Text("Estudiar", style: TextStyle(color: tp.primaryColor, fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(
              backgroundColor: btnBg,
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              elevation: 0,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _startRest,
            icon: Icon(Icons.coffee, color: tp.primaryColor),
            label: Text("Descansar", style: TextStyle(color: tp.primaryColor, fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(
              backgroundColor: btnBg,
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
    final tp = Provider.of<ThemeProvider>(context, listen: false);
    final salir = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: tp.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          "¿Deseas terminar tu sesión?",
          style: TextStyle(color: tp.primaryColor),
        ),
        content: Text(
          widget.idSesion != null
              ? "Si sales ahora, esta sesión se marcará como finalizada."
              : "Si retrocedes ahora, tu sesión de flashcards terminará.",
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
      ),
    );
    
    // ✅ FINALIZAR SESIÓN SI CONFIRMA SALIR
    if (salir == true && widget.idSesion != null) {
      try {
        print('🔄 Finalizando sesión Flashcards ${widget.idSesion}...');
        
        await SesionService.actualizarEstadoSesion(
          widget.idSesion!,
          'finalizada',
        );
        
        print('✅ Sesión ${widget.idSesion} finalizada automáticamente');
        
        await Future.delayed(const Duration(milliseconds: 300));
      } catch (e) {
        print('❌ Error finalizando sesión: $e');
      }
    }
    
    return salir == true;
  }



  @override
  void dispose() {
    _restTimer?.cancel();
      if (widget.idSesion != null && _cardsStudied > 0) {
    SesionService.actualizarEstadoSesion(
      widget.idSesion!,
      'finalizada',
    ).catchError((e) {
      print('Error finalizando sesión en dispose: $e');
    });
  }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tp = Provider.of<ThemeProvider>(context);
    final colors = tp.isDarkMode
        ? [const Color(0xFF212C36), const Color(0xFF313940), tp.backgroundColor]
        : [const Color(0xFFB6C9D6), const Color(0xFFE6DACA), tp.backgroundColor];

    return WillPopScope(
      onWillPop: _confirmarSalida,
      child: Scaffold(
        backgroundColor: tp.backgroundColor,
        appBar: AppBar(
          elevation: 0,
          centerTitle: true,
          title: Text(
            "Flashcards",
            style: TextStyle(color: tp.primaryColor, fontWeight: FontWeight.bold),
          ),
          actions: [
            IconButton(
              icon: Icon(Icons.info_outline, color: tp.primaryColor),
              onPressed: _showInfoDialog,
            ),
          ],
          // Gradiente igual que Home
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
        body: _isResting
            ? _restingView()
            : _isStudying
                ? _studyView()
                : _mainMenuView(),
      ),
    );
  }
}
