import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile_app/app/theme.dart';
import 'package:mobile_app/core/usecase/usecase.dart';
import 'package:mobile_app/features/flashcards/domain/repositories/flashcard_repository.dart';
import 'package:mobile_app/features/courses/domain/repositories/courses_repository.dart';
import 'package:mobile_app/features/courses/domain/entities/course.dart';
import 'package:mobile_app/injection_container.dart' as di;
import 'settings_screen.dart';
import 'package:mobile_app/features/flashcards/presentation/screens/finished_cards_screen.dart';
import 'package:mobile_app/features/flashcards/presentation/screens/custom_cards_screen.dart';
import 'support_screen.dart';
import 'notifications_screen.dart';
import 'package:mobile_app/features/flashcards/presentation/screens/favorites_screen.dart';

class DashboardScreen extends StatefulWidget {
  final Function(int) onTabChange;

  const DashboardScreen({
    Key? key,
    required this.onTabChange,
  }) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late FlashcardRepository _flashcardRepository;
  late CoursesRepository _coursesRepository;
  
  int _dueCount = 0;
  int _finishedCount = 0;

  String _username = 'User';
  String _educationalField = 'General';
  String _educationalLevel = 'Learner';

  // Banner rotation fields
  late PageController _pageController;
  int _currentBannerIndex = 0;
  Timer? _bannerTimer;

  final List<Map<String, dynamic>> _banners = [
    {
      'title': 'Spaced Repetition Mastery',
      'subtitle': 'Study systematically to retain 90% of what you learn.',
      'gradient': const [Color(0xFF8F53FF), Color(0xFF6236FF)],
      'icon': Icons.psychology,
    },
    {
      'title': 'Offline Learning Active',
      'subtitle': 'All your downloaded courses are stored securely offline.',
      'gradient': const [Color(0xFF09E5C3), Color(0xFF07A890)],
      'icon': Icons.offline_bolt,
    },
    {
      'title': 'Custom Flashcards',
      'subtitle': 'Create and study custom cards stored strictly on your device.',
      'gradient': const [Color(0xFFFF7A1A), Color(0xFFFFB61A)],
      'icon': Icons.dashboard_customize,
    },
  ];

