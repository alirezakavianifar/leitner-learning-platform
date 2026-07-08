import 'package:mobile_app/features/flashcards/domain/entities/card_progress.dart';

class CardProgressModel extends CardProgress {
  const CardProgressModel({
    required super.id,
    required super.courseId,
    required super.cardNumber,
    required super.currentBox,
    super.lastReviewedAt,
    super.nextReviewDue,
    super.lastTrigger,
    required super.isSynced,
    required super.hasEnteredLeitner,
  });

  factory CardProgressModel.fromMap(Map<String, dynamic> map) {
    return CardProgressModel(
      id: map['id'] as String,
      courseId: map['course_id'] as String,
      cardNumber: map['card_number'] as int,
      currentBox: map['current_box'] as int,
      lastReviewedAt: map['last_reviewed_at'] != null
          ? DateTime.parse(map['last_reviewed_at'] as String)
          : null,
      nextReviewDue: map['next_review_due'] != null
          ? DateTime.parse(map['next_review_due'] as String)
          : null,
      lastTrigger: map['last_trigger'] as String?,
      isSynced: (map['is_synced'] as int) == 1,
      hasEnteredLeitner: (map['has_entered_leitner'] as int? ?? 0) == 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'course_id': courseId,
      'card_number': cardNumber,
      'current_box': currentBox,
      'last_reviewed_at': lastReviewedAt?.toUtc().toIso8601String(),
      'next_review_due': nextReviewDue?.toUtc().toIso8601String(),
      'last_trigger': lastTrigger,
      'is_synced': isSynced ? 1 : 0,
      'has_entered_leitner': hasEnteredLeitner ? 1 : 0,
    };
  }
}
