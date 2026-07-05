import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile_app/app/theme.dart';
import 'package:mobile_app/core/localization/app_localizations.dart';
import 'package:mobile_app/core/usecase/usecase.dart';
import 'package:mobile_app/features/flashcards/domain/repositories/flashcard_repository.dart';
import 'package:mobile_app/features/courses/domain/repositories/courses_repository.dart';
import 'package:mobile_app/features/courses/domain/entities/course.dart';
import 'package:mobile_app/injection_container.dart' as di;
import 'settings_screen.dart';
import 'statistics_screen.dart';
import 'package:mobile_app/features/flashcards/presentation/screens/finished_cards_screen.dart';
import 'package:mobile_app/features/flashcards/presentation/screens/custom_courses_screen.dart';
import 'support_screen.dart';
import 'package:mobile_app/features/notifications/presentation/screens/notifications_screen.dart';
import 'package:mobile_app/features/notifications/domain/entities/banner.dart' as entity;
import 'package:mobile_app/features/notifications/domain/repositories/notifications_repository.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:mobile_app/features/flashcards/presentation/screens/favorites_screen.dart';

class DashboardScreen extends StatefulWidget {
  final Function(int) onTabChange;
  final ValueNotifier<int>? coursesTabNotifier;

  const DashboardScreen({
    Key? key,
    required this.onTabChange,
    this.coursesTabNotifier,
  }) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late FlashcardRepository _flashcardRepository;
  late CoursesRepository _coursesRepository;
  late NotificationsRepository _notificationsRepository;
  
  int _dueCount = 0;
  int _finishedCount = 0;

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
    _coursesRepository = di.sl<CoursesRepository>();
    _notificationsRepository = di.sl<NotificationsRepository>();
    _pageController = PageController(initialPage: 0);
    _loadProfile();
    _loadStats();
    _loadBanners();
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

  void _showFavoritesSelectDialog() async {
    final loc = AppLocalizations.of(context);
    final either = await _coursesRepository.getCourses();
    either.fold(
      (failure) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(failure.message), backgroundColor: AppColors.error));
      },
      (data) {
        final downloaded = data.$1.where((c) => c.isDownloaded).toList();
        if (downloaded.isEmpty) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: AppColors.surface,
              title: Text(loc.favorites, style: TextStyle(color: AppColors.textPrimary)),
              content: Text(loc.noDownloadedCourses, style: TextStyle(color: AppColors.textSecondary)),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: Text(loc.confirm)),
              ],
            ),
          );
          return;
        }

        showDialog(
          context: context,
          builder: (context) {
            return AlertDialog(
              backgroundColor: AppColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: AppColors.border),
              ),
              title: Text(loc.selectCourse, style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: downloaded.length,
                  itemBuilder: (context, idx) {
                    final course = downloaded[idx];
                    return ListTile(
                      title: Text(course.title, style: TextStyle(color: AppColors.textPrimary)),
                      trailing: Icon(Icons.chevron_right, color: AppColors.primary),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => FavoritesScreen(courseId: course.id, courseTitle: course.title),
                          ),
                        ).then((_) => _loadStats());
                      },
                    );
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        color: AppColors.primary,
        backgroundColor: AppColors.surface,
        onRefresh: () async {
          await _loadProfile();
          await _loadStats();
          await _loadBanners(force: true);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [


              // Banner Carousel
              SizedBox(
                height: 140,
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
                                      SizedBox(height: 8),
                                      Text('Failed to load banner', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                                    ],
                                  ),
                                );
                              },
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return Center(
                                  child: CircularProgressIndicator(color: AppColors.primary),
                                );
                              },
                            ),
                          ),
                        );
                      } else {
                        // Fallback/Default Banner
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
              const SizedBox(height: 10),
              // Page indicators
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
              const SizedBox(height: 24),

              Text(
                loc.quickHub,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),

              // Feature Grid
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.15,
                children: [
                  _buildGridCard(
                    title: loc.reviewToday,
                    imageAsset: 'assets/images/today_cards.png',
                    badgeCount: _dueCount,
                    badgeColor: AppColors.error,
                    onTap: () => widget.onTabChange(1),
                  ),
                  _buildGridCard(
                    title: loc.favorites,
                    imageAsset: 'assets/images/favorite_cards.png',
                    onTap: _showFavoritesSelectDialog,
                  ),
                  _buildGridCard(
                    title: loc.finishedCards,
                    imageAsset: 'assets/images/finished_cards.png',
                    badgeCount: _finishedCount,
                    badgeColor: const Color(0xFFFFD700),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const FinishedCardsScreen()),
                      ).then((_) => _loadStats());
                    },
                  ),
                  _buildGridCard(
                    title: loc.myCourses,
                    imageAsset: 'assets/images/my_courses.png',
                    onTap: () {
                      widget.coursesTabNotifier?.value = 1;
                      widget.onTabChange(2);
                    },
                  ),
                  _buildGridCard(
                    title: loc.courses,
                    imageAsset: 'assets/images/courses_list.png',
                    onTap: () {
                      widget.coursesTabNotifier?.value = 0;
                      widget.onTabChange(2);
                    },
                  ),
                  _buildGridCard(
                    title: loc.customCards,
                    imageAsset: 'assets/images/create_card.png',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const CustomCoursesScreen()),
                      ).then((_) => _loadStats());
                    },
                  ),

                ],
              ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGridCard({
    required String title,
    IconData? icon,
    String? imageAsset,
    int? badgeCount,
    Color? badgeColor,
    Color? iconColor,
    required VoidCallback onTap,
  }) {
    return Card(
      color: AppColors.surface.withOpacity(0.6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.border),
      ),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Stack(
            children: [
              SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (imageAsset != null)
                      Image.asset(
                        imageAsset,
                        width: 48,
                        height: 48,
                        fit: BoxFit.contain,
                      )
                    else if (icon != null)
                      Icon(icon, size: 28, color: iconColor ?? AppColors.primary),
                    const SizedBox(height: 12),
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
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
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: badgeColor ?? AppColors.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$badgeCount',
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
