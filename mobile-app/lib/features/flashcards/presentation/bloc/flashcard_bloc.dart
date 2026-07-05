import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile_app/features/flashcards/domain/entities/flashcard.dart';
import 'package:mobile_app/features/flashcards/domain/repositories/flashcard_repository.dart';
import 'flashcard_event.dart';
import 'flashcard_state.dart';

class FlashcardBloc extends Bloc<FlashcardEvent, FlashcardState> {
  final FlashcardRepository flashcardRepository;

  FlashcardBloc({required this.flashcardRepository}) : super(FlashcardInitial()) {
    on<LoadFlashcardQueue>(_onLoadFlashcardQueue);
    on<FlipFlashcard>(_onFlipFlashcard);
    on<SubmitReview>(_onSubmitReview);
    on<ToggleFavorite>(_onToggleFavorite);
    on<JumpToCardNumber>(_onJumpToCardNumber);
    on<SubmitReport>(_onSubmitReport);
    on<NextCard>(_onNextCard);
    on<PrevCard>(_onPrevCard);
    on<ClearJumpWarning>(_onClearJumpWarning);
    on<ResetCardProgressEvent>(_onResetCardProgress);
  }

  Future<void> _onLoadFlashcardQueue(
    LoadFlashcardQueue event,
    Emitter<FlashcardState> emit,
  ) async {
    emit(FlashcardLoading());
    try {
      final queue = await flashcardRepository.getReviewQueue(
        event.courseId,
        isTodayReview: event.isTodayReview,
      );
      if (queue.isEmpty) {
        emit(FlashcardFinished(event.courseId));
        return;
      }

      final isFav = await flashcardRepository.isFavorite(
        courseId: event.courseId,
        cardNumber: queue[0].cardNumber,
      );

      emit(FlashcardQueueLoaded(
        courseId: event.courseId,
        queue: queue,
        currentIndex: 0,
        isTodayReview: event.isTodayReview,
        isFavorited: isFav,
      ));
    } catch (e) {
      emit(FlashcardError('Failed to load study queue: ${e.toString()}'));
    }
  }

  void _onFlipFlashcard(
    FlipFlashcard event,
    Emitter<FlashcardState> emit,
  ) {
    final currentState = state;
    if (currentState is FlashcardQueueLoaded) {
      emit(currentState.copyWith(isFlipped: !currentState.isFlipped));
    }
  }

  Future<void> _onSubmitReview(
    SubmitReview event,
    Emitter<FlashcardState> emit,
  ) async {
    final currentState = state;
    if (currentState is FlashcardQueueLoaded) {
      final currentCard = currentState.currentCard;
      if (currentCard == null) return;

      try {
        await flashcardRepository.submitReview(
          courseId: currentState.courseId,
          cardNumber: currentCard.cardNumber,
          isCorrect: event.isCorrect,
        );

        final newQueue = await flashcardRepository.getReviewQueue(
          currentState.courseId,
          isTodayReview: currentState.isTodayReview,
        );
        if (newQueue.isEmpty) {
          emit(FlashcardFinished(currentState.courseId));
          return;
        }

        // After reviewing, we stay at index 0 (which is the next due card)
        final isFav = await flashcardRepository.isFavorite(
          courseId: currentState.courseId,
          cardNumber: newQueue[0].cardNumber,
        );

        emit(currentState.copyWith(
          queue: newQueue,
          currentIndex: 0,
          isFlipped: false,
          isFavorited: isFav,
        ));
      } catch (e) {
        emit(currentState.copyWith(error: 'Failed to submit review: ${e.toString()}'));
      }
    }
  }

  Future<void> _onToggleFavorite(
    ToggleFavorite event,
    Emitter<FlashcardState> emit,
  ) async {
    final currentState = state;
    if (currentState is FlashcardQueueLoaded) {
      final currentCard = currentState.currentCard;
      if (currentCard == null) return;

      try {
        await flashcardRepository.toggleFavorite(
          courseId: currentState.courseId,
          cardNumber: currentCard.cardNumber,
        );

        final isFav = await flashcardRepository.isFavorite(
          courseId: currentState.courseId,
          cardNumber: currentCard.cardNumber,
        );

        emit(currentState.copyWith(isFavorited: isFav));
      } catch (e) {
        emit(currentState.copyWith(error: 'Failed to update favorites: ${e.toString()}'));
      }
    }
  }

