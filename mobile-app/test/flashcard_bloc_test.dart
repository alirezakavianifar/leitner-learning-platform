import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/features/flashcards/domain/entities/flashcard.dart';
import 'package:mobile_app/features/flashcards/domain/entities/card_progress.dart';
import 'package:mobile_app/features/flashcards/domain/repositories/flashcard_repository.dart';
import 'package:mobile_app/features/flashcards/presentation/bloc/flashcard_bloc.dart';
import 'package:mobile_app/features/flashcards/presentation/bloc/flashcard_event.dart';
import 'package:mobile_app/features/flashcards/presentation/bloc/flashcard_state.dart';

class MockFlashcardRepository implements FlashcardRepository {
  final List<Flashcard> reviewQueue;
  final List<Flashcard> favoriteCards;

  MockFlashcardRepository({
    required this.reviewQueue,
    required this.favoriteCards,
  });

  @override
  Future<List<Flashcard>> getReviewQueue(String courseId, {bool isTodayReview = false}) async {
    return reviewQueue;
  }

  @override
  Future<List<Flashcard>> getFavoriteCards(String courseId) async {
    return favoriteCards;
  }

  @override
  Future<bool> isFavorite({required String courseId, required int cardNumber}) async {
    return favoriteCards.any((c) => c.cardNumber == cardNumber);
  }

