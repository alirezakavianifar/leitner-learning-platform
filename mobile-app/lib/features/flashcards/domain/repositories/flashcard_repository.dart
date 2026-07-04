import 'package:mobile_app/features/flashcards/domain/entities/flashcard.dart';

abstract class FlashcardRepository {
  /// Fetches the review queue for a given course.
  /// Only returns Box 1 cards + active due cards from Boxes 2–5.
  Future<List<Flashcard>> getReviewQueue(String courseId, {bool isTodayReview = false});

  /// Submits the review outcome for a card (Know / Don't Know).
  /// Calculates the next box, progression intervals, and next review due time.
  /// Also emits domain events: CardReviewed or CardFinished.
  Future<void> submitReview({
    required String courseId,
    required int cardNumber,
    required bool isCorrect,
  });

  /// Resets a card's Leitner progress back to Box 1.
  /// Emits LeitnerProgressReset.
  Future<void> resetCardProgress({
    required String courseId,
    required int cardNumber,
    required String reason,
  });

  /// Scans progress records in Boxes 2-5 for the given course.
  /// If next_review_due is strictly before today's start date (local time),
  /// the progress is reset back to Box 1, and DueDateOverdueReset is emitted.
  Future<void> checkForOverdueResets(String courseId);

  /// Synchronizes local progress changes (is_synced = 0) to the backend.
  Future<void> syncProgress();

  /// Fetches counts of cards per Leitner box in a course.
  /// Returns a map of box index (1 to 6) to count of cards.
  Future<Map<int, int>> getCourseStatistics(String courseId);

  /// Fetches a specific card by its number.
  Future<Flashcard?> getCardByNumber(String courseId, int cardNumber);

  /// Toggles a card's favorite status in the local database.
  Future<void> toggleFavorite({
    required String courseId,
    required int cardNumber,
  });

  /// Checks if a card is currently marked as favorite.
  Future<bool> isFavorite({
    required String courseId,
    required int cardNumber,
  });

  /// Fetches all favorited cards for a course.
  Future<List<Flashcard>> getFavoriteCards(String courseId);

  /// Submits a flashcard report to the backend API.
  Future<void> submitReport({
    required String courseId,
    required int cardNumber,
    required String reportText,
  });

  /// Fetches global due count of cards for all courses.
  Future<int> getGlobalDueCount();

  /// Fetches global finished count of cards for all courses.
  Future<int> getGlobalFinishedCount();

  /// Fetches all finished cards for all courses.
  Future<List<Flashcard>> getFinishedCards();

  /// Fetches all cards in a given course, matching with their current learning progress.
  Future<List<Flashcard>> getAllCardsForCourse(String courseId);
}
