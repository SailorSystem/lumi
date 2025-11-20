import 'package:flutter/material.dart';
import '../metodos/pomodoro/pomodoro_screen.dart';
import '../metodos/flashcards/flashcards_screen.dart';
import '../metodos/mentalmaps/mentalmaps.screen.dart';

class SesionRapidaScreen extends StatefulWidget {
  const SesionRapidaScreen({super.key});

  @override
  State<SesionRapidaScreen> createState() => _SesionRapidaScreenState();
}

class _SesionRapidaScreenState extends State<SesionRapidaScreen> {
  String _selectedMethod = 'Pomodoro';
  static const _bg = Color(0xFFD9CBBE);
  static const _bar = Color(0xFFB49D87);
  static const _primary = Color(0xFF2C4459);

  final List<String> _methods = [
    'Pomodoro',
    'Flashcards',
    'Mapa Mental',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bar,
        title: const Text('Sesión Rápida'),
        elevation: 0,
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Column(
            // removed large Spacer so controls stay compact
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              Text(
                'Método:',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: _primary,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxWidth: 420),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedMethod,
                    isExpanded: true,
                    icon: const Padding(
                      padding: EdgeInsets.only(right: 12.0),
                      child: Icon(Icons.arrow_drop_down),
                    ),
                    items: _methods.map((String method) {
                      return DropdownMenuItem<String>(
                        value: method,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10.0),
                          child: Text(
                            method,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 16),
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

              // Group the prompt and buttons closely
              Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text(
                    '¿Desea iniciar?',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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

                          icon: const Icon(Icons.play_circle_fill, size: 20),
                          label: const Text('Sí'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _primary,
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
                          icon: const Icon(Icons.close, size: 20),
                          label: const Text('No'),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                            side: BorderSide(color: Colors.grey.shade300),
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

              const SizedBox(height: 28), // small bottom spacing
            ],
          ),
        ),
      ),
    );
  }
}