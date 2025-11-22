import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/services/usuario_service.dart';
import '../../core/models/usuario.dart';
import '../../core/services/supabase_service.dart';
import '../../core/supabase_manager.dart';
import '../../core/services/sesion_service.dart'; 
import 'package:supabase_flutter/supabase_flutter.dart';


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
    
    // ✅ VERIFICAR SI YA EXISTE UN USUARIO (ANTES de limpiar)
    int? existingUserId = prefs.getInt('user_id'); // Con guion bajo
    
    // Si no encuentra con guion bajo, intentar sin guion (antiguo)
    if (existingUserId == null) {
      existingUserId = prefs.getInt('userid'); // Sin guion bajo (antiguo)
      
      // Si encontró con la clave antigua, migrar a la nueva
      if (existingUserId != null) {
        print('🔄 Migrando de "userid" a "user_id"');
        await prefs.setInt('user_id', existingUserId); // Guardar con la clave correcta
        await prefs.remove('userid'); // Eliminar la clave antigua
      }
    }
    
    if (existingUserId != null) {
      print('👤 Usuario existente encontrado: $existingUserId');
      
      // Obtener datos del usuario desde Supabase
      try {
        final usuarioData = await SupabaseService.getById(
          'usuarios',
          'id_usuario',
          existingUserId,
        );
        
        if (usuarioData != null) {
          final usuarioExistente = Usuario.fromMap(usuarioData);
          
          // Actualizar el nombre si cambió
          if (usuarioExistente.nombre != name) {
            await SupabaseService.update(
              'usuarios',
              'id_usuario',
              existingUserId,
              {'nombre': name},
            );
            await prefs.setString('user_name', name);
            print('✅ Nombre actualizado para usuario $existingUserId');
          }
          
          if (!mounted) return;
          Navigator.pop(context, usuarioExistente);
          return;
        }
      } catch (e) {
        print('❌ Error verificando usuario existente: $e');
        // Si falla, continuar para crear nuevo usuario
      }
    }

    // ✅ Si no existe usuario, crear uno nuevo
    print('🆕 Creando nuevo usuario...');
    
    Usuario? nuevoUsuario;

    try {
      nuevoUsuario = await UsuarioService.crearUsuario(name);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error registrando usuario: $e")),
      );
      setState(() => _saving = false);
      return;
    }

    if (nuevoUsuario == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error: Supabase no devolvió usuario.")),
      );
      setState(() => _saving = false);
      return;
    }

    // ✅ Guardar con la clave correcta
    await prefs.setInt('user_id', nuevoUsuario.idUsuario); // Con guion bajo
    await prefs.setString('user_name', name);
    
    // Limpiar clave antigua si existía
    await prefs.remove('userid');
    
    print('✅ Nuevo usuario creado y guardado: ${nuevoUsuario.idUsuario}');

    if (!mounted) return;

    Navigator.pop(context, nuevoUsuario);
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
                      color: Color(0xFF2C4459)),
                ),
                const SizedBox(height: 12),
                const Text(
                  "Antes de comenzar,\n¿cuál es tu nombre?",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 20),

                TextField(
                  controller: _nameCtrl,
                  decoration: InputDecoration(
                    labelText: "Tu nombre",
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                ElevatedButton(
                  onPressed: _saving ? null : _saveName,
                  child: _saving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text("Guardar"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
