/// Representa un tema o materia de estudio.
/// Corresponde a la tabla `temas`.
class Tema {
  final int? idTema;
  final String titulo;
  final String? colorHex;

  Tema({
    this.idTema,
    required this.titulo,
    this.colorHex,
  });

  factory Tema.fromMap(Map<String, dynamic> map) {
    return Tema(
      idTema: map['id_tema'],
      titulo: map['titulo'],
      colorHex: map['color_hex'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id_tema': idTema,
      'titulo': titulo,
      'color_hex': colorHex,
    };
  }
}
