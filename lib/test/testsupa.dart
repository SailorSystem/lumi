// lib/test/testsupa.dart
import 'package:flutter/material.dart';
import 'package:lumi_app/core/supabase_manager.dart';

class TestSupa extends StatefulWidget {
  const TestSupa({super.key});

  @override
  State<TestSupa> createState() => _TestSupaState();
}

class _TestSupaState extends State<TestSupa> {
  late Future<List<dynamic>> _futureUsuarios;

  @override
  void initState() {
    super.initState();
    // Llamada simple para probar conexión con Supabase
    _futureUsuarios = supabase.from('usuarios').select();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Prueba Supabase'),
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _futureUsuarios,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                '❌ Error: ${snapshot.error}',
                style: const TextStyle(color: Colors.red),
              ),
            );
          }

          final data = snapshot.data ?? [];

          if (data.isEmpty) {
            return const Center(
              child: Text(
                '✅ Conectado a Supabase\n(No hay usuarios aún)',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
            );
          }

          return ListView.builder(
            itemCount: data.length,
            itemBuilder: (context, index) {
              final user = data[index];
              return ListTile(
                leading: CircleAvatar(child: Text(user['idUsuario'].toString())),
                title: Text(user['nombre'] ?? 'Sin nombre'),
              );
            },
          );
        },
      ),
    );
  }
}
