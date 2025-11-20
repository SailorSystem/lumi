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
  final _titleController = TextEditingController();

  Map<String, dynamic>? _materiaSel; // Renombrado de _temaSel
  String _selectedMetodo = 'Pomodoro';
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  Duration _dur = const Duration(hours: 0, minutes: 0, seconds: 0);
  List<Map<String, dynamic>> _materias = []; // Renombrado de _temas
  static const List<Color> _palette = [
    Colors.blue, Colors.red, Colors.green, Colors.amber,
    Colors.purple, Colors.orange, Colors.teal, Colors.pink,
    Colors.indigo, Colors.brown, Colors.cyan, Colors.lime,
  ];

  @override
  void initState() {
    super.initState();
    _loadMaterias(); // Renombrado de _loadTemas
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  final List<Map<String, dynamic>> _metodos = [
    {'nombre': 'Pomodoro', 'icono': Icons.timelapse},
    {'nombre': 'Flashcards', 'icono': Icons.style},
    {'nombre': 'Mapa Mental', 'icono': Icons.account_tree},
    // Puedes agregar más métodos aquí...
  ];

  // --- LÓGICA DE MATERIAS ACTUALIZADA ---

  List<Map<String, dynamic>> _getDefaultMaterias() {
    // Esta es tu lista inicial
    return [
      {
        'id': 'default_math',
        'nombre': 'Matemática',
        'color': Colors.blue.value,
      },
      {
        'id': 'default_physics',
        'nombre': 'Física',
        'color': Colors.red.value,
      },
      {
        'id': 'default_biology',
        'nombre': 'Biología',
        'color': Colors.green.value,
      },
    ];
  }

  Future<void> _loadMaterias() async {
    final prefs = await SharedPreferences.getInstance();
    // Buscamos 'materias' en lugar de 'temas'
    final materiasJson = prefs.getStringList('materias') ?? [];

    if (materiasJson.isEmpty) {
      // Si no hay materias guardadas, cargamos las de por defecto
      setState(() {
        _materias = _getDefaultMaterias();
      });
      // Y las guardamos para la próxima vez
      await _saveMaterias();
    } else {
      // Si ya hay materias guardadas, simplemente las cargamos
      setState(() {
        _materias = materiasJson.map((e) => Map<String, dynamic>.from(json.decode(e))).toList();
        if (_materiaSel != null) {
          final m = _materias.where((t) => t['id'] == _materiaSel!['id']);
          if (m.isNotEmpty) _materiaSel = m.first;
        }
      });
    }
  }

  Future<void> _saveMaterias() async {
    final prefs = await SharedPreferences.getInstance();
    // Guardamos en 'materias'
    await prefs.setStringList('materias', _materias.map((e) => json.encode(e)).toList());
  }

  Future<void> _addMateria(Map<String, dynamic> materia) async {
    _materias.add(materia);
    await _saveMaterias();
    setState(() => _materiaSel = materia);
  }

  // --- FIN DE LÓGICA DE MATERIAS ---

  Future<void> _saveSession() async {
    if (!_formKey.currentState!.validate()) return;

    // Obtén el usuario actual (te aseguras arriba que userId != null)
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id');

    if (userId == null) {
      // No hay usuario en prefs: pedir registro / mostrar error
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay usuario activo. Regístrate primero.')),
      );
      return;
    }

    // Mapear método a id_metodo si tienes IDs. Por ahora asumimos Pomodoro = 1
    int? metodoId;
    if (_selectedMetodo.toLowerCase() == 'pomodoro') metodoId = 1;
    // Si luego tienes una tabla metodos, ajusta para buscar el id real.

    // Intentaremos mapear materia a id_tema si es numérico; si no, lo dejamos null
    int? idTema;
    if (_materiaSel != null) {
      var mid = _materiaSel!['id'];
      if (mid is int) {
        idTema = mid;
      } else {
        // Nuevo tema: crea primero en la base, pasando el nombre como "titulo", el color en string, y el usuario asociado
        final nuevoTema = await TemaService.crearTema(
          Tema(
            titulo: _materiaSel!['nombre'] as String,
            colorHex: (_materiaSel!['color'] as int).toRadixString(16),
            idUsuario: userId!, // <-- ESTA ES LA LÍNEA CRÍTICA
          ),
        );
        if (nuevoTema == null || nuevoTema.idTema == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No se pudo crear la materia en la base.')),
          );
          return;
        }
        idTema = nuevoTema.idTema!;
        _materiaSel!['id'] = idTema; // Actualiza para futuras sesiones
      }
    }

    final fecha = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    final duracionSegundos = _dur.inSeconds > 0 ? _dur.inSeconds : null;

    final nuevaSesion = Sesion(
      idSesion: null,
      idUsuario: userId,
      idMetodo: metodoId,
      idTema: idTema,
      nombreSesion: _titleController.text.trim(),
      fecha: fecha,
      esRapida: false,
      duracionTotal: duracionSegundos,
    );

    // Mostrar loading simple
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final creado = await SesionService.crearSesion(nuevaSesion);

      Navigator.of(context).pop(); // quitar loading

      if (creado == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo crear la sesión en Supabase.')),
        );
        return;
      }

      // Opcional: guardar una versión local (para compatibilidad con tu home si aún lee prefs)
      final sessionsLocal = prefs.getStringList('completed_sessions') ?? [];
      final localMap = {
        'id_sesion': creado.idSesion,
        'id_usuario': creado.idUsuario,
        'id_metodo': creado.idMetodo,
        'id_tema': creado.idTema,
        'titulo': creado.nombreSesion,
        'fecha': creado.fecha.toIso8601String(),
        'es_rapida': creado.esRapida,
        'duracion_total': creado.duracionTotal,
        'estado': 'programada',
      };
      sessionsLocal.add(json.encode(localMap));
      await prefs.setStringList('completed_sessions', sessionsLocal);

      // Confirmación y volver al Home (o mostrar la sesión recién creada)
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sesión creada correctamente.')),
      );

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (_) => false,
      );
    } catch (e) {
      Navigator.of(context).pop(); // quitar loading si hay error
      debugPrint('Error creando sesión en Supabase: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error creando sesión: $e')),
      );
    }
  }



  Widget _lumiPickerButton({
    required IconData icon,
    required String label,
    String? value,
    VoidCallback? onTap,
  }) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final cardColor  = themeProvider.cardColor;
    final textColor  = themeProvider.textColor;
    final primary    = themeProvider.primaryColor;

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
          boxShadow: const [BoxShadow(blurRadius: 4, offset: Offset(0,2), color: Colors.black12)],
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


  // Widget renombrado de _temaButton
  Widget _materiaButton() {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final cardColor  = themeProvider.cardColor;
    final textColor  = themeProvider.textColor;
    final primary    = themeProvider.primaryColor;
    final isSelected = _materiaSel != null;
    final color = isSelected ? Color(_materiaSel!['color'] as int) : Colors.black26;
    // Texto cambiado a "Elegir materia"
    final label = isSelected ? _materiaSel!['nombre'] as String : 'Elegir materia';
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () async {
        final picked = await showModalBottomSheet<Map<String, dynamic>>(
          context: context,
          backgroundColor: cardColor,
          // LÍNEA CORREGIDA (1 de 4)
          shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          builder: (ctx) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _materias.isEmpty
                // Texto cambiado a "materias"
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
        if (picked != null) setState(() => _materiaSel = picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.black26),
          boxShadow: const [BoxShadow(blurRadius: 4, offset: Offset(0,2), color: Colors.black12)],
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

  // Renombrado de _openTemaSheet
  Future<void> _openMateriaSheet() async {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final cardColor  = themeProvider.cardColor;
    final textColor  = themeProvider.textColor;
    final primary    = themeProvider.primaryColor;
    final nameCtrl = TextEditingController();
    Color picked = _palette.first;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: cardColor,
      // LÍNEA CORREGIDA (2 de 4)
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setS) {
          final bottom = MediaQuery.of(ctx).viewInsets.bottom;
          return Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottom),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(height: 4, width: 44, decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 12),
              // Texto cambiado
              const Text('Nueva Materia', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18)),
              const SizedBox(height: 12),
              TextField(
                controller: nameCtrl,
                // Texto cambiado
                decoration: const InputDecoration(labelText: 'Nombre de la materia', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10, runSpacing: 10,
                children: _palette.map((c) {
                  final sel = picked.value == c.value;
                  return InkWell(
                    onTap: () => setS(() => picked = c),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: c, shape: BoxShape.circle,
                        border: Border.all(color: sel ? Colors.black54 : Colors.black12, width: sel ? 2 : 1),
                        boxShadow: [if (sel) const BoxShadow(blurRadius: 6, spreadRadius: 1)],
                      ),
                      child: sel ? const Icon(Icons.check, color: Colors.white) : null,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: primary,
                      side: BorderSide(color: primary.withOpacity(0.45)),
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Cancelar', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      final name = nameCtrl.text.trim();
                      if (name.isEmpty) return;
                      // Variable renombrada
                      final materia = {
                        'id': DateTime.now().microsecondsSinceEpoch.toString(),
                        'nombre': name,
                        'color': picked.value,
                      };
                      Navigator.pop(ctx);
                      _addMateria(materia); // Función renombrada
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primary,
                      foregroundColor: Colors.white,
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 2,
                    ),
                    child: const Text('Guardar', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ]),
            ]),
          );
        });
      },
    );
  }

  Future<void> _openDurationSheet() async {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final cardColor  = themeProvider.cardColor;
    final textColor  = themeProvider.textColor;
    final primary    = themeProvider.primaryColor;
    int h = _dur.inHours.clamp(0, 23);
    int m = (_dur.inMinutes % 60).clamp(0, 59);
    int s = (_dur.inSeconds % 60).clamp(0, 59);
    final hc = FixedExtentScrollController(initialItem: h);
    final mc = FixedExtentScrollController(initialItem: m);
    final sc = FixedExtentScrollController(initialItem: s);
    await showModalBottomSheet(
      context: context,
      backgroundColor: cardColor,
      // LÍNEA CORREGIDA (3 de 4)
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('Duración', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18)),
              const SizedBox(height: 8),
              SizedBox(
                height: 160,
                child: Row(
                  children: [
                    _colLabel(context, 'HH'),
                    Expanded(child: CupertinoPicker(
                      scrollController: hc,
                      itemExtent: 36,
                      onSelectedItemChanged: (v) => h = v,
                      children: List.generate(24, (i) => Center(child: Text(_two(i)))),
                    )),
                    _colLabel(context, 'MM'),
                    Expanded(child: CupertinoPicker(
                      scrollController: mc,
                      itemExtent: 36,
                      onSelectedItemChanged: (v) => m = v,
                      children: List.generate(60, (i) => Center(child: Text(_two(i)))),
                    )),
                    _colLabel(context, 'SS'),
                    Expanded(child: CupertinoPicker(
                      scrollController: sc,
                      itemExtent: 36,
                      onSelectedItemChanged: (v) => s = v,
                      children: List.generate(60, (i) => Center(child: Text(_two(i)))),
                    )),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: primary,
                      side: BorderSide(color: primary.withOpacity(0.45)),
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Cancelar', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() => _dur = Duration(hours: h, minutes: m, seconds: s));
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primary,
                      foregroundColor: Colors.white,
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 2,
                    ),
                    child: const Text('Listo', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ]),
            ]),
          ),
        );
      },
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
    final bg         = themeProvider.backgroundColor;
    final appBarCol  = themeProvider.appBarColor;
    final primary    = themeProvider.primaryColor;
    final cardColor  = themeProvider.cardColor;
    final textColor  = themeProvider.textColor;

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
              controller: _titleController,
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
                    // Validación y variable actualizadas
                    validator: (_) => _materiaSel == null ? 'Por favor selecciona una materia' : null,
                    builder: (state) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Texto cambiado
                        Text('Materia', style: TextStyle(fontSize: 12, color: textColor )),
                        const SizedBox(height: 6),
                        _materiaButton(), // Función renombrada
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
                  height: 48, width: 48,
                  child: FloatingActionButton.small(
                    heroTag: 'addMateriaFab', // HeroTag cambiado
                    backgroundColor: primary,
                    onPressed: _openMateriaSheet, // Función renombrada
                    child: Icon(Icons.add, color: cardColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _lumiPickerButton(
              icon: Icons.school,
              label: 'Método',
              value: _selectedMetodo,
              onTap: () async {
                final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
                final cardColor  = themeProvider.cardColor;
                final textColor  = themeProvider.textColor;

                final v = await showModalBottomSheet<String>(
                  context: context,
                  backgroundColor: cardColor,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
                  builder: (_) => SafeArea(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: _metodos.map((metodo) => ListTile(
                        leading: Icon(metodo['icono'], color: textColor),
                        title: Text(metodo['nombre'], style: TextStyle(color: textColor)),
                        onTap: () => Navigator.pop(context, metodo['nombre']),
                      )).toList(),
                    ),
                  ),
                );
                if (v != null) setState(() => _selectedMetodo = v);
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _lumiPickerButton(
                    icon: Icons.calendar_today,
                    label: 'Fecha',
                    value: '${_two(_selectedDate.day)}/${_two(_selectedDate.month)}/${_selectedDate.year}',
                    onTap: () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate,
                        firstDate: DateTime.now().add(const Duration(days: -30)), // Permitir fechas pasadas por si acaso
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (d != null) setState(() => _selectedDate = d);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _lumiPickerButton(
                    icon: Icons.access_time,
                    label: 'Hora',
                    value: '${_two(_selectedTime.hour)}:${_two(_selectedTime.minute)}',
                    onTap: () async {
                      final t = await showTimePicker(context: context, initialTime: _selectedTime);
                      if (t != null) setState(() => _selectedTime = t);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _lumiPickerButton(
              icon: Icons.timer,
              label: 'Duración',
              value: '${_two(_dur.inHours)}:${_two(_dur.inMinutes % 60)}:${_two(_dur.inSeconds % 60)}',
              onTap: _openDurationSheet,
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: _saveSession,
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