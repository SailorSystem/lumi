import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Configuration keys for shared preferences
class SettingsKeys {
  static const notifs = 'notifs';
  static const sonido = 'sonido';
  static const vibrar = 'vibrar';
  static const metodoDefault = 'metodo_default';
  static const focoMin = 'foco_min';
  static const descansoMin = 'descanso_min';
  static const idioma = 'idioma';
}

/// Settings screen that allows users to configure app preferences
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Settings state
  late bool _notifs;
  late bool _sonido;
  late bool _vibrar;
  late String _metodoDefault;
  late int _focoMin;
  late int _descansoMin;
  late String _idioma;

  /// Default settings values
  static const Map<String, dynamic> _defaultSettings = {
    'notifs': true,
    'sonido': true,
    'vibrar': false,
    'metodoDefault': 'Pomodoro 25/5',
    'focoMin': 25,
    'descansoMin': 5,
    'idioma': 'es'
  };

  static const List<String> _metodos = ['Pomodoro 25/5', '52/17', '80/20'];
  static const List<String> _idiomas = ['es', 'en'];

  @override
  void initState() {
    super.initState();
    _initializeSettings();
    _load();
  }

  /// Initialize settings with default values
  void _initializeSettings() {
    _notifs = _defaultSettings['notifs'] as bool;
    _sonido = _defaultSettings['sonido'] as bool;
    _vibrar = _defaultSettings['vibrar'] as bool;
    _metodoDefault = _defaultSettings['metodoDefault'] as String;
    _focoMin = _defaultSettings['focoMin'] as int;
    _descansoMin = _defaultSettings['descansoMin'] as int;
    _idioma = _defaultSettings['idioma'] as String;
  }

  /// Load settings from SharedPreferences
  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _notifs = prefs.getBool(SettingsKeys.notifs) ?? _defaultSettings['notifs'] as bool;
        _sonido = prefs.getBool(SettingsKeys.sonido) ?? _defaultSettings['sonido'] as bool;
        _vibrar = prefs.getBool(SettingsKeys.vibrar) ?? _defaultSettings['vibrar'] as bool;
        _metodoDefault = prefs.getString(SettingsKeys.metodoDefault) ?? _defaultSettings['metodoDefault'] as String;
        _focoMin = prefs.getInt(SettingsKeys.focoMin) ?? _defaultSettings['focoMin'] as int;
        _descansoMin = prefs.getInt(SettingsKeys.descansoMin) ?? _defaultSettings['descansoMin'] as int;
        _idioma = prefs.getString(SettingsKeys.idioma) ?? _defaultSettings['idioma'] as String;
      });
    } catch (e) {
      if (!mounted) return;
      _showErrorMessage('Error al cargar ajustes');
    }
  }

  /// Save settings to SharedPreferences
  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await Future.wait([
        prefs.setBool(SettingsKeys.notifs, _notifs),
        prefs.setBool(SettingsKeys.sonido, _sonido),
        prefs.setBool(SettingsKeys.vibrar, _vibrar),
        prefs.setString(SettingsKeys.metodoDefault, _metodoDefault),
        prefs.setInt(SettingsKeys.focoMin, _focoMin),
        prefs.setInt(SettingsKeys.descansoMin, _descansoMin),
        prefs.setString(SettingsKeys.idioma, _idioma),
      ]);

      if (!mounted) return;
      _showMessage('Ajustes guardados');
    } catch (e) {
      if (!mounted) return;
      _showErrorMessage('Error al guardar ajustes');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  Future<void> _reset() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Restablecer ajustes'),
        content: const Text('Esto volverá todo a valores predeterminados.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Restablecer')),
        ],
      ),
    );
    if (ok != true) return;
    final p = await SharedPreferences.getInstance();
    await p.clear();
    if (!mounted) return;
    setState(() {
      _notifs = true;
      _sonido = true;
      _vibrar = false;
      _metodoDefault = 'Pomodoro 25/5';
      _focoMin = 25;
      _descansoMin = 5;
      _idioma = 'es';
    });
  }

  @override
  Widget build(BuildContext context) {
    const fondo = Color(0xFFD9CBBE);
    return Scaffold(
      backgroundColor: fondo,
      appBar: AppBar(
        title: const Text('Ajustes'),
        backgroundColor: fondo,
        foregroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
        actions: [
          IconButton(onPressed: _save, icon: const Icon(Icons.save)),
        ],
      ),
      body: ListView(
        children: [
          const _Section('Notificaciones'),
          SwitchListTile(
            title: const Text('Activar notificaciones'),
            value: _notifs,
            onChanged: (v) => setState(() => _notifs = v),
          ),
          SwitchListTile(
            title: const Text('Sonido'),
            value: _sonido,
            onChanged: (v) => setState(() => _sonido = v),
          ),
          SwitchListTile(
            title: const Text('Vibración'),
            value: _vibrar,
            onChanged: (v) => setState(() => _vibrar = v),
          ),

          const _Section('Temporizador por defecto'),
          ListTile(
            title: const Text('Método'),
            trailing: DropdownButton<String>(
              value: _metodoDefault,
              items: _metodos.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
              onChanged: (v) => setState(() => _metodoDefault = v!),
            ),
          ),
          ListTile(
            title: const Text('Minutos de foco'),
            trailing: _StepperInt(
              value: _focoMin,
              min: 1,
              max: 180,
              onChanged: (v) => setState(() => _focoMin = v),
            ),
          ),
          ListTile(
            title: const Text('Minutos de descanso'),
            trailing: _StepperInt(
              value: _descansoMin,
              min: 1,
              max: 120,
              onChanged: (v) => setState(() => _descansoMin = v),
            ),
          ),

          const _Section('App'),
          ListTile(
            title: const Text('Idioma'),
            trailing: DropdownButton<String>(
              value: _idioma,
              items: _idiomas.map((i) => DropdownMenuItem(value: i, child: Text(i.toUpperCase()))).toList(),
              onChanged: (v) => setState(() => _idioma = v!),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.restore),
            title: const Text('Restablecer ajustes'),
            onTap: _reset,
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  
  const _Section(this.title, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withOpacity(.05),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
    );
  }
}

class _StepperInt extends StatelessWidget {
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;
  
  const _StepperInt({
    required this.value,
    required this.min,
    required this.max, 
    required this.onChanged,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: value > min ? () => onChanged(value - 1) : null, 
          icon: const Icon(Icons.remove)
        ),
        Text('$value'),
        IconButton(
          onPressed: value < max ? () => onChanged(value + 1) : null, 
          icon: const Icon(Icons.add)
        ),
      ],
    );
  }
}
