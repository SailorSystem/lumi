import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FirstRegisterScreen extends StatefulWidget {
  const FirstRegisterScreen({super.key});

  @override
  State<FirstRegisterScreen> createState() => _FirstRegisterScreenState();
}

class _FirstRegisterScreenState extends State<FirstRegisterScreen> {
  final TextEditingController _nameCtrl = TextEditingController();
  bool _saving = false;

  Future<void> _saveName() async {
    final name = _nameCtrl.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Por favor ingresa tu nombre")),
      );
      return;
    }

    setState(() => _saving = true);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("user_name", name);

    // Aquí podrías registrar en Supabase si quieres:
    // await UsuarioService.crearUsuario(name);

    if (!mounted) return;

    Navigator.pop(context); // Regresa al Home
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFD9CBBE),
      body: SafeArea(
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(24),
            margin: const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.90),
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "Bienvenido",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2C4459),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  "Antes de comenzar,\n¿cuál es tu nombre?",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.black87),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _nameCtrl,
                  decoration: InputDecoration(
                    labelText: "Tu nombre",
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _saving ? null : _saveName,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2C4459),
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 36, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text(
                          "Guardar",
                          style: TextStyle(fontSize: 16),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
