import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/tema.dart';

class TemaService {
  static final _supabase = Supabase.instance.client;

  static Future<Tema?> crearTema(Tema tema) async {
    final res = await _supabase.from('temas').insert(tema.toJson()).select().single();
    if (res != null) return Tema.fromJson(res);
    return null;
  }

  static Future<List<Tema>> obtenerTemasPorUsuario(int idUsuario) async {
    final res = await _supabase.from('temas').select().eq('id_usuario', idUsuario);
    return (res as List).map((e) => Tema.fromJson(e)).toList();
  }

  static Future<void> borrarTema(int idTema) async {
    await _supabase.from('temas').delete().eq('id_tema', idTema);
  }
}
