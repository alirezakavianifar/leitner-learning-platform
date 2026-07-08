import 'package:equatable/equatable.dart';

class CardProgress extends Equatable {
  final String id; // courseId_cardNumber
  final String courseId;
  final int cardNumber;
  final int currentBox;
  final DateTime? lastReviewedAt;
  final DateTime? nextReviewDue;
  final String? lastTrigger;
  final bool isSynced;
  final bool hasEnteredLeitner;

  const CardProgress({
    required this.id,
    required this.courseId,
    required this.cardNumber,
    required this.currentBox,
    this.lastReviewedAt,
    this.nextReviewDue,
    this.lastTrigger,
    required this.isSynced,
    required this.hasEnteredLeitner,
  });

  CardProgress copyWith({
    String? id,
    String? courseId,
    int? cardNumber,
    int? currentBox,
    DateTime? lastReviewedAt,
    DateTime? nextReviewDue,
    String? lastTrigger,
    bool? isSynced,
    bool? hasEnteredLeitner,
  }) {
    return CardProgress(
      id: id ?? this.id,
      courseId: courseId ?? this.courseId,
      cardNumber: cardNumber ?? this.cardNumber,
      currentBox: currentBox ?? this.currentBox,
      lastReviewedAt: lastReviewedAt ?? this.lastReviewedAt,
      nextReviewDue: nextReviewDue ?? this.nextReviewDue,
      lastTrigger: lastTrigger ?? this.lastTrigger,
      isSynced: isSynced ?? this.isSynced,
      hasEnteredLeitner: hasEnteredLeitner ?? this.hasEnteredLeitner,
    );
  }

  @override
  List<Object?> get props => [
        id,
        courseId,
        cardNumber,
        currentBox,
        lastReviewedAt,
        nextReviewDue,
        lastTrigger,
        isSynced,
        hasEnteredLeitner,
      ];
}
