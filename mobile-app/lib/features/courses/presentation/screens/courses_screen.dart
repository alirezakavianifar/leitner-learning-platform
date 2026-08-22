import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile_app/app/theme.dart';
import 'package:mobile_app/core/localization/app_localizations.dart';
import 'package:mobile_app/core/services/payment_provider.dart';
import 'package:mobile_app/injection_container.dart';
import 'package:mobile_app/features/courses/domain/entities/course.dart';
import 'package:mobile_app/features/courses/domain/entities/course_package.dart';
import 'package:mobile_app/features/courses/presentation/bloc/courses_bloc.dart';
import 'package:mobile_app/features/courses/presentation/bloc/courses_event.dart';
import 'package:mobile_app/features/courses/presentation/bloc/courses_state.dart';
import 'package:mobile_app/features/courses/presentation/widgets/package_card.dart';
import 'package:mobile_app/features/courses/presentation/widgets/package_details_modal.dart';
import 'package:mobile_app/features/flashcards/presentation/screens/flashcard_study_screen.dart';
import 'package:mobile_app/core/error/error_formatter.dart';

class CoursesScreen extends StatefulWidget {
  final ValueNotifier<int>? tabNotifier;
  const CoursesScreen({Key? key, this.tabNotifier}) : super(key: key);

  @override
  State<CoursesScreen> createState() => _CoursesScreenState();
}

