import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../metodos/pomodoro/pomodoro_screen.dart';
import '../metodos/flashcards/flashcards_screen.dart';
import '../metodos/mentalmaps/mentalmaps.screen.dart';
import '../../core/providers/theme_provider.dart';

class SesionRapidaScreen extends StatefulWidget {
  const SesionRapidaScreen({super.key});

  @override
  State<SesionRapidaScreen> createState() => _SesionRapidaScreenState();
}

class _SesionRapidaScreenState extends State<SesionRapidaScreen> {
  String _selectedMethod = 'Pomodoro';
  //static const _bg = Color(0xFFD9CBBE);
  //static const _bar = Color(0xFFB49D87);
  //static const _primary = Color(0xFF2C4459);

  final List<String> _methods = [
    'Pomodoro',
    'Flashcards',
    'Mapa Mental',
  ];

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final bg         = themeProvider.backgroundColor;
    final primary    = themeProvider.primaryColor;
    final cardColor  = themeProvider.cardColor;
    final textColor  = themeProvider.textColor;

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
            crossAxisAlignment: CrossAxisAlignment.stretch,
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
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxWidth: 420),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: themeProvider.isDarkMode
                        ? Colors.grey[600]!
                        : Colors.grey.shade300,
                  ),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedMethod,
                    isExpanded: true,
                    icon: Padding(
                      padding: const EdgeInsets.only(right: 12.0),
                      child: Icon(Icons.arrow_drop_down, color: textColor),
                    ),
                    items: _methods.map((String method) {
                      return DropdownMenuItem<String>(
                        value: method,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10.0),
                          child: Text(
                            method,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              color: textColor,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        setState(() {
                          _selectedMethod = newValue;
                        });
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    '¿Desea iniciar?',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 140,
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: () {
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
                                SnackBar(
                                  content: Text('Método "$_selectedMethod" no implementado aún'),
                                ),
                              );
                            }
                          },
                          icon: Icon(Icons.play_circle_fill, size: 20, color: Colors.white),
                          label: const Text('Sí'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(28),
                            ),
                            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                      const SizedBox(width: 20),
                      SizedBox(
                        width: 140,
                        height: 48,
                        child: OutlinedButton.icon(
                          onPressed: () => Navigator.pop(context),
                          icon: Icon(Icons.close, size: 20, color: primary),
                          label: Text('No', style: TextStyle(color: primary)),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: cardColor,
                            foregroundColor: primary,
                            side: BorderSide(color: primary),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(28),
                            ),
                            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 28),
            ],
          ),
        ),
      ),
    );
  }

}