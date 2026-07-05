import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile_app/app/theme.dart';
import 'package:mobile_app/core/localization/app_localizations.dart';
import 'package:mobile_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:mobile_app/features/auth/presentation/bloc/auth_event.dart';
import 'package:mobile_app/features/auth/presentation/bloc/auth_state.dart';
import 'package:mobile_app/features/courses/presentation/bloc/courses_bloc.dart';
import 'package:mobile_app/features/courses/presentation/screens/courses_screen.dart';
import 'package:mobile_app/features/flashcards/presentation/widgets/review_tab.dart';
import 'package:mobile_app/features/flashcards/presentation/widgets/onboarding_tour.dart';
import 'package:mobile_app/injection_container.dart' as di;
import 'package:mobile_app/features/courses/presentation/screens/course_search_screen.dart';
import 'package:mobile_app/features/flashcards/presentation/widgets/interactive_tour_overlay.dart';
import 'otp_request_screen.dart';
import 'dashboard_screen.dart';
import 'settings_screen.dart';
import 'statistics_screen.dart';
import 'support_screen.dart';
import 'package:mobile_app/features/notifications/presentation/screens/notifications_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomeHubScreen extends StatefulWidget {
  const HomeHubScreen({Key? key}) : super(key: key);

  @override
  State<HomeHubScreen> createState() => HomeHubScreenState();
}

