//lib/core/models/tema.dart
class Tema {
  final int? idTema; // Nullable porque aún no existe al crear
  final int idUsuario;
  final String nombre;
  final int color;

  Tema({
    this.idTema,
    required this.idUsuario,
    required this.nombre,
    required this.color,
  });

  // Para enviar a Supabase
  Map<String, dynamic> toJson() => {
        'id_usuario': idUsuario,
        'nombre': nombre,
        'color': color,
      };

  // Para crear instancia desde Supabase
  factory Tema.fromJson(Map<String, dynamic> json) => Tema(
        idTema: json['id_tema'] as int?,
        idUsuario: json['id_usuario'] as int,
        nombre: json['nombre'] as String,
        color: json['color'] as int,
      );
}
