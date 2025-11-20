import 'package:flutter/material.dart';
import 'package:mind_map/mind_map.dart';

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
  static const _bg = Color(0xFFD9CBBE);
  static const _bar = Color(0xFFB49D87);
  static const _primary = Color(0xFF2C4459);

  MindNode? _rootNode;

  // Gradientes para diferenciar niveles
  final List<List<Color>> levelGradients = [
    [Color(0xffFFD700), Color(0xffFFF7AE)],      // Amarillo/dorado para el root
    [Color(0xffB8DFD8), Color(0xffD6EFE8)],      // Verde agua para nivel 1
    [Color(0xffE4C1F9), Color(0xffFBEAFE)],      // Lila para nivel 2
    [Color(0xffF7AF9D), Color(0xffFFE3D8)],      // Coral para nivel 3
    [Color(0xffA0E7E5), Color(0xffB4FFF8)],      // Celeste claro para nivel 4
  ];

  List<Color> nodeGradient(int level) => levelGradients[level % levelGradients.length];

  void _showInfoDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("¿Qué es un mapa mental?", style: TextStyle(fontWeight: FontWeight.bold, color: _primary)),
        content: const Text(
          "Un mapa mental te ayuda a organizar ideas y recordar conceptos de forma visual y conectada. Cada círculo es un tema o subtema, ¡y los colores te ayudan a diferenciar niveles fácilmente!",
          style: TextStyle(color: _primary),
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

  // Diálogo para crear un nodo (tema central o subtema)
  Future<MindNode?> _askNode({String title = "Tema o Subtema"}) async {
    final textController = TextEditingController();
    final descController = TextEditingController();
    MindNode? result;
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
        title: Text(title, style: const TextStyle(color: _primary, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: textController,
              decoration: const InputDecoration(
                labelText: "Nombre",
                labelStyle: TextStyle(color: _primary),
              ),
            ),
            TextField(
              controller: descController,
              decoration: const InputDecoration(
                labelText: "Descripción (opcional)",
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
              if (textController.text.trim().isNotEmpty) {
                result = MindNode(
                  text: textController.text.trim(),
                  description: descController.text.trim(),
                );
                Navigator.pop(context);
              }
            },
            child: const Text("Agregar", style: TextStyle(color: _primary)),
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

  // Widget para nodo visual (con gradiente y conexión)
  Widget _graphicalNode(MindNode node, {int level = 0, double minWidth = 120}) {
    return GestureDetector(
      onDoubleTap: () => _addChildNode(node),
      child: Container(
        constraints: BoxConstraints(minWidth: minWidth, minHeight: 46),
        margin: const EdgeInsets.all(6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: nodeGradient(level),
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 3),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
                Text(
                  node.text,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _primary,
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
                    color: _primary.withOpacity(0.8),
                    fontSize: (16 + (2 - level).clamp(0, 4)).toDouble(),
                  ),
                ),
              ),
            IconButton(
              icon: Icon(Icons.add_circle_outline, color: Colors.brown.shade700, size: 20),
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
    if (_rootNode == null) {
      return Center(
        child: ElevatedButton.icon(
          onPressed: _createRootNode,
          icon: const Icon(Icons.add, color: _primary),
          label: const Text("Crear mapa mental", style: TextStyle(color: _primary)),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
          ),
        ),
      );
    }
    return SingleChildScrollView(
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Mapa Mental',
          style: TextStyle(color: _primary, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline, color: _primary),
            onPressed: _showInfoDialog,
          ),
          if (_rootNode != null)
            IconButton(
              icon: const Icon(Icons.refresh, color: _primary),
              tooltip: "Nuevo mapa",
              onPressed: _createRootNode,
            ),
        ],
        // Gradiente igual que Home, hasta el 75%
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFFB6C9D6), // mar
                Color(0xFFE6DACA), // arena clara
                Color(0xFFD9CBBE), // arena suave
              ],
              stops: [0.0, 0.75, 1.0],
            ),
          ),
        ),
      ),

      body: Container(
        width: double.infinity,
        color: _bg,
        child: _buildMapVisual(),
      ),
    );
  }
}
