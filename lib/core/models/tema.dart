/// Representa un tema o materia de estudio.
/// Corresponde a la tabla `temas`.
class Tema {
  final int? idTema;
  final String titulo;
  final String? colorHex;
  final int idUsuario;

  Tema({
    this.idTema,
    required this.titulo,
    this.colorHex,
    required this.idUsuario,
  });

  factory Tema.fromMap(Map<String, dynamic> map) => Tema(
        idTema: map['id_tema'],
        titulo: map['titulo'],
        colorHex: map['color_hex'],
        idUsuario: map['id_usuario'],
      );

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'titulo': titulo,
      'color_hex': colorHex,
      'id_usuario': idUsuario,
    };
    if (idTema != null) map['id_tema'] = idTema;
    return map;
  }
}
