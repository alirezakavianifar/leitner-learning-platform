import 'package:equatable/equatable.dart';
import 'package:mobile_app/features/courses/domain/entities/course.dart';
import 'package:mobile_app/features/courses/domain/entities/course_package.dart';

abstract class CoursesState extends Equatable {
  const CoursesState();

  @override
  List<Object?> get props => [];
}

class CoursesInitial extends CoursesState {}

class CoursesLoading extends CoursesState {}

class CoursesLoaded extends CoursesState {
  final List<Course> courses;
  final List<CoursePackage> packages;
  final bool isOffline;

  const CoursesLoaded({
    required this.courses,
    this.packages = const [],
    this.isOffline = false,
  });

  @override
  List<Object?> get props => [courses, packages, isOffline];
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
  final List<CoursePackage> currentPackages;
  final bool isOffline;
  final double progress; // 0.0 to 1.0 (or 1.0 when extracting/verifying)

  const CourseDownloading({
    required this.courseId,
    required this.currentCourses,
    this.currentPackages = const [],
    this.isOffline = false,
    this.progress = 0.0,
  });

  @override
  List<Object?> get props => [courseId, currentCourses, currentPackages, isOffline, progress];
}


