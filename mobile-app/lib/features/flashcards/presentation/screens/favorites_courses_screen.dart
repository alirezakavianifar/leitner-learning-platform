import 'package:flutter/material.dart';
import 'package:mobile_app/app/theme.dart';
import 'package:mobile_app/core/localization/app_localizations.dart';
import 'package:mobile_app/features/courses/domain/entities/course.dart';
import 'package:mobile_app/features/courses/domain/repositories/courses_repository.dart';
import 'favorites_screen.dart';
import 'package:mobile_app/injection_container.dart' as di;

class FavoritesCoursesScreen extends StatefulWidget {
  const FavoritesCoursesScreen({Key? key}) : super(key: key);

  @override
  State<FavoritesCoursesScreen> createState() => _FavoritesCoursesScreenState();
}

class _FavoritesCoursesScreenState extends State<FavoritesCoursesScreen> {
  late CoursesRepository _coursesRepository;
  List<Course> _downloadedCourses = [];
  bool _isLoading = true;
  bool _isError = false;

  @override
  void initState() {
    super.initState();
    _coursesRepository = di.sl<CoursesRepository>();
    _loadCourses();
  }

  Future<void> _loadCourses() async {
    setState(() {
      _isLoading = true;
      _isError = false;
    });

    final either = await _coursesRepository.getCourses();
    either.fold(
      (failure) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _isError = true;
          });
        }
      },
      (data) {
        if (mounted) {
          setState(() {
            _downloadedCourses = data.$1.where((c) => c.isDownloaded).toList();
            _isLoading = false;
          });
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isFa = Localizations.localeOf(context).languageCode == 'fa';
    
    final titleText = isFa ? 'انتخاب دوره (نشان‌شده‌ها)' : 'Select Course (Favorites)';
    final noCoursesTitle = isFa ? 'هیچ دوره دانلود شده‌ای یافت نشد' : 'No Downloaded Courses';
    final noCoursesDesc = isFa 
        ? 'برای مشاهده کارت‌های نشان‌شده، ابتدا باید یک دوره را از تب دوره‌ها دانلود کرده و کارت‌های آن را مطالعه نمایید.'
        : 'To view bookmarked/favorited cards, please download a course from the catalog and start studying first.';
    final errorTitle = isFa ? 'خطا در بارگذاری دوره‌ها' : 'Failed to Load Courses';
    final retryText = isFa ? 'تلاش مجدد' : 'Retry';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          titleText,
          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _isError
              ? _buildErrorState(errorTitle, retryText)
              : _downloadedCourses.isEmpty
                  ? _buildEmptyState(noCoursesTitle, noCoursesDesc)
                  : RefreshIndicator(
                      color: AppColors.primary,
                      backgroundColor: AppColors.surface,
                      onRefresh: _loadCourses,
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                        itemCount: _downloadedCourses.length,
                        itemBuilder: (context, index) {
                          final course = _downloadedCourses[index];
                          final countText = isFa ? '${course.cardCount} کارت' : '${course.cardCount} cards';

                          return Card(
                            margin: const EdgeInsets.only(bottom: 16),
                            color: AppColors.surface.withOpacity(0.6),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(color: AppColors.border),
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => FavoritesScreen(
                                      courseId: course.id,
                                      courseTitle: course.title,
                                    ),
                                  ),
                                ).then((_) => _loadCourses());
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        color: AppColors.secondary.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(Icons.star, color: AppColors.secondary),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            course.title,
                                            style: TextStyle(
                                              color: AppColors.textPrimary,
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              if (course.category != null) ...[
                                                Text(
                                                  course.category!,
                                                  style: TextStyle(
                                                    color: AppColors.primary,
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  '•',
                                                  style: TextStyle(
                                                    color: AppColors.textSecondary,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                              ],
                                              Text(
                                                countText,
                                                style: TextStyle(
                                                  color: AppColors.textSecondary,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    Icon(Icons.chevron_right, color: AppColors.border, size: 20),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }

  Widget _buildEmptyState(String title, String desc) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.star_outline, size: 64, color: AppColors.secondary.withOpacity(0.5)),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              desc,
              style: TextStyle(color: AppColors.textSecondary, height: 1.4),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String title, String retryText) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: AppColors.error),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: _loadCourses,
              child: Text(retryText, style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}
