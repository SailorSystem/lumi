import 'package:flutter/material.dart';

class StartScreen extends StatelessWidget {
  final Map<String, dynamic>? session;

  const StartScreen({super.key, this.session});

  @override
  Widget build(BuildContext context) {
    final title = session?['titulo'] ?? 'Sesión N';

    return Scaffold(
      backgroundColor: const Color(0xFFD9CBBE),
      appBar: AppBar(
        backgroundColor: const Color(0xFFB49D87),
        title: Text(title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '¿Desea iniciar?',
              style: TextStyle(fontSize: 20),
            ),
            SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _ActionButton(label: 'Sí', color: Color(0xFF6D5FA4)),
                SizedBox(width: 16),
                _ActionButton(label: 'No', color: Color(0xFFE8E1F0), textColor: Colors.black),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final Color color;
  final Color textColor;

  const _ActionButton({
    required this.label,
    required this.color,
    this.textColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: () {},
      icon: const Icon(Icons.play_circle_outline),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: textColor,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
      ),
    );
  }
}
