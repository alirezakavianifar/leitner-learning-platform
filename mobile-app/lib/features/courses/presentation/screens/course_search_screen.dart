import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:mobile_app/app/theme.dart';
import 'package:mobile_app/core/utils/search_helper.dart';
import 'package:mobile_app/features/courses/domain/entities/course.dart';
import 'package:mobile_app/features/courses/domain/repositories/courses_repository.dart';
import 'package:mobile_app/features/flashcards/domain/entities/flashcard.dart';
import 'package:mobile_app/features/flashcards/domain/repositories/flashcard_repository.dart';
import 'package:mobile_app/features/flashcards/presentation/screens/flashcard_study_screen.dart';
import 'package:mobile_app/injection_container.dart' as di;
import 'package:mobile_app/core/localization/app_localizations.dart';

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
        // We can only search cards in purchased & downloaded courses
        final downloadedCourses = data.$1.where((c) => (c.isPurchased && c.isDownloaded) || (kIsWeb && c.isPurchased)).toList();
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

  void _handleCardTap(Flashcard card) {
    _navigateToStudyScreen(card);
  }

  void _navigateToStudyScreen(Flashcard card) {
    final course = _allCourses.firstWhere((c) => c.id == card.courseId);
    FlashcardStudyScreen.open(
      context,
      courseId: card.courseId,
      courseTitle: course.title,
      initialCardNumber: card.cardNumber,
    ).then((_) {
      // Refresh status after return
      _loadCardsForSelectedCourses();
    });
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final isFa = Localizations.localeOf(context).languageCode == 'fa';
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
          loc.translate('typo_search_title'),
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
                        loc.translate('step_select_courses'),
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
                                  loc.translate('no_downloaded_courses_found'),
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
                                    onTap: () => _onCourseSelectionChanged(course.id, !isSelected),
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
                                            textDirection: RegExp(r'[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB50-\uFDFF\uFE70-\uFEFF]').hasMatch(course.title)
                                                ? TextDirection.rtl
                                                : TextDirection.ltr,
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
                        loc.translate('step_search_cards'),
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
                              ? loc.translate('select_courses_first')
                              : loc.translate('search_cards_hint'),
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
                                      loc.translate('select_courses_begin'),
                                      style: TextStyle(color: AppColors.textSecondary),
                                    ),
                                  )
                                : _cardController.text.trim().isEmpty
                                    ? Center(
                                        child: Text(
                                          loc.translate('type_to_search'),
                                          style: TextStyle(color: AppColors.textSecondary),
                                        ),
                                      )
                                    : _filteredCards.isEmpty
                                        ? Center(
                                            child: Text(
                                              loc.translate('no_matching_cards'),
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
                                              if (card.progress.currentBox == 6) statusColor = AppColors.box6;
                                              if (card.progress.currentBox == 7) statusColor = AppColors.finished;

                                              return Card(
                                                margin: const EdgeInsets.only(bottom: 12),
                                                color: AppColors.surface.withOpacity(0.6),
                                                child: ListTile(
                                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                                  title: Row(
                                                    children: [
                                                      Text(
                                                        isFa ? 'کارت شماره ${card.cardNumber}' : 'Card #${card.cardNumber}',
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
                                                          card.progress.currentBox == 7 ? loc.translate('finished_box') : '${loc.translate('box_label_prefix')}${card.progress.currentBox}',
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
                                                        '${loc.translate('course_label_prefix')}${course.title}',
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
