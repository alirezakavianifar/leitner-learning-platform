import 'package:equatable/equatable.dart';

abstract class CoursesEvent extends Equatable {
  const CoursesEvent();

  @override
  List<Object?> get props => [];
}

class LoadCoursesEvent extends CoursesEvent {}

class DownloadCourseEvent extends CoursesEvent {
  final String courseId;

  const DownloadCourseEvent({required this.courseId});

  @override
  List<Object?> get props => [courseId];
}
