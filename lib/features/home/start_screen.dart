import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StartScreen extends StatefulWidget {
  // Ahora acepta un parámetro opcional `session`
  // Puede venir desde CrearSesionScreen (mapa con keys como 'metodoLabel', 'focoMin', 'descansoMin' o 'method', 'focusMinutes'...)
  final Map<String, dynamic>? session;

  const StartScreen({super.key, this.session});

  @override
  State<StartScreen> createState() => _StartScreenState();
}

class _StartScreenState extends State<StartScreen> {
  int _focusMinutes = 25;
  int _breakMinutes = 5;
  String _selectedMethod = 'Pomodoro 25/5';

  // Métodos disponibles con sus tiempos
  static const Map<String, List<int>> _methodTimes = {
    'Pomodoro 25/5': [25, 5],
    '52/17': [52, 17],
    '80/20': [80, 20],
  };

  @override
  void initState() {
    super.initState();

    // Si se pasó una session desde CrearSesionScreen, la aplicamos.
    if (widget.session != null) {
      _applySession(widget.session!);
    } else {
      // Si no, cargamos el método predeterminado desde SharedPreferences
      _loadDefaultMethod();
    }
  }

  void _applySession(Map<String, dynamic> s) {
    // Soportamos distintas keys (las que usas en CrearSesionScreen y las usadas en el ejemplo de HomeScreen)
    final method = s['metodoLabel'] ?? s['method'] ?? s['metodo'] ?? _selectedMethod;
    final foco = s['focoMin'] ?? s['focusMinutes'];
    final descanso = s['descansoMin'] ?? s['breakMinutes'];

    setState(() {
      if (method != null && _methodTimes.containsKey(method)) {
        _selectedMethod = method;
        _focusMinutes = foco ?? _methodTimes[method]![0];
        _breakMinutes = descanso ?? _methodTimes[method]![1];
      } else if (method != null) {
        // Si el método no está en la lista, lo usamos como etiqueta y tomamos valores si vienen
        _selectedMethod = method;
        if (foco != null) _focusMinutes = foco;
        if (descanso != null) _breakMinutes = descanso;
      } else {
        // fallback por seguridad
        _selectedMethod = 'Pomodoro 25/5';
        _focusMinutes = 25;
        _breakMinutes = 5;
      }
    });
  }

  // Cargar el método guardado en SharedPreferences
  Future<void> _loadDefaultMethod() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final defaultMethod = prefs.getString('metodo_default') ?? 'Pomodoro 25/5';
      setState(() {
        _selectedMethod = defaultMethod;
        _focusMinutes = _methodTimes[defaultMethod]![0];
        _breakMinutes = _methodTimes[defaultMethod]![1];
      });
    } catch (e) {
      if (!mounted) return;
      Future.microtask(() {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al cargar método predeterminado')),
        );
      });
    }
  }

  // Cambiar el método de estudio seleccionado
  void _onMethodChanged(String? method) {
    if (method == null) return;
    setState(() {
      _selectedMethod = method;
      _focusMinutes = _methodTimes[method]![0];
      _breakMinutes = _methodTimes[method]![1];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFD9CBBE),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Selecciona tu método de estudio',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            DropdownButtonFormField<String>(
              value: _selectedMethod,
              decoration: const InputDecoration(
                labelText: 'Método',
                border: OutlineInputBorder(),
              ),
              items: _methodTimes.keys.map((String method) {
                return DropdownMenuItem<String>(
                  value: method,
                  child: Text(method),
                );
              }).toList(),
              onChanged: _onMethodChanged,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _TimeSelector(
                    label: 'Foco',
                    value: _focusMinutes,
                    onChanged: (value) => setState(() => _focusMinutes = value),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _TimeSelector(
                    label: 'Descanso',
                    value: _breakMinutes,
                    onChanged: (value) => setState(() => _breakMinutes = value),
                  ),
                ),
              ],
            ),
            const Spacer(),
            FilledButton(
              onPressed: () {
                Navigator.pushNamed(
                  context,
                  '/session',
                  arguments: {
                    'focusMinutes': _focusMinutes,
                    'breakMinutes': _breakMinutes,
                    'method': _selectedMethod,
                  },
                );
              },
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.brown[300],
              ),
              child: const Text(
                'Comenzar',
                style: TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===============================
//   WIDGET SELECTOR DE TIEMPO
// ===============================
class _TimeSelector extends StatelessWidget {
  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  const _TimeSelector({
    required this.label,
    required this.value,
    required this.onChanged,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade400),
            borderRadius: BorderRadius.circular(8),
            color: Colors.white,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.remove),
                onPressed: value > 1 ? () => onChanged(value - 1) : null,
              ),
              Text(
                '$value min',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: value < 120 ? () => onChanged(value + 1) : null,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
