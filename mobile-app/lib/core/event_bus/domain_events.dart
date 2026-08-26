import 'package:equatable/equatable.dart';

abstract class DomainEvent extends Equatable {
  const DomainEvent();
}

class CardReviewed extends DomainEvent {
  final String courseId;
  final int cardNumber;
  final int box;
  final DateTime reviewedAt;

  const CardReviewed({
    required this.courseId,
    required this.cardNumber,
    required this.box,
    required this.reviewedAt,
  });

  @override
  List<Object?> get props => [courseId, cardNumber, box, reviewedAt];
}

class CardFinished extends DomainEvent {
  final String courseId;
  final int cardNumber;
  final DateTime finishedAt;

  const CardFinished({
    required this.courseId,
    required this.cardNumber,
    required this.finishedAt,
  });

  @override
  List<Object?> get props => [courseId, cardNumber, finishedAt];
}

class DueDateOverdueReset extends DomainEvent {
  final String courseId;
  final int cardNumber;
  final DateTime resetAt;

  const DueDateOverdueReset({
    required this.courseId,
    required this.cardNumber,
    required this.resetAt,
  });

  @override
  List<Object?> get props => [courseId, cardNumber, resetAt];
}

class LeitnerProgressReset extends DomainEvent {
  final String courseId;
  final int cardNumber;
  final DateTime resetAt;
  final String reason;

  const LeitnerProgressReset({
    required this.courseId,
    required this.cardNumber,
    required this.resetAt,
    required this.reason,
  });

  @override
  List<Object?> get props => [courseId, cardNumber, resetAt, reason];
}

class CourseDownloaded extends DomainEvent {
  final String courseId;

  const CourseDownloaded({required this.courseId});

  @override
  List<Object?> get props => [courseId];
}

class CourseProgressChanged extends DomainEvent {
  final String courseId;

  const CourseProgressChanged({required this.courseId});

  @override
  List<Object?> get props => [courseId];
}

class StatsRefreshRequested extends DomainEvent {
  const StatsRefreshRequested();

  @override
  List<Object?> get props => [];
}

class AnnouncementsUpdated extends DomainEvent {
  final int unreadCount;
  final int totalCount;

  const AnnouncementsUpdated({
    required this.unreadCount,
    required this.totalCount,
  });

  @override
  List<Object?> get props => [unreadCount, totalCount];
}
