/// lib/core/models/flashcard.dart
class Flashcard {
  final String id;
  String front;
  String back;

  Flashcard({
    required this.id,
    required this.front,
    required this.back,
  });

  factory Flashcard.fromJson(Map<String, dynamic> json) {
    return Flashcard(
      id: json['id'],
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
