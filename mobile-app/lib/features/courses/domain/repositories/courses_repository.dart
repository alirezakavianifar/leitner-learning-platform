import 'package:mobile_app/core/error/failures.dart';
import 'package:mobile_app/core/usecase/usecase.dart';
import 'package:mobile_app/features/courses/domain/entities/course.dart';

abstract class CoursesRepository {
  /// Fetches all courses. Attempts remote fetch first, then caches.
  /// Falls back to local SQLite cache if offline.
  Future<Either<Failure, (List<Course> courses, bool isOffline)>> getCourses();

  /// Downloads, decrypts, and extracts a course database and assets.
  Future<Either<Failure, void>> downloadCourse(String courseId);
}
