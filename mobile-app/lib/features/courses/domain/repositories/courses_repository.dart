import 'package:mobile_app/core/error/failures.dart';
import 'package:mobile_app/core/usecase/usecase.dart';
import 'package:mobile_app/features/courses/domain/entities/course.dart';
import 'package:mobile_app/features/courses/domain/entities/course_package.dart';

abstract class CoursesRepository {
  /// Fetches all courses. Attempts remote fetch first, then caches.
  /// Falls back to local SQLite cache if offline.
  Future<Either<Failure, (List<Course> courses, bool isOffline)>> getCourses();

  /// Fetches all packages. Attempts remote fetch first, then caches.
  /// Falls back to local SQLite cache if offline.
  Future<Either<Failure, (List<CoursePackage> packages, bool isOffline)>> getPackages();

  /// Fetches both courses and packages simultaneously.
  Future<Either<Failure, (List<Course> courses, List<CoursePackage> packages, bool isOffline)>> getCoursesAndPackages();

  /// Downloads, decrypts, and extracts a course database and assets.
  Future<Either<Failure, void>> downloadCourse(
    String courseId, {
    void Function(int received, int total)? onProgress,
  });
}


