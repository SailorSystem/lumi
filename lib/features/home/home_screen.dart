import 'package:flutter/material.dart';
import 'package:lumi_app/widgets/lumi_char.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFD9CBBE),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 32),
              const Center(child: LumiChar(size: 200)),
              const SizedBox(height: 48),
              _MenuButton(
                icon: Icons.play_arrow,
                label: 'Iniciar sesión',
                onPressed: () => Navigator.pushNamed(context, '/start'),
              ),
              const SizedBox(height: 16),
              _MenuButton(
                icon: Icons.add,
                label: 'Crear sesión',
                onPressed: () => Navigator.pushNamed(context, '/crear'),
              ),
              const SizedBox(height: 16),
              _MenuButton(
                icon: Icons.bar_chart,
                label: 'Estadísticas',
                onPressed: () => Navigator.pushNamed(context, '/stats'),
              ),
              const SizedBox(height: 16),
              _MenuButton(
                icon: Icons.settings,
                label: 'Ajustes',
                onPressed: () => Navigator.pushNamed(context, '/settings'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _MenuButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}