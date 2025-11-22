import 'dart:ui' as ui;
import 'dart:typed_data'; // <-- agrega Uint8List
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart'; // <-- agrega RenderRepaintBoundary
import 'package:mind_map/mind_map.dart';
import 'package:provider/provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart'; // <-- <<-- agrega esto para PdfPageFormat
import 'package:printing/printing.dart';
import '../../../core/providers/theme_provider.dart';

class MindNode {
  String text;
  String? description;
  List<MindNode> children;
  MindNode({required this.text, this.description = '', this.children = const []});
}

class MentalMapsScreen extends StatefulWidget {
  const MentalMapsScreen({Key? key}) : super(key: key);

  @override
  State<MentalMapsScreen> createState() => _MentalMapsScreenState();
}

class _MentalMapsScreenState extends State<MentalMapsScreen> {
  MindNode? _rootNode;

  // Key para capturar el widget (RepaintBoundary)
  final GlobalKey _mapRepaintKey = GlobalKey();

  // Gradientes para diferenciar niveles (light)
  final List<List<Color>> _levelGradientsLight = [
    [const Color(0xffFFD700), const Color(0xffFFF7AE)],
    [const Color(0xffB8DFD8), const Color(0xffD6EFE8)],
    [const Color(0xffE4C1F9), const Color(0xffFBEAFE)],
    [const Color(0xffF7AF9D), const Color(0xffFFE3D8)],
    [const Color(0xffA0E7E5), const Color(0xffB4FFF8)],
  ];

  // Gradientes alternativos para dark (más apagados)
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

  void _showInfoDialog() {
    final tp = Provider.of<ThemeProvider>(context, listen: false);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: tp.backgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text("¿Qué es un mapa mental?", style: TextStyle(fontWeight: FontWeight.bold, color: tp.primaryColor)),
        content: Text(
          "Un mapa mental te ayuda a organizar ideas y recordar conceptos de forma visual y conectada. Cada círculo es un tema o subtema, ¡y los colores te ayudan a diferenciar niveles fácilmente!",
          style: TextStyle(color: tp.primaryColor),
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

  // Diálogo para crear un nodo (tema central o subtema)
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

  // Crear mapa nuevo (tema central)
  void _createRootNode() async {
    MindNode? root = await _askNode(title: "Tema central");
    if (root != null) {
      setState(() => _rootNode = root);
    }
  }

  // Añadir subnodo a cualquier nodo
  void _addChildNode(MindNode parent) async {
    MindNode? child = await _askNode(title: "Nuevo subtema o idea");
    if (child != null) {
      setState(() {
        parent.children = List<MindNode>.from(parent.children)..add(child);
      });
    }
  }

  // Export a PDF como captura (imagen) del widget visible del mapa
  Future<void> _exportPdf() async {
    if (_rootNode == null) return;
    try {
      final boundary = _mapRepaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo capturar el mapa.')));
        return;
      }
      // aumentar pixelRatio para mejor calidad
      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error al generar imagen.')));
        return;
      }
      final Uint8List pngBytes = byteData.buffer.asUint8List();

      final doc = pw.Document();
      final pwImage = pw.MemoryImage(pngBytes);
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context ctx) {
            return pw.Center(
              child: pw.Image(pwImage, fit: pw.BoxFit.contain),
            );
          },
        ),
      );

      final pdfBytes = await doc.save();
      await Printing.sharePdf(bytes: pdfBytes, filename: '${_rootNode!.text}.pdf');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Falló exportar PDF: $e')));
    }
  }

  // Widget para nodo visual (con gradiente y conexión)
  Widget _graphicalNode(MindNode node, {int level = 0, double minWidth = 120}) {
    final tp = Provider.of<ThemeProvider>(context, listen: false);
    final gradColors = nodeGradient(context, level);
    final btnBg = tp.isDarkMode ? tp.cardColor : Colors.white.withOpacity(0.9);
    return GestureDetector(
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
          crossAxisAlignment: CrossAxisAlignment.center,
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
            if (node.description != null && node.description!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(
                  node.description!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: tp.primaryColor.withOpacity(0.8),
                    fontSize: (14 + (2 - level).clamp(0, 4)).toDouble(),
                  ),
                ),
              ),
            IconButton(
              icon: Icon(Icons.add_circle_outline, color: tp.primaryColor, size: 20),
              onPressed: () => _addChildNode(node),
              tooltip: "Agregar subtema",
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }

  // Recursivamente construye los nodos MindMap
  List<Widget> _buildMindMapChildren(MindNode node, int level) {
    if (node.children.isEmpty) return [];
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
          style: ElevatedButton.styleFrom(
            backgroundColor: tp.cardColor,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
          ),
        ),
      );
    }
    // RepaintBoundary envuelve la vista para capturar como imagen
    return RepaintBoundary(
      key: _mapRepaintKey,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
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
    );
  }

  Future<bool> _confirmarSalida() async {
    final tp = Provider.of<ThemeProvider>(context, listen: false);
    final salir = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: tp.backgroundColor,
        title: Text("¿Deseas terminar?", style: TextStyle(color: tp.primaryColor)),
        content: Text("Si retrocedes ahora, perderás el mapa actual.", style: TextStyle(color: tp.primaryColor)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text("No", style: TextStyle(color: tp.primaryColor))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text("Sí", style: TextStyle(color: tp.primaryColor))),
        ],
      ),
    );
    return salir == true;
  }

  @override
  Widget build(BuildContext context) {
    final tp = Provider.of<ThemeProvider>(context);
    // usar mismo gradiente que Home (respeta tp.isDarkMode y tp.backgroundColor)
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
          title: Text('Mapa Mental', style: TextStyle(color: tp.primaryColor, fontWeight: FontWeight.bold)),
          actions: [
            IconButton(
              icon: Icon(Icons.info_outline, color: tp.primaryColor),
              onPressed: _showInfoDialog,
            ),
            if (_rootNode != null)
              IconButton(
                icon: Icon(Icons.picture_as_pdf, color: tp.primaryColor),
                tooltip: "Exportar PDF",
                onPressed: _exportPdf,
              ),
            if (_rootNode != null)
              IconButton(
                icon: Icon(Icons.refresh, color: tp.primaryColor),
                tooltip: "Nuevo mapa",
                onPressed: _createRootNode,
              ),
          ],
          // Gradiente igual que Home (stops 0.0, 0.35, 1.0)
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
        body: Container(
          width: double.infinity,
          color: tp.backgroundColor,
          child: _buildMapVisual(),
        ),
      ),
    );
  }
}
