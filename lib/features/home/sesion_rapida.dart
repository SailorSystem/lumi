import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/providers/theme_provider.dart';
import '../../features/metodos/pomodoro/pomodoro_screen.dart';
import '../../features/metodos/flashcards/flashcards_screen.dart';
import '../../features/metodos/mentalmaps/mentalmaps.screen.dart';
import 'dart:convert';


class SesionRapidaScreen extends StatefulWidget {
  const SesionRapidaScreen({super.key});

  @override
  State<SesionRapidaScreen> createState() => _SesionRapidaScreenState();
}

class _SesionRapidaScreenState extends State<SesionRapidaScreen> {
  List<Map<String, dynamic>> metodosDb = [];

  @override
  void initState() {
    super.initState();
    _loadMetodosDb();
  }

  Future<void> _loadMetodosDb() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? stored = prefs.getStringList('metodos');

    if (stored != null && stored.isNotEmpty) {
      setState(() {
        metodosDb = stored.map((s) => json.decode(s) as Map<String, dynamic>).toList();
      });
      return;
    }

    // Métodos por defecto
    metodosDb = [
      {
        'idx': 0,
        'id_metodo': 1,
        'nombre': 'Pomodoro',
        'descripcion': 'Técnica de estudio basada en intervalos de 25 minutos.',
      },
      {
        'idx': 1,
        'id_metodo': 2,
        'nombre': 'Flashcards',
        'descripcion': 'Técnica basada en tarjetas con preguntas y respuestas.',
      },
      {
        'idx': 2,
        'id_metodo': 3,
        'nombre': 'Mapa Mental',
        'descripcion': 'Representación gráfica de ideas',
      },
    ];

    await prefs.setStringList('metodos', metodosDb.map((m) => json.encode(m)).toList());
    setState(() {});
  }

  IconData _getIconoMetodo(String nombreMetodo) {
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

  void _iniciarMetodo(int idMetodo) {
    Widget screen;
    switch (idMetodo) {
      case 1:
        screen = const PomodoroScreen(idSesion: null);
        break;
      case 2:
        screen = const FlashcardsScreen(idSesion: null);
        break;
      case 3:
        screen = const MentalMapsScreen(idSesion: null);
        break;
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Método no disponible')),
        );
        return;
    }

    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final primaryColor = themeProvider.primaryColor;
    final cardColor = themeProvider.cardColor;
    final textColor = themeProvider.textColor;

    return Scaffold(
      backgroundColor: themeProvider.backgroundColor,
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: primaryColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Sesión Rápida',
          style: TextStyle(
            color: primaryColor,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: isDark
                  ? [
                      const Color(0xFF212C36),
                      const Color(0xFF313940),
                      themeProvider.backgroundColor,
                    ]
                  : [
                      const Color(0xFFB6C9D6),
                      const Color(0xFFE6DACA),
                      themeProvider.backgroundColor,
                    ],
              stops: const [0.0, 0.75, 1.0],
            ),
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            
            // ✅ Título con ícono
            Row(
              children: [
                Icon(
                  Icons.flash_on,
                  color: primaryColor,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Elige un método de estudio',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 8),
            
            Text(
              'Inicia una sesión sin programar',
              style: TextStyle(
                fontSize: 14,
                color: textColor.withOpacity(0.7),
              ),
            ),
            
            const SizedBox(height: 24),

            // ✅ Lista de métodos con diseño igual a crear_sesion_screen
            Expanded(
              child: metodosDb.isEmpty
                  ? Center(
                      child: CircularProgressIndicator(
                        color: primaryColor,
                      ),
                    )
                  : ListView.separated(
                      itemCount: metodosDb.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final metodo = metodosDb[index];
                        final nombre = metodo['nombre'] as String;
                        final descripcion = metodo['descripcion'] as String? ?? '';
                        final idMetodo = metodo['id_metodo'] as int;
                        final icono = _getIconoMetodo(nombre);

                        return InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => _iniciarMetodo(idMetodo),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: cardColor,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: primaryColor.withOpacity(0.2),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                // ✅ Ícono del método
                                Container(
                                  width: 56,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    color: primaryColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    icono,
                                    color: primaryColor,
                                    size: 28,
                                  ),
                                ),
                                
                                const SizedBox(width: 16),
                                
                                // ✅ Nombre y descripción
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        nombre,
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: textColor,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        descripcion,
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: textColor.withOpacity(0.7),
                                          height: 1.35, // 👈 mejora la legibilidad
                                        ),
                                        softWrap: true,
                                      ),
                                    ],
                                  ),
                                ),
                                
                                const SizedBox(width: 12),
                                
                                // ✅ Flecha
                                Icon(
                                  Icons.arrow_forward_ios,
                                  color: primaryColor.withOpacity(0.5),
                                  size: 18,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
