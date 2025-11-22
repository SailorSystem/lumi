import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/models/sesion.dart';
import '../../core/services/sesion_service.dart';
import '../../core/providers/theme_provider.dart';

// IMPORTS REALES SEGÚN TU RUTA
import '../../features/metodos/pomodoro/pomodoro_screen.dart';
import '../../features/metodos/flashcards/flashcards_screen.dart';
import '../../features/metodos/mentalmaps/mentalmaps.screen.dart';

class SesionRapidaScreen extends StatefulWidget {
  const SesionRapidaScreen({super.key});

  @override
  State<SesionRapidaScreen> createState() => _SesionRapidaScreenState();
}

class _SesionRapidaScreenState extends State<SesionRapidaScreen> {
  String _selectedMethod = 'Pomodoro';

  final List<String> _methods = [
    'Pomodoro',
    'Flashcards',
    'Mapa Mental',
  ];

  /// Crear sesión rápida en Supabase
  Future<Sesion?> _crearSesionRapida() async {
    final prefs = await SharedPreferences.getInstance();
    final idUsuario = prefs.getInt('user_id');

    if (idUsuario == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No hay usuario activo.")),
      );
      return null;
    }

    int? metodoId;
    switch (_selectedMethod) {
      case 'Pomodoro':
        metodoId = 1;
        break;
      case 'Flashcards':
        metodoId = 2;
        break;
      case 'Mapa Mental':
        metodoId = 3;
        break;
      default:
        metodoId = null;
    }

    final Sesion nueva = Sesion(
      idSesion: null,
      idUsuario: idUsuario,
      idMetodo: metodoId,
      idTema: null,
      nombreSesion: 'Sesión Rápida ($_selectedMethod)',
      fecha: DateTime.now(),
      esRapida: true,
      duracionTotal: 0,
      estado: "finalizada",  // 👈 FIX CRUCIAL
    );

    try {
      final creada = await SesionService.crearSesion(nueva);
      return creada;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error creando sesión rápida: $e")),
      );
      return null;
    }
  }

  /// Iniciar el método correspondiente
  Future<void> _startQuickSession() async {
    final sesion = await _crearSesionRapida();
    if (sesion == null) return;

    if (!mounted) return;

    if (_selectedMethod == 'Pomodoro') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const PomodoroScreen()),
      );
    } else if (_selectedMethod == 'Flashcards') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const FlashcardsScreen()),
      );
    } else if (_selectedMethod == 'Mapa Mental') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MentalMapsScreen()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Método "$_selectedMethod" no implementado')),
      );
    }
  }

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
          'Sesión Rápida',
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
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Column(
            children: [
              const SizedBox(height: 20),
              Text(
                'Método:',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 8),

              // SELECTOR
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: themeProvider.isDarkMode
                        ? Colors.grey[700]!
                        : Colors.grey.shade300,
                  ),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton(
                    value: _selectedMethod,
                    isExpanded: true,
                    icon: Padding(
                      padding: const EdgeInsets.only(right: 12.0),
                      child: Icon(Icons.arrow_drop_down, color: textColor),
                    ),
                    items: _methods.map((method) {
                      return DropdownMenuItem(
                        value: method,
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Text(
                            method,
                            style: TextStyle(fontSize: 16, color: textColor),
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (value) =>
                        setState(() => _selectedMethod = value!),
                  ),
                ),
              ),

              const SizedBox(height: 30),

              Text(
                '¿Iniciar sesión ahora?',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),

              const SizedBox(height: 20),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // BOTÓN SÍ
                  SizedBox(
                    width: 140,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: _startQuickSession,
                      icon: const Icon(Icons.play_circle_fill,
                          size: 20, color: Colors.white),
                      label: const Text('Sí'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 20),

                  // BOTÓN NO
                  SizedBox(
                    width: 140,
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.close, size: 20, color: primary),
                      label: Text('No', style: TextStyle(color: primary)),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: primary),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
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
}