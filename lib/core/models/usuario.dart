/// Modelo que representa a un usuario registrado en la app.
/// Corresponde a la tabla `usuarios` en la base de datos.
class Usuario {
  final int? idUsuario;
  final String nombre;

  Usuario({
    this.idUsuario,
    required this.nombre,
  });

  /// Crea una instancia de [Usuario] desde un mapa (por ejemplo, de Supabase).
  factory Usuario.fromMap(Map<String, dynamic> map) {
    return Usuario(
      idUsuario: map['id_usuario'],
      nombre: map['nombre'],
    );
  }

  /// Convierte el objeto [Usuario] a un mapa para insertar o actualizar en la BD.
  Map<String, dynamic> toMap() {
    return {
      'id_usuario': idUsuario,
      'nombre': nombre,
    };
  }
}
