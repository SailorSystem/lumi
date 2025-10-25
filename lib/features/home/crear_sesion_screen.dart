import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'home_screen.dart';  // Add this import
import 'start_screen.dart'; // import relativo correcto (mismo directorio)

class CrearNuevaSesionScreen extends StatefulWidget {
  const CrearNuevaSesionScreen({super.key});

  @override
  State<CrearNuevaSesionScreen> createState() => _CrearNuevaSesionScreenState();
}

class _CrearNuevaSesionScreenState extends State<CrearNuevaSesionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _timeController = TextEditingController();
  String? _selectedTema;
  String _selectedMetodo = 'Pomodoro';
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  List<Map<String, dynamic>> _temas = [];

  @override
  void initState() {
    super.initState();
    _loadTemas();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _timeController.dispose();
    super.dispose();
  }

  Future<void> _loadTemas() async {
    final prefs = await SharedPreferences.getInstance();
    final temasJson = prefs.getStringList('temas') ?? [];
    setState(() {
      _temas = temasJson.map((e) => Map<String, dynamic>.from(json.decode(e))).toList();
    });
  }

  Future<void> _saveTema(String nombre, Color color) async {
    final prefs = await SharedPreferences.getInstance();
    final tema = {
      'nombre': nombre,
      'color': color.value,
    };
    _temas.add(tema);
    await prefs.setStringList(
      'temas',
      _temas.map((e) => json.encode(e)).toList(),
    );
    setState(() {
      _selectedTema = nombre;
    });
  }

  Future<void> _saveSession() async {
    if (!_formKey.currentState!.validate()) return;

    final session = {
      'titulo': _titleController.text,
      'tema': _selectedTema,
      'metodo': _selectedMetodo,
      'fecha': DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      ).toIso8601String(),
      'duracion': _timeController.text,
      'estado': 'pendiente',
    };

    final prefs = await SharedPreferences.getInstance();
    final sessions = prefs.getStringList('completed_sessions') ?? [];
    sessions.add(json.encode(session));
    await prefs.setStringList('completed_sessions', sessions);

    // programar notificaciones para esta sesión
    await scheduleSessionNotifications(session);

    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const HomeScreen()),
      (route) => false,
    );
  }

  void _showMetodoInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Método Pomodoro'),
        content: const Text(
          'La técnica Pomodoro consiste en usar un temporizador para dividir el trabajo '
          'en intervalos de 25 minutos de duración, separados por descansos cortos de 5 minutos.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  Future<void> _showNewTemaDialog() async {
    final nameController = TextEditingController();
    Color selectedColor = Colors.blue;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nuevo Tema'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Nombre del tema',
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: [
                Colors.blue,
                Colors.red,
                Colors.green,
                Colors.yellow,
                Colors.purple,
                Colors.orange,
              ].map((color) => InkWell(
                onTap: () {
                  selectedColor = color;
                  Navigator.pop(context);
                  _saveTema(nameController.text, color);
                },
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
              )).toList(),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFD9CBBE),
      appBar: AppBar(
        backgroundColor: const Color(0xFFB49D87),
        title: const Text('Crear Nueva Sesión'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Título
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Título',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Por favor ingresa un título';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Tema
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedTema,
                    decoration: const InputDecoration(
                      labelText: 'Tema',
                      border: OutlineInputBorder(),
                    ),
                    items: _temas.map((tema) {
                      return DropdownMenuItem(
                        value: tema['nombre'] as String,
                        child: Row(
                          children: [
                            Container(
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                color: Color(tema['color'] as int),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(tema['nombre'] as String),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (value) => setState(() => _selectedTema = value),
                    validator: (value) {
                      if (value == null) {
                        return 'Por favor selecciona un tema';
                      }
                      return null;
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: _showNewTemaDialog,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Método
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedMetodo,
                    decoration: const InputDecoration(
                      labelText: 'Método',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'Pomodoro',
                        child: Text('Pomodoro'),
                      ),
                    ],
                    onChanged: (value) => setState(() => _selectedMetodo = value!),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.info_outline),
                  onPressed: _showMetodoInfo,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Fecha y Hora
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_today),
                    label: Text(
                      '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                    ),
                    onPressed: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (date != null) {
                        setState(() => _selectedDate = date);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.access_time),
                    label: Text(
                      '${_selectedTime.hour}:${_selectedTime.minute.toString().padLeft(2, '0')}',
                    ),
                    onPressed: () async {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: _selectedTime,
                      );
                      if (time != null) {
                        setState(() => _selectedTime = time);
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Duración
            TextFormField(
              controller: _timeController,
              decoration: const InputDecoration(
                labelText: 'Duración',
                hintText: '00:00',
                border: OutlineInputBorder(),
                suffixIcon: Icon(Icons.access_time),
              ),
              keyboardType: TextInputType.datetime,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9:]')),
                LengthLimitingTextInputFormatter(5),
                _TimeInputFormatter(),
              ],
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Por favor ingresa la duración';
                }
                if (!RegExp(r'^([0-9]{2}):([0-9]{2})$').hasMatch(value)) {
                  return 'Formato inválido. Usa HH:MM';
                }
                final parts = value.split(':');
                final hours = int.parse(parts[0]);
                final minutes = int.parse(parts[1]);
                if (hours > 23 || minutes > 59) {
                  return 'Tiempo inválido';
                }
                return null;
              },
            ),
            const SizedBox(height: 32),

            // Botón Crear
            ElevatedButton(
              onPressed: _saveSession,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2C4459),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Crear Sesión'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimeInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var text = newValue.text;

    if (text.length > 5) {
      return oldValue;
    }

    // Add colon automatically
    if (text.length == 2 && oldValue.text.length == 1) {
      text = '$text:';
    }

    // Handle backspace when colon is present
    if (text.length == 2 && oldValue.text.length == 3) {
      text = text[0];
    }

    return newValue.copyWith(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
