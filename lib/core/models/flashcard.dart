/// lib/core/models/flashcard.dart
class Flashcard {
  String? id; // ahora opcional
  String front;
  String back;

  Flashcard({
    this.id,
    required this.front,
    required this.back,
  });

  factory Flashcard.fromJson(Map<String, dynamic> json) {
    return Flashcard(
      id: json['id'], // puede venir o no
      front: json['front'],
      back: json['back'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'front': front,
      'back': back,
    };
  }
}
