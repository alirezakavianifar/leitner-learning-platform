import 'package:equatable/equatable.dart';
import 'package:mobile_app/features/courses/domain/entities/course.dart';

abstract class CoursesState extends Equatable {
  const CoursesState();

  @override
  List<Object?> get props => [];
}

class CoursesInitial extends CoursesState {}

class CoursesLoading extends CoursesState {}

class CoursesLoaded extends CoursesState {
  final List<Course> courses;
  final bool isOffline;

  const CoursesLoaded({
    required this.courses,
    this.isOffline = false,
  });

  @override
  List<Object?> get props => [courses, isOffline];
}

class CoursesError extends CoursesState {
  final String message;

  const CoursesError({required this.message});

  @override
  List<Object?> get props => [message];
}

class CourseDownloading extends CoursesState {
  final String courseId;
  final List<Course> currentCourses; // Keep the list visible while downloading
  final bool isOffline;

  const CourseDownloading({
    required this.courseId,
    required this.currentCourses,
    this.isOffline = false,
  });

  @override
  List<Object?> get props => [courseId, currentCourses, isOffline];
}
