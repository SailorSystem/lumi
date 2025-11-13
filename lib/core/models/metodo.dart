/// Representa un método de estudio (Pomodoro, Leitner, etc.)
/// Corresponde a la tabla `metodos`.
class Metodo {
  final int? idMetodo;
  final String nombre;
  final String? descripcion;

  Metodo({
    this.idMetodo,
    required this.nombre,
    this.descripcion,
  });

  factory Metodo.fromMap(Map<String, dynamic> map) {
    return Metodo(
      idMetodo: map['id_metodo'],
      nombre: map['nombre'],
      descripcion: map['descripcion'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id_metodo': idMetodo,
      'nombre': nombre,
      'descripcion': descripcion,
    };
  }
}
