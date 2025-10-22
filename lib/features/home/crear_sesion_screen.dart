import 'package:flutter/material.dart';
import 'package:lumi_app/features/home/start_screen.dart';

class CrearSesionScreen extends StatefulWidget {
  const CrearSesionScreen({super.key});

  @override
  State<CrearSesionScreen> createState() => _CrearSesionScreenState();
}

class _CrearSesionScreenState extends State<CrearSesionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();

  final List<String> _temas = ['Matemáticas', 'Psicología', 'Inglés'];
  String? _temaSel;

  // Métodos disponibles; ajusta o conecta con /metodos/pomodoro y /metodos/80_20 si ya tienes lógica
  final List<_MetodoCfg> _metodos = const [
    _MetodoCfg(
      id: 'pomodoro_25_5',
      label: 'Pomodoro 25/5',
      foco: Duration(minutes: 25),
      descanso: Duration(minutes: 5),
      info:
          '4 ciclos de 25 min de foco y 5 min de descanso. Descanso largo de 15–30 min al final.',
    ),
    _MetodoCfg(
      id: '52_17',
      label: '52/17',
      foco: Duration(minutes: 52),
      descanso: Duration(minutes: 17),
      info: '1 ciclo de 52 min de foco y 17 min de descanso. Repetible.',
    ),
    _MetodoCfg(
      id: '80_20',
      label: '80/20',
      foco: Duration(minutes: 80),
      descanso: Duration(minutes: 20),
      info:
          'Prioriza el 20% de tareas con 80% de impacto. Bloques de 80 min y pausas de 20 min.',
    ),
  ];
  _MetodoCfg? _metodoSel;

  DateTime? _fechaSel;

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    final h = d.inHours > 0 ? '${d.inHours}:' : '';
    return '$h$m:$s';
  }

  Future<void> _pickFecha() async {
    final now = DateTime.now();
    final res = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
      initialDate: _fechaSel ?? now,
      helpText: 'Selecciona fecha',
    );
    if (res != null) setState(() => _fechaSel = res);
  }

  void _addTema() async {
    final ctrl = TextEditingController();
    final nuevo = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Nuevo tema'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(hintText: 'Nombre del tema'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(context, ctrl.text.trim()), child: const Text('Guardar')),
        ],
      ),
    );
    if (nuevo != null && nuevo.isNotEmpty) {
      setState(() {
        _temas.add(nuevo);
        _temaSel = nuevo;
      });
    }
  }

  void _showInfo(_MetodoCfg m) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(m.label, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(m.info),
            const SizedBox(height: 12),
            Text('Foco: ${m.foco.inMinutes} min'),
            Text('Descanso: ${m.descanso.inMinutes} min'),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _crear() {
    if (!_formKey.currentState!.validate()) return;
    final session = {
      'titulo': _titleCtrl.text.trim(),
      'tema': _temaSel,
      'metodoId': _metodoSel!.id,
      'metodoLabel': _metodoSel!.label,
      'focoMin': _metodoSel!.foco.inMinutes,
      'descansoMin': _metodoSel!.descanso.inMinutes,
      'fecha': _fechaSel?.toIso8601String(),
    };

    // Navega a la pantalla de inicio de sesión de estudio
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StartScreen(session: session),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const fondo = Color(0xFFD9CBBE);
    const azulBtn = Color(0xFF345C63);
    const azulClaro = Color(0xFF9CB7C2);

    return Scaffold(
      backgroundColor: fondo,
      appBar: AppBar(
        title: const Text('Crear Nueva Sesión de Estudio'),
        backgroundColor: fondo,
        foregroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                const _Label('Título:'),
                TextFormField(
                  controller: _titleCtrl,
                  decoration: _input(),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                ),
                const SizedBox(height: 14),

                const _Label('Tema:'),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _temaSel,
                        decoration: _input(),
                        items: _temas
                            .map((t) => DropdownMenuItem<String>(value: t, child: Text(t)))
                            .toList(),
                        onChanged: (v) => setState(() => _temaSel = v),
                        validator: (v) => v == null ? 'Selecciona un tema' : null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _addTema,
                      icon: const Icon(Icons.add_circle_outline),
                      color: azulBtn,
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                const _Label('Método:'),
                DropdownButtonFormField<_MetodoCfg>(
                  value: _metodoSel,
                  decoration: _input(),
                  items: _metodos
                      .map((m) => DropdownMenuItem<_MetodoCfg>(
                            value: m,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(m.label),
                                IconButton(
                                  icon: const Icon(Icons.info_outline),
                                  onPressed: () => _showInfo(m),
                                ),
                              ],
                            ),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _metodoSel = v),
                  validator: (v) => v == null ? 'Selecciona un método' : null,
                ),

                if (_metodoSel != null) ...[
                  const SizedBox(height: 8),
                  Center(
                    child: Column(
                      children: [
                        const Text('Vista previa del ciclo'),
                        const SizedBox(height: 4),
                        Text(
                          'Foco ${_metodoSel!.foco.inMinutes} min  •  Descanso ${_metodoSel!.descanso.inMinutes} min',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: azulClaro.withOpacity(.4),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _fmt(_metodoSel!.foco),
                            style: const TextStyle(
                              letterSpacing: 2,
                              fontSize: 24,
                              shadows: [Shadow(blurRadius: 2)],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 14),
                const _Label('Fecha:'),
                InkWell(
                  onTap: _pickFecha,
                  child: InputDecorator(
                    decoration: _input(),
                    child: Text(
                      _fechaSel == null
                          ? 'Selecciona fecha'
                          : '${_fechaSel!.day}/${_fechaSel!.month}/${_fechaSel!.year}',
                    ),
                  ),
                ),

                const SizedBox(height: 24),
                Center(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: azulBtn,
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    ),
                    onPressed: _crear,
                    child: const Text('Crear'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _input() => InputDecoration(
        filled: true,
        fillColor: Colors.white.withOpacity(.2),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.black.withOpacity(.2)),
        ),
      );
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, top: 6),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
      ),
    );
  }
}

class _MetodoCfg {
  final String id;
  final String label;
  final Duration foco;
  final Duration descanso;
  final String info;
  const _MetodoCfg({
    required this.id,
    required this.label,
    required this.foco,
    required this.descanso,
    required this.info,
  });
}