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
    ));

    final result = await downloadCourseUseCase(
      DownloadCourseParams(courseId: event.courseId),
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
