import 'dart:ui';
import 'package:flutter/material.dart';
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
import 'otp_request_screen.dart';
import 'dashboard_screen.dart';

class HomeHubScreen extends StatefulWidget {
  const HomeHubScreen({Key? key}) : super(key: key);

  @override
  State<HomeHubScreen> createState() => _HomeHubScreenState();
}

class _HomeHubScreenState extends State<HomeHubScreen> {
  int _currentIndex = 0;
  late final List<Widget> _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = [
      DashboardScreen(
        onTabChange: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
      ),
      const ReviewTab(),
      BlocProvider<CoursesBloc>(
        create: (_) => di.sl<CoursesBloc>(),
        child: const CoursesScreen(),
      ),
    ];
    // Auto-trigger onboarding tutorial on first app startup
    WidgetsBinding.instance.addPostFrameCallback((_) {
      OnboardingTour.showIfNeeded(context);
    });
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
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(
            loc.leitnerLearning,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: AppColors.primary,
                ),
          ),
          actions: [
            if (_currentIndex == 2)
              IconButton(
                icon: Icon(Icons.search, color: AppColors.primary),
                tooltip: 'Search',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CourseSearchScreen()),
                  );
                },
              ),
            IconButton(
              icon: Icon(Icons.help_outline, color: AppColors.primary),
              tooltip: 'Tutorial',
              onPressed: () => OnboardingTour.showIfNeeded(context, force: true),
            ),
            IconButton(
              icon: Icon(Icons.logout, color: AppColors.error),
              tooltip: loc.logout,
              onPressed: () => _showLogoutConfirmation(context),
            ),
          ],
        ),
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
    );
  }
}


