import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile_app/app/theme.dart';
import 'package:mobile_app/features/courses/domain/entities/course.dart';
import 'package:mobile_app/features/courses/presentation/bloc/courses_bloc.dart';
import 'package:mobile_app/features/courses/presentation/bloc/courses_event.dart';
import 'package:mobile_app/features/courses/presentation/bloc/courses_state.dart';
import 'package:mobile_app/features/flashcards/presentation/screens/flashcard_study_screen.dart';


class CoursesScreen extends StatefulWidget {
  const CoursesScreen({Key? key}) : super(key: key);

  @override
  State<CoursesScreen> createState() => _CoursesScreenState();
}

class _CoursesScreenState extends State<CoursesScreen> {
  @override
  void initState() {
    super.initState();
    // Load courses on entry
    context.read<CoursesBloc>().add(LoadCoursesEvent());
  }

  /// Sorts courses: Downloaded courses go to the top, then purchased, then unpaid.
  List<Course> _sortCourses(List<Course> courses) {
    final list = List<Course>.from(courses);
    list.sort((a, b) {
      if (a.isDownloaded && !b.isDownloaded) return -1;
      if (!a.isDownloaded && b.isDownloaded) return 1;
      if (a.isPurchased && !b.isPurchased) return -1;
      if (!a.isPurchased && b.isPurchased) return 1;
      return a.title.compareTo(b.title);
    });
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: BlocConsumer<CoursesBloc, CoursesState>(
        listener: (context, state) {
          if (state is CoursesError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppColors.error,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is CoursesLoading) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          List<Course> courses = [];
          bool isOffline = false;
          String? downloadingCourseId;

          if (state is CoursesLoaded) {
            courses = state.courses;
            isOffline = state.isOffline;
          } else if (state is CourseDownloading) {
            courses = state.currentCourses;
            isOffline = state.isOffline;
            downloadingCourseId = state.courseId;
          } else if (state is CoursesError && courses.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: AppColors.error),
                  const SizedBox(height: 16),
                  const Text(
                    'Failed to load courses catalog.',
                    style: TextStyle(color: AppColors.textPrimary, fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                    onPressed: () => context.read<CoursesBloc>().add(LoadCoursesEvent()),
                    child: const Text('Try Again'),
                  ),
                ],
              ),
            );
          }

          final sortedCourses = _sortCourses(courses);

          return RefreshIndicator(
            color: AppColors.primary,
            backgroundColor: AppColors.surface,
            onRefresh: () async {
              context.read<CoursesBloc>().add(LoadCoursesEvent());
            },
            child: CustomScrollView(
              slivers: [
                if (isOffline)
                  SliverToBoxAdapter(
                    child: Container(
                      width: double.infinity,
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF9800).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFF9800).withOpacity(0.5)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.wifi_off, color: Color(0xFFFF9800)),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Internet connection unavailable; course catalog update not performed.',
                              style: TextStyle(
                                color: Color(0xFFFFB74D),
                                fontSize: 13,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (sortedCourses.isEmpty)
                  const SliverFillRemaining(
                    child: Center(
                      child: Text(
                        'No courses available.',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 80),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final course = sortedCourses[index];
                          final isDownloading = downloadingCourseId == course.id;
                          return _buildCourseCard(course, isDownloading);
                        },
                        childCount: sortedCourses.length,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCourseCard(Course course, bool isDownloading) {
    final borderColor = course.isDownloaded
        ? AppColors.courseDownloaded
        : AppColors.courseNotDownloaded;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacity(0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          course.title,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (course.category != null || course.difficulty != null) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              if (course.category != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    course.category!,
                                    style: const TextStyle(
                                      color: AppColors.primary,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              if (course.category != null && course.difficulty != null)
                                const SizedBox(width: 8),
                              if (course.difficulty != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    course.difficulty!,
                                    style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Border label helper
                  Icon(
                    course.isDownloaded ? Icons.offline_pin : Icons.cloud_download,
                    color: borderColor,
                    size: 24,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (course.description != null) ...[
                Text(
                  course.description!,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
              ],
              const Divider(color: Color(0xFF333E56), height: 1),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${course.cardCount} Cards',
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        course.price == 0 ? 'Free' : '${course.price.toStringAsFixed(0)} IRR',
                        style: TextStyle(
                          color: course.price == 0 ? AppColors.secondary : AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  _buildActionButton(course, isDownloading),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(Course course, bool isDownloading) {
    if (course.isDownloaded) {
      return ElevatedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        backgroundColor: AppColors.courseDownloaded.withOpacity(0.15),
        foregroundColor: AppColors.courseDownloaded,
        side: const BorderSide(color: AppColors.courseDownloaded, width: 1),
      ).build(
        context,
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check, size: 16),
            SizedBox(width: 6),
            Text('Ready to Study'),
          ],
        ),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => FlashcardStudyScreen(
                courseId: course.id,
                courseTitle: course.title,
              ),
            ),
          );
        },
      );
    }

    if (isDownloading) {
      return ElevatedButton(
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          backgroundColor: AppColors.surface,
        ),
        onPressed: null,
        child: const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2),
        ),
      );
    }

    if (course.isPurchased) {
      return ElevatedButton(
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          backgroundColor: AppColors.primary,
        ),
        onPressed: () {
          context.read<CoursesBloc>().add(DownloadCourseEvent(courseId: course.id));
        },
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.download, size: 16),
            SizedBox(width: 6),
            Text('Download Now'),
          ],
        ),
      );
    }

    // Unpurchased course
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        backgroundColor: AppColors.secondary,
        foregroundColor: AppColors.background,
      ),
      onPressed: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment gateway for "${course.title}" will open.'),
            backgroundColor: AppColors.secondary,
          ),
        );
      },
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.payment, size: 16),
          SizedBox(width: 6),
          Text('Purchase'),
        ],
      ),
    );
  }
}

// Helper extension to make standard buttons look premium under customized design
extension on ButtonStyle {
  Widget build(
    BuildContext context, {
    required Widget child,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton(
      style: this,
      onPressed: onPressed,
      child: child,
    );
  }
}
