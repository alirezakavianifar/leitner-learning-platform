import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mobile_app/app/theme.dart';
import 'package:mobile_app/core/localization/app_localizations.dart';
import 'package:mobile_app/features/flashcards/domain/entities/card_progress.dart';
import 'package:mobile_app/features/flashcards/domain/entities/flashcard.dart';
import 'package:mobile_app/features/flashcards/domain/repositories/flashcard_repository.dart';
import 'package:mobile_app/features/flashcards/presentation/bloc/flashcard_bloc.dart';
import 'package:mobile_app/features/flashcards/presentation/bloc/flashcard_event.dart';
import 'package:mobile_app/features/flashcards/presentation/bloc/flashcard_state.dart';

class MockFlashcardRepo implements FlashcardRepository {
  final List<Flashcard> queue;
  MockFlashcardRepo(this.queue);

  @override
  Future<List<Flashcard>> getReviewQueue(String courseId, {bool isTodayReview = false}) async => queue;

  @override
  Future<List<Flashcard>> getFavoriteCards(String courseId) async => [];

  @override
  Future<bool> isFavorite({required String courseId, required int cardNumber}) async => false;

  @override
  Future<Flashcard?> getCardByNumber(String courseId, int cardNumber) async {
    try {
      return queue.firstWhere((c) => c.cardNumber == cardNumber);
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

List<Flashcard> generateTestCards(int count) {
  return List.generate(
    count,
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
}

void main() {
  group('Comprehensive Flashcard Shuffle Verification (Issue 7)', () {
    test('1. BLoC preserves active card position and card numbers during shuffle and restore', () async {
      final cards = generateTestCards(10);
      final repo = MockFlashcardRepo(cards);
      final bloc = FlashcardBloc(flashcardRepository: repo);

      // 1. Initial sequential queue
      bloc.add(const LoadFlashcardQueue('course-1'));
      await bloc.stream.firstWhere((s) => s is FlashcardQueueLoaded);
      final initial = bloc.state as FlashcardQueueLoaded;
      expect(initial.isShuffled, isFalse);
      expect(initial.queue.map((c) => c.cardNumber).toList(), [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);
      expect(initial.currentCard?.cardNumber, 1);

      // 2. Advance to card #5
      bloc.add(const NextCard());
      bloc.add(const NextCard());
      bloc.add(const NextCard());
      bloc.add(const NextCard());
      await bloc.stream.firstWhere((s) => s is FlashcardQueueLoaded && s.currentIndex == 4);
      final atFive = bloc.state as FlashcardQueueLoaded;
      expect(atFive.currentCard?.cardNumber, 5);

      // 3. Toggle Shuffle ON
      bloc.add(ToggleShuffleCards());
      await bloc.stream.firstWhere((s) => s is FlashcardQueueLoaded && s.isShuffled);
      final shuffled = bloc.state as FlashcardQueueLoaded;
      expect(shuffled.isShuffled, isTrue);
      expect(shuffled.queue.length, 10);
      // Verify all card numbers 1..10 are still present intact
      expect(shuffled.queue.map((c) => c.cardNumber).toSet(), {1, 2, 3, 4, 5, 6, 7, 8, 9, 10});
      // Verify active card is STILL card #5 (no jump)
      expect(shuffled.currentCard?.cardNumber, 5);
      expect(shuffled.currentIndex, shuffled.queue.indexWhere((c) => c.cardNumber == 5));

      // 4. Navigate to next card in shuffled queue
      final expectedNextNumber = shuffled.queue[(shuffled.currentIndex + 1) % 10].cardNumber;
      bloc.add(const NextCard());
      await bloc.stream.firstWhere((s) => s is FlashcardQueueLoaded && s.currentIndex == (shuffled.currentIndex + 1) % 10);
      final movedShuffled = bloc.state as FlashcardQueueLoaded;
      expect(movedShuffled.currentCard?.cardNumber, expectedNextNumber);

      // 5. Toggle Shuffle OFF (restore original sequence)
      bloc.add(ToggleShuffleCards());
      await bloc.stream.firstWhere((s) => s is FlashcardQueueLoaded && !s.isShuffled);
      final restored = bloc.state as FlashcardQueueLoaded;
      expect(restored.isShuffled, isFalse);
      // Queue must match exact original sequential order 1..10
      expect(restored.queue.map((c) => c.cardNumber).toList(), [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);
      // Active card must still match the last card viewed
      expect(restored.currentCard?.cardNumber, expectedNextNumber);
      expect(restored.currentIndex, expectedNextNumber - 1);
    });

    testWidgets('2. UI Shuffle Button toggles color, tooltip, and SnackBar accurately', (tester) async {
      final cards = generateTestCards(5);
      final repo = MockFlashcardRepo(cards);
      final bloc = FlashcardBloc(flashcardRepository: repo);

      bloc.add(const LoadFlashcardQueue('course-1'));
      await bloc.stream.firstWhere((s) => s is FlashcardQueueLoaded);

      await tester.pumpWidget(
        BlocProvider<FlashcardBloc>.value(
          value: bloc,
          child: MaterialApp(
            locale: const Locale('fa'),
            supportedLocales: const [Locale('fa'), Locale('en')],
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: Scaffold(
              body: BlocBuilder<FlashcardBloc, FlashcardState>(
                builder: (context, state) {
                  if (state is! FlashcardQueueLoaded) return const SizedBox();
                  final loc = AppLocalizations.of(context);
                  return Center(
                    child: IconButton(
                      key: const ValueKey('shuffle_btn'),
                      tooltip: state.isShuffled
                          ? loc.translate('restore_order')
                          : loc.translate('shuffle_cards'),
                      icon: Icon(
                        Icons.shuffle,
                        color: state.isShuffled ? AppColors.secondary : AppColors.textSecondary,
                        size: 20,
                      ),
                      onPressed: () {
                        context.read<FlashcardBloc>().add(ToggleShuffleCards());
                        ScaffoldMessenger.of(context).hideCurrentSnackBar();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(loc.translate(state.isShuffled ? 'cards_unshuffled' : 'cards_shuffled')),
                            duration: const Duration(seconds: 2),
                            backgroundColor: AppColors.primary,
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 1. Initial State: inactive color, tooltip 'بر زدن کارت‌ها'
      final initialIcon = tester.widget<Icon>(find.byIcon(Icons.shuffle));
      expect(initialIcon.color, AppColors.textSecondary);
      final initialBtn = tester.widget<IconButton>(find.byKey(const ValueKey('shuffle_btn')));
      expect(initialBtn.tooltip, 'بر زدن کارت‌ها');

      // 2. Tap Shuffle Button
      await tester.tap(find.byKey(const ValueKey('shuffle_btn')));
      await tester.pumpAndSettle();

      // Verify BLoC state is shuffled
      expect((bloc.state as FlashcardQueueLoaded).isShuffled, isTrue);

      // Verify UI updated: icon color changed to AppColors.secondary, tooltip changed
      final activeIcon = tester.widget<Icon>(find.byIcon(Icons.shuffle));
      expect(activeIcon.color, AppColors.secondary);
      final activeBtn = tester.widget<IconButton>(find.byKey(const ValueKey('shuffle_btn')));
      expect(activeBtn.tooltip, 'بازگردانی ترتیب اصلی');

      // Verify SnackBar appeared
      expect(find.text('ترتیب کارت‌ها به صورت تصادفی بر زده شد.'), findsOneWidget);

      // 3. Tap Shuffle Button Again to Restore
      await tester.tap(find.byKey(const ValueKey('shuffle_btn')));
      await tester.pumpAndSettle();

      // Verify BLoC state is un-shuffled
      expect((bloc.state as FlashcardQueueLoaded).isShuffled, isFalse);

      // Verify UI updated: icon color reverted to AppColors.textSecondary
      final revertedIcon = tester.widget<Icon>(find.byIcon(Icons.shuffle));
      expect(revertedIcon.color, AppColors.textSecondary);
      final revertedBtn = tester.widget<IconButton>(find.byKey(const ValueKey('shuffle_btn')));
      expect(revertedBtn.tooltip, 'بر زدن کارت‌ها');

      // Verify SnackBar updated
      expect(find.text('ترتیب کارت‌ها به حالت اولیه بازگشت.'), findsOneWidget);
    });
  });
}
