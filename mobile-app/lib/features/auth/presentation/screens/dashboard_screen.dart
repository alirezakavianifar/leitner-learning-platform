import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile_app/app/theme.dart';
import 'package:mobile_app/core/localization/app_localizations.dart';
import 'package:mobile_app/features/flashcards/domain/repositories/flashcard_repository.dart';
import 'package:mobile_app/injection_container.dart' as di;
import 'package:mobile_app/features/flashcards/presentation/screens/finished_cards_screen.dart';
import 'package:mobile_app/features/flashcards/presentation/screens/custom_courses_screen.dart';
import 'package:mobile_app/features/notifications/domain/entities/banner.dart' as entity;
import 'package:mobile_app/features/notifications/domain/repositories/notifications_repository.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:mobile_app/features/flashcards/presentation/screens/favorites_courses_screen.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile_app/features/config/presentation/bloc/config_bloc.dart';
import 'package:mobile_app/features/config/presentation/bloc/config_event.dart';
import 'package:mobile_app/features/config/presentation/bloc/config_state.dart';
import 'package:mobile_app/features/courses/domain/entities/course.dart';
import 'package:mobile_app/features/courses/domain/repositories/courses_repository.dart';
import 'package:mobile_app/features/flashcards/domain/entities/flashcard.dart';
import 'package:mobile_app/features/flashcards/presentation/screens/flashcard_study_screen.dart';
import 'package:mobile_app/features/courses/presentation/widgets/lesson_stage_pot.dart';
import 'package:mobile_app/core/utils/scroll_physics.dart';

class DashboardScreen extends StatefulWidget {
  final Function(int) onTabChange;
  final ValueNotifier<int>? coursesTabNotifier;
  final Key? todayReviewsKey;
  final Key? favoritesKey;
  final Key? finishedCardsKey;
  final Key? myCoursesKey;
  final Key? coursesListKey;
  final Key? createCardKey;

  const DashboardScreen({
    Key? key,
    required this.onTabChange,
    this.coursesTabNotifier,
    this.todayReviewsKey,
    this.favoritesKey,
    this.finishedCardsKey,
    this.myCoursesKey,
    this.coursesListKey,
    this.createCardKey,
  }) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _CourseLessonProgress {
  final String courseId;
  final String courseTitle;
  final List<_LessonBlockInfo> lessons;

  _CourseLessonProgress({
    required this.courseId,
    required this.courseTitle,
    required this.lessons,
  });
}

class _LessonBlockInfo {
  final int lessonIndex;
  final String lessonTitle;
  final int totalCards;
  final int remainingWords;
  final double progress;
  final List<Flashcard> cards;

  _LessonBlockInfo({
    required this.lessonIndex,
    required this.lessonTitle,
    required this.totalCards,
    required this.remainingWords,
    required this.progress,
    required this.cards,
  });
}

class _DashboardScreenState extends State<DashboardScreen> {
  late FlashcardRepository _flashcardRepository;
  late NotificationsRepository _notificationsRepository;
  late CoursesRepository _coursesRepository;
  
  int _dueCount = 0;
  int _finishedCount = 0;
  int _totalDownloadedCards = 0;
  List<_CourseLessonProgress> _userCoursesProgress = [];
  bool _loadingCoursesData = true;

  String _username = 'User';
  String _educationalField = 'General';
  String _educationalLevel = 'Learner';

  // Banner rotation fields
  late PageController _pageController;
  int _currentBannerIndex = 0;
  Timer? _bannerTimer;

  List<entity.Banner> _bannerList = [];
  bool _bannersLoading = true;

  final List<Map<String, dynamic>> _defaultBanners = const [
    {
      'key': 'banner_1',
      'gradient': [Color(0xFF8F53FF), Color(0xFF6236FF)],
      'icon': Icons.psychology,
    },
    {
      'key': 'banner_2',
      'gradient': [Color(0xFF09E5C3), Color(0xFF07A890)],
      'icon': Icons.offline_bolt,
    },
    {
      'key': 'banner_3',
      'gradient': [Color(0xFFFF7A1A), Color(0xFFFFB61A)],
      'icon': Icons.dashboard_customize,
    },
  ];

