import 'package:flutter/material.dart';
import 'package:mobile_app/app/theme.dart';
import 'package:mobile_app/core/localization/app_localizations.dart';
import 'package:mobile_app/features/courses/domain/entities/course.dart';
import 'package:mobile_app/features/courses/domain/repositories/courses_repository.dart';
import 'package:mobile_app/features/flashcards/domain/repositories/flashcard_repository.dart';
import 'package:mobile_app/features/flashcards/presentation/screens/flashcard_study_screen.dart';
import 'package:mobile_app/features/flashcards/presentation/screens/favorites_screen.dart';
import 'package:mobile_app/injection_container.dart' as di;

class ReviewTab extends StatefulWidget {
  const ReviewTab({Key? key}) : super(key: key);

  @override
  State<ReviewTab> createState() => _ReviewTabState();
}

class _ReviewTabState extends State<ReviewTab> {
  late CoursesRepository _coursesRepository;
  late FlashcardRepository _flashcardRepository;
  List<Course> _downloadedCourses = [];
  Map<String, int> _dueCounts = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _coursesRepository = di.sl<CoursesRepository>();
    _flashcardRepository = di.sl<FlashcardRepository>();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final either = await _coursesRepository.getCourses();
    
    await either.fold(
      (failure) async {
        setState(() => _isLoading = false);
      },
      (data) async {
        final (courses, isOffline) = data;
        final downloaded = courses.where((c) => c.isDownloaded).toList();
        final Map<String, int> counts = {};
        
        for (final course in downloaded) {
          try {
            final queue = await _flashcardRepository.getReviewQueue(course.id);
            counts[course.id] = queue.length;
          } catch (_) {
            counts[course.id] = 0;
          }
        }

        if (mounted) {
          setState(() {
            _downloadedCourses = downloaded;
            _dueCounts = counts;
            _isLoading = false;
          });
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    if (_downloadedCourses.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.download_for_offline_outlined, size: 64, color: AppColors.textSecondary.withOpacity(0.5)),
              const SizedBox(height: 16),
              Text(
                loc.noDownloadedCoursesTitle,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                loc.noDownloadedCoursesDesc,
                style: const TextStyle(color: AppColors.textSecondary, height: 1.4),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: AppColors.surface,
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: _downloadedCourses.length,
        itemBuilder: (context, index) {
          final course = _downloadedCourses[index];
          final dueCount = _dueCounts[course.id] ?? 0;

          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            color: AppColors.surface.withOpacity(0.6),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: AppColors.border),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          course.title,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      // Due reviews badge count
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: dueCount > 0 ? AppColors.box1.withOpacity(0.15) : Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: dueCount > 0 ? AppColors.box1 : AppColors.textSecondary.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.today,
                              size: 14,
                              color: dueCount > 0 ? AppColors.box1 : AppColors.textSecondary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '$dueCount ${loc.dueBadge}',
                              style: TextStyle(
                                color: dueCount > 0 ? AppColors.box1 : AppColors.textSecondary,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${course.cardCount} ${loc.totalCardsCount}',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  const Divider(color: Color(0xFF333E56), height: 1),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // View Favorites button
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.box2,
                          side: const BorderSide(color: AppColors.box2),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => FavoritesScreen(
                                courseId: course.id,
                                courseTitle: course.title,
                              ),
                            ),
                          );
                          _loadData();
                        },
                        icon: const Icon(Icons.star, size: 16),
                        label: Text(loc.favorites),
                      ),
                      // Start Study loop button
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => FlashcardStudyScreen(
                                courseId: course.id,
                                courseTitle: course.title,
                              ),
                            ),
                          );
                          _loadData();
                        },
                        icon: const Icon(Icons.play_arrow, color: Colors.white, size: 16),
                        label: Text(loc.startStudy, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
