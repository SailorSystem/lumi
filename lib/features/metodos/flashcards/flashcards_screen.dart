// flashcards_screen.dart
import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/services/sesion_service.dart';
import '../../../core/services/mood_service.dart';
import '../../../core/models/sesion.dart';
import '../../../core/services/stat_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/services/audio_player_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:convert';
import '../../../core/models/flashcard.dart'; 
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import '../../../core/services/flashcard_storage_service.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';

class FlashcardsScreen extends StatefulWidget {
  final int? idSesion;
  const FlashcardsScreen({super.key, this.idSesion});

  @override
  State<FlashcardsScreen> createState() => _FlashcardsScreenState();
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
  int? duracionEstipulada;
  int tiempoTranscurrido = 0;
  bool tiempoEstipuladoCumplido = false;
  Timer? tiempoTimer;
  bool isStudying = false;
  bool isResting = false;
  int? _sesionRapidaId;
  DateTime? _sesionInicioFecha;
  bool _skipInfoFlashcards = false;
  late List<Flashcard> _originalDeck;
  DateTime? _inicioSesion; 
  Timer? _timerConteo;
  int _segundosTotales = 0; 

  // Descanso
  int _restSeconds = 0;
  Timer? _restTimer;

  @override
  void initState() {
    super.initState();
    _cargarDuracionEstipulada();
    _iniciarConteoTiempo();
    _crearSesionRapidaSiNoExiste();
    _cargarPreferenciaInfo();
    _originalDeck = List.from(_flashcards);
  }


  Future<void> _mostrarDialogoGuardarConNombre() async {
    if (_flashcards.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No hay tarjetas para exportar")),
      );
      return;
    }

    final tp = Provider.of<ThemeProvider>(context, listen: false);
    final nombreController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    // Nombre sugerido
    final now = DateTime.now();
    final sugerencia = "flashcards_${now.day}_${now.month}_${now.year}";
    nombreController.text = sugerencia;

