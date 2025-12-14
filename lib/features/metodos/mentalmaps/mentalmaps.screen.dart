import 'dart:ui' as ui;
import 'dart:typed_data';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:mind_map/mind_map.dart';
import 'package:provider/provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/services/sesion_service.dart';
import '../../../core/services/mood_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/stat_service.dart';
import '../../../core/models/sesion.dart';
import '../../../core/services/audio_player_service.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:convert';
import 'dart:math';

class MindNode {
  final String id;
  String text;
  String? description;
  List<MindNode> children;
  bool isCollapsed;

  MindNode({
    String? id,
    required this.text,
    this.description,
    List<MindNode>? children,
    this.isCollapsed = false,
  })  : id = id ?? UniqueKey().toString(),
        children = children ?? [];
}

class MentalMapsScreen extends StatefulWidget {
  final int? idSesion;
  const MentalMapsScreen({Key? key, this.idSesion}) : super(key: key);

  @override
  State<MentalMapsScreen> createState() => _MentalMapsScreenState();
}

class _MentalMapsScreenState extends State<MentalMapsScreen> {
  MindNode? _rootNode;
  int _nodesCreated = 0;

  // Key para capturar solo el MAPA (no el UI)
  final GlobalKey _mapRepaintKey = GlobalKey();

  // ✅ Key para capturar EXACTAMENTE lo que el usuario ve (viewport con zoom/pan)
  final GlobalKey _viewportRepaintKey = GlobalKey();

  int? _sesionRapidaId;
  int? duracionEstipulada;
  int tiempoTranscurrido = 0;
  bool tiempoEstipuladoCumplido = false;
  Timer? tiempoTimer;
  DateTime? _sesionInicioFecha;
  bool _skipInfoMental = false;
  static const int _maxRenderDepth = 4;

  final TransformationController _zoomController = TransformationController();
  double _currentScale = 1.0;

  void _zoomBy(double factor) {
    final matrix = _zoomController.value.clone();
    final newScale = (_currentScale * factor).clamp(0.5, 2.5);

    matrix.scale(newScale / _currentScale);
    _currentScale = newScale;

    _zoomController.value = matrix;
  }

  Map<String, dynamic> _mindNodeToMap(MindNode node) {
    return {
      'id': node.id,
      'text': node.text,
      'description': node.description,
      'isCollapsed': node.isCollapsed,
      'children': node.children.map(_mindNodeToMap).toList(),
    };
  }

  // tamaño estimado del canvas para exportar
  Size _canvasSize = const Size(3000, 3000);

  // clave para el RepaintBoundary offstage (si quieres mantener export "completo")
  final GlobalKey _exportBoundaryKey = GlobalKey();

