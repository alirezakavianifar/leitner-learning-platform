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
      final List<Flashcard> queue;
      if (event.isFromFavorites) {
        queue = await flashcardRepository.getFavoriteCards(event.courseId);
      } else {
        queue = await flashcardRepository.getReviewQueue(
          event.courseId,
          isTodayReview: event.isTodayReview,
        );
      }

      int finalIndex = 0;
      List<Flashcard> finalQueue = List<Flashcard>.from(queue);
      Flashcard? initialCard;

      if (event.initialCardNumber != null) {
        final index = finalQueue.indexWhere((c) => c.cardNumber == event.initialCardNumber!);
        if (index != -1) {
          finalIndex = index;
        } else {
          initialCard = await flashcardRepository.getCardByNumber(
            event.courseId,
            event.initialCardNumber!,
          );
          if (initialCard != null) {
            // Insert at position 0. If it is in the active Leitner process
            // the jump-warning view will handle it; Prev/Next navigation
            // guards will skip it even if it ends up in the queue.
            finalQueue.insert(0, initialCard);
            finalIndex = 0;
          }
        }
      }

      if (finalQueue.isEmpty) {
        emit(FlashcardFinished(event.courseId));
        return;
      }

      final currentCard = finalQueue[finalIndex];
      final isFav = await flashcardRepository.isFavorite(
        courseId: event.courseId,
        cardNumber: currentCard.cardNumber,
      );

      final box = currentCard.progress.currentBox;
      if (box >= 2 && box <= 5 && (event.isFromFavorites || event.initialCardNumber != null)) {
        emit(FlashcardQueueLoaded(
          courseId: event.courseId,
          queue: finalQueue,
          currentIndex: finalIndex,
          isTodayReview: event.isTodayReview,
          isFromFavorites: event.isFromFavorites,
          isFavorited: isFav,
          jumpWarningCardNumber: currentCard.cardNumber,
          jumpTargetCard: currentCard,
        ));
        return;
      }

      emit(FlashcardQueueLoaded(
        courseId: event.courseId,
        queue: finalQueue,
        currentIndex: finalIndex,
        isTodayReview: event.isTodayReview,
        isFromFavorites: event.isFromFavorites,
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

        final newQueue = currentState.isFromFavorites
            ? await flashcardRepository.getFavoriteCards(currentState.courseId)
            : await flashcardRepository.getReviewQueue(
                currentState.courseId,
                isTodayReview: currentState.isTodayReview,
              );
        if (newQueue.isEmpty) {
          emit(FlashcardFinished(currentState.courseId));
          return;
        }

        int nextIndex;
        if (currentState.isFromFavorites) {
          final now = DateTime.now();
          nextIndex = newQueue.indexWhere((c) =>
              c.cardNumber > currentCard.cardNumber &&
              (c.progress.currentBox == 1 ||
                  c.progress.currentBox >= 6 ||
                  (c.progress.nextReviewDue != null &&
                      c.progress.nextReviewDue!.isBefore(now.add(const Duration(seconds: 1))))));

          if (nextIndex == -1) {
            nextIndex = newQueue.indexWhere((c) =>
                c.cardNumber != currentCard.cardNumber &&
                (c.progress.currentBox == 1 ||
                    c.progress.currentBox >= 6 ||
                    (c.progress.nextReviewDue != null &&
                        c.progress.nextReviewDue!.isBefore(now.add(const Duration(seconds: 1))))));
          }

          if (nextIndex == -1) {
            emit(FlashcardFinished(currentState.courseId));
            return;
          }
        } else {
          // Adjust index to the next card in sequence by card number, or the last card in new queue if out of bounds
          nextIndex = newQueue.indexWhere((c) => c.cardNumber > currentCard.cardNumber);
          if (nextIndex == -1) {
            nextIndex = newQueue.length - 1;
          }
        }

        final nextCard = newQueue[nextIndex];
        final isFav = await flashcardRepository.isFavorite(
          courseId: currentState.courseId,
          cardNumber: nextCard.cardNumber,
        );

        final box = nextCard.progress.currentBox;
        if (box >= 2 && box <= 5 && currentState.isFromFavorites) {
          emit(currentState.copyWith(
            queue: newQueue,
            currentIndex: nextIndex,
            isFlipped: false,
            isFavorited: isFav,
            jumpWarningCardNumber: nextCard.cardNumber,
            jumpTargetCard: nextCard,
          ));
        } else {
          emit(currentState.copyWith(
            queue: newQueue,
            currentIndex: nextIndex,
            isFlipped: false,
            isFavorited: isFav,
            jumpWarningCardNumber: null,
            jumpTargetCard: null,
          ));
        }
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

        final box = card.progress.currentBox;
        if (box >= 2 && box <= 5 && !event.forceReset) {
          emit(currentState.copyWith(
            jumpWarningCardNumber: card.cardNumber,
            jumpTargetCard: card,
          ));
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
          reportMessage: 'report_submitted_success',
        ));
      } catch (e) {
        emit(currentState.copyWith(
          isSubmittingReport: false,
          reportMessage: 'report_submitted_failure',
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
      int nextIndex = currentState.currentIndex + 1;
      if (nextIndex < currentState.queue.length) {
        final card = currentState.queue[nextIndex];
        final isFav = await flashcardRepository.isFavorite(
          courseId: currentState.courseId,
          cardNumber: card.cardNumber,
        );

        final box = card.progress.currentBox;
        if (box >= 2 && box <= 5 && currentState.isFromFavorites) {
          emit(currentState.copyWith(
            currentIndex: nextIndex,
            isFlipped: false,
            isFavorited: isFav,
            jumpWarningCardNumber: card.cardNumber,
            jumpTargetCard: card,
          ));
        } else {
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
  }

  Future<void> _onPrevCard(
    PrevCard event,
    Emitter<FlashcardState> emit,
  ) async {
    final currentState = state;
    if (currentState is FlashcardQueueLoaded) {
      int prevIndex = currentState.currentIndex - 1;
      if (prevIndex >= 0) {
        final card = currentState.queue[prevIndex];
        final isFav = await flashcardRepository.isFavorite(
          courseId: currentState.courseId,
          cardNumber: card.cardNumber,
        );

        final box = card.progress.currentBox;
        if (box >= 2 && box <= 5 && currentState.isFromFavorites) {
          emit(currentState.copyWith(
            currentIndex: prevIndex,
            isFlipped: false,
            isFavorited: isFav,
            jumpWarningCardNumber: card.cardNumber,
            jumpTargetCard: card,
          ));
        } else {
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
  }

  void _onClearJumpWarning(
    ClearJumpWarning event,
    Emitter<FlashcardState> emit,
  ) {
    final currentState = state;
    if (currentState is FlashcardQueueLoaded) {
      emit(currentState.copyWith(
        jumpWarningCardNumber: null,
        jumpTargetCard: null,
      ));
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
          reason: event.reason,
        );

        final newQueue = currentState.isFromFavorites
            ? await flashcardRepository.getFavoriteCards(currentState.courseId)
            : await flashcardRepository.getReviewQueue(
                currentState.courseId,
                isTodayReview: currentState.isTodayReview,
              );

        final card = await flashcardRepository.getCardByNumber(
          currentState.courseId,
          event.cardNumber,
        );

        final updatedQueue = List<Flashcard>.from(newQueue);
        final index = updatedQueue.indexWhere((c) => c.cardNumber == event.cardNumber);
        int finalIndex;

        if (index != -1) {
          finalIndex = index;
          if (card != null) {
            updatedQueue[index] = card;
          }
        } else {
          if (card != null) {
            final insertIdx = currentState.currentIndex < updatedQueue.length ? currentState.currentIndex : 0;
            updatedQueue.insert(insertIdx, card);
            finalIndex = insertIdx;
          } else {
            finalIndex = 0;
          }
        }

        final isFav = finalIndex < updatedQueue.length
            ? await flashcardRepository.isFavorite(
                courseId: currentState.courseId,
                cardNumber: updatedQueue[finalIndex].cardNumber,
              )
            : false;

        emit(currentState.copyWith(
          queue: updatedQueue,
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
