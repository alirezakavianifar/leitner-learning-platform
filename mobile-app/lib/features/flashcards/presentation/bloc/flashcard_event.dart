import 'package:equatable/equatable.dart';

abstract class FlashcardEvent extends Equatable {
  const FlashcardEvent();

  @override
  List<Object?> get props => [];
}

class LoadFlashcardQueue extends FlashcardEvent {
  final String courseId;
  final bool isTodayReview;

  const LoadFlashcardQueue(this.courseId, {this.isTodayReview = false});

  @override
  List<Object?> get props => [courseId, isTodayReview];
}

class FlipFlashcard extends FlashcardEvent {}

class SubmitReview extends FlashcardEvent {
  final bool isCorrect;

  const SubmitReview({required this.isCorrect});

  @override
  List<Object?> get props => [isCorrect];
}

class ToggleFavorite extends FlashcardEvent {}

class JumpToCardNumber extends FlashcardEvent {
  final int cardNumber;
  final bool forceReset;

  const JumpToCardNumber(this.cardNumber, {this.forceReset = false});

  @override
  List<Object?> get props => [cardNumber, forceReset];
}

class SubmitReport extends FlashcardEvent {
  final String reportText;

  const SubmitReport(this.reportText);

  @override
  List<Object?> get props => [reportText];
}

class NextCard extends FlashcardEvent {
  final bool forceReset;
  const NextCard({this.forceReset = false});

  @override
  List<Object?> get props => [forceReset];
}

class PrevCard extends FlashcardEvent {
  final bool forceReset;
  const PrevCard({this.forceReset = false});

  @override
  List<Object?> get props => [forceReset];
}

class ClearJumpWarning extends FlashcardEvent {}

class ResetCardProgressEvent extends FlashcardEvent {
  final int cardNumber;
  const ResetCardProgressEvent(this.cardNumber);

  @override
  List<Object?> get props => [cardNumber];
}
