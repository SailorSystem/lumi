/// Representa las estadísticas de una sesión de estudio.
/// Corresponde a la tabla `stats`.
class Stat {
  final int? idStat;
  final int idUsuario;
  final int idSesion;
  final DateTime fechaRegistro;
  final int tiempoTotalEstudio;
  final int ciclosCompletados;

  Stat({
    this.idStat,
    required this.idUsuario,
    required this.idSesion,
    required this.fechaRegistro,
    required this.tiempoTotalEstudio,
    required this.ciclosCompletados,
  });

  factory Stat.fromMap(Map<String, dynamic> map) {
    return Stat(
      idStat: map['id_stat'],
      idUsuario: map['id_usuario'],
      idSesion: map['id_sesion'],
      fechaRegistro: DateTime.parse(map['fecha_registro']),
      tiempoTotalEstudio: map['tiempo_total_estudio'],
      ciclosCompletados: map['ciclos_completados'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id_stat': idStat,
      'id_usuario': idUsuario,
      'id_sesion': idSesion,
      'fecha_registro': fechaRegistro.toIso8601String(),
      'tiempo_total_estudio': tiempoTotalEstudio,
      'ciclos_completados': ciclosCompletados,
    };
  }
}
