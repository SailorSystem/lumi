/// Representa una sesión de estudio del usuario.
/// Corresponde a la tabla `sesiones`.
class Sesion {
  final int? idSesion;
  final int idUsuario;
  final int? idMetodo;
  final int? idTema;
  final String nombreSesion;
  final DateTime fecha;
  final bool esRapida;
  final int? duracionTotal;
  final String estado; // <-- AGREGADO

  Sesion({
    this.idSesion,
    required this.idUsuario,
    this.idMetodo,
    this.idTema,
    required this.nombreSesion,
    required this.fecha,
    this.esRapida = false,
    this.duracionTotal,
    this.estado = "programada", // <-- default en tu SQL
  });

  factory Sesion.fromMap(Map<String, dynamic> map) {
    return Sesion(
      idSesion: map['id_sesion'],
      idUsuario: map['id_usuario'],
      idMetodo: map['id_metodo'],
      idTema: map['id_tema'],
      nombreSesion: map['nombre_sesion'],
      fecha: DateTime.parse(map['fecha']),
      esRapida: map['es_rapida'] ?? false,
      duracionTotal: map['duracion_total'],
      estado: map['estado'] ?? 'programada',
    );
  }

  Map<String, dynamic> toMap() {
    final map = {
      'id_usuario': idUsuario,
      'id_metodo': idMetodo,
      'id_tema': idTema,
      'nombre_sesion': nombreSesion,
      'fecha': fecha.toIso8601String(),
      'es_rapida': esRapida,
      'duracion_total': duracionTotal,
      'estado': estado,
    };

    if (idSesion != null) {
      map['id_sesion'] = idSesion;
    }

    return map;
  }
}