  MindNode _mindNodeFromMap(Map<String, dynamic> m) {
    return MindNode(
      id: m['id'],
      text: m['text'] ?? '',
      description: m['description'],
      isCollapsed: m['isCollapsed'] ?? false,
      children: (m['children'] as List<dynamic>? ?? [])
          .map((e) => _mindNodeFromMap(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }

  @override
  void initState() {
    super.initState();
    _createRootNode();
    _cargarDuracionEstipulada();
    _iniciarContadorTiempo();
    _crearSesionRapidaSiNoExiste();
    _cargarPreferenciaInfo();
  }

  bool _removeNodeFromParent(MindNode parent, MindNode target) {
    for (int i = 0; i < parent.children.length; i++) {
      if (parent.children[i].id == target.id) {
        parent.children.removeAt(i);
        return true;
      }
      if (_removeNodeFromParent(parent.children[i], target)) {
        return true;
      }
    }
    return false;
  }

  bool _removeNode(MindNode parent, MindNode target) {
    if (parent.children.contains(target)) {
      parent.children = List<MindNode>.from(parent.children)..remove(target);
      return true;
    }

    for (final child in parent.children) {
      if (_removeNode(child, target)) return true;
    }

    return false;
  }

  Future<void> _confirmRemoveNode(MindNode node) async {
    final tp = Provider.of<ThemeProvider>(context, listen: false);

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: tp.backgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
        title: Text("Eliminar nodo", style: TextStyle(color: tp.primaryColor)),
        content: const Text("¿Eliminar este nodo y todos sus subtemas?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text("Cancelar", style: TextStyle(color: tp.primaryColor)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Eliminar", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (ok == true && node != _rootNode) {
      setState(() {
        _removeNodeFromParent(_rootNode!, node);
        _updateCanvasSize();
      });
    }
  }

  /// Pide un nombre de archivo al usuario (devuelve null si canceló)
  Future<String?> _askFilenameDialog({String defaultPrefix = 'lumi_map'}) async {
    final tp = Provider.of<ThemeProvider>(context, listen: false);
    final ctrl = TextEditingController(
      text: '${defaultPrefix}${DateTime.now().millisecondsSinceEpoch}',
    );

    final r = await showDialog<String?>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: tp.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Nombre de archivo',
          style: TextStyle(color: tp.primaryColor, fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(hintText: 'nombre_sin_extensión'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: Text('Cancelar', style: TextStyle(color: tp.primaryColor)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(
              context,
              ctrl.text.trim().isEmpty ? null : ctrl.text.trim(),
            ),
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );

    return r;
  }

  /// Exportar el mapa (JSON) a archivo, y ofrecer compartir
  Future<void> _exportMapJson({required String filename}) async {
    if (_rootNode == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay mapa para exportar.')),
      );
      return;
    }

    try {
      final map = _mindNodeToMap(_rootNode!);
      final jsonStr = jsonEncode(map);

      final dir = await getTemporaryDirectory();
      final filePath = '${dir.path}/$filename.json';
      final file = File(filePath);
      await file.writeAsString(jsonStr);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Mapa guardado temporalmente: $filePath')),
      );

      final share = await showDialog<bool>(
        context: context,
        builder: (_) {
          final tp = Provider.of<ThemeProvider>(context, listen: false);
          return AlertDialog(
            backgroundColor: tp.cardColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            title: Text(
              'Compartir o guardar',
              style: TextStyle(color: tp.primaryColor, fontWeight: FontWeight.bold),
            ),
            content: Text('Archivo $filename.json listo. ¿Deseas compartirlo ahora?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('No', style: TextStyle(color: tp.primaryColor)),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Compartir'),
              ),
            ],
          );
        },
      );

      if (share == true) {
        await Share.shareXFiles(
          [XFile(filePath)],
          text: 'Mapa mental exportado desde Lumi',
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error exportando JSON: $e')),
      );
    }
  }

  /// Importar mapa (JSON) desde archivo elegido por el usuario
  Future<void> _importMapJson() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (result == null || result.files.isEmpty) return;

      final path = result.files.single.path;
      if (path == null) return;

      final file = File(path);
      final content = await file.readAsString();
      final decoded = jsonDecode(content);

      final newRoot = _mindNodeFromMap(Map<String, dynamic>.from(decoded));

      if (_rootNode != null) {
        final ok = await _confirmarSobreEscritura();
        if (!ok) return;
      }

      setState(() {
        _rootNode = newRoot;
        _nodesCreated = 1;
      });
      _updateCanvasSize();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mapa importado correctamente')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error importando JSON: $e')),
      );
    }
  }

  Future<bool> _confirmarSobreEscritura() async {
    final tp = Provider.of<ThemeProvider>(context, listen: false);
    final r = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: tp.cardColor,
        title: Text(
          'Sobrescribir mapa actual?',
          style: TextStyle(color: tp.primaryColor, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'El mapa actual se perderá si continúas. ¿Deseas continuar?',
          style: TextStyle(color: tp.primaryColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar', style: TextStyle(color: tp.primaryColor)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Continuar'),
          ),
        ],
      ),
    );
    return r == true;
  }

  Future<void> _confirmarNuevoMapa() async {
    if (_rootNode == null) {
      _createRootNode();
      return;
    }

    final tp = Provider.of<ThemeProvider>(context, listen: false);

    final action = await showDialog<String?>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: tp.cardColor,
        title: Text(
          'Crear nuevo mapa',
          style: TextStyle(color: tp.primaryColor, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'El mapa actual se borrará si continúas. ¿Qué deseas hacer?',
          style: TextStyle(color: tp.primaryColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: Text('Cancelar', style: TextStyle(color: tp.primaryColor)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'guardar'),
            child: Text('Guardar', style: TextStyle(color: tp.primaryColor)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, 'continuar'),
            child: const Text('Continuar sin guardar'),
          ),
        ],
      ),
    );

    if (action == 'guardar') {
      final name = await _askFilenameDialog(defaultPrefix: 'lumi_map');
      if (name != null) await _exportMapJson(filename: name);
      setState(() {
        _rootNode = null;
        _nodesCreated = 0;
      });
    } else if (action == 'continuar') {
      setState(() {
        _rootNode = null;
        _nodesCreated = 0;
      });
    }
  }

  Future<void> _confirmarFinalizarSesion() async {
    final tp = Provider.of<ThemeProvider>(context, listen: false);
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: tp.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          '¿Completar sesión?',
          style: TextStyle(color: tp.primaryColor, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Has creado $_nodesCreated nodos. ¿Deseas marcar esta sesión como finalizada?',
          style: TextStyle(color: tp.primaryColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar', style: TextStyle(color: tp.primaryColor)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Completar'),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      await _finalizarSesion();
      if (mounted) Navigator.of(context).pop(true);
    }
  }

  Future<bool> _confirmarSalir() async {
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
                '¿Deseas salir?',
                style: TextStyle(color: tp.primaryColor, fontWeight: FontWeight.bold),
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
                  ? 'Si sales ahora, esta sesión se marcará como finalizada.'
                  : 'Si sales ahora, el mapa mental actual se cerrará.',
              style: TextStyle(color: tp.primaryColor),
            ),
            const SizedBox(height: 12),
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
                      'Recuerda guardar tu mapa mental antes de salir. '
                      'Si no lo haces, se perderán los cambios.',
                      style: TextStyle(color: tp.primaryColor, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(context, false),
            style: OutlinedButton.styleFrom(
              foregroundColor: tp.primaryColor,
              side: BorderSide(color: tp.primaryColor.withOpacity(0.4)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Salir'),
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
        } catch (e) {
          print('Error: $e');
        }
      }
    }

    return salir == true;
  }

  void _updateCanvasSize() {
    if (_rootNode == null) {
      setState(() => _canvasSize = const Size(800, 600));
      return;
    }

    final Map<int, int> countPerLevel = {};
    void dfs(MindNode node, int level) {
      countPerLevel[level] = (countPerLevel[level] ?? 0) + 1;
      for (final c in node.children) dfs(c, level + 1);
    }

    dfs(_rootNode!, 0);

    final maxDepth = countPerLevel.keys.isEmpty
        ? 1
        : (countPerLevel.keys.reduce((a, b) => a > b ? a : b) + 1);
    final maxPerLevel = countPerLevel.values.isEmpty
        ? 1
        : countPerLevel.values.reduce((a, b) => a > b ? a : b);

    const double colWidth = 260;
    const double rowHeight = 140;

    final double width = (maxDepth + 1) * colWidth;
    final double height = (maxPerLevel + 1) * rowHeight;

    final double finalWidth = width.clamp(800, 8000);
    final double finalHeight = height.clamp(600, 8000);

    setState(() {
      _canvasSize = Size(finalWidth, finalHeight);
    });
  }

  // (opcional) Render "completo" offstage — se mantiene por si lo quieres aparte
  Future<ui.Image?> _renderFullMapImage() async {
    final overlay = Overlay.of(context);
    if (overlay == null) return null;

    final repaintKey = GlobalKey();
    final overlayEntry = OverlayEntry(
      builder: (context) {
        return Material(
          color: Colors.transparent,
          child: Center(
            child: Offstage(
              offstage: false,
              child: RepaintBoundary(
                key: repaintKey,
                child: SizedBox(
                  width: _canvasSize.width,
                  height: _canvasSize.height,
                  child: _buildFullMapForExport(),
                ),
              ),
            ),
          ),
        );
      },
    );

    overlay.insert(overlayEntry);

    await Future.delayed(const Duration(milliseconds: 120));
    await WidgetsBinding.instance.endOfFrame;

    try {
      final boundary = repaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        overlayEntry.remove();
        return null;
      }

      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      overlayEntry.remove();
      return image;
    } catch (e) {
      overlayEntry.remove();
      rethrow;
    }
  }

  Widget _buildFullMapForExport() {
    if (_rootNode == null) return const SizedBox.shrink();

    return Container(
      color: Colors.transparent,
      child: Center(
        child: SizedBox(
          width: _canvasSize.width,
          height: _canvasSize.height,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: MindMap(
                  dotRadius: 5,
                  children: [
                    _graphicalNode(_rootNode!, level: 0, minWidth: 150),
                    ..._buildMindMapChildren(_rootNode!, 0),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _cargarPreferenciaInfo() async {
    final prefs = await SharedPreferences.getInstance();
    _skipInfoMental = prefs.getBool('skip_info_mental') ?? false;
    if (!_skipInfoMental && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showInfoDialog(forced: true);
      });
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
        print('⏱ Duración estipulada: ${duracionEstipulada! ~/ 60} minutos');
      }
    } catch (e) {
      print('❌ Error cargando duración: $e');
    }
  }

  void _iniciarContadorTiempo() {
    tiempoTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      tiempoTranscurrido++;

      if (!tiempoEstipuladoCumplido &&
          duracionEstipulada != null &&
          tiempoTranscurrido >= duracionEstipulada!) {
        tiempoEstipuladoCumplido = true;
        AudioPlayerService.play('assets/sounds/alert_finish.mp3');
        _mostrarDialogoTiempoCumplido();
      }
    });
  }

  Future<void> _crearSesionRapidaSiNoExiste() async {
    if (widget.idSesion != null) {
      print('📅 Sesión programada: ${widget.idSesion}');
      return;
    }

    print('🚀 Creando sesión rápida de Mapa Mental...');

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
        nombreSesion: 'Sesión Rápida (Mapa Mental)',
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

  Future<void> _mostrarDialogoTiempoCumplido() async {
    final tp = Provider.of<ThemeProvider>(context, listen: false);

    final continuar = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: tp.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.check_circle, color: Colors.green, size: 28),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                '¡Tiempo cumplido!',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Text(
          'Has completado los ${duracionEstipulada! ~/ 60} minutos estipulados para tu Mapa Mental.\n\n¿Deseas continuar o finalizar?',
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

  final List<List<Color>> _levelGradientsLight = [
    [const Color(0xffFFD700), const Color(0xffFFF7AE)],
    [const Color(0xffB8DFD8), const Color(0xffD6EFE8)],
    [const Color(0xffE4C1F9), const Color(0xffFBEAFE)],
    [const Color(0xffF7AF9D), const Color(0xffFFE3D8)],
    [const Color(0xffA0E7E5), const Color(0xffB4FFF8)],
  ];

  final List<List<Color>> _levelGradientsDark = [
    [const Color(0xFF8B6A00), const Color(0xFF6F5A00)],
    [const Color(0xFF176A5A), const Color(0xFF225E50)],
    [const Color(0xFF6B4A85), const Color(0xFF5A3E72)],
    [const Color(0xFF8B4B3C), const Color(0xFF6E382A)],
    [const Color(0xFF1E7A78), const Color(0xFF1A5F5D)],
  ];

  List<Color> nodeGradient(BuildContext context, int level) {
    final tp = Provider.of<ThemeProvider>(context, listen: false);
    final list = tp.isDarkMode ? _levelGradientsDark : _levelGradientsLight;
    return list[level % list.length];
  }

  void _showInfoDialog({bool forced = false}) {
    final tp = Provider.of<ThemeProvider>(context, listen: false);

    showDialog(
      context: context,
      barrierDismissible: !forced,
      builder: (_) => AlertDialog(
        backgroundColor: tp.backgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          "¿Qué es un mapa mental?",
          style: TextStyle(fontWeight: FontWeight.bold, color: tp.primaryColor),
        ),
        content: Text(
          "Un mapa mental te ayuda a organizar ideas y recordar conceptos de forma visual y conectada. "
          "Cada círculo es un tema o subtema, ¡y los colores te ayudan a diferenciar niveles fácilmente!",
          style: TextStyle(color: tp.primaryColor),
        ),
        actions: [
          if (!_skipInfoMental)
            TextButton(
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('skip_info_mental', true);
                setState(() => _skipInfoMental = true);
                if (mounted) Navigator.pop(context);
              },
              child: Text("No volver a mostrar", style: TextStyle(color: tp.primaryColor)),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Entendido", style: TextStyle(color: tp.primaryColor)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    if (widget.idSesion != null && _nodesCreated > 0) {
      SesionService.actualizarEstadoSesion(widget.idSesion!, 'finalizada').catchError((e) {
        print('Error finalizando sesión en dispose: $e');
      });
    }
    tiempoTimer?.cancel();
    super.dispose();
  }

  Future<void> _finalizarSesion() async {
    print('\n╔════════════════════════════════════════════════╗');
    print('║   INICIANDO FINALIZACIÓN DE MAPA MENTAL        ║');
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

    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id');
    print('   userId: $userId');

    if (userId != null) {
      print('\n😊 Actualizando estado de ánimo...');
      await MoodService.calcularYActualizarEstadoAnimo(userId);
      print('   ✅ Estado de ánimo actualizado');
    }

    try {
      print('\n🔄 ACTUALIZANDO SESIÓN EN BD...');
      print('   Sesión ID: $sesionId');
      print('   Datos a actualizar:');
      print('   - estado: finalizada');
      print('   - duracion_total: 0');
      print('   - fecha: ${DateTime.now().toIso8601String()}');

      try {
        await SesionService.actualizarSesion(
          sesionId,
          {
            'estado': 'finalizada',
            'duracion_total': 0,
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
            tiempoTotalSegundos: 0,
            ciclosCompletados: 1,
          );

          if (statGuardada) {
            print('   ✅ Estadística guardada correctamente');
          } else {
            print('   ⚠ Estadística retornó false');
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
            content: Text('✅ Sesión de Mapa Mental completada'),
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

  Widget _buildCompletarButton() {
    final tp = Provider.of<ThemeProvider>(context);

    return Padding(
      padding: const EdgeInsets.all(20),
      child: ElevatedButton.icon(
        onPressed: () async {
          final confirmar = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: tp.cardColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text(
                '¿Completar sesión?',
                style: TextStyle(color: tp.primaryColor, fontWeight: FontWeight.bold),
              ),
              content: Text(
                'Has creado $_nodesCreated nodos en tu mapa mental.\n\n'
                '¿Deseas marcar esta sesión como finalizada?',
                style: TextStyle(color: tp.primaryColor),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text('Cancelar', style: TextStyle(color: tp.primaryColor)),
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
            if (mounted) Navigator.of(context).pop(true);
          }
        },
        icon: const Icon(Icons.check_circle),
        label: const Text('Completar Sesión'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Future<MindNode?> _askNode({String title = "Tema o Subtema"}) async {
    final tp = Provider.of<ThemeProvider>(context, listen: false);
    final textController = TextEditingController();
    final descController = TextEditingController();
    MindNode? result;

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: tp.backgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
        title: Text(title, style: TextStyle(color: tp.primaryColor, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: textController,
              decoration: InputDecoration(
                labelText: "Nombre",
                labelStyle: TextStyle(color: tp.primaryColor),
              ),
            ),
            TextField(
              controller: descController,
              decoration: InputDecoration(
                labelText: "Descripción (opcional)",
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
              if (textController.text.trim().isNotEmpty) {
                result = MindNode(
                  text: textController.text.trim(),
                  description: descController.text.trim(),
                );
                Navigator.pop(context);
              }
            },
            child: Text("Agregar", style: TextStyle(color: tp.primaryColor)),
          ),
        ],
      ),
    );

    return result;
  }

  void _createRootNode() async {
    MindNode? root = await _askNode(title: "Tema central");
    if (root != null) {
      setState(() {
        _rootNode = root;
        _nodesCreated++;
      });
      _updateCanvasSize();
    }
  }

  void _addChildNode(MindNode parent) async {
    MindNode? child = await _askNode(title: "Nuevo subtema o idea");
    if (child != null) {
      setState(() {
        parent.children = List<MindNode>.from(parent.children)..add(child);
        _nodesCreated++;
      });
      _updateCanvasSize();
    }
  }

  // ✅ Captura el viewport EXACTO (lo que se ve, con zoom/pan)
  Future<Uint8List?> _captureViewportPng({double pixelRatio = 3.0}) async {
    await WidgetsBinding.instance.endOfFrame;

    final boundary =
        _viewportRepaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return null;

    final ui.Image image = await boundary.toImage(pixelRatio: pixelRatio);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List();
  }

  // ✅ Export PDF como "captura" de lo que el usuario ve (zoom/pan incluidos)
  Future<void> _exportPdf() async {
    if (_rootNode == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay mapa para exportar.')),
      );
      return;
    }

    try {
      final pngBytes = await _captureViewportPng(pixelRatio: 3.0);
      if (pngBytes == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo capturar la vista actual.')),
        );
        return;
      }

      final doc = pw.Document();
      final image = pw.MemoryImage(pngBytes);

      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (_) => pw.Center(
            child: pw.Image(image, fit: pw.BoxFit.contain),
          ),
        ),
      );

      final pdfBytes = await doc.save();
      await Printing.sharePdf(
        bytes: pdfBytes,
        filename: '${_rootNode!.text}_vista_actual.pdf',
      );
    } catch (e, st) {
      print('Error export PDF: $e\n$st');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Falló exportar PDF: $e')),
      );
    }
  }

  Widget _graphicalNode(MindNode node, {int level = 0, double minWidth = 120}) {
    final tp = Provider.of<ThemeProvider>(context, listen: false);
    final gradColors = nodeGradient(context, level);

    return RepaintBoundary(
      child: GestureDetector(
        onDoubleTap: () => _addChildNode(node),
        child: Container(
          constraints: BoxConstraints(minWidth: minWidth, minHeight: 46),
          margin: const EdgeInsets.all(6),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: gradColors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: tp.primaryColor.withOpacity(0.12),
                blurRadius: 8,
                offset: const Offset(0, 3),
              )
            ],
            border: Border.all(color: tp.primaryColor.withOpacity(0.14)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                node.text,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: tp.primaryColor,
                  fontSize: (16 + (2 - level).clamp(0, 4)).toDouble(),
                ),
              ),
              if (node.description?.isNotEmpty == true)
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(
                    node.description!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: tp.primaryColor.withOpacity(0.8),
                      fontSize: 13,
                    ),
                  ),
                ),
              if (node != _rootNode)
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => _confirmRemoveNode(node),
                ),
              IconButton(
                icon: Icon(Icons.add_circle_outline, color: tp.primaryColor, size: 20),
                onPressed: () => _addChildNode(node),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildMindMapChildren(MindNode node, int level) {
    if (node.isCollapsed) {
      return [
        MindMap(
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                '+${node.children.length} subtemas ocultos',
                style: TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: Theme.of(context).primaryColor.withOpacity(0.7),
                ),
              ),
            ),
          ],
        ),
      ];
    }

    if (level >= _maxRenderDepth) return [];

    return node.children.map((child) {
      return MindMap(
        dotRadius: 4,
        children: [
          _graphicalNode(child, level: level + 1),
          ..._buildMindMapChildren(child, level + 1),
        ],
      );
    }).toList();
  }

  Widget _buildMapVisual() {
    final tp = Provider.of<ThemeProvider>(context, listen: false);

    if (_rootNode == null) {
      return Center(
        child: ElevatedButton.icon(
          onPressed: _createRootNode,
          icon: Icon(Icons.add, color: tp.primaryColor),
          label: Text("Crear mapa mental", style: TextStyle(color: tp.primaryColor)),
        ),
      );
    }

    return Stack(
      children: [
        // ✅ Boundary del "viewport visible"
        RepaintBoundary(
          key: _viewportRepaintKey,
          child: SizedBox.expand(
            child: ClipRect(
              child: InteractiveViewer(
                transformationController: _zoomController,
                minScale: 0.4,
                maxScale: 3.0,
                constrained: false, // mantiene tu canvas libre
                panEnabled: true,
                scaleEnabled: true,
                child: RepaintBoundary(
                  key: _mapRepaintKey,
                  child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: MindMap(
                      dotRadius: 5,
                      children: [
                        _graphicalNode(_rootNode!, level: 0, minWidth: 150),
                        ..._buildMindMapChildren(_rootNode!, 0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),

        // ✅ UI fuera de la captura
        Positioned(
          right: 16,
          bottom: 16,
          child: Column(
            children: [
              FloatingActionButton(
                mini: true,
                onPressed: () => _zoomBy(1.2),
                child: const Icon(Icons.add),
              ),
              const SizedBox(height: 8),
              FloatingActionButton(
                mini: true,
                onPressed: () => _zoomBy(0.8),
                child: const Icon(Icons.remove),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final tp = Provider.of<ThemeProvider>(context);

    final colors = tp.isDarkMode
        ? [const Color(0xFF212C36), const Color(0xFF313940), tp.backgroundColor]
        : [const Color(0xFFB6C9D6), const Color(0xFFE6DACA), tp.backgroundColor];

    return WillPopScope(
      onWillPop: () async => await _confirmarSalir(),
      child: Scaffold(
        backgroundColor: tp.backgroundColor,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(90),
          child: AppBar(
            elevation: 0,
            centerTitle: true,
            automaticallyImplyLeading: true,
            title: Text(
              'Mapa Mental',
              style: TextStyle(color: tp.primaryColor, fontWeight: FontWeight.bold),
            ),
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
            actions: [
              IconButton(
                icon: Icon(Icons.info_outline, color: tp.primaryColor),
                tooltip: 'Información',
                onPressed: _showInfoDialog,
              ),
              Builder(
                builder: (ctx) => IconButton(
                  icon: Icon(Icons.menu, color: tp.primaryColor),
                  tooltip: 'Menú',
                  onPressed: () => Scaffold.of(ctx).openEndDrawer(),
                ),
              ),
            ],
          ),
        ),
        endDrawer: Drawer(
          backgroundColor: tp.cardColor,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.horizontal(left: Radius.circular(25)),
          ),
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              DrawerHeader(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: colors,
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: Text(
                    'Opciones del mapa',
                    style: TextStyle(
                      color: tp.primaryColor,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              // Guardar JSON
              ListTile(
                leading: Icon(Icons.save_alt, color: tp.primaryColor),
                title: Text('Guardar mapa', style: TextStyle(color: tp.primaryColor)),
                subtitle: Text(
                  'Archivo .json seguro en tu dispositivo\nNo es peligroso, solo texto editable',
                  style: TextStyle(color: tp.primaryColor.withOpacity(0.7), fontSize: 12),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  final name = await _askFilenameDialog(defaultPrefix: 'mimapa');
                  if (name != null) await _exportMapJson(filename: name);
                },
              ),

              // Cargar JSON
              ListTile(
                leading: Icon(Icons.folder_open, color: tp.primaryColor),
                title: Text('Cargar mapa', style: TextStyle(color: tp.primaryColor)),
                subtitle: Text(
                  'Selecciona archivo .json de mapas guardados',
                  style: TextStyle(color: tp.primaryColor.withOpacity(0.7), fontSize: 12),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  await _importMapJson();
                },
              ),

              // Exportar PDF (vista actual)
              if (_rootNode != null)
                ListTile(
                  leading: Icon(Icons.picture_as_pdf, color: tp.primaryColor),
                  title: Text("Exportar PDF (vista actual)", style: TextStyle(color: tp.primaryColor)),
                  onTap: () async {
                    Navigator.pop(context);
                    await _exportPdf();
                  },
                ),

              const Divider(),

              if (_rootNode != null)
                ListTile(
                  leading: Icon(Icons.refresh, color: tp.primaryColor),
                  title: Text("Nuevo mapa", style: TextStyle(color: tp.primaryColor)),
                  onTap: () {
                    Navigator.pop(context);
                    _confirmarNuevoMapa();
                  },
                ),

              if (widget.idSesion != null && _nodesCreated > 0)
                ListTile(
                  leading: const Icon(Icons.check_circle, color: Colors.green),
                  title: const Text("Completar sesión", style: TextStyle(color: Colors.green)),
                  onTap: () async {
                    Navigator.pop(context);
                    await _confirmarFinalizarSesion();
                  },
                ),

              const Divider(),

              ListTile(
                leading: Icon(Icons.close, color: tp.primaryColor),
                title: Text("Cerrar menú", style: TextStyle(color: tp.primaryColor)),
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
        body: Container(
          width: double.infinity,
          color: tp.backgroundColor,
          child: _buildMapVisual(),
        ),
      ),
    );
  }
}