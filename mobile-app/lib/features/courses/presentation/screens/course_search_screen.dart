import 'package:flutter/material.dart';
import 'package:mobile_app/app/theme.dart';
import 'package:mobile_app/core/utils/search_helper.dart';
import 'package:mobile_app/features/courses/domain/entities/course.dart';
import 'package:mobile_app/features/courses/domain/repositories/courses_repository.dart';
import 'package:mobile_app/features/flashcards/domain/entities/flashcard.dart';
import 'package:mobile_app/features/flashcards/domain/repositories/flashcard_repository.dart';
import 'package:mobile_app/features/flashcards/presentation/screens/flashcard_study_screen.dart';
import 'package:mobile_app/injection_container.dart' as di;

class CourseSearchScreen extends StatefulWidget {
  const CourseSearchScreen({super.key});

  @override
  State<CourseSearchScreen> createState() => _CourseSearchScreenState();
}

class _CourseSearchScreenState extends State<CourseSearchScreen> {
  late final CoursesRepository _coursesRepository;
  late final FlashcardRepository _flashcardRepository;

  List<Course> _allCourses = [];
  List<Course> _filteredCourses = [];
  final Set<String> _selectedCourseIds = {};

  // All loaded cards from selected courses
  List<Flashcard> _loadedCards = [];
  List<Flashcard> _filteredCards = [];

  final TextEditingController _courseController = TextEditingController();
  final TextEditingController _cardController = TextEditingController();