  @override
  void initState() {
    super.initState();
    _flashcardRepository = di.sl<FlashcardRepository>();
    _coursesRepository = di.sl<CoursesRepository>();
    _pageController = PageController(initialPage: 0);
    _loadProfile();
    _loadStats();
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
        final nextPage = (_currentBannerIndex + 1) % _banners.length;
        _pageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOutCubic,
        );
      }
    });
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

  void _showStatsDialog() async {
    showDialog(
      context: context,
      builder: (context) {
        return FutureBuilder<Either<dynamic, (List<Course> courses, bool isOffline)>>(
          future: _coursesRepository.getCourses(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator(color: AppColors.primary));
            }
            
            List<Course> downloaded = [];
            snapshot.data!.fold((_) {}, (r) {
              downloaded = r.$1.where((c) => c.isDownloaded).toList();
            });

            if (downloaded.isEmpty) {
              return AlertDialog(
                backgroundColor: AppColors.surface,
                title: const Text('Statistics', style: TextStyle(color: AppColors.textPrimary)),
                content: const Text('No downloaded courses available for statistics.', style: TextStyle(color: AppColors.textSecondary)),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  )
                ],
              );
            }

            return StatefulBuilder(
              builder: (context, setState) {
                return AlertDialog(
                  backgroundColor: AppColors.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: AppColors.border),
                  ),
                  title: const Text(
                    'Leitner Box Distribution',
                    style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
                  ),
                  content: SizedBox(
                    width: double.maxFinite,
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: downloaded.length,
                      itemBuilder: (context, idx) {
                        final course = downloaded[idx];
                        return FutureBuilder<Map<int, int>>(
                          future: _flashcardRepository.getCourseStatistics(course.id),
                          builder: (context, statSnap) {
                            if (!statSnap.hasData) return const SizedBox();
                            final stats = statSnap.data!;
                            final total = stats.values.fold(0, (sum, val) => sum + val);

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    course.title,
                                    style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(height: 8),
                                  if (total == 0)
                                    const Text('No learning progress on this course yet.', style: TextStyle(color: AppColors.textSecondary, fontSize: 12))
                                  else
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: SizedBox(
                                        height: 16,
                                        width: double.infinity,
                                        child: Row(
                                          children: [
                                            if (stats[1]! > 0) Expanded(flex: stats[1]!, child: Container(color: AppColors.box1)),
                                            if (stats[2]! > 0) Expanded(flex: stats[2]!, child: Container(color: AppColors.box2)),
                                            if (stats[3]! > 0) Expanded(flex: stats[3]!, child: Container(color: AppColors.box3)),
                                            if (stats[4]! > 0) Expanded(flex: stats[4]!, child: Container(color: AppColors.box4)),
                                            if (stats[5]! > 0) Expanded(flex: stats[5]!, child: Container(color: AppColors.box5)),
                                            if (stats[6]! > 0) Expanded(flex: stats[6]!, child: Container(color: AppColors.finished)),
                                          ],
                                        ),
                                      ),
                                    ),
                                  const SizedBox(height: 8),
                                  // Color legend helper
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 4,
                                    children: [
                                      _buildLegendItem('Box 1', AppColors.box1, stats[1] ?? 0),
                                      _buildLegendItem('Box 2', AppColors.box2, stats[2] ?? 0),
                                      _buildLegendItem('Box 3', AppColors.box3, stats[3] ?? 0),
                                      _buildLegendItem('Box 4', AppColors.box4, stats[4] ?? 0),
                                      _buildLegendItem('Box 5', AppColors.box5, stats[5] ?? 0),
                                      _buildLegendItem('Finished', AppColors.finished, stats[6] ?? 0),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close', style: TextStyle(color: AppColors.primary)),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildLegendItem(String label, Color color, int count) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text('$label: $count', style: const TextStyle(color: AppColors.textSecondary, fontSize: 10)),
      ],
    );
  }

  void _showFavoritesSelectDialog() async {
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
              title: const Text('Favorites', style: TextStyle(color: AppColors.textPrimary)),
              content: const Text('No downloaded courses found to browse favorites.', style: TextStyle(color: AppColors.textSecondary)),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
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
              title: const Text('Select Course', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: downloaded.length,
                  itemBuilder: (context, idx) {
                    final course = downloaded[idx];
                    return ListTile(
                      title: Text(course.title, style: const TextStyle(color: AppColors.textPrimary)),
                      trailing: const Icon(Icons.chevron_right, color: AppColors.primary),
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
    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        color: AppColors.primary,
        backgroundColor: AppColors.surface,
        onRefresh: () async {
          await _loadProfile();
          await _loadStats();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome Hub Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0x338F53FF), Color(0x11121620)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: AppColors.primary.withOpacity(0.2),
                      child: const Icon(Icons.person, size: 36, color: AppColors.primary),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome back, $_username!',
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '$_educationalField • $_educationalLevel',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Banner Carousel
              SizedBox(
                height: 140,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: _banners.length,
                    onPageChanged: (idx) {
                      setState(() {
                        _currentBannerIndex = idx;
                      });
                    },
                    itemBuilder: (context, index) {
                      final banner = _banners[index];
                      return Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: banner['gradient'] as List<Color>,
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
                                    banner['title'] as String,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    banner['subtitle'] as String,
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
                              banner['icon'] as IconData,
                              size: 48,
                              color: Colors.white.withOpacity(0.4),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // Page indicators
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _banners.length,
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

              const Text(
                'Quick Hub',
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
                childAspectRatio: 1.4,
                children: [
                  _buildGridCard(
                    title: "Today's Cards",
                    icon: Icons.today,
                    badgeCount: _dueCount,
                    badgeColor: AppColors.error,
                    iconColor: AppColors.primary,
                    onTap: () => widget.onTabChange(1),
                  ),
                  _buildGridCard(
                    title: 'Finished Cards',
                    icon: Icons.verified,
                    badgeCount: _finishedCount,
                    badgeColor: const Color(0xFFFFD700),
                    iconColor: const Color(0xFFFFD700),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const FinishedCardsScreen()),
                      ).then((_) => _loadStats());
                    },
                  ),
                  _buildGridCard(
                    title: 'Custom Cards',
                    icon: Icons.add_card,
                    iconColor: AppColors.secondary,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const CustomCardsScreen()),
                      ).then((_) => _loadStats());
                    },
                  ),
                  _buildGridCard(
                    title: 'Favorites',
                    icon: Icons.star,
                    iconColor: AppColors.box2,
                    onTap: _showFavoritesSelectDialog,
                  ),
                  _buildGridCard(
                    title: 'Statistics',
                    icon: Icons.bar_chart,
                    iconColor: AppColors.box3,
                    onTap: _showStatsDialog,
                  ),
                  _buildGridCard(
                    title: 'Settings',
                    icon: Icons.settings,
                    iconColor: AppColors.textSecondary,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SettingsScreen()),
                      ).then((_) {
                        _loadProfile();
                        _loadStats();
                      });
                    },
                  ),
                  _buildGridCard(
                    title: 'Notifications',
                    icon: Icons.notifications,
                    iconColor: AppColors.box4,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                      );
                    },
                  ),
                  _buildGridCard(
                    title: 'Support',
                    icon: Icons.contact_support,
                    iconColor: AppColors.box5,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SupportScreen()),
                      );
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
    required IconData icon,
    int? badgeCount,
    Color? badgeColor,
    required Color iconColor,
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
          padding: const EdgeInsets.all(16.0),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(icon, size: 28, color: iconColor),
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              if (badgeCount != null && badgeCount > 0)
                Positioned(
                  top: 0,
                  right: 0,
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
