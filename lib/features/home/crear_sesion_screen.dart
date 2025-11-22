import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_screen.dart';
import '../../core/models/sesion.dart';
import '../../core/models/tema.dart';
import '../../core/services/tema_service.dart';
import '../../core/services/sesion_service.dart';
import '../../core/providers/theme_provider.dart';

class CrearNuevaSesionScreen extends StatefulWidget {
  const CrearNuevaSesionScreen({super.key});
  
  @override
  State<CrearNuevaSesionScreen> createState() => _CrearNuevaSesionScreenState();
}

class _CrearNuevaSesionScreenState extends State<CrearNuevaSesionScreen> {
  final _formKey = GlobalKey<FormState>();
  final titleController = TextEditingController();
  
  int _selectedMetodoId = 1; // ✅ Variable para el ID del método
  
  List<Map<String, dynamic>> _metodosDb = [];
  Map<String, dynamic>? materiaSel;
  DateTime selectedDate = DateTime.now();
  TimeOfDay selectedTime = TimeOfDay.now();
  Duration selectedDuration = const Duration(hours: 1);
  List<Map<String, dynamic>> _materias = [];
  
  static const List<List<Color>> _paletteOrganizada = [
    [Color(0xFFE53935), Color(0xFFD81B60), Color(0xFFEC407A), Color(0xFFAD1457)],
    [Color(0xFFFF6F00), Color(0xFFFF9800), Color(0xFFFFA726), Color(0xFFFBC02D)],
    [Color(0xFF43A047), Color(0xFF66BB6A), Color(0xFF00897B), Color(0xFF2E7D32)],
    [Color(0xFF1E88E5), Color(0xFF42A5F5), Color(0xFF0277BD), Color(0xFF039BE5)],
    [Color(0xFF5E35B1), Color(0xFF7E57C2), Color(0xFF8E24AA), Color(0xFF4A148C)],
    [Color(0xFF546E7A), Color(0xFF6D4C41), Color(0xFF757575), Color(0xFF455A64)],
  ];

  IconData getIconoMetodo(String nombreMetodo) {
    switch (nombreMetodo.toLowerCase()) {
      case 'pomodoro':
        return Icons.timelapse;
      case 'flashcards':
        return Icons.style;
      case 'mapa mental':
        return Icons.account_tree;
      default:
        return Icons.school;
    }
  }

  @override
  void initState() {
    super.initState();
    _loadMaterias();
    _limpiarMetodosViejos();
    loadMetodosDb();
  }

  Future<void> _limpiarMetodosViejos() async {
    final prefs = await SharedPreferences.getInstance();
    // Eliminar los métodos viejos con estructura incorrecta
    await prefs.remove('metodos');
    print('🧹 Métodos viejos eliminados de SharedPreferences');
  }
  
  Future<void> loadMetodosDb() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? stored = prefs.getStringList('metodos');
    
    if (stored != null && stored.isNotEmpty) {
      setState(() {
        _metodosDb = stored.map((s) => json.decode(s) as Map<String, dynamic>).toList();
      });
      return;
    }

    _metodosDb = [
      {
        'idx': 0,
        'id_metodo': 1,
        'nombre': 'Pomodoro',
        'descripcion': 'Técnica de estudio basada en intervalos de 25 minutos'
      },
      {
        'idx': 1,
        'id_metodo': 2,
        'nombre': 'Flashcards',
        'descripcion': 'Técnica de estudio basada en tarjetas con preguntas y respuestas para reforzar la memoria.'
      },
      {
        'idx': 2,
        'id_metodo': 3,
        'nombre': 'Mapa Mental',
        'descripcion': 'Representación gráfica de ideas y conceptos organizada de forma radial para facilitar la comprensión y el recuerdo.'
      }
    ];

