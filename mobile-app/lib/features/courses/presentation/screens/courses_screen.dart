import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile_app/app/theme.dart';
import 'package:mobile_app/core/localization/app_localizations.dart';
import 'package:mobile_app/core/services/payment_provider.dart';
import 'package:mobile_app/injection_container.dart';
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
  int _selectedTab = 0; // 0 for Catalog, 1 for My Courses

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

  Widget _buildTabSelector() {
    final loc = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 12.0, bottom: 4.0),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _selectedTab = 0),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: _selectedTab == 0 ? AppColors.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      loc.catalog,
                      style: TextStyle(
                        color: _selectedTab == 0 ? Colors.white : AppColors.textSecondary,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _selectedTab = 1),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: _selectedTab == 1 ? AppColors.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      loc.myCourses,
                      style: TextStyle(
                        color: _selectedTab == 1 ? Colors.white : AppColors.textSecondary,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _buildTabSelector(),
          Expanded(
            child: BlocConsumer<CoursesBloc, CoursesState>(
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
                  return Center(
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
                        Icon(Icons.error_outline, size: 48, color: AppColors.error),
                        const SizedBox(height: 16),
                        Text(
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

                var sortedCourses = _sortCourses(courses);
                if (_selectedTab == 1) {
                  sortedCourses = sortedCourses.where((c) => c.isDownloaded).toList();
                }

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
                        SliverFillRemaining(
                          child: Center(
                            child: Text(
                              _selectedTab == 1
                                  ? 'No downloaded courses available.'
                                  : 'No courses available.',
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
          ),
        ],
      ),
    );
  }

  void _purchaseCourse(Course course) async {
    final config = sl<AppConfig>();

    if (config.isPremium) {
      // Show payment selector modal sheet
      showModalBottomSheet(
        context: context,
        backgroundColor: AppColors.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Select Payment Method',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  ListTile(
                    leading: Icon(Icons.payment, color: AppColors.primary),
                    title: Text('Direct Gateway (ZarinPal)', style: TextStyle(color: AppColors.textPrimary)),
                    onTap: () => _processPurchase(course, sl<DirectPaymentProvider>()),
                  ),
                  ListTile(
                    leading: Icon(Icons.store, color: AppColors.secondary),
                    title: Text('Cafe Bazaar Billing', style: TextStyle(color: AppColors.textPrimary)),
                    onTap: () => _processPurchase(course, sl<BazaarPaymentProvider>()),
                  ),
                  ListTile(
                    leading: Icon(Icons.shopping_bag_outlined, color: AppColors.secondary),
                    title: Text('Myket Billing', style: TextStyle(color: AppColors.textPrimary)),
                    onTap: () => _processPurchase(course, sl<MyketPaymentProvider>()),
                  ),
                  ListTile(
                    leading: const Icon(Icons.shop_two, color: Colors.blue),
                    title: Text('Google Play IAP', style: TextStyle(color: AppColors.textPrimary)),
                    onTap: () => _processPurchase(course, sl<GooglePlayPaymentProvider>()),
                  ),
                ],
              ),
            ),
          );
        },
      );
    } else {
      // Store Version: show non-IAP descriptive dialog
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            backgroundColor: AppColors.surface,
            title: Text(
              'Purchase Course',
              style: TextStyle(color: AppColors.textPrimary),
            ),
            content: Text(
              'In-App Purchases are not supported in this edition.\n\nPlease visit our official website to purchase courses and unlock premium content.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text('Visit Website'),
              ),
            ],
          );
        },
      );
    }
  }

  void _processPurchase(Course course, PaymentProvider provider) async {
    Navigator.pop(context); // Close bottom sheet
    
    // Show progress loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
    );

    final success = await provider.purchaseCourse(course.id);
    
    Navigator.pop(context); // Close loading dialog

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Course "${course.title}" unlocked successfully!'),
          backgroundColor: AppColors.courseDownloaded,
        ),
      );
      // Reload courses to update purchased status
      context.read<CoursesBloc>().add(LoadCoursesEvent());
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Purchase transaction failed. Please try again.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
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
                          style: TextStyle(
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
                                    style: TextStyle(
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
                                    style: TextStyle(
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
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
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
                        '${course.cardCount} ${AppLocalizations.of(context).cardsCount}',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        course.price == 0 ? AppLocalizations.of(context).free : '${course.price.toStringAsFixed(0)} IRR',
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
    final loc = AppLocalizations.of(context);
    if (course.isDownloaded) {
      return ElevatedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        backgroundColor: AppColors.courseDownloaded.withOpacity(0.15),
        foregroundColor: AppColors.courseDownloaded,
        side: BorderSide(color: AppColors.courseDownloaded, width: 1),
      ).build(
        context,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check, size: 16),
            const SizedBox(width: 6),
            Text(loc.readyToStudy),
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
        child: SizedBox(
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
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.download, size: 16),
            const SizedBox(width: 6),
            Text(loc.downloadNow),
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
        _purchaseCourse(course);
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.payment, size: 16),
          const SizedBox(width: 6),
          Text(loc.purchase),
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