  @override
  Future<Flashcard?> getCardByNumber(String courseId, int cardNumber) async {
    final all = [...reviewQueue, ...favoriteCards];
    try {
      return all.firstWhere((c) => c.cardNumber == cardNumber);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> submitReview({required String courseId, required int cardNumber, required bool isCorrect}) async {}

  @override
  Future<void> toggleFavorite({required String courseId, required int cardNumber}) async {}

  @override
  Future<void> submitReport({required String courseId, required int cardNumber, required String reportText}) async {}

  @override
  Future<void> resetCardProgress({required String courseId, required int cardNumber, String reason = 'JUMP'}) async {}

  @override
  Future<void> checkForOverdueResets(String courseId) async {}

  @override
  Future<List<Flashcard>> getAllCardsForCourse(String courseId) async => [];

  @override
  Future<Map<int, int>> getCourseStatistics(String courseId) async => {};

  @override
  Future<List<Flashcard>> getFinishedCards() async => [];

  @override
  Future<int> getGlobalDueCount() async => 0;

  @override
  Future<int> getGlobalFinishedCount() async => 0;

  @override
  Future<void> syncProgress() async {}
}

void main() {
  final card1 = Flashcard(
    id: '1',
    courseId: 'course-1',
    cardNumber: 1,
    questionText: 'Question 1',
    answerText: 'Answer 1',
    options: const [],
    progress: const CardProgress(id: '1', courseId: 'course-1', cardNumber: 1, currentBox: 1, isSynced: true, hasEnteredLeitner: true),
  );

  final card2 = Flashcard(
    id: '2',
    courseId: 'course-1',
    cardNumber: 2,
    questionText: 'Question 2 (Favorite)',
    answerText: 'Answer 2',
    options: const [],
    progress: const CardProgress(id: '1', courseId: 'course-1', cardNumber: 1, currentBox: 1, isSynced: true, hasEnteredLeitner: true),
  );

  final card3 = Flashcard(
    id: '3',
    courseId: 'course-1',
    cardNumber: 3,
    questionText: 'Question 3 (Favorite)',
    answerText: 'Answer 3',
    options: const [],
    progress: const CardProgress(id: '1', courseId: 'course-1', cardNumber: 1, currentBox: 1, isSynced: true, hasEnteredLeitner: true),
  );

  group('FlashcardBloc Favorites Queue Tests', () {
    test('LoadFlashcardQueue loads normal queue when isFromFavorites is false', () async {
      final repo = MockFlashcardRepository(
        reviewQueue: [card1, card2, card3],
        favoriteCards: [card2, card3],
      );
      final bloc = FlashcardBloc(flashcardRepository: repo);

      bloc.add(const LoadFlashcardQueue('course-1', isFromFavorites: false));

      await expectLater(
        bloc.stream,
        emitsInOrder([
          isA<FlashcardLoading>(),
          predicate<FlashcardState>((state) {
            if (state is FlashcardQueueLoaded) {
              return state.queue.length == 3 && !state.isFromFavorites;
            }
            return false;
          }),
        ]),
      );
    });

    test('LoadFlashcardQueue loads ONLY favorite cards when isFromFavorites is true', () async {
      final repo = MockFlashcardRepository(
        reviewQueue: [card1, card2, card3],
        favoriteCards: [card2, card3],
      );
      final bloc = FlashcardBloc(flashcardRepository: repo);

      bloc.add(const LoadFlashcardQueue('course-1', isFromFavorites: true, initialCardNumber: 3));

      await expectLater(
        bloc.stream,
        emitsInOrder([
          isA<FlashcardLoading>(),
          predicate<FlashcardState>((state) {
            if (state is FlashcardQueueLoaded) {
              return state.queue.length == 2 &&
                  state.isFromFavorites &&
                  state.currentCard?.cardNumber == 3 &&
                  state.currentIndex == 1;
            }
            return false;
          }),
        ]),
      );
    });

    test('LoadFlashcardQueue with Box 2 favorite card emits jumpWarningCardNumber', () async {
      final box2Card = Flashcard(
        id: '2',
        courseId: 'course-1',
        cardNumber: 2,
        questionText: 'Question 2 (Favorite Box 2)',
        answerText: 'Answer 2',
        options: const [],
        progress: const CardProgress(
          id: '2',
          courseId: 'course-1',
          cardNumber: 2,
          currentBox: 2,
          isSynced: true,
          hasEnteredLeitner: true,
        ),
      );

      final repo = MockFlashcardRepository(
        reviewQueue: [card1],
        favoriteCards: [box2Card, card3],
      );
      final bloc = FlashcardBloc(flashcardRepository: repo);

      bloc.add(const LoadFlashcardQueue('course-1', isFromFavorites: true, initialCardNumber: 2));

      await expectLater(
        bloc.stream,
        emitsInOrder([
          isA<FlashcardLoading>(),
          predicate<FlashcardState>((state) {
            if (state is FlashcardQueueLoaded) {
              return state.queue.length == 2 &&
                  state.isFromFavorites &&
                  state.currentCard?.cardNumber == 2 &&
                  state.jumpWarningCardNumber == 2 &&
                  state.jumpTargetCard?.cardNumber == 2;
            }
            return false;
          }),
        ]),
      );
    });

    test('ToggleShuffleCards toggles between shuffled queue and original queue sequence without modifying card numbers', () async {
      final cards = List.generate(
        10,
        (i) => Flashcard(
          id: 'card-$i',
          courseId: 'course-1',
          cardNumber: i + 1,
          questionText: 'Question ${i + 1}',
          answerText: 'Answer ${i + 1}',
          options: const [],
          progress: CardProgress(
            id: 'p-$i',
            courseId: 'course-1',
            cardNumber: i + 1,
            currentBox: 1,
            isSynced: true,
            hasEnteredLeitner: true,
          ),
        ),
      );

      final repo = MockFlashcardRepository(
        reviewQueue: cards,
        favoriteCards: [],
      );
      final bloc = FlashcardBloc(flashcardRepository: repo);

      bloc.add(const LoadFlashcardQueue('course-1'));
      await bloc.stream.firstWhere((s) => s is FlashcardQueueLoaded);

      final initialLoaded = bloc.state as FlashcardQueueLoaded;
      expect(initialLoaded.isShuffled, isFalse);
      expect(initialLoaded.queue.map((c) => c.cardNumber).toList(), [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);

      // Toggle Shuffle ON
      bloc.add(ToggleShuffleCards());
      await bloc.stream.firstWhere((s) => s is FlashcardQueueLoaded && s.isShuffled);

      final shuffledState = bloc.state as FlashcardQueueLoaded;
      expect(shuffledState.isShuffled, isTrue);
      expect(shuffledState.queue.length, 10);
      // All card numbers 1..10 must be present intact
      expect(shuffledState.queue.map((c) => c.cardNumber).toSet(), {1, 2, 3, 4, 5, 6, 7, 8, 9, 10});

      // Toggle Shuffle OFF (restore original sequence)
      bloc.add(ToggleShuffleCards());
      await bloc.stream.firstWhere((s) => s is FlashcardQueueLoaded && !s.isShuffled);

      final restoredState = bloc.state as FlashcardQueueLoaded;
      expect(restoredState.isShuffled, isFalse);
      expect(restoredState.queue.map((c) => c.cardNumber).toList(), [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);
    });
  });
}
