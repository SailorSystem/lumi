import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lumi - Home'),
      ),
      body: const Center(
        child: Text(
          '¡Bienvenido a Lumi!',
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}