    await prefs.setStringList('metodos', _metodosDb.map((m) => json.encode(m)).toList());
    setState(() {});
  }

  @override
  void dispose() {
    titleController.dispose();
    super.dispose();
  }

  Future<void> _loadMaterias() async {
    final prefs = await SharedPreferences.getInstance();
    final materiasJson = prefs.getStringList('materias') ?? [];

    if (materiasJson.isEmpty) {
      await _saveMaterias();
    } else {
      setState(() {
        _materias = materiasJson.map((e) => Map<String, dynamic>.from(json.decode(e))).toList();
        if (materiaSel != null) {
          final m = _materias.where((t) => t['id'] == materiaSel!['id']);
          if (m.isNotEmpty) materiaSel = m.first;
        }
      });
    }
  }

  Future<void> _saveMaterias() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('materias', _materias.map((e) => json.encode(e)).toList());
  }

  Future<void> _addMateria(Map<String, dynamic> materia) async {
    _materias.add(materia);
    await _saveMaterias();
    setState(() => materiaSel = materia);
  }

  Future<void> saveSession() async {
    print('🔵 saveSession() iniciado');
    
    if (!_formKey.currentState!.validate()) {
      print('❌ Validación de formulario falló');
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id');
    
    print('👤 UserID obtenido de SharedPreferences: $userId');
    
    if (userId == null) {
      print('❌ No hay user_id en SharedPreferences');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay usuario activo. Regístrate primero.')),
      );
      return;
    }

    final metodoId = _selectedMetodoId;
    
    print('✅ Método ID seleccionado: $metodoId');

    final selectedDateTime = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
      selectedTime.hour,
      selectedTime.minute,
    );

    int? temaId;
    if (materiaSel != null) {
      temaId = materiaSel!['id_tema'] as int?;
    }

    final duracionSegundos = selectedDuration.inSeconds;

    final nueva = Sesion(
      idSesion: null,
      idUsuario: userId,
      idMetodo: metodoId,
      idTema: temaId,
      nombreSesion: titleController.text.trim(),
      fecha: selectedDateTime,
      esRapida: false,
      duracionTotal: duracionSegundos,
      estado: 'programada',
    );

    print('📤 Enviando sesión a Supabase:');
    print('   - Usuario ID: ${nueva.idUsuario}');
    print('   - Método ID: ${nueva.idMetodo}');
    print('   - Tema ID: ${nueva.idTema}');
    print('   - Nombre: ${nueva.nombreSesion}');
    print('   - Fecha: ${nueva.fecha}');
    print('   - Duración: ${nueva.duracionTotal} segundos');

    try {
      final creada = await SesionService.crearSesion(nueva);
      
      print('✅ Sesión creada exitosamente con ID: ${creada?.idSesion}');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Sesión creada con éxito"),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      print('❌ Error creando sesión: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error al guardar: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _lumiPickerButton({
    required IconData icon,
    required String label,
    String? value,
    VoidCallback? onTap,
  }) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final cardColor = themeProvider.cardColor;
    final textColor = themeProvider.textColor;
    final primary = themeProvider.primaryColor;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: themeProvider.isDarkMode ? Colors.grey[700]! : Colors.black26,
          ),
          boxShadow: const [BoxShadow(blurRadius: 4, offset: Offset(0, 2), color: Colors.black12)],
        ),
        child: Row(
          children: [
            Icon(icon, color: primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(fontSize: 12, color: textColor.withOpacity(0.7))),
                  Text(value ?? 'Seleccionar', style: TextStyle(fontSize: 16, color: textColor)),
                ],
              ),
            ),
            Icon(Icons.arrow_drop_down, color: textColor),
          ],
        ),
      ),
    );
  }

  Widget _materiaButton() {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final cardColor = themeProvider.cardColor;
    final textColor = themeProvider.textColor;
    final primary = themeProvider.primaryColor;
    final isSelected = materiaSel != null;
    final color = isSelected ? Color(materiaSel!['color'] as int) : Colors.black26;
    final label = isSelected ? materiaSel!['nombre'] as String : 'Elegir materia';
    
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () async {
        final picked = await showModalBottomSheet<Map<String, dynamic>>(
          context: context,
          backgroundColor: cardColor,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          builder: (ctx) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _materias.isEmpty
                    ? const Text('Aún no hay materias. Crea una con +.')
                    : ListView.separated(
                  itemCount: _materias.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final t = _materias[i];
                    return ListTile(
                      leading: CircleAvatar(backgroundColor: Color(t['color'] as int)),
                      title: Text(t['nombre'] as String),
                      onTap: () => Navigator.pop(ctx, t),
                    );
                  },
                ),
              ),
            );
          },
        );
        if (picked != null) setState(() => materiaSel = picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.black26),
          boxShadow: const [BoxShadow(blurRadius: 4, offset: Offset(0, 2), color: Colors.black12)],
        ),
        child: Row(
          children: [
            Container(width: 20, height: 20, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 10),
            Expanded(child: Text(label, style: const TextStyle(fontSize: 16))),
            const Icon(Icons.expand_more),
          ],
        ),
      ),
    );
  }

  Future<void> _openMateriaSheet() async {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final cardColor = themeProvider.cardColor;
    final textColor = themeProvider.textColor;
    final primary = themeProvider.primaryColor;
    
    final nameCtrl = TextEditingController();
    Color picked = _paletteOrganizada.first.first;
    
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setS) {
          final bottom = MediaQuery.of(ctx).viewInsets.bottom;
          return SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottom),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: 4,
                    width: 44,
                    decoration: BoxDecoration(
                      color: textColor.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  Text(
                    'Nueva Materia',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 18,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  TextField(
                    controller: nameCtrl,
                    style: TextStyle(color: textColor),
                    decoration: InputDecoration(
                      labelText: 'Nombre de la materia',
                      labelStyle: TextStyle(color: textColor.withOpacity(0.7)),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: textColor.withOpacity(0.3),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: primary, width: 2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Elige un color',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: textColor.withOpacity(0.8),
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      ..._paletteOrganizada.asMap().entries.map((entry) {
                        final index = entry.key;
                        final colores = entry.value;
                        
                        final categorias = [
                          'Rojos y Rosas',
                          'Naranjas y Amarillos',
                          'Verdes',
                          'Azules',
                          'Púrpuras y Violetas',
                          'Neutros',
                        ];
                        
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8, left: 4),
                                child: Text(
                                  categorias[index],
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: textColor.withOpacity(0.6),
                                  ),
                                ),
                              ),
                              
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: colores.map((c) {
                                  final sel = picked.value == c.value;
                                  return InkWell(
                                    onTap: () => setS(() => picked = c),
                                    borderRadius: BorderRadius.circular(12),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      width: sel ? 50 : 44,
                                      height: sel ? 50 : 44,
                                      decoration: BoxDecoration(
                                        color: c,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: sel ? Colors.white : c.withOpacity(0.3),
                                          width: sel ? 3 : 2,
                                        ),
                                        boxShadow: sel
                                            ? [
                                                BoxShadow(
                                                  color: c.withOpacity(0.5),
                                                  blurRadius: 12,
                                                  spreadRadius: 2,
                                                ),
                                              ]
                                            : [
                                                BoxShadow(
                                                  color: Colors.black.withOpacity(0.1),
                                                  blurRadius: 4,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ],
                                      ),
                                      child: sel
                                          ? const Icon(
                                              Icons.check,
                                              color: Colors.white,
                                              size: 28,
                                            )
                                          : null,
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                  
                  const SizedBox(height: 20),
                  
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: primary,
                            side: BorderSide(color: primary.withOpacity(0.45)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text(
                            'Cancelar',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            final name = nameCtrl.text.trim();
                            if (name.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Por favor ingresa un nombre'),
                                ),
                              );
                              return;
                            }
                            
                            final materia = {
                              'id': DateTime.now().microsecondsSinceEpoch.toString(),
                              'nombre': name,
                              'color': picked.value,
                            };
                            Navigator.pop(ctx);
                            _addMateria(materia);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            elevation: 2,
                          ),
                          child: const Text(
                            'Guardar',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        });
      },
    );
  }

  Future<void> openDurationSheet() async {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final cardColor = themeProvider.cardColor;
    final textColor = themeProvider.textColor;
    final primary = themeProvider.primaryColor;

    int h = selectedDuration.inHours.clamp(0, 23);
    int m = (selectedDuration.inMinutes % 60).clamp(0, 59);
    
    final hc = FixedExtentScrollController(initialItem: h);
    final mc = FixedExtentScrollController(initialItem: m);

    await showModalBottomSheet(
      context: context,
      backgroundColor: cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Duración',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 160,
                child: Row(
                  children: [
                    _colLabel(context, 'HH'),
                    Expanded(
                      child: CupertinoPicker(
                        scrollController: hc,
                        itemExtent: 36,
                        onSelectedItemChanged: (v) => h = v,
                        children: List.generate(24, (i) => Center(child: Text(_two(i)))),
                      ),
                    ),
                    _colLabel(context, 'MM'),
                    Expanded(
                      child: CupertinoPicker(
                        scrollController: mc,
                        itemExtent: 36,
                        onSelectedItemChanged: (v) => m = v,
                        children: List.generate(60, (i) => Center(child: Text(_two(i)))),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: primary,
                        side: BorderSide(color: primary.withOpacity(0.45)),
                        shape: const StadiumBorder(),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text(
                        'Cancelar',
                        style: TextStyle(fontWeight: FontWeight.w600), 
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          selectedDuration = Duration(hours: h, minutes: m);
                        });
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primary,
                        foregroundColor: Colors.white,
                        shape: const StadiumBorder(),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 2,
                      ),
                      child: const Text(
                        'Listo',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _colLabel(BuildContext context, String t) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final textColor = themeProvider.textColor;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Text(
        t,
        style: TextStyle(color: textColor.withOpacity(0.7)),
      ),
    );
  }

  static String _two(int n) => n.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final bg = themeProvider.backgroundColor;
    final primary = themeProvider.primaryColor;
    final cardColor = themeProvider.cardColor;
    final textColor = themeProvider.textColor;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Crear Nueva Sesión',
          style: TextStyle(
            color: primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: themeProvider.isDarkMode
                ? [
                    const Color(0xFF212C36),
                    const Color(0xFF313940),
                    bg,
                  ]
                : [
                    const Color(0xFFB6C9D6),
                    const Color(0xFFE6DACA),
                    bg,
                  ],
              stops: const [0.0, 0.75, 1.0],
            ),
          ),
        ),
      ),

      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: titleController,
              decoration: InputDecoration(
                labelText: 'Título',
                hintText: 'Escribe un título',
                filled: true,
                fillColor: cardColor,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Colors.black26),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFF7C6F66), width: 1),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: primary, width: 2),
                ),
                labelStyle: const TextStyle(color: Color(0xFF7C6F66)),
              ),
              validator: (v) => (v == null || v.isEmpty) ? 'Por favor ingresa un título' : null,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FormField<Map<String, dynamic>>(
                    validator: (_) => materiaSel == null ? 'Por favor selecciona una materia' : null,
                    builder: (state) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Materia', style: TextStyle(fontSize: 12, color: textColor)),
                        const SizedBox(height: 6),
                        _materiaButton(),
                        if (state.hasError)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(state.errorText!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  height: 48,
                  width: 48,
                  child: FloatingActionButton.small(
                    heroTag: 'addMateriaFab',
                    backgroundColor: primary,
                    onPressed: _openMateriaSheet,
                    child: Icon(Icons.add, color: cardColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _lumiPickerButton(
              icon: Icons.school,
              label: 'Método',
              value: _metodosDb
                  .firstWhere(
                    (m) => m['id_metodo'] == _selectedMetodoId,
                    orElse: () => {'nombre': 'Seleccionar'},
                  )['nombre']
                  ?.toString() ??
                  'Seleccionar',
              onTap: () async {
                final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
                final cardColor = themeProvider.cardColor;
                final textColor = themeProvider.textColor;
                final primary = themeProvider.primaryColor;
                
                final picked = await showModalBottomSheet<int>(
                  context: context,
                  backgroundColor: cardColor,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  builder: (_) {
                    return SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Selecciona un método',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: textColor,
                              ),
                            ),
                            const SizedBox(height: 16),
                            
                            ..._metodosDb.map((metodo) {
                              final id = metodo['id_metodo'] as int;
                              final nombre = metodo['nombre'] as String;
                              final descripcion = metodo['descripcion'] as String? ?? 'Sin descripción disponible';
                              final icono = getIconoMetodo(nombre);
                              
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: primary.withOpacity(0.05),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: _selectedMetodoId == id
                                          ? primary
                                          : primary.withOpacity(0.2),
                                      width: _selectedMetodoId == id ? 2 : 1,
                                    ),
                                  ),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 4,
                                    ),
                                    leading: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: primary.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(icono, color: primary, size: 24),
                                    ),
                                    title: Text(
                                      nombre,
                                      style: TextStyle(
                                        color: textColor,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 16,
                                      ),
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: Icon(
                                            Icons.info_outline,
                                            color: primary,
                                            size: 24,
                                          ),
                                          onPressed: () {
                                            showDialog(
                                              context: context,
                                              builder: (dialogContext) => AlertDialog(
                                                backgroundColor: cardColor,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(16),
                                                ),
                                                title: Row(
                                                  children: [
                                                    Icon(icono, color: primary),
                                                    const SizedBox(width: 12),
                                                    Expanded(
                                                      child: Text(
                                                        nombre,
                                                        style: TextStyle(
                                                          color: primary,
                                                          fontSize: 20,
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                content: Text(
                                                  descripcion,
                                                  style: TextStyle(
                                                    color: textColor,
                                                    fontSize: 15,
                                                    height: 1.5,
                                                  ),
                                                ),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () =>
                                                        Navigator.pop(dialogContext),
                                                    child: Text(
                                                      'ENTENDIDO',
                                                      style: TextStyle(
                                                        color: primary,
                                                        fontWeight: FontWeight.w600,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          },
                                          tooltip: 'Ver información',
                                        ),
                                        const SizedBox(width: 4),
                                      ],
                                    ),
                                    onTap: () => Navigator.pop(context, id),
                                  ),
                                ),
                              );
                            }).toList(),
                          ],
                        ),
                      ),
                    );
                  },
                );
                
                if (picked != null) {
                  setState(() {
                    _selectedMetodoId = picked;
                    print('✅ Método seleccionado ID: $_selectedMetodoId');
                  });
                }
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _lumiPickerButton(
                    icon: Icons.calendar_today,
                    label: 'Fecha',
                    value: '${_two(selectedDate.day)}/${_two(selectedDate.month)}/${selectedDate.year}',
                    onTap: () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime.now().add(const Duration(days: -30)),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (d != null) setState(() => selectedDate = d);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _lumiPickerButton(
                    icon: Icons.access_time,
                    label: 'Hora',
                    value: '${_two(selectedTime.hour)}:${_two(selectedTime.minute)}',
                    onTap: () async {
                      final t = await showTimePicker(context: context, initialTime: selectedTime);
                      if (t != null) setState(() => selectedTime = t);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _lumiPickerButton(
              icon: Icons.timer,
              label: 'Duración',
              value: '${_two(selectedDuration.inHours)}:${_two(selectedDuration.inMinutes % 60)}',
              onTap: openDurationSheet,
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: saveSession,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  elevation: 2,
                ),
                child: const Text('Crear Sesión', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
