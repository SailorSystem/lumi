import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFD9CBBE),
      appBar: AppBar(
        backgroundColor: const Color(0xFFB49D87),
        title: const Text('Ajustes'),
      ),
      body: const Center(
        child: Text('Configuraciones aquí...'),
      ),
    );
  }
}
