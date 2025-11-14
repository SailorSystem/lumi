/// Modelo que representa a un usuario registrado en la app.
/// Corresponde a la tabla `usuarios` en la base de datos.
class Usuario {
  final int idUsuario;
  final String nombre;
  final int estadoAnimo; // 0, 1 o 2

  Usuario({
    required this.idUsuario,
    required this.nombre,
    required this.estadoAnimo,
  });

  // From DB
  factory Usuario.fromMap(Map<String, dynamic> map) {
    return Usuario(
      idUsuario: map['id_usuario'],
      nombre: map['nombre'],
      estadoAnimo: map['estado_animo'] ?? 1,
    );
  }

  // To DB
  Map<String, dynamic> toMap() {
    return {
      'id_usuario': idUsuario,
      'nombre': nombre,
      'estado_animo': estadoAnimo,
    };
  }

  Usuario copyWith({
    int? idUsuario,
    String? nombre,
    int? estadoAnimo,
  }) {
    return Usuario(
      idUsuario: idUsuario ?? this.idUsuario,
      nombre: nombre ?? this.nombre,
      estadoAnimo: estadoAnimo ?? this.estadoAnimo,
    );
  }
}
