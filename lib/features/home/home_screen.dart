import 'package:flutter/material.dart';
import 'crear_sesion_screen.dart';
import 'start_screen.dart';
import '../settings/settings_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sessions = ['Sesión 1', 'Sesión 2', 'Sesión 3', 'Sesión 4'];

    return Scaffold(
      backgroundColor: const Color(0xFFD9CBBE),
      appBar: AppBar(
        backgroundColor: const Color(0xFFB49D87),
        title: const Text('Hola Nay\nMe llamo Lumi'),
        actions: [
          IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CrearNuevaSesionScreen()),
              );
            },
            icon: const Icon(Icons.add_circle_outline),
            label: const Text('Nueva Sesión de Estudio'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2C4459),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
            ),
          ),
          const SizedBox(height: 30),
          for (var i = 0; i < sessions.length; i++) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => StartScreen(session: {'titulo': sessions[i]}),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF80A6B3),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(200, 45),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                child: Text(sessions[i]),
              ),
            ),
          ],
          const SizedBox(height: 30),
          Image.asset('assets/images/lumi.jpg', height: 80),
        ],
      ),
    );
  }
}
