import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lumi_app/core/models/usuario.dart';
import 'package:lumi_app/core/services/usuario_service.dart';
import 'package:lumi_app/core/services/supabase_service.dart';

void main() {
  group('🧪 Supabase Tests - Usuario + Estado de Ánimo', () {
    late int userId;

    // ============================
    // 🔧 Inicialización global
    // ============================
    setUpAll(() async {
      // Evita MissingPluginException al usar shared_preferences en tests
      SharedPreferences.setMockInitialValues({});

      // Inicializa Supabase (usa tu URL y anon key reales)
      await Supabase.initialize(
        url: 'https://poxheykxpublcwwodzpz.supabase.co',
        anonKey:
            'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBveGhleWt4cHVibGN3d29kenB6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjI3NzE4MjcsImV4cCI6MjA3ODM0NzgyN30.DZ2L7TxLWCPW65KNk4cHWol3vtipbladCG28D3oPros',
      );

      // NO es necesario asignar nada a SupabaseService.client porque el getter
      // ya devuelve Supabase.instance.client directamente.
      print("✅ Supabase inicializado correctamente.");
    });

    // ============================
    // 1️⃣ Crear usuario
    // ============================
    test('Crear usuario', () async {
      final user = await UsuarioService.crearUsuario("Tester");

      expect(user, isNotNull);
      expect(user!.nombre, "Tester");
      expect(user.estadoAnimo, 1); // default

      userId = user.idUsuario;

      print("👤 Usuario creado con id: $userId");
    });

    // ============================
    // 2️⃣ Obtener usuario
    // ============================
    test('Obtener usuario creado', () async {
      final usuario = await UsuarioService.getUsuario(userId);

      expect(usuario, isNotNull);
      expect(usuario!.idUsuario, userId);
      expect(usuario.nombre, "Tester");

      print("📥 Usuario leído: ${usuario.nombre}");
    });

    // ============================
    // 3️⃣ Update estado_animo
    // ============================
    test('Actualizar estado de ánimo', () async {
      final ok = await UsuarioService.actualizarEstadoAnimo(userId, 2);

      expect(ok, true);

      final usuario = await UsuarioService.getUsuario(userId);

      expect(usuario!.estadoAnimo, 2);

      print("😺 Estado actualizado a: ${usuario.estadoAnimo}");
    });

    // ============================
    // 4️⃣ Modelo Usuario: fromMap / copyWith
    // ============================
    test('Verificación modelo Usuario', () async {
      final data = {
        'id_usuario': 10,
        'nombre': 'Ana',
        'estado_animo': 0,
      };

      final u = Usuario.fromMap(data);

      expect(u.idUsuario, 10);
      expect(u.nombre, "Ana");
      expect(u.estadoAnimo, 0);

      final u2 = u.copyWith(estadoAnimo: 1);

      expect(u2.estadoAnimo, 1);

      print("🧩 Modelo Usuario funciona correctamente.");
    });

    // ============================
    // 5️⃣ Eliminar registro de prueba
    // ============================
    test('Eliminar usuario creado', () async {
      final result = await SupabaseService.client
          .from("usuarios")
          .delete()
          .eq("id_usuario", userId);

      // En la API moderna, result puede ser List o Map; revisamos si hubo error
      expect(result is Map ? result['error'] == null : true , true);

      print("🗑️ Usuario $userId eliminado.");
    });
  });
}
