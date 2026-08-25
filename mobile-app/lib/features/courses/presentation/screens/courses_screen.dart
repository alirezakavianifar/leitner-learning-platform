import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile_app/app/theme.dart';
import 'package:mobile_app/core/localization/app_localizations.dart';
import 'package:mobile_app/core/services/payment_provider.dart';
import 'package:mobile_app/core/services/deep_link_service.dart';
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

class _CoursesScreenState extends State<CoursesScreen> with WidgetsBindingObserver {
  late int _selectedTab;
  int _catalogFilterIndex = 0; // 0: All, 1: Single Courses, 2: Packages
  StreamSubscription<PaymentResult>? _paymentSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _selectedTab = widget.tabNotifier?.value ?? 0;
    widget.tabNotifier?.addListener(_handleTabNotifierChange);
    
    // Subscribe to incoming deep link payment callbacks
    _paymentSub = sl<DeepLinkService>().paymentResults.listen(_handlePaymentResult);

    // Load courses on entry
    context.read<CoursesBloc>().add(LoadCoursesEvent());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Reload courses when user returns to app from browser or other apps
      context.read<CoursesBloc>().add(LoadCoursesEvent());
    }
  }

  void _handlePaymentResult(PaymentResult result) {
    if (!mounted) return;
    final loc = AppLocalizations.of(context);

    if (result.isSuccess) {
      // Trigger catalog & my courses reload
      context.read<CoursesBloc>().add(LoadCoursesEvent());

      // Show success modal with Ref ID
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.courseDownloaded.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.check_circle_outline, color: AppColors.courseDownloaded, size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  loc.translate('payment_successful_title'),
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                loc.translate('payment_successful_desc'),
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.5),
              ),
              if (result.refId != null && result.refId!.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.background.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      Text(
                        loc.translate('payment_ref_id').replaceAll('{ref}', result.refId!),
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                setState(() => _selectedTab = 1); // Switch to My Courses tab
              },
              child: Text(loc.translate('view_courses'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    } else if (result.isCancelled) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(loc.translate('payment_cancelled')),
          backgroundColor: AppColors.textSecondary,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(loc.translate('payment_failed')),
          backgroundColor: AppColors.error,
        ),
      );
    }
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
    WidgetsBinding.instance.removeObserver(this);
    _paymentSub?.cancel();
    widget.tabNotifier?.removeListener(_handleTabNotifierChange);
    super.dispose();
  }

  /// Sorts courses: courses needing an update go first, then downloaded & purchased, then purchased, then unpaid.
  List<Course> _sortCourses(List<Course> courses) {
    final list = List<Course>.from(courses);
    list.sort((a, b) {
      if (a.updateAvailable && !b.updateAvailable) return -1;
      if (!a.updateAvailable && b.updateAvailable) return 1;
      final aDownloadedOwned = a.isPurchased && a.isDownloaded;
      final bDownloadedOwned = b.isPurchased && b.isDownloaded;
      if (aDownloadedOwned && !bDownloadedOwned) return -1;
      if (!aDownloadedOwned && bDownloadedOwned) return 1;
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
                  sortedCourses = sortedCourses
                      .where((c) => (c.isPurchased && c.isDownloaded) || (kIsWeb && c.isPurchased))
                      .toList();
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
        useRootNavigator: false,
        backgroundColor: AppColors.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (sheetCtx) {
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
                    onTap: () {
                      Navigator.pop(sheetCtx);
                      _processPackagePurchase(package, sl<DirectPaymentProvider>());
                    },
                  ),
                  ListTile(
                    leading: Icon(Icons.store, color: AppColors.secondary),
                    title: Text(loc.translate('bazaar_billing'), style: TextStyle(color: AppColors.textPrimary)),
                    onTap: () {
                      Navigator.pop(sheetCtx);
                      _processPackagePurchase(package, sl<BazaarPaymentProvider>());
                    },
                  ),
                  ListTile(
                    leading: Icon(Icons.shopping_bag_outlined, color: AppColors.secondary),
                    title: Text(loc.translate('myket_billing'), style: TextStyle(color: AppColors.textPrimary)),
                    onTap: () {
                      Navigator.pop(sheetCtx);
                      _processPackagePurchase(package, sl<MyketPaymentProvider>());
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.shop_two, color: Colors.blue),
                    title: Text(loc.translate('google_play_iap'), style: TextStyle(color: AppColors.textPrimary)),
                    onTap: () {
                      Navigator.pop(sheetCtx);
                      _processPackagePurchase(package, sl<GooglePlayPaymentProvider>());
                    },
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

    showDialog(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      builder: (context) => Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
    );

    final success = await provider.purchasePackage(package.id);
    if (mounted) {
      Navigator.of(context, rootNavigator: true).pop(); // Close loading dialog safely
    }

    if (!mounted) return;

    if (provider is DirectPaymentProvider) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(loc.translate('redirecting_to_gateway')),
            backgroundColor: AppColors.primary,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(loc.translate('purchase_failed')),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } else {
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
  }

  void _purchaseCourse(Course course) async {
    final config = sl<AppConfig>();
    final loc = AppLocalizations.of(context);

    if (config.isPremium) {
      // Show payment selector modal sheet
      showModalBottomSheet(
        context: context,
        useRootNavigator: false,
        backgroundColor: AppColors.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (sheetCtx) {
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
                    onTap: () {
                      Navigator.pop(sheetCtx);
                      _processPurchase(course, sl<DirectPaymentProvider>());
                    },
                  ),
                  ListTile(
                    leading: Icon(Icons.store, color: AppColors.secondary),
                    title: Text(loc.translate('bazaar_billing'), style: TextStyle(color: AppColors.textPrimary)),
                    onTap: () {
                      Navigator.pop(sheetCtx);
                      _processPurchase(course, sl<BazaarPaymentProvider>());
                    },
                  ),
                  ListTile(
                    leading: Icon(Icons.shopping_bag_outlined, color: AppColors.secondary),
                    title: Text(loc.translate('myket_billing'), style: TextStyle(color: AppColors.textPrimary)),
                    onTap: () {
                      Navigator.pop(sheetCtx);
                      _processPurchase(course, sl<MyketPaymentProvider>());
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.shop_two, color: Colors.blue),
                    title: Text(loc.translate('google_play_iap'), style: TextStyle(color: AppColors.textPrimary)),
                    onTap: () {
                      Navigator.pop(sheetCtx);
                      _processPurchase(course, sl<GooglePlayPaymentProvider>());
                    },
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
    
    // Show progress loading
    showDialog(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      builder: (context) => Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
    );

    final success = await provider.purchaseCourse(course.id);
    
    if (mounted) {
      Navigator.of(context, rootNavigator: true).pop(); // Close loading dialog safely
    }

    if (!mounted) return;

    if (provider is DirectPaymentProvider) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(loc.translate('redirecting_to_gateway')),
            backgroundColor: AppColors.primary,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(loc.translate('purchase_failed')),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } else {
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
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacity(0.65),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor.withOpacity(0.6), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            if ((course.isPurchased && course.isDownloaded) || (kIsWeb && course.isPurchased)) {
              FlashcardStudyScreen.open(
                context,
                courseId: course.id,
                courseTitle: course.title,
                isTodayReview: false,
              );
            } else {
              _showCourseDetailsModal(course, isDownloading, downloadProgress, parentPackage);
            }
          },
          onLongPress: () {
            _showCourseDetailsModal(course, isDownloading, downloadProgress, parentPackage);
          },
          child: Padding(
            padding: const EdgeInsets.all(10.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 1. Course Image / Thumbnail
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 66,
                    height: 66,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: borderColor.withOpacity(0.35),
                        width: 1,
                      ),
                    ),
                    child: _buildCourseThumbnail(course),
                  ),
                ),
                const SizedBox(width: 12),

                // 2. Course Meta & Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Title & Status Icon
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              course.title,
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 14.5,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(
                            course.updateAvailable
                                ? Icons.system_update
                                : (course.isDownloaded ? Icons.offline_pin : Icons.cloud_download),
                            color: course.updateAvailable
                                ? (course.isCriticalUpdate ? AppColors.error : const Color(0xFFFF9800))
                                : borderColor,
                            size: 18,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),

                      // Meta row (Category, cards count, price)
                      Row(
                        children: [
                          if (course.category != null) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                course.category!,
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          Text(
                            '${course.cardCount} ${loc.cardsCount}',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            _formatPrice(course.price, context),
                            style: TextStyle(
                              color: course.price == 0 ? AppColors.secondary : AppColors.textSecondary,
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      // Bottom actions row: Description hint or bundle badge + Action button
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (parentPackage != null && !course.isPurchased && !parentPackage.isPurchased)
                            GestureDetector(
                              onTap: () => PackageDetailsModal.show(
                                context,
                                package: parentPackage,
                                onPurchase: () => _purchasePackage(parentPackage),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.auto_awesome, size: 12, color: Color(0xFFFF9800)),
                                  const SizedBox(width: 4),
                                  Text(
                                    loc.translate('in_bundle'),
                                    style: const TextStyle(
                                      color: Color(0xFFFFB300),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            GestureDetector(
                              onTap: () => _showCourseDetailsModal(course, isDownloading, downloadProgress, parentPackage),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.info_outline, size: 12, color: AppColors.textSecondary.withOpacity(0.7)),
                                  const SizedBox(width: 4),
                                  Text(
                                    loc.translate('more_info_hint'),
                                    style: TextStyle(
                                      color: AppColors.textSecondary.withOpacity(0.7),
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          _buildCompactActionButton(course, isDownloading, downloadProgress),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCourseThumbnail(Course course) {
    if (course.imageUrl != null && course.imageUrl!.trim().isNotEmpty) {
      final img = course.imageUrl!.trim();
      if (img.startsWith('http://') || img.startsWith('https://')) {
        return Image.network(
          img,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildFallbackThumbnail(course),
        );
      } else if (img.startsWith('assets/')) {
        return Image.asset(
          img,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildFallbackThumbnail(course),
        );
      } else if (!kIsWeb) {
        try {
          final file = File(img);
          if (file.existsSync()) {
            return Image.file(
              file,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _buildFallbackThumbnail(course),
            );
          }
        } catch (_) {}
      }
    }
    return _buildFallbackThumbnail(course);
  }

  Widget _buildFallbackThumbnail(Course course) {
    final hash = course.id.hashCode;
    final gradients = [
      [const Color(0xFF6C63FF), const Color(0xFF3F3D56)],
      [const Color(0xFF00B4D8), const Color(0xFF0077B6)],
      [const Color(0xFFFF758C), const Color(0xFFFF7EB3)],
      [const Color(0xFF43E97B), const Color(0xFF38F9D7)],
      [const Color(0xFFFA709A), const Color(0xFFFEE140)],
      [const Color(0xFF30CFD0), const Color(0xFF330867)],
    ];
    final colorPair = gradients[hash.abs() % gradients.length];

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colorPair[0].withOpacity(0.4), colorPair[1].withOpacity(0.6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(
          Icons.menu_book_rounded,
          color: Colors.white.withOpacity(0.9),
          size: 28,
        ),
      ),
    );
  }

  void _showCourseDetailsModal(
    Course course,
    bool isDownloading,
    double downloadProgress,
    CoursePackage? parentPackage,
  ) {
    final loc = AppLocalizations.of(context);
    final borderColor = course.isDownloaded
        ? AppColors.courseDownloaded
        : AppColors.courseNotDownloaded;

    showModalBottomSheet(
      context: context,
      useRootNavigator: false,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.textSecondary.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: borderColor, width: 1.5),
                        ),
                        child: _buildCourseThumbnail(course),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            course.title,
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              if (course.category != null) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
                                const SizedBox(width: 6),
                              ],
                              if (course.difficulty != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
                          const SizedBox(height: 6),
                          Text(
                            '${course.cardCount} ${loc.cardsCount}  •  ${_formatPrice(course.price, context)}',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(color: Color(0xFF333E56), height: 1),
                const SizedBox(height: 14),

                if (course.description != null && course.description!.isNotEmpty) ...[
                  Text(
                    loc.description,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 180),
                    child: SingleChildScrollView(
                      child: Text(
                        course.description!,
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13.5,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                _buildModalActionButton(course, isDownloading, downloadProgress, parentPackage, sheetCtx),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildModalActionButton(
    Course course,
    bool isDownloading,
    double downloadProgress,
    CoursePackage? parentPackage,
    BuildContext sheetCtx,
  ) {
    final loc = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (!isDownloading && !kIsWeb && course.updateAvailable) {
      return ElevatedButton(
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          backgroundColor: course.isCriticalUpdate ? AppColors.error : const Color(0xFFFF9800),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        onPressed: () {
          Navigator.pop(sheetCtx);
          context.read<CoursesBloc>().add(DownloadCourseEvent(courseId: course.id));
        },
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.system_update, size: 18),
            const SizedBox(width: 8),
            Text(loc.updateNow, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          ],
        ),
      );
    }

    if ((course.isPurchased && course.isDownloaded) || (kIsWeb && course.isPurchased)) {
      return ElevatedButton(
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          backgroundColor: isDark 
              ? const Color(0xFF1B5E20).withOpacity(0.4) 
              : const Color(0xFFE8F5E9),
          foregroundColor: isDark 
              ? const Color(0xFF81C784) 
              : const Color(0xFF2E7D32),
          side: BorderSide(
            color: isDark ? const Color(0xFF2E7D32) : const Color(0xFF81C784), 
            width: 1.5,
          ),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        onPressed: () {
          Navigator.pop(sheetCtx);
          FlashcardStudyScreen.open(
            context,
            courseId: course.id,
            courseTitle: course.title,
            isTodayReview: false,
          );
        },
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(kIsWeb ? Icons.play_arrow : Icons.check, size: 18),
            const SizedBox(width: 8),
            Text(loc.readyToStudy, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          ],
        ),
      );
    }

    if (course.isPurchased) {
      return ElevatedButton(
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        onPressed: () {
          Navigator.pop(sheetCtx);
          context.read<CoursesBloc>().add(DownloadCourseEvent(courseId: course.id));
        },
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.download, size: 18),
            const SizedBox(width: 8),
            Text(loc.downloadNow, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          ],
        ),
      );
    }

    // Unpurchased
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: AppColors.secondary,
        foregroundColor: const Color(0xFF181837),
        padding: const EdgeInsets.symmetric(vertical: 14),
      ),
      onPressed: () {
        Navigator.pop(sheetCtx);
        _purchaseCourse(course);
      },
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.payment, size: 18),
          const SizedBox(width: 8),
          Text(loc.purchase, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        ],
      ),
    );
  }

  Widget _buildCompactActionButton(Course course, bool isDownloading, [double downloadProgress = 0.0]) {
    final loc = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (!isDownloading && !kIsWeb && course.updateAvailable) {
      return SizedBox(
        height: 28,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            backgroundColor: course.isCriticalUpdate ? AppColors.error : const Color(0xFFFF9800),
            foregroundColor: Colors.white,
          ),
          onPressed: () {
            context.read<CoursesBloc>().add(DownloadCourseEvent(courseId: course.id));
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.system_update, size: 13),
              const SizedBox(width: 4),
              Text(loc.updateNow, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      );
    }

    if ((course.isPurchased && course.isDownloaded) || (kIsWeb && course.isPurchased)) {
      return SizedBox(
        height: 28,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
          ),
          onPressed: () {
            FlashcardStudyScreen.open(
              context,
              courseId: course.id,
              courseTitle: course.title,
              isTodayReview: false,
            );
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(kIsWeb ? Icons.play_arrow : Icons.check, size: 13),
              const SizedBox(width: 4),
              Text(loc.readyToStudy, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      );
    }

    if (isDownloading) {
      final percent = (downloadProgress * 100).clamp(0, 100).toInt();
      return Container(
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.primary.withOpacity(0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                value: downloadProgress > 0 ? downloadProgress : null,
                color: AppColors.primary,
                backgroundColor: AppColors.primary.withOpacity(0.2),
                strokeWidth: 2,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '$percent%',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    if (course.isPurchased) {
      return SizedBox(
        height: 28,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
          onPressed: () {
            context.read<CoursesBloc>().add(DownloadCourseEvent(courseId: course.id));
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.download, size: 13),
              const SizedBox(width: 4),
              Text(loc.downloadNow, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      );
    }

    // Unpurchased course
    return SizedBox(
      height: 28,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          backgroundColor: AppColors.secondary,
          foregroundColor: const Color(0xFF181837),
        ),
        onPressed: () {
          _purchaseCourse(course);
        },
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.payment, size: 13),
            const SizedBox(width: 4),
            Text(loc.purchase, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          ],
        ),
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
