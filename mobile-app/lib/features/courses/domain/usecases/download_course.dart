import 'package:equatable/equatable.dart';
import 'package:mobile_app/core/error/failures.dart';
import 'package:mobile_app/core/usecase/usecase.dart';
import 'package:mobile_app/features/courses/domain/repositories/courses_repository.dart';

class DownloadCourse implements UseCase<Either<Failure, void>, DownloadCourseParams> {
  final CoursesRepository repository;

  DownloadCourse(this.repository);

  @override
  Future<Either<Failure, void>> call(DownloadCourseParams params) async {
    return await repository.downloadCourse(
      params.courseId,
      onProgress: params.onProgress,
    );
  }
}

class DownloadCourseParams extends Equatable {
  final String courseId;
  final void Function(int received, int total)? onProgress;

  const DownloadCourseParams({
    required this.courseId,
    this.onProgress,
  });

  @override
  List<Object?> get props => [courseId, onProgress];
}

