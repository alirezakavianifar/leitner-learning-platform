import 'package:equatable/equatable.dart';
import 'card_progress.dart';

class Flashcard extends Equatable {
  final String id;
  final String courseId;
  final int cardNumber;
  final String questionText;
  final String answerText;
  final String? imageUrl;
  final String? audioUrl;
  final List<String>? options;
  final CardProgress progress;

  const Flashcard({
    required this.id,
    required this.courseId,
    required this.cardNumber,
    required this.questionText,
    required this.answerText,
    this.imageUrl,
    this.audioUrl,
    this.options,
    required this.progress,
  });

  Flashcard copyWith({
    String? id,
    String? courseId,
    int? cardNumber,
    String? questionText,
    String? answerText,
    String? imageUrl,
    String? audioUrl,
    List<String>? options,
    CardProgress? progress,
  }) {
    return Flashcard(
      id: id ?? this.id,
      courseId: courseId ?? this.courseId,
      cardNumber: cardNumber ?? this.cardNumber,
      questionText: questionText ?? this.questionText,
      answerText: answerText ?? this.answerText,
      imageUrl: imageUrl ?? this.imageUrl,
      audioUrl: audioUrl ?? this.audioUrl,
      options: options ?? this.options,
      progress: progress ?? this.progress,
    );
  }

  @override
  List<Object?> get props => [
        id,
        courseId,
        cardNumber,
        questionText,
        answerText,
        imageUrl,
        audioUrl,
        options,
        progress,
      ];
}
