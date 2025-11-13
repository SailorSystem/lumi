/// Configuración personalizada de un usuario.
/// Corresponde a la tabla `configuraciones`.
class Configuracion {
  final int? idConfig;
  final int idUsuario;
  final bool modoOscuro;
  final bool notificacionesActivadas;
  final bool sonido;

  Configuracion({
    this.idConfig,
    required this.idUsuario,
    this.modoOscuro = false,
    this.notificacionesActivadas = true,
    this.sonido = true,
  });

  factory Configuracion.fromMap(Map<String, dynamic> map) {
    return Configuracion(
      idConfig: map['id_config'],
      idUsuario: map['id_usuario'],
      modoOscuro: map['modo_oscuro'] ?? false,
      notificacionesActivadas: map['notificaciones_activadas'] ?? true,
      sonido: map['sonido'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id_config': idConfig,
      'id_usuario': idUsuario,
      'modo_oscuro': modoOscuro,
      'notificaciones_activadas': notificacionesActivadas,
      'sonido': sonido,
    };
  }
}
