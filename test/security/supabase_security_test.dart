import 'package:flutter_test/flutter_test.dart';
import 'package:supabase/supabase.dart';

void main() {
  late SupabaseClient client;

  setUpAll(() {
    client = SupabaseClient(
      'https://poxheykxpublcwwodzpz.supabase.co',
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBveGhleWt4cHVibGN3d29kenB6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjI3NzE4MjcsImV4cCI6MjA3ODM0NzgyN30.DZ2L7TxLWCPW65KNk4cHWol3vtipbladCG28D3oPros',
    );
  });

  test('Seguridad: acceso no autorizado debe fallar', () async {
    dynamic result;
    String? errorMessage;

    try {
      /// Elegimos una tabla *que debería estar protegida* por RLS.
      /// Normalmente: sesiones, configuraciones o stats
      result = await client.from('configuraciones').select().limit(1);
    } catch (e) {
      errorMessage = e.toString();
    }

    print('--- RESULTADO PRUEBA DE SEGURIDAD ---');
    print('Respuesta: $result');
    print('Error: $errorMessage');
    print('-------------------------------------');

    /// La prueba valida que:
    /// - NO se recibió información
    /// - O hubo error de acceso

    final bool accesoDenegado = errorMessage != null || result == null;

    expect(
      accesoDenegado,
      true,
      reason:
          '⚠️  La tabla "configuraciones" devolvió datos. RLS podría no estar bien configurado.',
    );
  });
}
