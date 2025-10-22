import 'package:flutter/material.dart';

class CrearNuevaSesionScreen extends StatelessWidget {
  const CrearNuevaSesionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFD9CBBE),
      appBar: AppBar(
        backgroundColor: const Color(0xFFB49D87),
        title: const Text('Crear Nueva Sesión de Estudio'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            _buildInput('Título:', 'Value'),
            const SizedBox(height: 16),
            _buildDropdown('Tema:', ['Menu item']),
            const SizedBox(height: 16),
            _buildDropdown('Método:', ['Método 1', 'Método 2', 'Método 3']),
            const SizedBox(height: 16),
            _buildDropdown('Fecha:', ['Value']),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text('Método:', style: TextStyle(fontSize: 16)),
                Text('00:00', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 30),
            Center(
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2C4459),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                ),
                child: const Text('Crear'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInput(String label, String placeholder) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        TextField(
          decoration: InputDecoration(
            hintText: placeholder,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown(String label, List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
          ),
          value: items.first,
          items: items
              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
              .toList(),
          onChanged: (_) {},
        ),
      ],
    );
  }
}
