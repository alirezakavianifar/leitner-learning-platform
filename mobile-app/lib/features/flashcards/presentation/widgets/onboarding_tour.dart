import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile_app/app/theme.dart';
import 'package:mobile_app/injection_container.dart' as di;

class OnboardingTour extends StatefulWidget {
  final VoidCallback? onComplete;

  const OnboardingTour({Key? key, this.onComplete}) : super(key: key);

  static Future<void> showIfNeeded(BuildContext context, {bool force = false}) async {
    final prefs = di.sl<SharedPreferences>();
    final completed = prefs.getBool('first_run_completed') ?? false;

    if (!completed || force) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogCtx) => OnboardingTour(
          onComplete: () {
            prefs.setBool('first_run_completed', true);
            Navigator.pop(dialogCtx);
          },
        ),
      );
    }
  }

  @override
  State<OnboardingTour> createState() => _OnboardingTourState();
}

class _OnboardingTourState extends State<OnboardingTour> {
  final PageController _pageController = PageController();
  int _currentStep = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentStep < 13) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      if (widget.onComplete != null) widget.onComplete!();
    }
  }

  void _prevPage() {
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        height: 580,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.border, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 20,
              spreadRadius: 5,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: AppColors.background.withOpacity(0.4),
                  border: Border(
                    bottom: BorderSide(color: AppColors.border),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.school, color: AppColors.primary),
                        SizedBox(width: 8),
                        Text(
                          'Guided Tutorial',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '${_currentStep + 1} / 14',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              // Body
              Expanded(
                child: PageView(
                  controller: _pageController,
                  onPageChanged: (idx) {
                    setState(() {
                      _currentStep = idx;
                    });
                  },
                  children: [
                    _buildIntroSlide(),
                    _buildColorGuideSlide(),
                    _buildStepSlide('1. Courses Screen Overview', Icons.library_books,
                        'The main library displays all available learning packages. Downloaded courses appear automatically at the top with a green border so you can identify offline content instantly.'),
                    _buildStepSlide('2. Search Workflow', Icons.search,
                        'Target content easily by first searching the courses catalog, selecting one or more courses, and then typing terms or card numbers to search cards inside those chosen courses. Support is fully typo-tolerant!'),
                    _buildStepSlide('3. Flashcard Interface', Icons.aspect_ratio,
                        'Study sessions utilize a dedicated layout featuring a fixed header for stage indicators, a 3D flip card at the center displaying text, images, or audio controls, and navigation buttons at the footer.'),
                    _buildStepSlide('4. "Know" Button', Icons.check_circle,
                        'Answering correct ("Know") advances the flashcard to the next Leitner Box. Spaced intervals will apply automatically, ensuring active memory training.'),
                    _buildStepSlide('5. "Don\'t Know" Button', Icons.cancel,
                        'Answering incorrect ("Don\'t Know") immediately resets the card to Box 1. Overdue cards that you miss on their scheduled review dates are also returned to Box 1 to reinforce learning.'),
                    _buildStepSlide('6. Create Card Workflow', Icons.add_box,
                        'Create and learn your own custom flashcards. These custom decks are stored strictly locally on your device to ensure maximum privacy.'),
                    _buildStepSlide('7. Finished Cards View', Icons.emoji_events,
                        'Cards successfully mastered and completed from Box 5 transition into the Finished pool. Reviewing them later and clicking "Don\'t Know" resets them back to Box 1, while "Know It" retains finished status.'),
                    _buildStepSlide('8. Favorites Section', Icons.star,
                        'Mark challenging cards as Favorites to study them separately. Note that viewing a card directly inside Favorites resets active box progress to Box 1 after a safety confirmation!'),
                    _buildStepSlide('9. My Courses Screen', Icons.folder_special,
                        'A dedicated learning screen that displays exclusively your purchased and downloaded courses with green offline status indicators.'),
                    _buildStepSlide('10. Flashcard Reports', Icons.report_problem,
                        'Spotted a typo or mistake? Use the report system inside the study footer to submit feedback directly to the backend administration console.'),
                    _buildStepSlide('11. Today\'s Cards', Icons.today,
                        'A dashboard badge indicates the exact count of pending cards scheduled for review today. Stay consistent to prevent overdue progress resets!'),
                    _buildStepSlide('12. Statistics & Charts', Icons.bar_chart,
                        'Track your learning progress using color-coded box distribution status bars, detailing where cards reside in the Leitner progression system.'),
                  ],
                ),
              ),
              // Footer / Actions
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: AppColors.background.withOpacity(0.4),
                  border: Border(
                    top: BorderSide(color: AppColors.border),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: _currentStep > 0 ? _prevPage : null,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                      ),
                      child: const Text('Back'),
                    ),
                    Row(
                      children: List.generate(
                        14,
                        (index) => Container(
                          width: 6,
                          height: 6,
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _currentStep == index
                                ? AppColors.primary
                                : AppColors.textSecondary.withOpacity(0.3),
                          ),
                        ),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: _nextPage,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        _currentStep == 13 ? 'Done' : 'Next',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIntroSlide() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.calendar_month_outlined,
                color: AppColors.primary,
                size: 48,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: Text(
              'Leitner Spaced Repetition',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'The Leitner platform optimizes memory retention by spacing review intervals across 5 distinct boxes:',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          _buildIntervalRow('Box 1', 'Immediate', 'Always available for review', AppColors.box1),
          _buildIntervalRow('Box 2', '3 Days Delay', 'Becomes due 3 days after entering', AppColors.box2),
          _buildIntervalRow('Box 3', '7 Days Delay', 'Becomes due 7 days after entering', AppColors.box3),
          _buildIntervalRow('Box 4', '16 Days Delay', 'Becomes due 16 days after entering', AppColors.box4),
          _buildIntervalRow('Box 5', '31 Days Delay', 'Becomes due 31 days after entering', AppColors.box5),
        ],
      ),
    );
  }

  Widget _buildColorGuideSlide() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.secondary.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.palette_outlined,
                color: AppColors.secondary,
                size: 48,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: Text(
              'Leitner Box Colors',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Throughout the application, cards and progress states are color-coded to indicate their current Leitner Box status:',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          _buildColorRow('Orange', 'Box 1 Indicator', AppColors.box1),
          _buildColorRow('Yellow', 'Box 2 Indicator', AppColors.box2),
          _buildColorRow('Green', 'Box 3 Indicator', AppColors.box3),
          _buildColorRow('Blue', 'Box 4 Indicator', AppColors.box4),
          _buildColorRow('Purple', 'Box 5 Indicator', AppColors.box5),
          _buildColorRow('Gold', 'Finished Cards Indicator', AppColors.finished),
        ],
      ),
    );
  }

  Widget _buildStepSlide(String title, IconData icon, String description) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.primary.withOpacity(0.2)),
            ),
            child: Icon(
              icon,
              color: AppColors.primary,
              size: 64,
            ),
          ),
          const SizedBox(height: 28),
          Text(
            title,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            description,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildIntervalRow(String box, String duration, String info, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.background.withOpacity(0.3),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            box,
            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(width: 8),
          Text('•', style: TextStyle(color: AppColors.textSecondary)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$duration ($info)',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColorRow(String colorName, String desc, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.background.withOpacity(0.3),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(6),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.4),
                  blurRadius: 6,
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                colorName,
                style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