class _CoursesScreenState extends State<CoursesScreen> {
  late int _selectedTab;
  int _catalogFilterIndex = 0; // 0: All, 1: Single Courses, 2: Packages

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.tabNotifier?.value ?? 0;
    widget.tabNotifier?.addListener(_handleTabNotifierChange);
    // Load courses on entry
    context.read<CoursesBloc>().add(LoadCoursesEvent());
  }

  void _handleTabNotifierChange() {
    if (mounted && widget.tabNotifier != null) {
      setState(() {
        _selectedTab = widget.tabNotifier!.value;
      });
    }
  }

  @override
  void dispose() {
    widget.tabNotifier?.removeListener(_handleTabNotifierChange);
    super.dispose();
  }

  /// Sorts courses: courses needing an update go first, then downloaded, then purchased, then unpaid.
  List<Course> _sortCourses(List<Course> courses) {
    final list = List<Course>.from(courses);
    list.sort((a, b) {
      if (a.updateAvailable && !b.updateAvailable) return -1;
      if (!a.updateAvailable && b.updateAvailable) return 1;
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
      padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 12.0, bottom: 6.0),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: AppColors.surface.withOpacity(0.8),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _selectedTab = 0),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  decoration: BoxDecoration(
                    color: _selectedTab == 0 ? AppColors.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: _selectedTab == 0
                        ? [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.35),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            )
                          ]
                        : [],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: _selectedTab == 0
                              ? Colors.white.withOpacity(0.2)
                              : AppColors.primary.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        padding: const EdgeInsets.all(4),
                        child: Image.asset(
                          'assets/images/courses_list.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          loc.catalog,
                          style: TextStyle(
                            color: _selectedTab == 0 ? Colors.white : AppColors.textSecondary,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _selectedTab = 1),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  decoration: BoxDecoration(
                    color: _selectedTab == 1 ? AppColors.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: _selectedTab == 1
                        ? [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.35),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            )
                          ]
                        : [],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: _selectedTab == 1
                              ? Colors.white.withOpacity(0.2)
                              : AppColors.primary.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        padding: const EdgeInsets.all(4),
                        child: Image.asset(
                          'assets/images/my_courses.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          loc.myCourses,
                          style: TextStyle(
                            color: _selectedTab == 1 ? Colors.white : AppColors.textSecondary,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChips(int packagesCount) {
    final loc = AppLocalizations.of(context);
    final chips = [
      {'index': 0, 'label': loc.translate('filter_all'), 'icon': Icons.grid_view},
      {'index': 1, 'label': loc.translate('filter_individual'), 'icon': Icons.menu_book},
      if (packagesCount > 0)
        {'index': 2, 'label': loc.translate('filter_bundles'), 'icon': Icons.auto_awesome},
    ];

    return Container(
      height: 40,
      margin: const EdgeInsets.only(top: 4, bottom: 8),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: chips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, idx) {
          final item = chips[idx];
          final index = item['index'] as int;
          final isSelected = _catalogFilterIndex == index;
          return ChoiceChip(
            showCheckmark: false,
            avatar: Icon(
              item['icon'] as IconData,
              size: 14,
              color: isSelected ? Colors.white : AppColors.textSecondary,
            ),
            label: Text(
              item['label'] as String,
              style: TextStyle(
                color: isSelected ? Colors.white : AppColors.textSecondary,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            selected: isSelected,
            selectedColor: AppColors.primary,
            backgroundColor: AppColors.surface.withOpacity(0.7),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(
                color: isSelected ? AppColors.primary : AppColors.border,
              ),
            ),
            onSelected: (val) {
              if (val) {
                setState(() => _catalogFilterIndex = index);
              }
            },
          );
        },
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
                      content: Text(AppErrorFormatter.formatError(state.message, context: context)),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              },
              builder: (context, state) {
                final loc = AppLocalizations.of(context);
                if (state is CoursesLoading) {
                  return Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  );
                }

                List<Course> courses = [];
                List<CoursePackage> packages = [];
                bool isOffline = false;
                String? downloadingCourseId;
                double downloadProgress = 0.0;

                if (state is CoursesLoaded) {
                  courses = state.courses;
                  packages = state.packages;
                  isOffline = state.isOffline;
                } else if (state is CourseDownloading) {
                  courses = state.currentCourses;
                  packages = state.currentPackages;
                  isOffline = state.isOffline;
                  downloadingCourseId = state.courseId;
                  downloadProgress = state.progress;
                } else if (state is CoursesError && courses.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline, size: 48, color: AppColors.error),
                          const SizedBox(height: 16),
                          Text(
                            AppErrorFormatter.formatError(state.message, context: context),
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.textPrimary, fontSize: 15),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                            onPressed: () => context.read<CoursesBloc>().add(LoadCoursesEvent()),
                            child: Text(loc.retry),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                var sortedCourses = _sortCourses(courses);
                if (_selectedTab == 1) {
                  sortedCourses = sortedCourses.where((c) => c.isDownloaded).toList();
                }

                final shouldShowPackages = _selectedTab == 0 &&
                    (_catalogFilterIndex == 0 || _catalogFilterIndex == 2) &&
                    packages.isNotEmpty;

                final shouldShowCourses = _selectedTab == 1 ||
                    _catalogFilterIndex == 0 ||
                    _catalogFilterIndex == 1;

                final displayedCourses = shouldShowCourses ? sortedCourses : <Course>[];

                return RefreshIndicator(
                  color: AppColors.primary,
                  backgroundColor: AppColors.surface,
                  onRefresh: () async {
                    context.read<CoursesBloc>().add(LoadCoursesEvent());
                  },
                  child: CustomScrollView(
                    slivers: [
                      if (_selectedTab == 0)
                        SliverToBoxAdapter(
                          child: _buildFilterChips(packages.length),
                        ),
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
                            child: Row(
                              children: [
                                const Icon(Icons.wifi_off, color: Color(0xFFFF9800)),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    loc.translate('offline_catalog_warning'),
                                    style: const TextStyle(
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

                      // Bundles Section (when applicable)
                      if (shouldShowPackages) ...[
                        SliverPadding(
                          padding: const EdgeInsets.only(left: 16, right: 16, top: 4, bottom: 4),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final pkg = packages[index];
                                return PackageCard(
                                  package: pkg,
                                  onTap: () => PackageDetailsModal.show(
                                    context,
                                    package: pkg,
                                    onPurchase: () => _purchasePackage(pkg),
                                  ),
                                  onPurchase: () => _purchasePackage(pkg),
                                );
                              },
                              childCount: packages.length,
                            ),
                          ),
                        ),
                      ],

                      // Course List Section
                      if (displayedCourses.isEmpty && (!shouldShowPackages || packages.isEmpty))
                        SliverFillRemaining(
                          child: Center(
                            child: Text(
                              _selectedTab == 1
                                  ? loc.translate('no_downloaded_courses_avail')
                                  : loc.translate('no_courses_avail'),
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          ),
                        )
                      else if (shouldShowCourses && displayedCourses.isNotEmpty)
                        SliverPadding(
                          padding: const EdgeInsets.only(left: 16, right: 16, top: 4, bottom: 80),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final course = displayedCourses[index];
                                final isDownloading = downloadingCourseId == course.id;

                                // Check if this course belongs to any active package
                                CoursePackage? parentPackage;
                                try {
                                  parentPackage = packages.firstWhere(
                                    (pkg) => pkg.courses.any((c) => c.id == course.id),
                                  );
                                } catch (_) {
                                  parentPackage = null;
                                }

                                return _buildCourseCard(
                                  course,
                                  isDownloading,
                                  downloadProgress,
                                  parentPackage,
                                );
                              },
                              childCount: displayedCourses.length,
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

  void _purchasePackage(CoursePackage package) async {
    final config = sl<AppConfig>();
    final loc = AppLocalizations.of(context);

    if (config.isPremium) {
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
                    '${loc.translate('select_payment_method')} (${package.title})',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  ListTile(
                    leading: Icon(Icons.payment, color: AppColors.primary),
                    title: Text(loc.translate('zarinpal_gateway'), style: TextStyle(color: AppColors.textPrimary)),
                    onTap: () => _processPackagePurchase(package, sl<DirectPaymentProvider>()),
                  ),
                  ListTile(
                    leading: Icon(Icons.store, color: AppColors.secondary),
                    title: Text(loc.translate('bazaar_billing'), style: TextStyle(color: AppColors.textPrimary)),
                    onTap: () => _processPackagePurchase(package, sl<BazaarPaymentProvider>()),
                  ),
                  ListTile(
                    leading: Icon(Icons.shopping_bag_outlined, color: AppColors.secondary),
                    title: Text(loc.translate('myket_billing'), style: TextStyle(color: AppColors.textPrimary)),
                    onTap: () => _processPackagePurchase(package, sl<MyketPaymentProvider>()),
                  ),
                  ListTile(
                    leading: const Icon(Icons.shop_two, color: Colors.blue),
                    title: Text(loc.translate('google_play_iap'), style: TextStyle(color: AppColors.textPrimary)),
                    onTap: () => _processPackagePurchase(package, sl<GooglePlayPaymentProvider>()),
                  ),
                ],
              ),
            ),
          );
        },
      );
    } else {
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            backgroundColor: AppColors.surface,
            title: Text(
              loc.translate('purchase_bundle'),
              style: TextStyle(color: AppColors.textPrimary),
            ),
            content: Text(
              loc.translate('iap_not_supported_desc'),
              style: TextStyle(color: AppColors.textSecondary),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(loc.cancel, style: TextStyle(color: AppColors.textSecondary)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                onPressed: () => Navigator.pop(context),
                child: Text(loc.translate('visit_website')),
              ),
            ],
          );
        },
      );
    }
  }

  void _processPackagePurchase(CoursePackage package, PaymentProvider provider) async {
    final loc = AppLocalizations.of(context);
    Navigator.pop(context); // Close modal

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
    );

    final success = await provider.purchasePackage(package.id);
    Navigator.pop(context); // Close loading dialog

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(loc.translate('bundle_unlocked_success').replaceAll('{title}', package.title)),
          backgroundColor: AppColors.courseDownloaded,
        ),
      );
      // Reload courses to reflect newly unlocked courses in both Catalog and My Courses
      context.read<CoursesBloc>().add(LoadCoursesEvent());
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(loc.translate('purchase_failed')),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _purchaseCourse(Course course) async {
    final config = sl<AppConfig>();
    final loc = AppLocalizations.of(context);

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
                    loc.translate('select_payment_method'),
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
                    title: Text(loc.translate('zarinpal_gateway'), style: TextStyle(color: AppColors.textPrimary)),
                    onTap: () => _processPurchase(course, sl<DirectPaymentProvider>()),
                  ),
                  ListTile(
                    leading: Icon(Icons.store, color: AppColors.secondary),
                    title: Text(loc.translate('bazaar_billing'), style: TextStyle(color: AppColors.textPrimary)),
                    onTap: () => _processPurchase(course, sl<BazaarPaymentProvider>()),
                  ),
                  ListTile(
                    leading: Icon(Icons.shopping_bag_outlined, color: AppColors.secondary),
                    title: Text(loc.translate('myket_billing'), style: TextStyle(color: AppColors.textPrimary)),
                    onTap: () => _processPurchase(course, sl<MyketPaymentProvider>()),
                  ),
                  ListTile(
                    leading: const Icon(Icons.shop_two, color: Colors.blue),
                    title: Text(loc.translate('google_play_iap'), style: TextStyle(color: AppColors.textPrimary)),
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
              loc.translate('purchase_course_title'),
              style: TextStyle(color: AppColors.textPrimary),
            ),
            content: Text(
              loc.translate('iap_not_supported_desc'),
              style: TextStyle(color: AppColors.textSecondary),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(loc.cancel, style: TextStyle(color: AppColors.textSecondary)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                onPressed: () {
                  Navigator.pop(context);
                },
                child: Text(loc.translate('visit_website')),
              ),
            ],
          );
        },
      );
    }
  }

  void _processPurchase(Course course, PaymentProvider provider) async {
    final loc = AppLocalizations.of(context);
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
          content: Text(loc.translate('course_unlocked_success').replaceAll('{title}', course.title)),
          backgroundColor: AppColors.courseDownloaded,
        ),
      );
      // Reload courses to update purchased status
      context.read<CoursesBloc>().add(LoadCoursesEvent());
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(loc.translate('purchase_failed')),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Widget _buildCourseCard(
    Course course,
    bool isDownloading, [
    double downloadProgress = 0.0,
    CoursePackage? parentPackage,
  ]) {
    final borderColor = course.isDownloaded
        ? AppColors.courseDownloaded
        : AppColors.courseNotDownloaded;
    final loc = AppLocalizations.of(context);

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
                        if (parentPackage != null && !course.isPurchased && !parentPackage.isPurchased) ...[
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTap: () => PackageDetailsModal.show(
                              context,
                              package: parentPackage,
                              onPurchase: () => _purchasePackage(parentPackage),
                            ),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF9800).withOpacity(0.12),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFFFF9800).withOpacity(0.4)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.auto_awesome, size: 12, color: Color(0xFFFF9800)),
                                  const SizedBox(width: 4),
                                  Text(
                                    loc.translate('available_in_bundle').replaceAll('{bundle}', parentPackage.title),
                                    style: const TextStyle(
                                      color: Color(0xFFFFB300),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Border label helper
                  Icon(
                    course.updateAvailable
                        ? Icons.system_update
                        : (course.isDownloaded ? Icons.offline_pin : Icons.cloud_download),
                    color: course.updateAvailable
                        ? (course.isCriticalUpdate ? AppColors.error : const Color(0xFFFF9800))
                        : borderColor,
                    size: 24,
                  ),
                ],
              ),
              if (course.updateAvailable) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: (course.isCriticalUpdate ? AppColors.error : const Color(0xFFFF9800)).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    course.isCriticalUpdate
                        ? AppLocalizations.of(context).translate('critical_update_desc')
                        : AppLocalizations.of(context).updateAvailable,
                    style: TextStyle(
                      color: course.isCriticalUpdate ? AppColors.error : const Color(0xFFFF9800),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
              if (course.isArchived && course.isPurchased) ...[
                const SizedBox(height: 8),
                Text(
                  AppLocalizations.of(context).translate('course_no_longer_in_store'),
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
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
                        _formatPrice(course.price, context),
                        style: TextStyle(
                          color: course.price == 0 ? AppColors.secondary : AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  _buildActionButton(course, isDownloading, downloadProgress),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(Course course, bool isDownloading, [double downloadProgress = 0.0]) {
    final loc = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (!isDownloading && !kIsWeb && course.updateAvailable) {
      return ElevatedButton(
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          backgroundColor: course.isCriticalUpdate ? AppColors.error : const Color(0xFFFF9800),
          foregroundColor: Colors.white,
        ),
        onPressed: () {
          context.read<CoursesBloc>().add(DownloadCourseEvent(courseId: course.id));
        },
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.system_update, size: 16),
            const SizedBox(width: 6),
            Text(loc.updateNow),
          ],
        ),
      );
    }

    if (course.isDownloaded || (kIsWeb && course.isPurchased)) {
      return ElevatedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        backgroundColor: isDark 
            ? const Color(0xFF1B5E20).withOpacity(0.3) 
            : const Color(0xFFE8F5E9),
        foregroundColor: isDark 
            ? const Color(0xFF81C784) 
            : const Color(0xFF2E7D32),
        side: BorderSide(
          color: isDark ? const Color(0xFF2E7D32) : const Color(0xFF81C784), 
          width: 1,
        ),
        elevation: 0,
      ).build(
        context,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(kIsWeb ? Icons.play_arrow : Icons.check, size: 16),
            const SizedBox(width: 6),
            Text(loc.readyToStudy),
          ],
        ),
        onPressed: () {
          FlashcardStudyScreen.open(
            context,
            courseId: course.id,
            courseTitle: course.title,
            isTodayReview: false,
          );
        },
      );
    }

    if (isDownloading) {
      final percent = (downloadProgress * 100).clamp(0, 100).toInt();
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.15),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.primary.withOpacity(0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                value: downloadProgress > 0 ? downloadProgress : null,
                color: AppColors.primary,
                backgroundColor: AppColors.primary.withOpacity(0.2),
                strokeWidth: 2.5,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$percent%',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }


    if (course.isPurchased) {
      return ElevatedButton(
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
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
        foregroundColor: const Color(0xFF181837),
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

  String _formatPrice(double price, BuildContext context) {
    if (price == 0) {
      return AppLocalizations.of(context).free;
    }
    final formattedNumber = price.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
    return '$formattedNumber ${AppLocalizations.of(context).toman}';
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
