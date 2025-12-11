import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_screen.dart';
import '../../core/models/sesion.dart';
import '../../core/local/local_tema_repository.dart';
import '../../core/services/sesion_service.dart';
import '../../core/providers/theme_provider.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/connectivity_service.dart';
import '../../widgets/no_connection_dialog.dart';

class CrearNuevaSesionScreen extends StatefulWidget {
  const CrearNuevaSesionScreen({super.key});
  
  @override
  State<CrearNuevaSesionScreen> createState() => _CrearNuevaSesionScreenState();
}

class _CrearNuevaSesionScreenState extends State<CrearNuevaSesionScreen> {
  final _formKey = GlobalKey<FormState>();
  final titleController = TextEditingController();
  bool _canSave = false;
  String? _mensajeAyuda;
  int _selectedMetodoId = 1; // ✅ Variable para el ID del método
  List<String> _erroresVisibles = [];
  List<Map<String, dynamic>> _metodosDb = [];
  Map<String, dynamic>? materiaSel;
  DateTime selectedDate = DateTime.now();
  TimeOfDay selectedTime = TimeOfDay.fromDateTime(
  DateTime.now().add(const Duration(minutes: 10)),
  );
  Duration selectedDuration = const Duration(hours: 1);
  List<Map<String, dynamic>> _materias = [];
  Duration get _minOffset => const Duration(minutes: 5);
  String? _ayudaTiempo;
  bool _errorFechaHora = false;
  bool _errorDuracion = false;
  bool _errorNombreMateria = false;