class HomeHubScreenState extends State<HomeHubScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _currentIndex = 0;
  late final List<Widget> _tabs;

  final GlobalKey<NavigatorState> _dashboardNavigatorKey = GlobalKey<NavigatorState>();
  final GlobalKey<NavigatorState> _reviewNavigatorKey = GlobalKey<NavigatorState>();
  final GlobalKey<NavigatorState> _coursesNavigatorKey = GlobalKey<NavigatorState>();

  final ValueNotifier<int> _coursesTabNotifier = ValueNotifier<int>(0);

  final GlobalKey _menuKey = GlobalKey();
  final GlobalKey _bottomNavKey = GlobalKey();
  final GlobalKey _todayReviewsKey = GlobalKey();
  final GlobalKey _myCoursesKey = GlobalKey();
  final GlobalKey _createCardKey = GlobalKey();

  OverlayEntry? _tourOverlayEntry;

  late final List<NavigatorObserver> _observers;

  NavigatorState? _getCurrentNavigator() {
    switch (_currentIndex) {
      case 0:
        return _dashboardNavigatorKey.currentState;
      case 1:
        return _reviewNavigatorKey.currentState;
      case 2:
        return _coursesNavigatorKey.currentState;
      default:
        return null;
    }
  }

  bool _shouldShowRootAppBar() {
    final navigator = _getCurrentNavigator();
    if (navigator == null) return true;
    return !navigator.canPop();
  }

  void _pushNested(Widget screen) {
    final navigator = _getCurrentNavigator();
    if (navigator != null) {
      navigator.push(
        MaterialPageRoute(builder: (_) => screen),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => screen),
      );
    }
  }

  void startInteractiveTour() {
    _tourOverlayEntry?.remove();
    _tourOverlayEntry = OverlayEntry(
      builder: (context) => InteractiveTourOverlay(
        steps: [
          TourStep(
            targetKey: _menuKey,
            title: 'Sidebar Menu',
            description: 'Tap this purple button to access settings, statistics, notifications, and support guides.',
          ),
          TourStep(
            targetKey: _todayReviewsKey,
            title: 'Today\'s Cards',
            description: 'Check how many cards are scheduled for review today. Reviewing consistently prevents cards from resetting back to Box 1!',
          ),
          TourStep(
            targetKey: _myCoursesKey,
            title: 'My Courses',
            description: 'Tap here to see exclusively your purchased and downloaded offline course packages.',
          ),
          TourStep(
            targetKey: _createCardKey,
            title: 'Create Custom Card',
            description: 'Create your own custom flashcards and manage custom decks. Decks are stored 100% locally on your device for absolute privacy.',
          ),
          TourStep(
            targetKey: _bottomNavKey,
            title: 'Bottom Navigation Bar',
            description: 'Use the persistent bottom navigation bar to switch between the Home Dashboard, Review lists, and the Courses Catalog quickly from any screen.',
          ),
        ],
        onComplete: () {
          _tourOverlayEntry?.remove();
          _tourOverlayEntry = null;
          final prefs = di.sl<SharedPreferences>();
          prefs.setBool('first_run_completed', true);
        },
        onSkip: () {
          _tourOverlayEntry?.remove();
          _tourOverlayEntry = null;
          final prefs = di.sl<SharedPreferences>();
          prefs.setBool('first_run_completed', true);
        },
      ),
    );

    Overlay.of(context).insert(_tourOverlayEntry!);
  }

  @override
  void initState() {
    super.initState();
    
    _observers = [
      _NestedNavigatorObserver(() {
        if (mounted) setState(() {});
      }),
      _NestedNavigatorObserver(() {
        if (mounted) setState(() {});
      }),
      _NestedNavigatorObserver(() {
        if (mounted) setState(() {});
      }),
    ];

    _tabs = [
      Navigator(
        key: _dashboardNavigatorKey,
        observers: [_observers[0]],
        onGenerateRoute: (settings) => MaterialPageRoute(
          builder: (context) => DashboardScreen(
            onTabChange: (index) {
              if (mounted) {
                setState(() {
                  _currentIndex = index;
                });
              }
            },
            coursesTabNotifier: _coursesTabNotifier,
            todayReviewsKey: _todayReviewsKey,
            myCoursesKey: _myCoursesKey,
            createCardKey: _createCardKey,
          ),
        ),
      ),
      Navigator(
        key: _reviewNavigatorKey,
        observers: [_observers[1]],
        onGenerateRoute: (settings) => MaterialPageRoute(
          builder: (context) => const ReviewTab(),
        ),
      ),
      Navigator(
        key: _coursesNavigatorKey,
        observers: [_observers[2]],
        onGenerateRoute: (settings) => MaterialPageRoute(
          builder: (context) => BlocProvider<CoursesBloc>(
            create: (_) => di.sl<CoursesBloc>(),
            child: CoursesScreen(tabNotifier: _coursesTabNotifier),
          ),
        ),
      ),
    ];

    // Auto-trigger onboarding tutorial on first app startup
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final prefs = di.sl<SharedPreferences>();
      final completed = prefs.getBool('first_run_completed') ?? false;
      if (!completed) {
        await Future.delayed(const Duration(milliseconds: 600));
        if (mounted) {
          startInteractiveTour();
        }
      }
    });
  }

  @override
  void dispose() {
    _tourOverlayEntry?.remove();
    _coursesTabNotifier.dispose();
    super.dispose();
  }

  void _showLogoutConfirmation(BuildContext context) {
    final loc = AppLocalizations.of(context);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: AppColors.border),
          ),
          title: Text(
            loc.logout,
            style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
          ),
          content: Text(
            loc.logoutConfirm,
            style: TextStyle(color: AppColors.textSecondary, height: 1.4),
          ),
          actions: [
            TextButton(
              style: TextButton.styleFrom(
                backgroundColor: const Color(0xFF333E56).withOpacity(0.4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () => Navigator.pop(dialogContext),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Text(loc.cancel, style: TextStyle(color: AppColors.textPrimary)),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () {
                Navigator.pop(dialogContext); // Close modal
                context.read<AuthBloc>().add(LogoutEvent()); // Trigger logout
              },
              child: Text(loc.confirm, style: const TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);

    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is UnauthenticatedState) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const OtpRequestScreen()),
            (route) => false,
          );
        }
      },
      child: PopScope(
        canPop: false,
        onPopInvoked: (didPop) async {
          if (didPop) return;
          final navigator = _getCurrentNavigator();
          if (navigator != null) {
            final handled = await navigator.maybePop();
            if (handled) return;
          }
          if (_currentIndex != 0) {
            setState(() {
              _currentIndex = 0;
            });
          } else {
            // Minimize or pop from platform system navigator
            await SystemChannels.platform.invokeMethod('SystemNavigator.pop');
          }
        },
        child: Scaffold(
          key: _scaffoldKey,
          drawer: _buildDrawer(context),
          appBar: _shouldShowRootAppBar()
              ? AppBar(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  automaticallyImplyLeading: false,
                  leadingWidth: 68,
                  leading: Padding(
                    padding: const EdgeInsetsDirectional.only(start: 16.0, top: 8.0, bottom: 8.0),
                    child: InkWell(
                      key: _menuKey,
                      onTap: () => _scaffoldKey.currentState?.openDrawer(),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.menu, color: Colors.white, size: 22),
                      ),
                    ),
                  ),
                  title: Text(
                    _currentIndex == 0
                        ? loc.home
                        : _currentIndex == 1
                            ? loc.review
                            : loc.courses,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  actions: [
                    if (_currentIndex == 2)
                      IconButton(
                        icon: Icon(Icons.search, color: AppColors.primary),
                        tooltip: 'Search',
                        onPressed: () {
                          _pushNested(const CourseSearchScreen());
                        },
                      ),
                  ],
                )
              : null,
          body: IndexedStack(
            index: _currentIndex,
            children: _tabs,
          ),
          extendBody: true, // Enables transparent/blur bottom navigation styling
          bottomNavigationBar: ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16.0, sigmaY: 16.0),
              child: Container(
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.background.withOpacity(0.8),
                  border: Border(
                    top: BorderSide(color: AppColors.border, width: 1),
                  ),
                ),
                child: BottomNavigationBar(
                  key: _bottomNavKey,
                  currentIndex: _currentIndex,
                  onTap: (index) {
                    setState(() {
                      _currentIndex = index;
                    });
                  },
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  selectedItemColor: AppColors.primary,
                  unselectedItemColor: AppColors.textSecondary,
                  items: [
                    BottomNavigationBarItem(
                      icon: const Icon(Icons.home_outlined),
                      activeIcon: const Icon(Icons.home),
                      label: loc.home,
                    ),
                    BottomNavigationBarItem(
                      icon: const Icon(Icons.rate_review_outlined),
                      activeIcon: const Icon(Icons.rate_review),
                      label: loc.review,
                    ),
                    BottomNavigationBarItem(
                      icon: const Icon(Icons.library_books_outlined),
                      activeIcon: const Icon(Icons.library_books),
                      label: loc.courses,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showHelpSelectionDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: AppColors.border),
          ),
          title: Text(
            'راهنمای برنامه (Help Guide)',
            style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
            textAlign: TextAlign.center,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Button 1: Walkthrough Guide
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  Navigator.pop(dialogCtx);
                  OnboardingTour.showIfNeeded(context, force: true);
                },
                icon: const Icon(Icons.school),
                label: const Text('آموزش ابتدای برنامه (Walkthrough)'),
              ),
              const SizedBox(height: 12),
              // Button 2: Leitner Method
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.secondary,
                  foregroundColor: AppColors.background,
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  Navigator.pop(dialogCtx);
                  _showLeitnerMethodDialog(context);
                },
                icon: const Icon(Icons.explore),
                label: const Text('آموزش روش لایتنر (Leitner Method)'),
              ),
              const SizedBox(height: 12),
              // Button 3: Color Status
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueGrey,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  Navigator.pop(dialogCtx);
                  _showColorStatusDialog(context);
                },
                icon: const Icon(Icons.palette),
                label: const Text('راهنمای رنگ‌ها (Color Status Guide)'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showLeitnerMethodDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: AppColors.border),
          ),
          title: Text(
            'روش جعبه لایتنر (Leitner Method)',
            style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
            textAlign: TextAlign.center,
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'روش لایتنر یک روش علمی برای انتقال اطلاعات به حافظه بلندمدت بر اساس فواصل مرور است:',
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 13, height: 1.4),
                  textAlign: TextAlign.right,
                ),
                const SizedBox(height: 12),
                _buildLeitnerStep(context, 'خانه اول (Box 1)', 'کارت های جدید و اشتباه شده. مرور روزانه.'),
                _buildLeitnerStep(context, 'خانه دوم (Box 2)', 'کارت هایی که بلد بودید. مرور هر ۲ روز.'),
                _buildLeitnerStep(context, 'خانه سوم (Box 3)', 'کارت های تایید شده قبلی. مرور هر ۴ روز.'),
                _buildLeitnerStep(context, 'خانه چهارم (Box 4)', 'مرور هر ۸ روز.'),
                _buildLeitnerStep(context, 'خانه پنجم (Box 5)', 'مرور هر ۱۶ روز.'),
                _buildLeitnerStep(context, 'خانه ششم (Finished)', 'اتمام یادگیری کارت و آرشیو شدن آن.'),
                const SizedBox(height: 12),
                Text(
                  'قوانین پیشرفت:',
                  style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12),
                ),
                Text(
                  '- پاسخ صحیح (بلدم): کارت یک خانه به جلو میرود.\n- پاسخ غلط (بلد نیستم): کارت بلافاصله به خانه اول (Box 1) برمی‌گردد و تمام مراحل از اول آغاز می‌شود.',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.4),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('بستن (Close)'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildLeitnerStep(BuildContext context, String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12)),
          Text(desc, style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        ],
      ),
    );
  }

  void _showColorStatusDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: AppColors.border),
          ),
          title: Text(
            'راهنمای رنگ وضعیت خانه‌ها (Color Guide)',
            style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
            textAlign: TextAlign.center,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildColorStatusRow('خانه اول (Box 1)', AppColors.box1),
              _buildColorStatusRow('خانه دوم (Box 2)', AppColors.box2),
              _buildColorStatusRow('خانه سوم (Box 3)', AppColors.box3),
              _buildColorStatusRow('خانه چهارم (Box 4)', AppColors.box4),
              _buildColorStatusRow('خانه پنجم (Box 5)', AppColors.box5),
              _buildColorStatusRow('کارت‌های تمام شده (Finished)', AppColors.finished),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('بستن (Close)'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildColorStatusRow(String label, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white24),
            ),
          ),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(color: AppColors.textPrimary, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final prefs = di.sl<SharedPreferences>();
    final username = prefs.getString('user_username') ?? 'User';
    final educationalField = prefs.getString('user_educational_field') ?? 'General';
    final educationalLevel = prefs.getString('user_educational_level') ?? 'Learner';

    return Drawer(
      backgroundColor: AppColors.background,
      child: Column(
        children: [
          // Drawer Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.only(top: 60, bottom: 24, left: 20, right: 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.primary.withOpacity(0.7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.white.withOpacity(0.2),
                  child: const Icon(Icons.person, size: 32, color: Colors.white),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        username,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$educationalField • $educationalLevel',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Drawer items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _buildDrawerItem(
                  icon: Icons.bar_chart,
                  iconColor: AppColors.box3,
                  title: loc.statistics,
                  onTap: () {
                    Navigator.pop(context); // Close drawer
                    _pushNested(const StatisticsScreen());
                  },
                ),
                _buildDrawerItem(
                  icon: Icons.notifications,
                  iconColor: AppColors.box4,
                  title: loc.notifications,
                  onTap: () {
                    Navigator.pop(context); // Close drawer
                    _pushNested(const NotificationsScreen());
                  },
                ),
                _buildDrawerItem(
                  icon: Icons.contact_support,
                  iconColor: AppColors.box5,
                  title: loc.support,
                  onTap: () {
                    Navigator.pop(context); // Close drawer
                    _pushNested(const SupportScreen());
                  },
                ),
                _buildDrawerItem(
                  icon: Icons.settings,
                  iconColor: AppColors.textSecondary,
                  title: loc.settings,
                  onTap: () {
                    Navigator.pop(context); // Close drawer
                    _pushNested(const SettingsScreen());
                  },
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Divider(),
                ),
                _buildDrawerItem(
                  icon: Icons.help_outline,
                  iconColor: AppColors.primary,
                  title: 'راهنمای برنامه (Help Guide)',
                  onTap: () {
                    Navigator.pop(context); // Close drawer
                    _showHelpSelectionDialog(context);
                  },
                ),
              ],
            ),
          ),

          // Logout button at bottom
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: _buildDrawerItem(
              icon: Icons.logout,
              iconColor: AppColors.error,
              title: loc.logout,
              onTap: () {
                Navigator.pop(context); // Close drawer
                _showLogoutConfirmation(context);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: iconColor),
      title: Text(
        title,
        style: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      trailing: Icon(Icons.chevron_right, color: AppColors.border, size: 18),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      onTap: onTap,
    );
  }
}

class _NestedNavigatorObserver extends NavigatorObserver {
  final VoidCallback onRouteChanged;
  _NestedNavigatorObserver(this.onRouteChanged);

  @override
  void didPush(Route route, Route? previousRoute) {
    super.didPush(route, previousRoute);
    WidgetsBinding.instance.addPostFrameCallback((_) => onRouteChanged());
  }

  @override
  void didPop(Route route, Route? previousRoute) {
    super.didPop(route, previousRoute);
    WidgetsBinding.instance.addPostFrameCallback((_) => onRouteChanged());
  }
}


