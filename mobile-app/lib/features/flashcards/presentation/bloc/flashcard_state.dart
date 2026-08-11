import 'package:equatable/equatable.dart';
import 'package:mobile_app/features/flashcards/domain/entities/flashcard.dart';

abstract class FlashcardState extends Equatable {
  const FlashcardState();

  @override
  List<Object?> get props => [];
}

class FlashcardInitial extends FlashcardState {}

class FlashcardLoading extends FlashcardState {}

class FlashcardQueueLoaded extends FlashcardState {
  final String courseId;
  final List<Flashcard> queue;
  final int currentIndex;
  final bool isTodayReview;
  final bool isFromFavorites;
  final bool isFlipped;
  final bool isFavorited;
  final bool isSubmittingReport;
  final String? reportMessage;
  final int? jumpWarningCardNumber; // If not null, displays a reset confirmation warning dialog in UI
  final Flashcard? jumpTargetCard;  // The loaded card for jumping after confirmation
  final String? error;

  const FlashcardQueueLoaded({
    required this.courseId,
    required this.queue,
    required this.currentIndex,
    this.isTodayReview = false,
    this.isFromFavorites = false,
    this.isFlipped = false,
    this.isFavorited = false,
    this.isSubmittingReport = false,
    this.reportMessage,
    this.jumpWarningCardNumber,
    this.jumpTargetCard,
    this.error,
  });

  Flashcard? get currentCard {
    if (queue.isEmpty || currentIndex < 0 || currentIndex >= queue.length) {
      return null;
    }
    return queue[currentIndex];
  }

  FlashcardQueueLoaded copyWith({
    String? courseId,
    List<Flashcard>? queue,
    int? currentIndex,
    bool? isTodayReview,
    bool? isFromFavorites,
    bool? isFlipped,
    bool? isFavorited,
    bool? isSubmittingReport,
    String? reportMessage,
    int? jumpWarningCardNumber,
    Flashcard? jumpTargetCard,
    String? error,
  }) {
    return FlashcardQueueLoaded(
      courseId: courseId ?? this.courseId,
      queue: queue ?? this.queue,
      currentIndex: currentIndex ?? this.currentIndex,
      isTodayReview: isTodayReview ?? this.isTodayReview,
      isFromFavorites: isFromFavorites ?? this.isFromFavorites,
      isFlipped: isFlipped ?? this.isFlipped,
      isFavorited: isFavorited ?? this.isFavorited,
      isSubmittingReport: isSubmittingReport ?? this.isSubmittingReport,
      reportMessage: reportMessage, // reset/nullified unless specified
      jumpWarningCardNumber: jumpWarningCardNumber, // reset unless specified
      jumpTargetCard: jumpTargetCard, // reset unless specified
      error: error,
    );
  }

  @override
  List<Object?> get props => [
        courseId,
        queue,
        currentIndex,
        isTodayReview,
        isFromFavorites,
        isFlipped,
        isFavorited,
        isSubmittingReport,
        reportMessage,
        jumpWarningCardNumber,
        jumpTargetCard,
        error,
      ];
}

class FlashcardFinished extends FlashcardState {
  final String courseId;

  const FlashcardFinished(this.courseId);

  @override
  List<Object?> get props => [courseId];
}

class FlashcardError extends FlashcardState {
  final String message;

  const FlashcardError(this.message);

  @override
  List<Object?> get props => [message];
}
