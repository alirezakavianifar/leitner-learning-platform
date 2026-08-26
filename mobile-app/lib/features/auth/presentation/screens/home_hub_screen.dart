import 'dart:io';
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
import 'profile_screen.dart';
import 'rules_screen.dart';
import 'about_us_screen.dart';
import 'statistics_screen.dart';
import 'support_screen.dart';
import 'package:mobile_app/features/notifications/presentation/screens/notifications_screen.dart';
import 'package:mobile_app/features/config/presentation/bloc/config_bloc.dart';
import 'package:mobile_app/features/config/presentation/bloc/config_state.dart';
import 'package:mobile_app/core/widgets/app_logo.dart';
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
  final GlobalKey _favoritesKey = GlobalKey();
  final GlobalKey _finishedCardsKey = GlobalKey();
  final GlobalKey _myCoursesKey = GlobalKey();
  final GlobalKey _coursesListKey = GlobalKey();
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

  void _pushGlobal(Widget screen) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  void startInteractiveTour() {
    final loc = AppLocalizations.of(context);
    _tourOverlayEntry?.remove();
    _tourOverlayEntry = OverlayEntry(
      builder: (context) => InteractiveTourOverlay(
        steps: [
          TourStep(
            targetKey: _menuKey,
            title: loc.translate('tour_menu_title'),
            description: loc.translate('tour_menu_desc'),
          ),
          TourStep(
            targetKey: _todayReviewsKey,
            title: loc.translate('tour_today_title'),
            description: loc.translate('tour_today_desc'),
          ),
          TourStep(
            targetKey: _favoritesKey,
            title: loc.translate('tour_favorites_title'),
            description: loc.translate('tour_favorites_desc'),
          ),
          TourStep(
            targetKey: _finishedCardsKey,
            title: loc.translate('tour_finished_title'),
            description: loc.translate('tour_finished_desc'),
          ),
          TourStep(
            targetKey: _myCoursesKey,
            title: loc.translate('tour_my_courses_title'),
            description: loc.translate('tour_my_courses_desc'),
          ),
          TourStep(
            targetKey: _coursesListKey,
            title: loc.translate('tour_catalog_title'),
            description: loc.translate('tour_catalog_desc'),
          ),
          TourStep(
            targetKey: _createCardKey,
            title: loc.translate('tour_create_card_title'),
            description: loc.translate('tour_create_card_desc'),
          ),
          TourStep(
            targetKey: _bottomNavKey,
            title: loc.translate('tour_bottom_nav_title'),
            description: loc.translate('tour_bottom_nav_desc'),
          ),
        ],
        onComplete: () async {
          _tourOverlayEntry?.remove();
          _tourOverlayEntry = null;
          final prefs = di.sl<SharedPreferences>();
          await prefs.setBool('first_run_completed', true);
        },
        onSkip: () async {
          _tourOverlayEntry?.remove();
          _tourOverlayEntry = null;
          final prefs = di.sl<SharedPreferences>();
          await prefs.setBool('first_run_completed', true);
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
            favoritesKey: _favoritesKey,
            finishedCardsKey: _finishedCardsKey,
            myCoursesKey: _myCoursesKey,
            coursesListKey: _coursesListKey,
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
    final configState = context.watch<ConfigBloc>().state;
    final bottomNavIconSize = configState is ConfigLoaded
        ? configState.config.bottomNavIconSize
        : (configState is ConfigMaintenance ? configState.config.bottomNavIconSize : 26.0);
    final appBarIconSize = configState is ConfigLoaded
        ? configState.config.appBarIconSize
        : (configState is ConfigMaintenance ? configState.config.appBarIconSize : 24.0);

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
                        child: Icon(Icons.menu, color: Colors.white, size: (appBarIconSize - 2).clamp(18.0, 32.0)),
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
                        icon: Icon(Icons.search, color: AppColors.primary, size: appBarIconSize),
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
          extendBody: false,
          bottomNavigationBar: Container(
            height: 68,
            decoration: BoxDecoration(
              color: AppColors.background,
              border: Border(
                top: BorderSide(color: AppColors.border, width: 1),
              ),
            ),
            child: BottomNavigationBar(
                  key: _bottomNavKey,
                  currentIndex: _currentIndex,
                  onTap: (index) {
                    if (_currentIndex == index) {
                      final navigator = _getCurrentNavigator();
                      if (navigator != null && navigator.canPop()) {
                        navigator.popUntil((route) => route.isFirst);
                      }
                    } else {
                      setState(() {
                        _currentIndex = index;
                      });
                    }
                  },
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  iconSize: bottomNavIconSize + 2,
                  selectedItemColor: AppColors.primary,
                  unselectedItemColor: AppColors.textSecondary,
                  selectedFontSize: 12,
                  unselectedFontSize: 11,
                  selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
                  items: [
                    BottomNavigationBarItem(
                      icon: Padding(
                        padding: const EdgeInsets.only(bottom: 2.0),
                        child: Icon(Icons.dashboard_outlined, size: bottomNavIconSize),
                      ),
                      activeIcon: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(Icons.dashboard_rounded, size: bottomNavIconSize + 2, color: AppColors.primary),
                      ),
                      label: loc.home,
                    ),
                    BottomNavigationBarItem(
                      icon: Padding(
                        padding: const EdgeInsets.only(bottom: 2.0),
                        child: Icon(Icons.style_outlined, size: bottomNavIconSize),
                      ),
                      activeIcon: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(Icons.style_rounded, size: bottomNavIconSize + 2, color: AppColors.primary),
                      ),
                      label: loc.review,
                    ),
                    BottomNavigationBarItem(
                      icon: Padding(
                        padding: const EdgeInsets.only(bottom: 2.0),
                        child: Icon(Icons.school_outlined, size: bottomNavIconSize),
                      ),
                      activeIcon: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(Icons.school_rounded, size: bottomNavIconSize + 2, color: AppColors.primary),
                      ),
                      label: loc.courses,
                    ),
                  ],
                ),
              ),
        ),
      ),
    );
  }

  void _showHelpSelectionDialog(BuildContext context) {
    final loc = AppLocalizations.of(context);
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
            loc.translate('help_guide_title'),
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
                label: Text(loc.translate('walkthrough_btn')),
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
                label: Text(loc.translate('leitner_btn')),
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
                label: Text(loc.translate('color_guide_btn')),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showLeitnerMethodDialog(BuildContext context) {
    final loc = AppLocalizations.of(context);
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
            loc.translate('leitner_method_title'),
            style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
            textAlign: TextAlign.center,
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  loc.translate('leitner_desc'),
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 13, height: 1.4),
                  textAlign: TextAlign.right,
                ),
                const SizedBox(height: 12),
                _buildLeitnerStep(context, loc.translate('leitner_step_1_title'), loc.translate('leitner_step_1_desc')),
                _buildLeitnerStep(context, loc.translate('leitner_step_2_title'), loc.translate('leitner_step_2_desc')),
                _buildLeitnerStep(context, loc.translate('leitner_step_3_title'), loc.translate('leitner_step_3_desc')),
                _buildLeitnerStep(context, loc.translate('leitner_step_4_title'), loc.translate('leitner_step_4_desc')),
                _buildLeitnerStep(context, loc.translate('leitner_step_5_title'), loc.translate('leitner_step_5_desc')),
                _buildLeitnerStep(context, loc.translate('leitner_step_6_title'), loc.translate('leitner_step_6_desc')),
                const SizedBox(height: 12),
                Text(
                  loc.translate('progress_rules_title'),
                  style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12),
                ),
                Text(
                  loc.translate('progress_rules_desc'),
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.4),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: Text(loc.translate('close_btn')),
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
    final loc = AppLocalizations.of(context);
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
            loc.translate('color_guide_title'),
            style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
            textAlign: TextAlign.center,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildColorStatusRow(loc.box1, AppColors.box1),
              _buildColorStatusRow(loc.box2, AppColors.box2),
              _buildColorStatusRow(loc.box3, AppColors.box3),
              _buildColorStatusRow(loc.box4, AppColors.box4),
              _buildColorStatusRow(loc.box5, AppColors.box5),
              _buildColorStatusRow(loc.finished, AppColors.finished),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: Text(loc.translate('close_btn')),
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
    final rawField = prefs.getString('user_educational_field') ?? 'General';
    final rawLevel = prefs.getString('user_educational_level') ?? 'Student';
    final educationalField = loc.translate(rawField);
    final educationalLevel = loc.translate(rawLevel);
    final avatarPath = prefs.getString('user_avatar_path');
    final avatarImage = avatarPath != null ? FileImage(File(avatarPath)) : null;

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
                  backgroundImage: avatarImage,
                  child: avatarImage == null
                      ? const Icon(Icons.person, size: 32, color: Colors.white)
                      : null,
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
                  icon: Icons.person,
                  iconColor: AppColors.primary,
                  title: loc.profileDetails,
                  onTap: () {
                    Navigator.pop(context); // Close drawer
                    _pushGlobal(const ProfileScreen());
                  },
                ),
                _buildDrawerItem(
                  icon: Icons.bar_chart,
                  iconColor: AppColors.box3,
                  title: loc.statistics,
                  onTap: () {
                    Navigator.pop(context); // Close drawer
                    _pushGlobal(const StatisticsScreen());
                  },
                ),
                _buildDrawerItem(
                  icon: Icons.notifications,
                  iconColor: AppColors.box4,
                  title: loc.notifications,
                  onTap: () {
                    Navigator.pop(context); // Close drawer
                    _pushGlobal(const NotificationsScreen());
                  },
                ),
                _buildDrawerItem(
                  icon: Icons.description,
                  iconColor: AppColors.box2,
                  title: loc.termsConditions,
                  onTap: () {
                    Navigator.pop(context); // Close drawer
                    _pushGlobal(const RulesScreen());
                  },
                ),
                _buildDrawerItem(
                  icon: Icons.info,
                  iconColor: AppColors.secondary,
                  title: loc.aboutUs,
                  onTap: () {
                    Navigator.pop(context); // Close drawer
                    _pushGlobal(const AboutUsScreen());
                  },
                ),
                _buildDrawerItem(
                  icon: Icons.contact_support,
                  iconColor: AppColors.box5,
                  title: loc.support,
                  onTap: () {
                    Navigator.pop(context); // Close drawer
                    _pushGlobal(const SupportScreen());
                  },
                ),
                _buildDrawerItem(
                  icon: Icons.settings,
                  iconColor: AppColors.textSecondary,
                  title: loc.settings,
                  onTap: () {
                    Navigator.pop(context); // Close drawer
                    _pushGlobal(const SettingsScreen());
                  },
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Divider(),
                ),
                _buildDrawerItem(
                  icon: Icons.help_outline,
                  iconColor: AppColors.primary,
                  title: loc.translate('help_guide_title'),
                  onTap: () {
                    Navigator.pop(context); // Close drawer
                    _showHelpSelectionDialog(context);
                  },
                ),
              ],
            ),
          ),

          // App Logo Branding in Drawer
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 4.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const AppLogo(size: 26, showShadow: false),
                const SizedBox(width: 8),
                Text(
                  loc.appTitle,
                  style: TextStyle(
                    color: AppColors.textSecondary.withOpacity(0.7),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
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


