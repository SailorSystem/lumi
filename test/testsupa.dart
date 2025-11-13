import 'package:flutter_test/flutter_test.dart';
import 'package:supabase/supabase.dart'; // 👈 usa el paquete base, no supabase_flutter

void main() {
  group('🧠 Pruebas Supabase - Integración completa (modo consola)', () {
    late SupabaseClient client;
    late int usuarioId;
    late int metodoId;
    late int temaId;
    late int sesionId;

    setUpAll(() async {
      client = SupabaseClient(
        'https://poxheykxpublcwwodzpz.supabase.co',
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBveGhleWt4cHVibGN3d29kenB6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjI3NzE4MjcsImV4cCI6MjA3ODM0NzgyN30.DZ2L7TxLWCPW65KNk4cHWol3vtipbladCG28D3oPros',
      );
      print('✅ Cliente Supabase inicializado (modo Dart puro).');
    });

    test('1️⃣ Verificar conexión básica', () async {
      final response = await client.from('usuarios').select().limit(1);
      expect(response, isA<List>());
      print('✅ Conexión exitosa con Supabase.');
    });

    test('2️⃣ Insertar usuario', () async {
      final response = await client.from('usuarios').insert({
        'nombre': 'Tester Unitario',
      }).select();

      usuarioId = response.first['id_usuario'];
      expect(usuarioId, isNotNull);
      print('👤 Usuario creado con ID: $usuarioId');
    });

    test('3️⃣ Insertar configuración', () async {
      final response = await client.from('configuraciones').insert({
        'id_usuario': usuarioId,
        'modo_oscuro': true,
        'notificaciones_activadas': false,
        'sonido': true,
      });
      expect(response, isNotNull);
      print('⚙️ Configuración creada correctamente.');
    });

    test('4️⃣ Insertar método', () async {
      final response = await client.from('metodos').insert({
        'nombre': 'Pomodoro',
        'descripcion': 'Sesiones cortas de enfoque intenso',
      }).select();
      metodoId = response.first['id_metodo'];
      print('📚 Método creado con ID: $metodoId');
    });

    test('5️⃣ Insertar tema', () async {
      final response = await client.from('temas').insert({
        'titulo': 'Estructuras de Datos',
        'color_hex': '#C6905B',
      }).select();
      temaId = response.first['id_tema'];
      print('🧠 Tema creado con ID: $temaId');
    });

    test('6️⃣ Insertar sesión', () async {
      final response = await client.from('sesiones').insert({
        'id_usuario': usuarioId,
        'id_metodo': metodoId,
        'id_tema': temaId,
        'nombre_sesion': 'Sesión de prueba con Pomodoro',
        'es_rapida': false,
        'duracion_total': 25,
      }).select();
      sesionId = response.first['id_sesion'];
      print('⏱️ Sesión creada con ID: $sesionId');
    });

    test('7️⃣ Insertar stat', () async {
      final response = await client.from('stats').insert({
        'id_usuario': usuarioId,
        'id_sesion': sesionId,
        'tiempo_total_estudio': 25,
        'ciclos_completados': 4,
      }).select();
      expect(response, isNotEmpty);
      print('📊 Stat creada correctamente.');
    });

    test('8️⃣ Limpieza final', () async {
      await client.from('usuarios').delete().eq('id_usuario', usuarioId);
      print('🧹 Usuario y registros relacionados eliminados.');
    });
  });
}