    final nombre = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: tp.cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(Icons.save_alt, color: tp.primaryColor),
              const SizedBox(width: 12),
              Text(
                'Guardar Flashcards',
                style: TextStyle(
                  color: tp.primaryColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ingresa el nombre del archivo:',
                  style: TextStyle(
                    color: tp.primaryColor.withOpacity(0.8),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: nombreController,
                  autofocus: true,
                  style: TextStyle(color: tp.primaryColor),
                  decoration: InputDecoration(
                    hintText: 'Ej: flashcards_matematicas',
                    hintStyle: TextStyle(color: tp.primaryColor.withOpacity(0.4)),
                    suffixText: '.json',
                    suffixStyle: TextStyle(
                      color: tp.primaryColor.withOpacity(0.6),
                      fontWeight: FontWeight.w500,
                    ),
                    filled: true,
                    fillColor: tp.isDarkMode
                        ? Colors.grey[800]
                        : Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: tp.primaryColor, width: 2),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.redAccent, width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                  validator: (value) {
                    final texto = (value ?? '').trim();
                    if (texto.isEmpty) {
                      return 'El nombre no puede estar vacío';
                    }
                    if (texto.contains(RegExp(r'[<>:"/\\|?*]'))) {
                      return 'Caracteres no permitidos: < > : " / \\ | ? *';
                    }
                    if (texto.length > 50) {
                      return 'Máximo 50 caracteres';
                    }
                    return null;
                  },
                  onFieldSubmitted: (val) {
                    if (formKey.currentState?.validate() ?? false) {
                      Navigator.pop(ctx, nombreController.text.trim());
                    }
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  '💡 Seleccione una carpeta para guardar el archivo',
                  style: TextStyle(
                    color: tp.primaryColor.withOpacity(0.6),
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Cancelar',
                style: TextStyle(
                  color: tp.primaryColor.withOpacity(0.7),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) {
                  Navigator.pop(ctx, nombreController.text.trim());
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: tp.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
              child: const Text(
                'Guardar',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        );
      },
    );

    // Si el usuario confirmó, guardar con ese nombre
    if (nombre != null && nombre.isNotEmpty) {
      _exportFlashcardsWithName(nombre);
    }
  }


  // -------------------- EXPORTAR / IMPORTAR JSON --------------------

  void _openSaveLoadMenu() {
    final tp = Provider.of<ThemeProvider>(context, listen: false);

    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Tarjetas de estudio",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: tp.primaryColor,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                "Guarda tus tarjetas para usarlas más tarde o cárgalas desde un archivo.",
                style: TextStyle(
                  fontSize: 14,
                  color: tp.primaryColor.withOpacity(0.75),
                ),
              ),
              const SizedBox(height: 20),

              // GUARDAR - ahora llama a la nueva función
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _mostrarDialogoGuardarConNombre(); // 👈 CAMBIO AQUÍ
                },
                icon: Icon(Icons.download_rounded, color: tp.primaryColor),
                label: Text(
                  "Guardar tarjetas",
                  style: TextStyle(
                    color: tp.primaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: tp.cardColor,
                  elevation: 0,
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // CARGAR
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _importFlashcards();
                },
                icon: Icon(Icons.folder_open_rounded, color: tp.primaryColor),
                label: Text(
                  "Cargar tarjetas",
                  style: TextStyle(
                    color: tp.primaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: tp.cardColor,
                  elevation: 0,
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 16,
                    color: tp.primaryColor.withOpacity(0.5),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      "El archivo es solo de texto (.json). No se ejecuta ni instala nada.",
                      style: TextStyle(
                        fontSize: 12,
                        color: tp.primaryColor.withOpacity(0.55),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    "Cancelar",
                    style: TextStyle(
                      color: tp.primaryColor.withOpacity(0.8),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


  void _exportFlashcardsWithName(String filename) async {
    if (_flashcards.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("No hay tarjetas para exportar")),
      );
      return;
    }

    try {
      // Si el usuario no escribió nada → generar nombre lumi_XXXX.json
      if (filename.isEmpty) {
        final now = DateTime.now();
        final formatted =
            "${now.year}-${now.month}-${now.day}_${now.hour}-${now.minute}";
        filename = "lumi_$formatted";
      }

      // Asegurar extensión .json
      if (!filename.endsWith(".json")) {
        filename = "$filename.json";
      }

      // Convertir las tarjetas a JSON
      final jsonStr = jsonEncode(
        _flashcards.map((c) => c.toJson()).toList(),
      );

      // Guardar temporalmente
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$filename');
      await file.writeAsString(jsonStr);

      // Compartir
      await Share.shareXFiles(
        [XFile(file.path)],
        text: "Mis flashcards",
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Archivo exportado como $filename")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error al exportar: $e")),
      );
    }
  }

  void _exportFlashcards() async {
    final jsonStr = jsonEncode(_flashcards.map((c) => c.toJson()).toList());

    final file = await FilePicker.platform.saveFile(
      dialogTitle: 'Guardar tarjetas',
      fileName: 'flashcards.json',
    );

    if (file != null) {
      await File(file).writeAsString(jsonStr);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Tarjetas guardadas correctamente")),
      );
    }
  }

  void _importFlashcards() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );

    if (result == null) return;

    final file = File(result.files.single.path!);
    final content = await file.readAsString();
    final decoded = jsonDecode(content);

    setState(() {
      _flashcards.clear();
      _flashcards.addAll(
        (decoded as List).map((e) => Flashcard.fromJson(e)).toList(),
      );
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Tarjetas cargadas correctamente")),
    );
  }

  
  Future<void> _cargarPreferenciaInfo() async {
    final prefs = await SharedPreferences.getInstance();
    _skipInfoFlashcards = prefs.getBool('skip_info_flashcards') ?? false;
    if (!_skipInfoFlashcards && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showInfoDialog(forced: true);
      });
    }
  }

  Future<void> _crearSesionRapidaSiNoExiste() async {
    if (widget.idSesion != null) {
      print('📅 Sesión programada: ${widget.idSesion}');
      return;
    }

    print('🚀 Creando sesión rápida de Flashcards...');

    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('user_id');

      if (userId == null) {
        print('❌ No hay userId');
        return;
      }

      _sesionInicioFecha = DateTime.now();

      final nuevaSesion = Sesion(
        idUsuario: userId,
        idMetodo: 2,
        nombreSesion: 'Sesión Rápida (Flashcards)',
        fecha: _sesionInicioFecha!,
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

  void _iniciarConteoTiempo() {
    _inicioSesion = DateTime.now();
    _timerConteo?.cancel();

    _timerConteo = Timer.periodic(const Duration(seconds: 1), (_) {
      _segundosTotales++;
    });

    print("⏱️ Contador iniciado en $_inicioSesion");
  }


  Future<void> _mostrarDialogoTiempoCumplido() async {
    final tp = Provider.of<ThemeProvider>(context, listen: false);

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
          'Has completado los ${duracionEstipulada! ~/ 60} minutos estipulados para esta sesión de Flashcards.\n\n¿Deseas continuar estudiando o finalizar?',
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

    if (continuar != true) {
      await _finalizarSesion();
      if (mounted) Navigator.of(context).pop(true);
    }
  }

  void _showInfoDialog({bool forced = false}) {
    final tp = Provider.of<ThemeProvider>(context, listen: false);

    showDialog(
      context: context,
      barrierDismissible: !forced,
      builder: (_) => AlertDialog(
        backgroundColor: tp.backgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          "¿Cómo funciona?",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: tp.primaryColor,
          ),
        ),
        content: Text(
          "Crea cartas con términos o preguntas. Estudia volteando cada carta. "
          "Si te equivocas, la carta se repite más adelante. Descansa si lo necesitas, y vuelve cuando estés listo.",
          style: TextStyle(color: tp.primaryColor, height: 1.4),
        ),
        actions: [
          if (!_skipInfoFlashcards)
            TextButton(
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('skip_info_flashcards', true);
                setState(() => _skipInfoFlashcards = true);
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

  Future<void> _finalizarSesion() async {
    print('\n===== FINALIZANDO FLASHCARDS =====');

    final sesionId = _sesionRapidaId ?? widget.idSesion;

    if (sesionId == null) {
      print('❌ ERROR: sesionId es null');
      return;
    }

    // 🛑 Detener contador
    _timerConteo?.cancel();
    print("⏱️ Tiempo total registrado: $_segundosTotales s");

    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id');

    if (userId != null) {
      await MoodService.calcularYActualizarEstadoAnimo(userId);
    }

    try {
      print('🔄 Actualizando sesión...');

      await SesionService.actualizarSesion(
        sesionId,
        {
          'estado': 'finalizada',
          'duracion_total': _segundosTotales,
        },
      );

      print("✅ Sesión guardada con $_segundosTotales segundos");

      if (userId != null) {
        await StatService.registrarEstadistica(
          idUsuario: userId,
          idSesion: sesionId,
          tiempoTotalSegundos: _segundosTotales,
          ciclosCompletados: 1,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Sesión completada'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('❌ Error finalizando sesión: $e');
    }
  }


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
                labelText: "Palabra (frontal)",
                hintText: "Máximo 2 palabras",
                labelStyle: TextStyle(color: tp.primaryColor),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Definición (reverso)",
                  style: TextStyle(
                    color: tp.primaryColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: backController,
                  maxLines: 3,
                  maxLength: 60,
                  textAlignVertical: TextAlignVertical.top,
                  decoration: InputDecoration(
                    hintText: "Escribe la definición aquí",
                    isDense: true,
                    counterText: "",
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
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
      _cardsStudied = 0;
    });
  }

  void _flipCard() => setState(() => _isFront = !_isFront);

  void _mark(bool correcto) {
    bool isLast = _current == _studyDeck.length - 1;

    setState(() {
      _cardsStudied++;

      if (!correcto) {
        _incorrect.add(_studyDeck[_current]);
      }

      if (!isLast) {
        _current++;
        _isFront = true;
      }
    });

    // ⚠️ FUERA del setState
    if (isLast) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_incorrect.isNotEmpty) {
          _showRetryIncorrectDialog();
        } else {
          _showAllCorrectDialog();
        }
      });
    }
  }


  // dialogo cuando todas correctas
  Future<void> _showAllCorrectDialog() async {
    final tp = Provider.of<ThemeProvider>(context, listen: false);

    // Detectamos modo oscuro
    final isDark = tp.isDarkMode;
    final btnTextColor = isDark ? Colors.white : tp.primaryColor;
    final btnBorder = isDark ? Colors.white70 : tp.primaryColor.withOpacity(0.45);

    AudioPlayerService.play('assets/sounds/alert_finish.mp3');

    final r = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: tp.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            const Icon(Icons.celebration, color: Colors.amber),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '¡Felicidades!',
                style: TextStyle(
                  color: tp.primaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'Has completado todas las tarjetas sin errores.\n\n¿Qué quieres hacer ahora?',
          style: TextStyle(color: tp.primaryColor),
        ),
        actions: [
          // -------- BOTÓN SECUNDARIO --------
          OutlinedButton(
            onPressed: () => Navigator.pop(context, 'menu'),
            style: OutlinedButton.styleFrom(
              foregroundColor: btnTextColor,
              side: BorderSide(color: btnBorder),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            ),
            child: const Text('Volver al menú'),
          ),

          // -------- BOTÓN PRINCIPAL --------
          ElevatedButton(
            onPressed: () => Navigator.pop(context, 'repetir'),
            style: ElevatedButton.styleFrom(
              backgroundColor: tp.primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              elevation: 2,
            ),
            child: const Text('Volver a estudiar'),
          ),
        ],
      ),
    );

    // 🔥 AQUÍ ESTABA EL PROBLEMA (ESTO ES LO NUEVO)
    if (r == 'repetir') {
      // ⛔ cortamos el render actual
      setState(() {
        _isStudying = false;
      });

      // ✅ esperamos a que Flutter limpie la vista
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _startStudySession();
      });
    } else {
      setState(() {
        _isStudying = false;
        _studyDeck.clear();
        _incorrect.clear();
        _current = 0;
        _isFront = true;
      });
    }
  }




  // dialogo cuando hubo incorrectas
  Future<void> _showRetryIncorrectDialog() async {
    final tp = Provider.of<ThemeProvider>(context, listen: false);

    // Detectamos modo oscuro
    final isDark = tp.isDarkMode;
    final btnTextColor = isDark ? Colors.white : tp.primaryColor;
    final btnBorder = isDark ? Colors.white70 : tp.primaryColor.withOpacity(0.45);

    AudioPlayerService.play('assets/sounds/alert_finish.mp3');

    final r = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: tp.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            const Icon(Icons.refresh, color: Colors.blue),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Vamos de nuevo',
                style: TextStyle(
                  color: tp.primaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),

        content: Text(
          'Hay ${_incorrect.length} tarjetas que necesitaban repasarse. ¿Quieres repasarlas ahora?',
          style: TextStyle(color: tp.primaryColor),
        ),

        actions: [
          // -------- BOTÓN SECUNDARIO --------
          OutlinedButton(
            onPressed: () => Navigator.pop(context, 'menu'),
            style: OutlinedButton.styleFrom(
              foregroundColor: btnTextColor,
              side: BorderSide(color: btnBorder),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            ),
            child: const Text('Volver al menú'),
          ),

          // -------- BOTÓN PRINCIPAL --------
          ElevatedButton(
            onPressed: () => Navigator.pop(context, 'vamos'),
            style: ElevatedButton.styleFrom(
              backgroundColor: tp.primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              elevation: 2,
            ),
            child: const Text('Vamos'),
          ),
        ],
      ),
    );

    if (r == 'vamos') {
      setState(() {
        _studyDeck = List.from(_incorrect);
        _incorrect.clear();
        _current = 0;
        _isFront = true;
        _isStudying = true;
      });
    } else {
      setState(() {
        _isStudying = false;
        _studyDeck.clear();
        _incorrect.clear();
        _current = 0;
        _isFront = true;
      });
    }
  }

  // ---------- Descanso (mejorado estilo "alarma/pomodoro") ----------
  Future<void> _startRest() async {
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

    if (option == 'period') {
      // Dialog tipo alarma / pomodoro
      final pickedDuration = await showModalBottomSheet<Duration>(
        context: context,
        isScrollControlled: true,
        backgroundColor: tp.cardColor,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (ctx) {
          int minutes = 5;
          int seconds = 0;

          return StatefulBuilder(builder: (ctx, setS) {
            String timeStr() {
              final mm = minutes.toString().padLeft(2, '0');
              final ss = seconds.toString().padLeft(2, '0');
              return '$mm:$ss';
            }

            void incMin() => setS(() => minutes = (minutes + 1).clamp(1, 999));
            void decMin() => setS(() => minutes = (minutes - 1).clamp(1, 999));
            void incSec() => setS(() => seconds = (seconds + 15) % 60);
            void decSec() => setS(() => seconds = (seconds - 15).clamp(0, 59));

            return Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Descansar por periodo', style: TextStyle(color: tp.primaryColor, fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(height: 12),
                  // Gran display centrado tipo alarma
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 24),
                    decoration: BoxDecoration(
                      color: tp.isDarkMode ? Colors.black54 : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12)],
                    ),
                    child: Column(
                      children: [
                        Text('Tiempo', style: TextStyle(color: tp.primaryColor.withOpacity(0.8))),
                        const SizedBox(height: 8),
                        Text(timeStr(), style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: tp.primaryColor)),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // -1 min
                            IconButton(
                              onPressed: decMin,
                              icon: Icon(Icons.remove_circle_outline, color: tp.primaryColor),
                              iconSize: 36,
                            ),
                            const SizedBox(width: 6),
                            ElevatedButton(
                              onPressed: () => setS(() {
                                minutes = minutes + 5;
                              }),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: tp.primaryColor,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                child: Text('+5 min', style: TextStyle(color: Colors.white)),
                              ),
                            ),
                            const SizedBox(width: 6),
                            IconButton(
                              onPressed: incMin,
                              icon: Icon(Icons.add_circle_outline, color: tp.primaryColor),
                              iconSize: 36,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // segundos quick adjust
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(onPressed: decSec, icon: Icon(Icons.remove, color: tp.primaryColor)),
                            const SizedBox(width: 8),
                            Text('$seconds s', style: TextStyle(color: tp.primaryColor)),
                            const SizedBox(width: 8),
                            IconButton(onPressed: incSec, icon: Icon(Icons.add, color: tp.primaryColor)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: Text('Cancelar', style: TextStyle(color: tp.primaryColor)),
                          style: OutlinedButton.styleFrom(side: BorderSide(color: tp.primaryColor.withOpacity(0.45))),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            final total = Duration(minutes: minutes, seconds: seconds);
                            if (total.inSeconds <= 0) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                                content: Text('El tiempo debe ser mayor a 0'),
                                backgroundColor: Colors.orange,
                              ));
                              return;
                            }
                            Navigator.pop(ctx, total);
                          },
                          child: const Text('Comenzar descanso'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          });
        },
      );

      if (pickedDuration != null) {
        // arrancar descanso
        _startRestTimer(pickedDuration.inSeconds);
      }
    } else if (option == 'hour') {
      // elegir hora objetivo
      final now = DateTime.now();
      TimeOfDay? t = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(now.add(const Duration(minutes: 5))),
      );
      if (t != null) {
        DateTime target = DateTime(now.year, now.month, now.day, t.hour, t.minute);
        if (target.isBefore(now)) {
          // No permitimos horas pasadas
          await showDialog(
            context: context,
            builder: (_) {
              final tp = Provider.of<ThemeProvider>(context, listen: false);
              return AlertDialog(
                backgroundColor: tp.cardColor,
                title: Text('Hora inválida', style: TextStyle(color: tp.primaryColor, fontWeight: FontWeight.bold)),
                content: Text('La hora seleccionada ya pasó. Elige una hora en el futuro.', style: TextStyle(color: tp.primaryColor)),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context), child: Text('Entendido', style: TextStyle(color: tp.primaryColor))),
                ],
              );
            },
          );
          return;
        }
        final seconds = target.difference(now).inSeconds;
        if (seconds > 0) {
          _startRestTimer(seconds);
        }
      }
    }
  }

  void _startRestTimer(int seconds) {
    // Inicializar/validar
    if (seconds <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('El tiempo debe ser mayor a 0'), backgroundColor: Colors.orange));
      return;
    }
    setState(() {
      _isResting = true;
      _restSeconds = seconds;
    });

    _restTimer?.cancel();
    _restTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_restSeconds <= 1) {
        timer.cancel();
        setState(() {
          _isResting = false;
          _restSeconds = 0;
        });
        AudioPlayerService.play('assets/sounds/alert_finish.mp3');
        // mostrar dialogo al terminar descanso
        if (mounted) {
          final tp = Provider.of<ThemeProvider>(context, listen: false);
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              backgroundColor: tp.cardColor,
              title: Row(
                children: [Icon(Icons.bedtime, color: tp.primaryColor), const SizedBox(width: 8), Text('Descanso finalizado', style: TextStyle(color: tp.primaryColor))],
              ),
              content: Text('Se terminó tu descanso. ¿Listo para volver a estudiar?', style: TextStyle(color: tp.primaryColor)),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: Text('Volver al menú', style: TextStyle(color: tp.primaryColor))),
                ElevatedButton(onPressed: () { Navigator.pop(context); _startStudySession(); }, child: const Text('Volver a estudiar')),
              ],
            ),
          );
        }
      } else {
        setState(() => _restSeconds--);
      }
    });
  }

  void _finishRestEarly() {
    _restTimer?.cancel();
    setState(() => _isResting = false);
  }

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
            if (widget.idSesion != null && _cardsStudied > 0) _buildCompletarButton(),
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
              width: 310,
              height: 180,
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

  // ---------- VER / EDITAR CARTAS (modal) ----------
  Future<void> _openManageCardsModal() async {
    final tp = Provider.of<ThemeProvider>(context, listen: false);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: tp.cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setS) {
          return Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(ctx).viewInsets.bottom + 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(height: 4, width: 44, decoration: BoxDecoration(color: tp.primaryColor.withOpacity(0.2), borderRadius: BorderRadius.circular(4))),
                const SizedBox(height: 12),
                Text("Mis cartas", style: TextStyle(color: tp.primaryColor, fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 12),
                if (_flashcards.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text("Aún no tienes cartas. Crea una para empezar.", style: TextStyle(color: tp.primaryColor.withOpacity(0.8))),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    itemCount: _flashcards.length,
                    separatorBuilder: (_, __) => const Divider(),
                    itemBuilder: (_, i) {
                      final c = _flashcards[i];
                      return ListTile(
                        leading: CircleAvatar(child: Text('${i + 1}')),
                        title: Text(c.front, style: TextStyle(color: tp.primaryColor, fontWeight: FontWeight.w600)),
                        subtitle: Text(c.back, style: TextStyle(color: tp.primaryColor.withOpacity(0.8))),
                        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () {
                              // Editar carta
                              final frontCtrl = TextEditingController(text: c.front);
                              final backCtrl = TextEditingController(text: c.back);
                              showDialog(
                                context: context,
                                builder: (_) => AlertDialog(
                                  backgroundColor: tp.backgroundColor,
                                  title: Text('Editar carta', style: TextStyle(color: tp.primaryColor)),
                                  content: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      TextField(controller: frontCtrl, decoration: InputDecoration(labelText: 'Frontal', labelStyle: TextStyle(color: tp.primaryColor))),
                                      TextField(controller: backCtrl, minLines: 2, maxLines: 4, decoration: InputDecoration(labelText: 'Reverso', labelStyle: TextStyle(color: tp.primaryColor))),
                                    ],
                                  ),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancelar', style: TextStyle(color: tp.primaryColor))),
                                    TextButton(
                                      onPressed: () {
                                        if (frontCtrl.text.trim().isNotEmpty && backCtrl.text.trim().isNotEmpty) {
                                          setState(() {
                                            _flashcards[i] = Flashcard(front: frontCtrl.text.trim(), back: backCtrl.text.trim());
                                          });
                                          setS(() {}); // refresh modal list
                                          Navigator.pop(context);
                                        }
                                      },
                                      child: Text('Guardar', style: TextStyle(color: tp.primaryColor)),
                                    )
                                  ],
                                ),
                              );
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (_) => AlertDialog(
                                  backgroundColor: tp.cardColor,
                                  title: Text('Eliminar carta', style: TextStyle(color: tp.primaryColor)),
                                  content: Text('¿Eliminar la carta "${c.front}"?', style: TextStyle(color: tp.primaryColor)),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancelar', style: TextStyle(color: tp.primaryColor))),
                                    TextButton(
                                      onPressed: () {
                                        setState(() => _flashcards.removeAt(i));
                                        setS(() {});
                                        Navigator.pop(context);
                                      },
                                      child: Text('Eliminar', style: TextStyle(color: Colors.red)),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ]),
                      );
                    },
                  ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _showCreateCardDialog();
                  },
                  icon: Icon(Icons.add, color: tp.primaryColor),
                  label: Text('Crear carta', style: TextStyle(color: tp.primaryColor)),
                  style: ElevatedButton.styleFrom(backgroundColor: tp.isDarkMode ? tp.cardColor : Colors.white.withOpacity(0.9)),
                ),
                const SizedBox(height: 12),
              ],
            ),
          );
        });
      },
    );
  }

  Widget _mainMenuView() {
    final tp = Provider.of<ThemeProvider>(context);
    final btnBg = tp.isDarkMode ? tp.cardColor : Colors.white.withOpacity(0.9);

    // Ocupa más espacio y botones más grandes
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
        child: Column(
          children: [
            SizedBox(height: 8),
            _flashcards.isEmpty
                ? Text("No tienes cartas aún.", style: TextStyle(color: tp.primaryColor, fontSize: 18))
                : Text(
                    "Tienes ${_flashcards.length} cartas creadas",
                    style: TextStyle(color: tp.primaryColor, fontWeight: FontWeight.bold, fontSize: 18),
                  ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _openManageCardsModal,
                icon: Icon(Icons.view_list, color: tp.primaryColor),
                label: Text("Ver y editar cartas", style: TextStyle(color: tp.primaryColor, fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: btnBg,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _showCreateCardDialog,
                icon: Icon(Icons.add, color: tp.primaryColor),
                label: Text("Crear Cartas", style: TextStyle(color: tp.primaryColor, fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: btnBg,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _startStudySession,
                icon: Icon(Icons.play_arrow, color: tp.primaryColor),
                label: Text("Estudiar", style: TextStyle(color: tp.primaryColor, fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: btnBg,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _startRest,
                icon: Icon(Icons.coffee, color: tp.primaryColor),
                label: Text("Descansar", style: TextStyle(color: tp.primaryColor, fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: btnBg,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(height: 16),
            // BOTÓN UNIFICADO GUARDAR/CARGAR
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _openSaveLoadMenu,
                icon: Icon(Icons.folder, color: tp.primaryColor),
                label: Text(
                  "Guardar / Cargar tarjetas",
                  style: TextStyle(color: tp.primaryColor, fontWeight: FontWeight.w700),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: btnBg,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Info pequeño
            Text('Consejo: toma descansos cortos y enfocados.', style: TextStyle(color: tp.primaryColor.withOpacity(0.7))),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Future<bool> _confirmarSalida() async {
    final tp = Provider.of<ThemeProvider>(context, listen: false);

    final salir = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: tp.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),

        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.amber.shade700),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                "¿Deseas salir?",
                style: TextStyle(
                  color: tp.primaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),

        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.idSesion != null
                  ? "Si sales ahora, esta sesión se marcará como finalizada."
                  : "Si sales ahora, tu sesión de flashcards terminará.",
              style: TextStyle(color: tp.primaryColor),
            ),
            const SizedBox(height: 12),

            // ⚠️ AVISO IMPORTANTE
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.amber.shade700, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Recuerda guardar tus tarjetas antes de salir. "
                      "Si no lo haces, se eliminarán al cerrar la sesión.",
                      style: TextStyle(
                        color: tp.primaryColor,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        actions: [
          // BOTÓN SEGURO
          OutlinedButton(
            onPressed: () => Navigator.pop(context, false),
            style: OutlinedButton.styleFrom(
              foregroundColor: tp.primaryColor,
              side: BorderSide(color: tp.primaryColor.withOpacity(0.4)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text("Cancelar"),
          ),

          // BOTÓN DE SALIDA
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text("Salir"),
          ),
        ],
      ),
    );

    if (salir == true) {
      final sesionId = _sesionRapidaId ?? widget.idSesion;

      if (sesionId != null) {
        try {
          await _finalizarSesion();
          await Future.delayed(const Duration(milliseconds: 300));
        } catch (_) {}
      }
    }

    return salir == true;
  }

  @override
  void dispose() {
    _restTimer?.cancel();
    tiempoTimer?.cancel();
    if (widget.idSesion != null && _cardsStudied > 0) {
      SesionService.actualizarEstadoSesion(widget.idSesion!, 'finalizada').catchError((e) {
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
            IconButton(icon: Icon(Icons.info_outline, color: tp.primaryColor), onPressed: _showInfoDialog),
          ],
        
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: colors, stops: const [0.0, 0.35, 1.0]),
            ),
          ),
        ),
        body: _isResting ? _restingView() : _isStudying ? _studyView() : _mainMenuView(),
      ),
    );
  }
}
