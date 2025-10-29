import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_screen.dart';

class CrearNuevaSesionScreen extends StatefulWidget {
  const CrearNuevaSesionScreen({super.key});
  @override
  State<CrearNuevaSesionScreen> createState() => _CrearNuevaSesionScreenState();
}

class _CrearNuevaSesionScreenState extends State<CrearNuevaSesionScreen> {
  static const bg = Color(0xFFD9CBBE);
  static const appbar = Color(0xFFB49D87);
  static const primary = Color(0xFF2C4459);

  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();

  Map<String, dynamic>? _temaSel;
  String _selectedMetodo = 'Pomodoro';
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  Duration _dur = const Duration(hours: 0, minutes: 0, seconds: 0);
  List<Map<String, dynamic>> _temas = [];
  static const List<Color> _palette = [
    Colors.blue, Colors.red, Colors.green, Colors.amber,
    Colors.purple, Colors.orange, Colors.teal, Colors.pink,
    Colors.indigo, Colors.brown, Colors.cyan, Colors.lime,
  ];

  @override
  void initState() {
    super.initState();
    _loadTemas();
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _loadTemas() async {
    final prefs = await SharedPreferences.getInstance();
    final temasJson = prefs.getStringList('temas') ?? [];
    setState(() {
      _temas = temasJson.map((e) => Map<String, dynamic>.from(json.decode(e))).toList();
      if (_temaSel != null) {
        final m = _temas.where((t) => t['id'] == _temaSel!['id']);
        if (m.isNotEmpty) _temaSel = m.first;
      }
    });
  }

  Future<void> _saveTemas() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('temas', _temas.map((e) => json.encode(e)).toList());
  }

  Future<void> _addTema(Map<String, dynamic> tema) async {
    _temas.add(tema);
    await _saveTemas();
    setState(() => _temaSel = tema);
  }

  Future<void> _saveSession() async {
    if (!_formKey.currentState!.validate()) return;
    final session = {
      'titulo': _titleController.text,
      'tema': _temaSel == null ? null : {
        'id': _temaSel!['id'], 'nombre': _temaSel!['nombre'], 'color': _temaSel!['color']
      },
      'metodo': _selectedMetodo,
      'fecha': DateTime(
        _selectedDate.year, _selectedDate.month, _selectedDate.day,
        _selectedTime.hour, _selectedTime.minute,
      ).toIso8601String(),
      'duracion': _two(_dur.inHours) + ':' + _two(_dur.inMinutes % 60) + ':' + _two(_dur.inSeconds % 60),
      'estado': 'pendiente',
    };
    final prefs = await SharedPreferences.getInstance();
    final sessions = prefs.getStringList('completed_sessions') ?? [];
    sessions.add(json.encode(session));
    await prefs.setStringList('completed_sessions', sessions);
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (_) => false,
    );
  }

  Widget _lumiPickerButton({
    required IconData icon,
    required String label,
    String? value,
    VoidCallback? onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFF6EFE9),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.black26),
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
                  Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54)),
                  const SizedBox(height: 2),
                  Text(value ?? 'Seleccionar', style: const TextStyle(fontSize: 16)),
                ],
              ),
            ),
            const Icon(Icons.arrow_drop_down),
          ],
        ),
      ),
    );
  }

  Widget _temaButton() {
    final isSelected = _temaSel != null;
    final color = isSelected ? Color(_temaSel!['color'] as int) : Colors.black26;
    final label = isSelected ? _temaSel!['nombre'] as String : 'Elegir tema';
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () async {
        final picked = await showModalBottomSheet<Map<String, dynamic>>(
          context: context,
          backgroundColor: const Color(0xFFF6EFE9),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          builder: (ctx) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _temas.isEmpty
                    ? const Text('Aún no hay temas. Crea uno con +.')
                    : ListView.separated(
                        itemCount: _temas.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final t = _temas[i];
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
        if (picked != null) setState(() => _temaSel = picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFF6EFE9),
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

  Future<void> _openTemaSheet() async {
    final nameCtrl = TextEditingController();
    Color picked = _palette.first;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFF6EFE9),
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
              const Text('Nuevo Tema', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18)),
              const SizedBox(height: 12),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Nombre del tema', border: OutlineInputBorder()),
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
                      final tema = {
                        'id': DateTime.now().microsecondsSinceEpoch.toString(),
                        'nombre': name,
                        'color': picked.value,
                      };
                      Navigator.pop(ctx);
                      _addTema(tema);
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
    int h = _dur.inHours.clamp(0, 23);
    int m = (_dur.inMinutes % 60).clamp(0, 59);
    int s = (_dur.inSeconds % 60).clamp(0, 59);
    final hc = FixedExtentScrollController(initialItem: h);
    final mc = FixedExtentScrollController(initialItem: m);
    final sc = FixedExtentScrollController(initialItem: s);
    await showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFFF6EFE9),
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
                    _colLabel('HH'),
                    Expanded(child: CupertinoPicker(
                      scrollController: hc,
                      itemExtent: 36,
                      onSelectedItemChanged: (v) => h = v,
                      children: List.generate(24, (i) => Center(child: Text(_two(i)))),
                    )),
                    _colLabel('MM'),
                    Expanded(child: CupertinoPicker(
                      scrollController: mc,
                      itemExtent: 36,
                      onSelectedItemChanged: (v) => m = v,
                      children: List.generate(60, (i) => Center(child: Text(_two(i)))),
                    )),
                    _colLabel('SS'),
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

  static Widget _colLabel(String t) =>
      Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: Text(t, style: const TextStyle(color: Colors.black54)));

  static String _two(int n) => n.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(backgroundColor: appbar, title: const Text('Crear Nueva Sesión')),
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
                fillColor: const Color(0xFFEFE3D8),
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
                  borderSide: const BorderSide(color: primary, width: 2),
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
                    validator: (_) => _temaSel == null ? 'Por favor selecciona un tema' : null,
                    builder: (state) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Tema', style: TextStyle(fontSize: 12, color: Colors.black87)),
                        const SizedBox(height: 6),
                        _temaButton(),
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
                    heroTag: 'addTemaFab',
                    backgroundColor: primary,
                    onPressed: _openTemaSheet,
                    child: const Icon(Icons.add, color: Colors.white),
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
                final v = await showModalBottomSheet<String>(
                  context: context,
                  backgroundColor: const Color(0xFFF6EFE9),
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
                  builder: (_) => SafeArea(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      ListTile(
                        leading: const Icon(Icons.timelapse),
                        title: const Text('Pomodoro'),
                        onTap: () => Navigator.pop(context, 'Pomodoro'),
                      ),
                    ]),
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
                        firstDate: DateTime.now(),
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