  bool _isLoadingCourses = true;
  bool _isLoadingCards = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _coursesRepository = di.sl<CoursesRepository>();
    _flashcardRepository = di.sl<FlashcardRepository>();
    _loadCourses();
  }

  @override
  void dispose() {
    _courseController.dispose();
    _cardController.dispose();
    super.dispose();
  }

  Future<void> _loadCourses() async {
    setState(() {
      _isLoadingCourses = true;
      _errorMessage = null;
    });

    final result = await _coursesRepository.getCourses();
    result.fold(
      (failure) {
        setState(() {
          _isLoadingCourses = false;
          _errorMessage = failure.message;
        });
      },
      (data) {
        // We can only search cards in downloaded courses
        final downloadedCourses = data.$1.where((c) => c.isDownloaded).toList();
        setState(() {
          _allCourses = downloadedCourses;
          _filteredCourses = downloadedCourses;
          _isLoadingCourses = false;
        });
      },
    );
  }

  void _onCourseSearchChanged(String query) {
    setState(() {
      _filteredCourses = _allCourses
          .where((course) => SearchHelper.fuzzyMatch(course.title, query))
          .toList();
    });
  }

  Future<void> _onCourseSelectionChanged(String courseId, bool selected) async {
    setState(() {
      if (selected) {
        _selectedCourseIds.add(courseId);
      } else {
        _selectedCourseIds.remove(courseId);
      }
    });
    await _loadCardsForSelectedCourses();
  }

  Future<void> _loadCardsForSelectedCourses() async {
    setState(() {
      _isLoadingCards = true;
    });

    final List<Flashcard> allSelectedCards = [];
    for (final courseId in _selectedCourseIds) {
      final cards = await _flashcardRepository.getAllCardsForCourse(courseId);
      allSelectedCards.addAll(cards);
    }

    setState(() {
      _loadedCards = allSelectedCards;
      _isLoadingCards = false;
    });
    _onCardSearchChanged(_cardController.text);
  }

  void _onCardSearchChanged(String query) {
    if (query.trim().isEmpty) {
      setState(() {
        _filteredCards = [];
      });
      return;
    }

    setState(() {
      _filteredCards = _loadedCards.where((card) {
        // Match on card number, question text, or answer text
        final matchesNumber = card.cardNumber.toString() == query.trim();
        final matchesText = SearchHelper.fuzzyMatch(card.questionText, query) ||
            SearchHelper.fuzzyMatch(card.answerText, query);
        return matchesNumber || matchesText;
      }).toList();
    });
  }

  void _handleCardTap(Flashcard card) async {
    final currentBox = card.progress.currentBox;

    if (currentBox >= 2 && currentBox <= 5) {
      // Safety confirmation dialog
      final confirm = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogCtx) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: AppColors.border),
          ),
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: AppColors.box1),
              SizedBox(width: 8),
              Text(
                'Safety Confirmation',
                style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Text(
            'Card #${card.cardNumber} is currently in Leitner Box $currentBox. '
            'Viewing it directly will reset its learning progress back to Box 1.\n\n'
            'Do you want to proceed?',
            style: TextStyle(color: AppColors.textSecondary, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx, false),
              child: Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
              onPressed: () => Navigator.pop(dialogCtx, true),
              child: const Text('Reset & Open', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );

      if (confirm == true) {
        // Reset card progress
        await _flashcardRepository.resetCardProgress(
          courseId: card.courseId,
          cardNumber: card.cardNumber,
          reason: 'JUMP',
        );
        _navigateToStudyScreen(card);
      }
    } else {
      _navigateToStudyScreen(card);
    }
  }

  void _navigateToStudyScreen(Flashcard card) {
    final course = _allCourses.firstWhere((c) => c.id == card.courseId);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FlashcardStudyScreen(
          courseId: card.courseId,
          courseTitle: course.title,
          initialCardNumber: card.cardNumber,
        ),
      ),
    ).then((_) {
      // Refresh status after return
      _loadCardsForSelectedCourses();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Typo-Tolerant Search',
          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
        ),
      ),
      body: _isLoadingCourses
          ? Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Text(_errorMessage!, style: TextStyle(color: AppColors.error)),
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 12),
                      Text(
                        'Step 1: Select Courses',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Course Search input
                      TextField(
                        controller: _courseController,
                        onChanged: _onCourseSearchChanged,
                        decoration: InputDecoration(
                          hintText: 'جستجو در عنوان دوره ها',
                          prefixIcon: Icon(Icons.library_books, color: AppColors.textSecondary),
                          suffixIcon: _courseController.text.isNotEmpty
                              ? IconButton(
                                  icon: Icon(Icons.clear, color: AppColors.textSecondary),
                                  onPressed: () {
                                    _courseController.clear();
                                    _onCourseSearchChanged('');
                                  },
                                )
                              : null,
                        ),
                        style: TextStyle(color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 12),
                      // Matching courses list with checkboxes
                      SizedBox(
                        height: 90,
                        child: _filteredCourses.isEmpty
                            ? Center(
                                child: Text(
                                  'No downloaded courses found.',
                                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                                ),
                              )
                            : ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: _filteredCourses.length,
                                itemBuilder: (context, index) {
                                  final course = _filteredCourses[index];
                                  final isSelected = _selectedCourseIds.contains(course.id);

                                  return GestureDetector(
                                    onLongPress: () => _onCourseSelectionChanged(course.id, !isSelected),
                                    child: Container(
                                      margin: const EdgeInsets.only(right: 12, top: 4, bottom: 8),
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? AppColors.primary.withOpacity(0.15)
                                            : AppColors.surface,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: isSelected ? AppColors.primary : AppColors.border,
                                          width: 1.5,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            isSelected ? Icons.check_circle : Icons.radio_button_off,
                                            color: isSelected ? AppColors.primary : AppColors.textSecondary,
                                            size: 18,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            course.title,
                                            style: TextStyle(
                                              color: isSelected ? AppColors.primary : AppColors.textPrimary,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Step 2: Search Cards Inside Selection',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Card Search input
                      TextField(
                        controller: _cardController,
                        onChanged: _onCardSearchChanged,
                        enabled: _selectedCourseIds.isNotEmpty,
                        decoration: InputDecoration(
                          hintText: _selectedCourseIds.isEmpty
                              ? 'Please select one or more courses first'
                              : 'Search card contents or numbers...',
                          prefixIcon: Icon(Icons.search, color: AppColors.textSecondary),
                          suffixIcon: _cardController.text.isNotEmpty
                              ? IconButton(
                                  icon: Icon(Icons.clear, color: AppColors.textSecondary),
                                  onPressed: () {
                                    _cardController.clear();
                                    _onCardSearchChanged('');
                                  },
                                )
                              : null,
                        ),
                        style: TextStyle(color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 16),
                      // Card Results List
                      Expanded(
                        child: _isLoadingCards
                            ? Center(child: CircularProgressIndicator(color: AppColors.primary))
                            : _selectedCourseIds.isEmpty
                                ? Center(
                                    child: Text(
                                      'Select courses above to begin searching.',
                                      style: TextStyle(color: AppColors.textSecondary),
                                    ),
                                  )
                                : _cardController.text.trim().isEmpty
                                    ? Center(
                                        child: Text(
                                          'Type keywords or card number to show results.',
                                          style: TextStyle(color: AppColors.textSecondary),
                                        ),
                                      )
                                    : _filteredCards.isEmpty
                                        ? Center(
                                            child: Text(
                                              'No matching cards found.',
                                              style: TextStyle(color: AppColors.textSecondary),
                                            ),
                                          )
                                        : ListView.builder(
                                            itemCount: _filteredCards.length,
                                            itemBuilder: (context, index) {
                                              final card = _filteredCards[index];
                                              final course = _allCourses.firstWhere((c) => c.id == card.courseId);

                                              // Highlight card box status
                                              Color statusColor = AppColors.box1;
                                              if (card.progress.currentBox == 2) statusColor = AppColors.box2;
                                              if (card.progress.currentBox == 3) statusColor = AppColors.box3;
                                              if (card.progress.currentBox == 4) statusColor = AppColors.box4;
                                              if (card.progress.currentBox == 5) statusColor = AppColors.box5;
                                              if (card.progress.currentBox == 6) statusColor = AppColors.finished;

                                              return Card(
                                                margin: const EdgeInsets.only(bottom: 12),
                                                color: AppColors.surface.withOpacity(0.6),
                                                child: ListTile(
                                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                                  title: Row(
                                                    children: [
                                                      Text(
                                                        'Card #${card.cardNumber}',
                                                        style: TextStyle(
                                                          color: AppColors.textPrimary,
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 12),
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                        decoration: BoxDecoration(
                                                          color: statusColor.withOpacity(0.15),
                                                          borderRadius: BorderRadius.circular(4),
                                                          border: Border.all(color: statusColor.withOpacity(0.4)),
                                                        ),
                                                        child: Text(
                                                          card.progress.currentBox == 6 ? 'Finished' : 'Box ${card.progress.currentBox}',
                                                          style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  subtitle: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      const SizedBox(height: 6),
                                                      Text(
                                                        card.questionText,
                                                        maxLines: 2,
                                                        overflow: TextOverflow.ellipsis,
                                                        style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                                                      ),
                                                      const SizedBox(height: 4),
                                                      Text(
                                                        'Course: ${course.title}',
                                                        style: TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w600),
                                                      ),
                                                    ],
                                                  ),
                                                  trailing: Icon(Directionality.of(context) == TextDirection.rtl ? Icons.arrow_back_ios : Icons.arrow_forward_ios, size: 16, color: AppColors.primary),
                                                  onTap: () => _handleCardTap(card),
                                                ),
                                              );
                                            },
                                          ),
                      ),
                    ],
                  ),
                ),
    );
  }
}