  @override
  void initState() {
    super.initState();
    _flashcardRepository = di.sl<FlashcardRepository>();
    _notificationsRepository = di.sl<NotificationsRepository>();
    _coursesRepository = di.sl<CoursesRepository>();
    _pageController = PageController(initialPage: 0);
    _loadProfile();
    _loadStats();
    _loadBanners();
    _loadCoursesData();
    _startBannerRotation();
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _startBannerRotation() {
    _bannerTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (_pageController.hasClients) {
        final activeListLength = _bannerList.isNotEmpty ? _bannerList.length : _defaultBanners.length;
        if (activeListLength > 0) {
          final nextPage = (_currentBannerIndex + 1) % activeListLength;
          _pageController.animateToPage(
            nextPage,
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeInOutCubic,
          );
        }
      }
    });
  }

  Future<void> _loadBanners({bool force = false}) async {
    try {
      final data = await _notificationsRepository.getBanners(forceRefresh: force);
      if (mounted) {
        setState(() {
          _bannerList = data.take(5).toList();
          _bannersLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _bannerList = [];
          _bannersLoading = false;
        });
      }
    }
  }

  Future<void> _launchUrl(String urlString) async {
    final uri = Uri.parse(urlString);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context).couldNotOpenBanner)),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).couldNotOpenBanner)),
        );
      }
    }
  }

  Future<void> _loadProfile() async {
    final prefs = di.sl<SharedPreferences>();
    setState(() {
      _username = prefs.getString('user_username') ?? 'User';
      _educationalField = prefs.getString('user_educational_field') ?? 'General';
      _educationalLevel = prefs.getString('user_educational_level') ?? 'Learner';
    });
  }

  Future<void> _loadStats() async {
    final due = await _flashcardRepository.getGlobalDueCount();
    final finished = await _flashcardRepository.getGlobalFinishedCount();
    if (mounted) {
      setState(() {
        _dueCount = due;
        _finishedCount = finished;
      });
    }
  }

  Future<void> _loadCoursesData() async {
    try {
      final coursesResult = await _coursesRepository.getCourses();
      List<Course> downloadedCourses = [];
      coursesResult.fold((_) {}, (res) {
        downloadedCourses = res.$1.where((c) => c.isDownloaded).toList();
      });

      List<_CourseLessonProgress> list = [];
      int totalCardsSum = 0;

      final loc = AppLocalizations.of(context);
      final lessonLabelText = loc.translate('lesson_label');

      for (final course in downloadedCourses) {
        final cards = await _flashcardRepository.getAllCardsForCourse(course.id);
        totalCardsSum += cards.length;

        const blockSize = 20;
        List<_LessonBlockInfo> lessons = [];
        final totalBlocks = cards.isNotEmpty ? (cards.length / blockSize).ceil() : 0;

        for (int i = 0; i < totalBlocks; i++) {
          final blockCards = cards.skip(i * blockSize).take(blockSize).toList();
          if (blockCards.isEmpty) continue;

          int unmastered = 0;
          int mastered = 0;
          for (final card in blockCards) {
            if (card.progress.currentBox >= 4) {
              mastered++;
            } else {
              unmastered++;
            }
          }

          final progressRatio = blockCards.isNotEmpty ? (mastered / blockCards.length) : 0.0;
          lessons.add(_LessonBlockInfo(
            lessonIndex: i + 1,
            lessonTitle: '$lessonLabelText ${i + 1}',
            totalCards: blockCards.length,
            remainingWords: unmastered,
            progress: progressRatio,
            cards: blockCards,
          ));
        }

        list.add(_CourseLessonProgress(
          courseId: course.id,
          courseTitle: course.title,
          lessons: lessons,
        ));
      }

      if (mounted) {
        setState(() {
          _userCoursesProgress = list;
          _totalDownloadedCards = totalCardsSum;
          _loadingCoursesData = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loadingCoursesData = false;
        });
      }
    }
  }

  Future<void> _onRefresh() async {
    await _loadProfile();
    await _loadStats();
    await _loadBanners(force: true);
    await _loadCoursesData();
    if (mounted) {
      context.read<ConfigBloc>().add(LoadConfigEvent());
    }
  }


  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);

    bool enableGamifiedLayout = false;
    try {
      final configState = context.watch<ConfigBloc>().state;
      if (configState.config != null) {
        enableGamifiedLayout = configState.config!.enableGamifiedLayout;
      }
    } catch (_) {}

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        color: AppColors.primary,
        backgroundColor: AppColors.surface,
        onRefresh: _onRefresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: enableGamifiedLayout
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Greeting & VIP Header
                    _buildTopGamifiedHeader(context, loc),
                    const SizedBox(height: 16),

                    // Gamified 3D Learning Hero Banner
                    _buildGamifiedHeroBanner(context, loc),
                    const SizedBox(height: 20),

                    // Practice More Section Title
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          loc.translate('practice_more'),
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Daily Practice Orange Review Banner Card
                    _buildDailyPracticeCard(context, loc),
                    const SizedBox(height: 20),

                    // Dynamic Real Course Accordion & Lesson Progress Tree
                    _buildCourseAccordionTree(context, loc),
                    const SizedBox(height: 48),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Classic Carousel Banner Layout
                    _buildClassicBannerCarousel(context, loc),
                    const SizedBox(height: 16),

                    Text(
                      loc.quickHub,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Classic Feature Grid (6 Cards)
                    _buildClassicFeatureGrid(context, loc),
                    const SizedBox(height: 64),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildGridCard({
    Key? key,
    required String title,
    IconData? icon,
    String? imageAsset,
    int? badgeCount,
    Color? badgeColor,
    Color? iconColor,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Distinct soft light purple in light mode, rich deep purple in dark mode
    final cardBgColor = isDark
        ? const Color(0xFF1F1B35)
        : const Color(0xFFF1EAFF);
    final borderColor = isDark
        ? const Color(0xFF6C63FF).withOpacity(0.35)
        : const Color(0xFFD7C7F7);

    return Container(
      key: key,
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 1.3),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.3)
                : const Color(0xFF6C63FF).withOpacity(0.10),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          splashColor: AppColors.primary.withOpacity(0.18),
          highlightColor: AppColors.primary.withOpacity(0.08),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 10.0),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      if (imageAsset != null)
                        Image.asset(
                          imageAsset,
                          width: 88,
                          height: 88,
                          fit: BoxFit.contain,
                        )
                      else if (icon != null)
                        Icon(icon, size: 54, color: iconColor ?? AppColors.primary),
                      const SizedBox(height: 6),
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isDark ? Colors.white : const Color(0xFF261D4E),
                          fontSize: 14.5,
                          fontWeight: FontWeight.bold,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
                if (badgeCount != null && badgeCount > 0)
                  PositionedDirectional(
                    top: 0,
                    end: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: badgeColor ?? AppColors.primary,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: (badgeColor ?? AppColors.primary).withOpacity(0.45),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        '$badgeCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildClassicBannerCarousel(BuildContext context, AppLocalizations loc) {
    return Column(
      children: [
        SizedBox(
          height: 125,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: PageView.builder(
              controller: _pageController,
              itemCount: _bannerList.isNotEmpty ? _bannerList.length : _defaultBanners.length,
              onPageChanged: (idx) {
                setState(() {
                  _currentBannerIndex = idx;
                });
              },
              itemBuilder: (context, index) {
                final activeList = _bannerList.isNotEmpty ? _bannerList : _defaultBanners;
                final isRealBanner = _bannerList.isNotEmpty;
                final banner = activeList[index];

                if (isRealBanner) {
                  final realBanner = banner as entity.Banner;
                  return GestureDetector(
                    onTap: () {
                      if (realBanner.linkUrl != null && realBanner.linkUrl!.isNotEmpty) {
                        _launchUrl(realBanner.linkUrl!);
                      }
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                      ),
                      child: Image.network(
                        realBanner.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: AppColors.surface,
                            alignment: Alignment.center,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.broken_image, color: AppColors.textSecondary, size: 36),
                                const SizedBox(height: 8),
                                Text(loc.failedLoadBanner, style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  );
                } else {
                  final defaultBanner = banner as Map<String, dynamic>;
                  final key = defaultBanner['key'] as String;
                  String title = '';
                  String subtitle = '';
                  if (key == 'banner_1') {
                    title = loc.banner1Title;
                    subtitle = loc.banner1Sub;
                  } else if (key == 'banner_2') {
                    title = loc.banner2Title;
                    subtitle = loc.banner2Sub;
                  } else if (key == 'banner_3') {
                    title = loc.banner3Title;
                    subtitle = loc.banner3Sub;
                  }

                  return Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: defaultBanner['gradient'] as List<Color>,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    padding: const EdgeInsets.all(20.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                subtitle,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(
                          defaultBanner['icon'] as IconData,
                          size: 48,
                          color: Colors.white.withOpacity(0.4),
                        ),
                      ],
                    ),
                  );
                }
              },
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            _bannerList.isNotEmpty ? _bannerList.length : _defaultBanners.length,
            (index) => Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _currentBannerIndex == index
                    ? AppColors.primary
                    : AppColors.textSecondary.withOpacity(0.3),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTopGamifiedHeader(BuildContext context, AppLocalizations loc) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              loc.translate('greeting_hello'),
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              loc.translate('greeting_sub'),
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ],
        ),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Icon(Icons.shopping_cart_outlined, size: 18, color: AppColors.textSecondary),
                  const SizedBox(width: 6),
                  Text(
                    loc.translate('vip_membership'),
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGamifiedHeroBanner(BuildContext context, AppLocalizations loc) {
    final overallPercentage = (_finishedCount > 0 && _totalDownloadedCards > 0)
        ? ((_finishedCount / _totalDownloadedCards) * 100).round().clamp(0, 100)
        : 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0072FF), Color(0xFF00C6FF)],
          begin: Alignment.centerRight,
          end: Alignment.centerLeft,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0072FF).withOpacity(0.35),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Row(
            children: [
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person_pin,
                  size: 48,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.25),
                            border: Border.all(color: Colors.white.withOpacity(0.4), width: 2),
                          ),
                          child: Center(
                            child: Text(
                              '%$overallPercentage',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '$_finishedCount ${loc.translate('words_so_far')}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF0072FF),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      ),
                      onPressed: () => widget.onTabChange(1),
                      child: Text(
                        loc.translate('start_learning'),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDailyPracticeCard(BuildContext context, AppLocalizations loc) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF9500), Color(0xFFFF5E00)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF9500).withOpacity(0.35),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => widget.onTabChange(1),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        loc.translate('review_words_title'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _dueCount > 0
                            ? '${_dueCount} ${loc.translate("words_remaining")}'
                            : loc.translate('review_words_sub'),
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.85),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    _dueCount > 0 ? '$_dueCount ${loc.translate("daily_practice_badge")}' : loc.translate('daily_practice_badge'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCourseAccordionTree(BuildContext context, AppLocalizations loc) {
    if (_loadingCoursesData) {
      return Container(
        padding: const EdgeInsets.all(24),
        alignment: Alignment.center,
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (_userCoursesProgress.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Icon(Icons.school_outlined, size: 48, color: AppColors.primary),
            const SizedBox(height: 12),
            Text(
              loc.translate('my_courses'),
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              loc.translate('courses'),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                widget.coursesTabNotifier?.value = 0;
                widget.onTabChange(2);
              },
              icon: const Icon(Icons.download, size: 18),
              label: Text(loc.courses),
            ),
          ],
        ),
      );
    }

    return Column(
      children: _userCoursesProgress.asMap().entries.map((entry) {
        final index = entry.key;
        final courseProgress = entry.value;
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: ExpansionTile(
              initiallyExpanded: index == 0,
              iconColor: AppColors.primary,
              collapsedIconColor: AppColors.textSecondary,
              tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              title: Row(
                children: [
                  const Text('✍️ ', style: TextStyle(fontSize: 18)),
                  Expanded(
                    child: Text(
                      courseProgress.courseTitle,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 12, right: 12, bottom: 12),
                  child: Column(
                    children: courseProgress.lessons.map((lesson) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: _buildLessonItem(
                          context: context,
                          lessonTitle: lesson.lessonTitle,
                          remainingWords: '${lesson.remainingWords} ${loc.translate("words_remaining")}',
                          progress: lesson.progress,
                          onTap: () {
                            if (lesson.cards.isNotEmpty) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => FlashcardStudyScreen(
                                    courseId: courseProgress.courseId,
                                    courseTitle: courseProgress.courseTitle,
                                    initialCardNumber: lesson.cards.first.cardNumber,
                                  ),
                                ),
                              ).then((_) => _onRefresh());
                            }
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildLessonItem({
    required BuildContext context,
    required String lessonTitle,
    required String remainingWords,
    required double progress,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background.withOpacity(0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border.withOpacity(0.5)),
      ),
      child: ListTile(
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        leading: const Icon(Icons.arrow_back_ios_new, size: 16, color: Colors.grey),
        title: Text(
          lessonTitle,
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          remainingWords,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
          ),
        ),
        trailing: LessonStagePot(
          progress: progress,
          size: 48,
        ),
      ),
    );
  }

  Widget _buildClassicFeatureGrid(BuildContext context, AppLocalizations loc) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 14,
      mainAxisSpacing: 14,
      childAspectRatio: 1.0,
      children: [
        _buildGridCard(
          key: widget.coursesListKey,
          title: loc.courses,
          imageAsset: 'assets/images/courses_list.png',
          onTap: () {
            widget.coursesTabNotifier?.value = 0;
            widget.onTabChange(2);
          },
        ),
        _buildGridCard(
          key: widget.todayReviewsKey,
          title: loc.reviewToday,
          imageAsset: 'assets/images/today_cards.png',
          badgeCount: _dueCount,
          badgeColor: AppColors.error,
          onTap: () => widget.onTabChange(1),
        ),
        _buildGridCard(
          key: widget.myCoursesKey,
          title: loc.myCourses,
          imageAsset: 'assets/images/my_courses.png',
          onTap: () {
            widget.coursesTabNotifier?.value = 1;
            widget.onTabChange(2);
          },
        ),
        _buildGridCard(
          key: widget.createCardKey,
          title: loc.customCards,
          imageAsset: 'assets/images/create_card.png',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CustomCoursesScreen()),
            ).then((_) => _onRefresh());
          },
        ),
        _buildGridCard(
          key: widget.finishedCardsKey,
          title: loc.finishedCards,
          imageAsset: 'assets/images/finished_cards.png',
          badgeCount: _finishedCount,
          badgeColor: const Color(0xFFFFD700),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const FinishedCardsScreen()),
            ).then((_) => _onRefresh());
          },
        ),
        _buildGridCard(
          key: widget.favoritesKey,
          title: loc.favorites,
          imageAsset: 'assets/images/favorite_cards.png',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const FavoritesCoursesScreen()),
            ).then((_) => _onRefresh());
          },
        ),
      ],
    );
  }
}