  Future<void> _onJumpToCardNumber(
    JumpToCardNumber event,
    Emitter<FlashcardState> emit,
  ) async {
    final currentState = state;
    if (currentState is FlashcardQueueLoaded) {
      try {
        final card = await flashcardRepository.getCardByNumber(
          currentState.courseId,
          event.cardNumber,
        );

        if (card == null) {
          emit(currentState.copyWith(error: 'Card number ${event.cardNumber} not found in this course.'));
          return;
        }

        final updatedQueue = List<Flashcard>.from(currentState.queue);
        final index = updatedQueue.indexWhere((c) => c.cardNumber == card.cardNumber);
        int finalIndex;

        if (index != -1) {
          finalIndex = index;
        } else {
          updatedQueue.removeWhere((c) => c.cardNumber == card.cardNumber);
          updatedQueue.insert(currentState.currentIndex, card);
          finalIndex = currentState.currentIndex;
        }

        final isFav = await flashcardRepository.isFavorite(
          courseId: currentState.courseId,
          cardNumber: card.cardNumber,
        );

        emit(currentState.copyWith(
          queue: updatedQueue,
          currentIndex: finalIndex,
          isFlipped: false,
          isFavorited: isFav,
          jumpWarningCardNumber: null,
          jumpTargetCard: null,
        ));
      } catch (e) {
        emit(currentState.copyWith(error: 'Failed to jump to card: ${e.toString()}'));
      }
    }
  }

  Future<void> _onSubmitReport(
    SubmitReport event,
    Emitter<FlashcardState> emit,
  ) async {
    final currentState = state;
    if (currentState is FlashcardQueueLoaded) {
      final currentCard = currentState.currentCard;
      if (currentCard == null) return;

      emit(currentState.copyWith(isSubmittingReport: true));
      try {
        await flashcardRepository.submitReport(
          courseId: currentState.courseId,
          cardNumber: currentCard.cardNumber,
          reportText: event.reportText,
        );

        emit(currentState.copyWith(
          isSubmittingReport: false,
          reportMessage: 'Flashcard report submitted successfully.',
        ));
      } catch (e) {
        emit(currentState.copyWith(
          isSubmittingReport: false,
          reportMessage: 'Failed to submit report. Please check your network connection.',
        ));
      }
    }
  }

  Future<void> _onNextCard(
    NextCard event,
    Emitter<FlashcardState> emit,
  ) async {
    final currentState = state;
    if (currentState is FlashcardQueueLoaded) {
      final nextIndex = currentState.currentIndex + 1;
      if (nextIndex < currentState.queue.length) {
        final card = currentState.queue[nextIndex];
        final isFav = await flashcardRepository.isFavorite(
          courseId: currentState.courseId,
          cardNumber: card.cardNumber,
        );

        emit(currentState.copyWith(
          currentIndex: nextIndex,
          isFlipped: false,
          isFavorited: isFav,
          jumpWarningCardNumber: null,
          jumpTargetCard: null,
        ));
      }
    }
  }

  Future<void> _onPrevCard(
    PrevCard event,
    Emitter<FlashcardState> emit,
  ) async {
    final currentState = state;
    if (currentState is FlashcardQueueLoaded) {
      final prevIndex = currentState.currentIndex - 1;
      if (prevIndex >= 0) {
        final card = currentState.queue[prevIndex];
        final isFav = await flashcardRepository.isFavorite(
          courseId: currentState.courseId,
          cardNumber: card.cardNumber,
        );

        emit(currentState.copyWith(
          currentIndex: prevIndex,
          isFlipped: false,
          isFavorited: isFav,
          jumpWarningCardNumber: null,
          jumpTargetCard: null,
        ));
      }
    }
  }

  void _onClearJumpWarning(
    ClearJumpWarning event,
    Emitter<FlashcardState> emit,
  ) {
    final currentState = state;
    if (currentState is FlashcardQueueLoaded) {
      emit(currentState.copyWith());
    }
  }

  Future<void> _onResetCardProgress(
    ResetCardProgressEvent event,
    Emitter<FlashcardState> emit,
  ) async {
    final currentState = state;
    if (currentState is FlashcardQueueLoaded) {
      try {
        await flashcardRepository.resetCardProgress(
          courseId: currentState.courseId,
          cardNumber: event.cardNumber,
          reason: 'JUMP',
        );

        final newQueue = await flashcardRepository.getReviewQueue(
          currentState.courseId,
          isTodayReview: currentState.isTodayReview,
        );

        final newIndex = newQueue.indexWhere((c) => c.cardNumber == event.cardNumber);
        final finalIndex = newIndex != -1 ? newIndex : (currentState.currentIndex < newQueue.length ? currentState.currentIndex : 0);

        final isFav = finalIndex < newQueue.length
            ? await flashcardRepository.isFavorite(
                courseId: currentState.courseId,
                cardNumber: newQueue[finalIndex].cardNumber,
              )
            : false;

        emit(currentState.copyWith(
          queue: newQueue,
          currentIndex: finalIndex,
          isFlipped: false,
          isFavorited: isFav,
          jumpWarningCardNumber: null,
          jumpTargetCard: null,
        ));
      } catch (e) {
        emit(currentState.copyWith(error: 'Failed to reset progress: ${e.toString()}'));
      }
    }
  }
}