  bool _fechaHoraEsValida() {
    final fechaSeleccionada = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
      selectedTime.hour,
      selectedTime.minute,
    );
    final diff = fechaSeleccionada.difference(DateTime.now());
    return diff >= _minOffset;
  }

  int _minutosMinimosPorMetodo() {
    switch (_selectedMetodoId) {
      case 1: // Pomodoro
        return 25;
      case 2: // Flashcards
        return 5;
      case 3: // Mapa mental
        return 5;
      default:
        return 3;
    }
  }

  bool _duracionValidaParaMetodo() {
    final minutos = selectedDuration.inMinutes;
    return minutos >= _minutosMinimosPorMetodo();
  }


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
    titleController.addListener(_recalcularCanSave);

  }

  void _validarYMostrarErrores() {
    final errores = <String>[];

    final titulo = titleController.text.trim();
    if (titulo.isEmpty) {
      errores.add('El título no puede estar vacío.');
    } else if (titulo.length > 50) {
      errores.add('El título no debe superar los 50 caracteres.');
    }

    if (materiaSel == null) {
      errores.add('Selecciona una materia.');
    }

    if (!_fechaHoraEsValida()) {
      errores.add('La fecha y hora deben ser al menos ${_minOffset.inMinutes} minutos en el futuro.');
    }

    if (!_duracionValidaParaMetodo()) {
      errores.add('La duración es demasiado corta para el método seleccionado.');
    }

    setState(() {
      _erroresVisibles = errores;
    });
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
    titleController.removeListener(_recalcularCanSave);
    titleController.dispose();
    super.dispose();
  }

  void _recalcularCanSave() {
    final titulo = titleController.text.trim();

    bool ok = true;

    // título y materia: sus mensajes los maneja el validator
    if (titulo.isEmpty || titulo.length > 50) ok = false;
    if (materiaSel == null) ok = false;

    // fecha / hora
    final fechaValida = _fechaHoraEsValida();
    if (!fechaValida) ok = false;

    // duración según método
    final duracionValida = _duracionValidaParaMetodo();
    if (!duracionValida) ok = false;

    setState(() {
      _canSave = ok;
      _errorFechaHora = !fechaValida;
      _errorDuracion = !duracionValida;
    });
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
    final conectado = await ConnectivityService.verificarConexion();
    if (!conectado) {
      await showNoConnectionDialog(context,
        message: 'No se pudo crear la sesión. Revisa tu conexión e inténtalo de nuevo.');
      return;
    }
    // 1) Validar el formulario VISUALMENTE
    if (!_formKey.currentState!.validate()) {
      print('❌ Formulario inválido');
      return;
    }

    // 2) Validar reglas extra (fecha / duración)
    if (!_fechaHoraEsValida() || !_duracionValidaParaMetodo()) {
      // aquí puedes poner SOLO UN SnackBar si quieres algo general
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Revisa fecha y duración antes de crear la sesión.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // 3) Usuario
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id');
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay usuario activo. Regístrate primero.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final metodoId = _selectedMetodoId;
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

    final nueva = Sesion(
      idSesion: null,
      idUsuario: userId,
      idMetodo: metodoId,
      idTema: temaId,
      nombreSesion: titleController.text.trim(),
      fecha: selectedDateTime,
      esRapida: false,
      duracionTotal: selectedDuration.inSeconds,
      estado: 'programada',
    );

    try {
      final creada = await SesionService.crearSesion(nueva);

      if (creada != null && creada.idSesion != null) {
        await NotificationService.programarRecordatorio(
          idSesion: creada.idSesion!,
          nombreSesion: creada.nombreSesion,
          fechaSesion: creada.fecha,
        );
        await NotificationService.programarNotificacionInicio(
          idSesion: creada.idSesion!,
          nombreSesion: creada.nombreSesion,
          fechaSesion: creada.fecha,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("✅ Sesión creada con éxito"),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      print('❌ Error creando sesión: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("❌ Error al guardar: $e"),
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
    bool error = false,
  }) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final cardColor = themeProvider.cardColor;
    final textColor = themeProvider.textColor;
    final primary = themeProvider.primaryColor;

    final borderColor = error
        ? Colors.redAccent
        : (themeProvider.isDarkMode ? Colors.grey[700]! : Colors.black26);

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: error ? 2 : 1),
          boxShadow: const [
            BoxShadow(blurRadius: 4, offset: Offset(0, 2), color: Colors.black12),
          ],
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: error ? Colors.redAccent : primary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // etiqueta principal
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      color: error
                          ? Colors.redAccent
                          : textColor.withOpacity(0.7),
                      fontWeight:
                          error ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                  // valor
                  Text(
                    value ?? 'Seleccionar',
                    style: TextStyle(fontSize: 16, color: textColor),
                  ),
                  // 👇 ETIQUETA SEMITRANSPARENTE solo cuando hay error

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
        if (picked != null) {
          setState(() => materiaSel = picked);
          _recalcularCanSave();              
        }
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
        // esta variable vive durante toda la vida del modal
        bool errorLocal = false;
        // form key persistente dentro del modal
        final formKey = GlobalKey<FormState>();

        return StatefulBuilder(
          builder: (ctx, setS) {
            final bottom = MediaQuery.of(ctx).viewInsets.bottom;
            final nombre = nameCtrl.text.trim();
            final puedeGuardar = nombre.isNotEmpty;

            print("DEBUG openMateriaSheet -> puedeGuardar=$puedeGuardar, nombre='$nombre'");

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

                    // ---------- FORMULARIO con TextFormField ----------
                    Form(
                      key: formKey,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextFormField(
                            controller: nameCtrl,
                            style: TextStyle(color: textColor),
                            decoration: InputDecoration(
                              labelText: 'Nombre de la materia',
                              labelStyle: TextStyle(color: textColor.withOpacity(0.7)),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              errorStyle: const TextStyle(color: Colors.redAccent, fontSize: 13),
                            ),
                            validator: (v) {
                              final t = (v ?? '').trim();
                              if (t.isEmpty) {
                                print("VALIDATOR: nombre vacío");
                                return 'El nombre de la materia no puede estar vacío';
                              }
                              final repetido = _materias.any((m) {
                                final n = (m['nombre'] as String?) ?? '';
                                return n.toLowerCase() == t.toLowerCase();
                              });
                              if (repetido) {
                                print("VALIDATOR: nombre repetido -> $t");
                                return 'Ya existe una materia con ese nombre';
                              }
                              return null;
                            },
                            onChanged: (_) {
                              // reiniciamos estado de error local y forzamos re-evaluación del form
                              setS(() {
                                errorLocal = false;
                              });
                              // opcional: forzar validar automáticamente
                              formKey.currentState?.validate();
                            },
                          ),

                          // fallback: texto rojo manual (por si quieres evitar depender sólo del errorText)
                          if (errorLocal)
                            Padding(
                              padding: const EdgeInsets.only(top: 6, left: 4),
                              child: Text(
                                '⚠ Nombre vacío o repetido',
                                style: TextStyle(
                                  color: Colors.redAccent,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // PALETA DE COLORES (igual)
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
                                        ),
                                        child: sel
                                            ? const Icon(Icons.check, color: Colors.white, size: 28)
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

                    // BOTONES
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
                            child: const Text('Cancelar', style: TextStyle(fontWeight: FontWeight.w600)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              // 1) Si el form NO valida, mostramos errorLocal y no cerramos
                              final ok = formKey.currentState?.validate() ?? false;
                              print("AL PRESIONAR Guardar -> form valid? $ok");
                              if (!ok) {
                                setS(() {
                                  errorLocal = true;
                                });
                                return;
                              }

                              // 2) si pasa validación, creamos la materia
                              final nuevaMateria = {
                                'id': DateTime.now().millisecondsSinceEpoch,
                                'nombre': nombre,
                                'color': picked.value,
                              };

                              print("CREANDO materia -> $nuevaMateria");
                              await _addMateria(nuevaMateria);
                              Navigator.pop(ctx);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: puedeGuardar ? primary : primary.withOpacity(0.4),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              elevation: 2,
                            ),
                            child: const Text('Guardar', style: TextStyle(fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
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
                        _recalcularCanSave();
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
    final minReq = _minutosMinimosPorMetodo();

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
              validator: (value) {
                final text = value?.trim() ?? '';
                if (text.isEmpty) return 'El título no puede estar vacío';
                if (text.length > 50) return 'Máximo 50 caracteres';
                return null;
              },
                onChanged: (_) {
                _formKey.currentState!.validate(); // pinta o borra el error
                _recalcularCanSave();              // recalcula el botón
              },
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
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (d != null) {
                      setState(() => selectedDate = d);
                      _recalcularCanSave();
                    }
                  },
                  ),
                ),
                const SizedBox(width: 8),
                // HORA (con borde rojo y mensaje cuando _errorFechaHora == true)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _lumiPickerButton(
                        icon: Icons.access_time,
                        label: 'Hora',
                        value: '${_two(selectedTime.hour)}:${_two(selectedTime.minute)}',
                        onTap: () async {
                          final t = await showTimePicker(
                            context: context,
                            initialTime: selectedTime,
                          );
                          if (t != null) {
                            setState(() => selectedTime = t);
                            _recalcularCanSave();
                          }
                        },
                        error: _errorFechaHora,
                      ),
                      if (_errorFechaHora) ...[
                        const SizedBox(height: 4),
                        Text(
                          'La hora debe ser al menos ${_minOffset.inMinutes} min en el futuro',
                          style: const TextStyle(
                            color: Colors.redAccent,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _lumiPickerButton(
              icon: Icons.timer,
              label: 'Duración (mínimo ${minReq} min)',
              value: '${_two(selectedDuration.inHours)}:${_two(selectedDuration.inMinutes % 60)}',
              onTap: openDurationSheet,
              error: _errorDuracion,
            ),
            if (_errorDuracion) ...[
              const SizedBox(height: 4),
              Text(
                'La duración no puede ser menor a ${minReq} min',
                style: const TextStyle(
                  color: Colors.redAccent,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: () {
                  // 1) Siempre validamos visualmente
                  final okForm = _formKey.currentState!.validate();

                  // 2) Recalcular reglas extra (materia, fecha, duración)
                  _recalcularCanSave();

                  // 3) Si TODO está bien, recién llamamos a saveSession
                  if (_canSave && okForm) {
                    saveSession();
                  }

                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _canSave ? primary : primary.withOpacity(0.4),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  elevation: _canSave ? 2 : 0,
                ),
                child: const Text(
                  'Crear Sesión',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
