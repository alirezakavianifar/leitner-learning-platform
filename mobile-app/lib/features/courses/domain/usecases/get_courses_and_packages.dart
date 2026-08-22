import 'package:mobile_app/core/error/failures.dart';
import 'package:mobile_app/core/usecase/usecase.dart';
import 'package:mobile_app/features/courses/domain/entities/course.dart';
import 'package:mobile_app/features/courses/domain/entities/course_package.dart';
import 'package:mobile_app/features/courses/domain/repositories/courses_repository.dart';

class GetCoursesAndPackages implements UseCase<Either<Failure, (List<Course> courses, List<CoursePackage> packages, bool isOffline)>, NoParams> {
  final CoursesRepository repository;

  GetCoursesAndPackages(this.repository);

  @override
  Future<Either<Failure, (List<Course> courses, List<CoursePackage> packages, bool isOffline)>> call(NoParams params) async {
    return await repository.getCoursesAndPackages();
  }
}
