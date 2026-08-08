import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile_app/core/usecase/usecase.dart';
import 'package:mobile_app/features/courses/domain/usecases/download_course.dart';
import 'package:mobile_app/features/courses/domain/usecases/get_courses.dart';
import 'courses_event.dart';
import 'courses_state.dart';

class CoursesBloc extends Bloc<CoursesEvent, CoursesState> {
  final GetCourses getCoursesUseCase;
  final DownloadCourse downloadCourseUseCase;

  CoursesBloc({
    required this.getCoursesUseCase,
    required this.downloadCourseUseCase,
  }) : super(CoursesInitial()) {
    on<LoadCoursesEvent>(_onLoadCourses);
    on<DownloadCourseEvent>(_onDownloadCourse);
  }

  Future<void> _onLoadCourses(
    LoadCoursesEvent event,
    Emitter<CoursesState> emit,
  ) async {
    emit(CoursesLoading());
    final result = await getCoursesUseCase(NoParams());
    result.fold(
      (failure) => emit(CoursesError(message: failure.message)),
      (data) {
        final (courses, isOffline) = data;
        emit(CoursesLoaded(courses: courses, isOffline: isOffline));
      },
    );
  }

  Future<void> _onDownloadCourse(
    DownloadCourseEvent event,
    Emitter<CoursesState> emit,
  ) async {
    final currentState = state;
    List<dynamic> currentCourses = [];
    bool isOffline = false;

    if (currentState is CoursesLoaded) {
      currentCourses = currentState.courses;
      isOffline = currentState.isOffline;
    } else if (currentState is CourseDownloading) {
      currentCourses = currentState.currentCourses;
      isOffline = currentState.isOffline;
    }

    emit(CourseDownloading(
      courseId: event.courseId,
      currentCourses: List.from(currentCourses),
      isOffline: isOffline,
      progress: 0.0,
    ));

    int lastReportedPercent = -1;

    final result = await downloadCourseUseCase(
      DownloadCourseParams(
        courseId: event.courseId,
        onProgress: (received, total) {
          double progress;
          if (total > 0) {
            progress = (received / total).clamp(0.0, 1.0);
          } else if (received > 0) {
            // Fallback for unknown total length: scale received bytes into 0.05 to 0.95
            progress = (1.0 - (1.0 / (1.0 + (received / 500000)))).clamp(0.05, 0.95);
          } else {
            progress = 0.0;
          }

          final int percent = (progress * 100).clamp(0, 100).toInt();
          if (percent != lastReportedPercent) {
            lastReportedPercent = percent;
            emit(CourseDownloading(
              courseId: event.courseId,
              currentCourses: List.from(currentCourses),
              isOffline: isOffline,
              progress: progress,
            ));
          }
        },
      ),
    );

    await result.fold(
      (failure) async {
        emit(CoursesError(message: failure.message));
        // Put it back to loaded after emitting error state to restore catalog view
        emit(CoursesLoaded(
          courses: List.from(currentCourses),
          isOffline: isOffline,
        ));
      },
      (_) async {
        // Success: reload the courses to update download flags and borders
        final reloadResult = await getCoursesUseCase(NoParams());
        reloadResult.fold(
          (failure) => emit(CoursesError(message: failure.message)),
          (data) {
            final (courses, isOffline) = data;
            emit(CoursesLoaded(courses: courses, isOffline: isOffline));
          },
        );
      },
    );
  }

}
