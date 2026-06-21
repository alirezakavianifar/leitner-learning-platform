import 'package:mobile_app/core/error/failures.dart';
import 'package:mobile_app/core/usecase/usecase.dart';
import 'package:mobile_app/features/courses/domain/entities/course.dart';
import 'package:mobile_app/features/courses/domain/repositories/courses_repository.dart';

class GetCourses implements UseCase<Either<Failure, (List<Course> courses, bool isOffline)>, NoParams> {
  final CoursesRepository repository;

  GetCourses(this.repository);

  @override
  Future<Either<Failure, (List<Course> courses, bool isOffline)>> call(NoParams params) async {
    return await repository.getCourses();
  }
}
