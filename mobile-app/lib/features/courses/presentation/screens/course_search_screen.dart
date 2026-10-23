import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:mobile_app/app/theme.dart';
import 'package:mobile_app/core/localization/app_localizations.dart';
import 'package:mobile_app/core/utils/bidi_utils.dart';
import 'package:mobile_app/core/utils/image_url_resolver.dart';
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

  int _activeTabIndex = 0; // 0: Courses, 1: Flashcards

  // All catalog & purchased courses
  List<Course> _allPlatformCourses = [];
  List<Course> _filteredCourses = [];
  List<Course> _downloadedCourses = [];

  // Card search state
  String? _selectedCourseFilterId; // null = all downloaded courses
  List<Flashcard> _allLoadedCards = [];
  List<Flashcard> _filteredCards = [];

  final TextEditingController _courseSearchController = TextEditingController();
  final TextEditingController _cardSearchController = TextEditingController();

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
    _courseSearchController.dispose();
    _cardSearchController.dispose();
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
        if (!mounted) return;
        setState(() {
          _isLoadingCourses = false;
          _errorMessage = failure.message;
        });
      },
      (data) {
        if (!mounted) return;
        final allCourses = data.$1;
        final downloaded = allCourses
            .where((c) => (c.isPurchased && c.isDownloaded) || (kIsWeb && c.isPurchased))
            .toList();

        setState(() {
          _allPlatformCourses = allCourses;
          _filteredCourses = allCourses;
          _downloadedCourses = downloaded;
          _isLoadingCourses = false;
        });

        // Preload cards from all downloaded courses in background
        _loadAllDownloadedCards();
      },
    );
  }

  Future<void> _loadAllDownloadedCards() async {
    if (_downloadedCourses.isEmpty) {
      if (mounted) {
        setState(() {
          _allLoadedCards = [];
          _filteredCards = [];
          _isLoadingCards = false;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isLoadingCards = true;
      });
    }

    final List<Flashcard> cards = [];
    for (final course in _downloadedCourses) {
      final courseCards = await _flashcardRepository.getAllCardsForCourse(course.id);
      cards.addAll(courseCards);
    }

    if (mounted) {
      setState(() {
        _allLoadedCards = cards;
        _isLoadingCards = false;
      });
      _onCardSearchChanged(_cardSearchController.text);
    }
  }

  void _onCourseSearchChanged(String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _filteredCourses = _allPlatformCourses;
      });
      return;
    }

    setState(() {
      _filteredCourses = _allPlatformCourses.where((course) {
        final titleMatch = SearchHelper.fuzzyMatch(course.title, trimmed);
        final descMatch = course.description != null &&
            SearchHelper.fuzzyMatch(course.description!, trimmed);
        return titleMatch || descMatch;
      }).toList();
    });
  }

  void _onCardSearchChanged(String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _filteredCards = [];
      });
      return;
    }

    List<Flashcard> sourceCards = _allLoadedCards;
    if (_selectedCourseFilterId != null) {
      sourceCards = sourceCards.where((c) => c.courseId == _selectedCourseFilterId).toList();
    }

    setState(() {
      _filteredCards = sourceCards.where((card) {
        final matchesNumber = card.cardNumber.toString() == trimmed;
        final matchesQuestion = SearchHelper.fuzzyMatch(card.questionText, trimmed);
        final matchesAnswer = SearchHelper.fuzzyMatch(card.answerText, trimmed);
        return matchesNumber || matchesQuestion || matchesAnswer;
      }).toList();
    });
  }

  void _onCourseFilterChipSelected(String? courseId) {
    setState(() {
      _selectedCourseFilterId = courseId;
    });
    _onCardSearchChanged(_cardSearchController.text);
  }

  void _navigateToCardStudyScreen(Flashcard card) {
    Course? course;
    try {
      course = _allPlatformCourses.firstWhere((c) => c.id == card.courseId);
    } catch (_) {
      course = null;
    }
    final courseTitle = course?.title ?? '';

    FlashcardStudyScreen.open(
      context,
      courseId: card.courseId,
      courseTitle: courseTitle,
      initialCardNumber: card.cardNumber,
    ).then((_) {
      _loadAllDownloadedCards();
    });
  }

  String _formatPrice(BuildContext context, double price) {
    if (price == 0) {
      return AppLocalizations.of(context).free;
    }
    final formattedNumber = price.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
    return '$formattedNumber ${AppLocalizations.of(context).toman}';
  }

  void _showCourseDetailsSheet(Course course) {
    final loc = AppLocalizations.of(context);
    final isDownloaded = (course.isPurchased && course.isDownloaded) || (kIsWeb && course.isPurchased);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.85,
          ),
          child: SingleChildScrollView(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      course.title,
                      textDirection: detectTextDirection(course.title),
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDownloaded
                          ? AppColors.courseDownloaded.withOpacity(0.15)
                          : (course.isPurchased
                              ? AppColors.primary.withOpacity(0.15)
                              : Colors.amber.withOpacity(0.15)),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isDownloaded
                            ? AppColors.courseDownloaded
                            : (course.isPurchased ? AppColors.primary : Colors.amber),
                      ),
                    ),
                    child: Text(
                      isDownloaded
                          ? loc.readyToStudy
                          : (course.isPurchased
                              ? loc.myCourses
                              : _formatPrice(context, course.price)),
                      style: TextStyle(
                        color: isDownloaded
                            ? AppColors.courseDownloaded
                            : (course.isPurchased ? AppColors.primary : Colors.amber),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.style_outlined, size: 16, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        '${course.cardCount} ${loc.translate('cards_unit')}',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                      ),
                    ],
                  ),
                  if (course.category != null && course.category!.isNotEmpty)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.category_outlined, size: 16, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          loc.translate(course.category!),
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                        ),
                      ],
                    ),
                ],
              ),
              if (course.description != null && course.description!.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(
                  loc.translate('description'),
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  course.description!,
                  textDirection: detectTextDirection(course.description!),
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.5),
                ),
              ],
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  if (isDownloaded) {
                    FlashcardStudyScreen.open(
                      context,
                      courseId: course.id,
                      courseTitle: course.title,
                    );
                  } else {
                    Navigator.pop(context);
                  }
                },
                child: Text(
                  isDownloaded
                      ? loc.startStudy
                      : (course.isPurchased
                          ? loc.myCourses
                          : loc.translate('explore_catalog')),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

  Widget _buildTabSelector(AppLocalizations loc) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacity(0.85),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _activeTabIndex = 0),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                decoration: BoxDecoration(
                  color: _activeTabIndex == 0 ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: _activeTabIndex == 0
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.3),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : [],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.school_outlined,
                      size: 18,
                      color: _activeTabIndex == 0 ? Colors.white : AppColors.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      loc.translate('search_courses_tab'),
                      style: TextStyle(
                        color: _activeTabIndex == 0 ? Colors.white : AppColors.textSecondary,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _activeTabIndex = 1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                decoration: BoxDecoration(
                  color: _activeTabIndex == 1 ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: _activeTabIndex == 1
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.3),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : [],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.style_outlined,
                      size: 18,
                      color: _activeTabIndex == 1 ? Colors.white : AppColors.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      loc.translate('search_cards_tab'),
                      style: TextStyle(
                        color: _activeTabIndex == 1 ? Colors.white : AppColors.textSecondary,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoursesSearchTab(AppLocalizations loc) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.surface.withOpacity(0.9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: TextField(
              controller: _courseSearchController,
              onChanged: _onCourseSearchChanged,
              style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
              decoration: InputDecoration(
                hintText: loc.translate('search_courses_catalog_hint'),
                hintStyle: TextStyle(color: AppColors.textSecondary.withOpacity(0.7), fontSize: 13),
                prefixIcon: Icon(Icons.search, size: 20, color: AppColors.primary),
                suffixIcon: _courseSearchController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear, size: 18, color: AppColors.textSecondary),
                        onPressed: () {
                          _courseSearchController.clear();
                          _onCourseSearchChanged('');
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                border: InputBorder.none,
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: _filteredCourses.isEmpty
              ? Center(
                  child: Text(
                    loc.translate('no_courses_found_for_query'),
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: _filteredCourses.length,
                  itemBuilder: (context, index) {
                    final course = _filteredCourses[index];
                    final isDownloaded = (course.isPurchased && course.isDownloaded) || (kIsWeb && course.isPurchased);

                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      color: AppColors.surface.withOpacity(0.8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: AppColors.border.withOpacity(0.6)),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: isDownloaded
                                ? AppColors.courseDownloaded.withOpacity(0.15)
                                : AppColors.primary.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            isDownloaded ? Icons.folder_special : Icons.menu_book_rounded,
                            color: isDownloaded ? AppColors.courseDownloaded : AppColors.primary,
                            size: 22,
                          ),
                        ),
                        title: Text(
                          course.title,
                          textDirection: detectTextDirection(course.title),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Row(
                            children: [
                              Text(
                                '${course.cardCount} ${loc.translate('cards_unit')}',
                                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                              ),
                              if (course.category != null && course.category!.isNotEmpty) ...[
                                const SizedBox(width: 8),
                                Text('•', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    loc.translate(course.category!),
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isDownloaded
                                ? AppColors.courseDownloaded.withOpacity(0.15)
                                : (course.isPurchased
                                    ? AppColors.primary.withOpacity(0.15)
                                    : (course.price == 0
                                        ? AppColors.courseDownloaded.withOpacity(0.15)
                                        : Colors.amber.withOpacity(0.15))),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isDownloaded
                                  ? AppColors.courseDownloaded.withOpacity(0.5)
                                  : (course.isPurchased
                                      ? AppColors.primary.withOpacity(0.5)
                                      : (course.price == 0
                                          ? AppColors.courseDownloaded.withOpacity(0.5)
                                          : Colors.amber.withOpacity(0.5))),
                            ),
                          ),
                          child: Text(
                            isDownloaded
                                ? loc.readyToStudy
                                : (course.isPurchased
                                    ? loc.myCourses
                                    : _formatPrice(context, course.price)),
                            style: TextStyle(
                              color: isDownloaded
                                  ? AppColors.courseDownloaded
                                  : (course.isPurchased
                                      ? AppColors.primary
                                      : (course.price == 0 ? AppColors.courseDownloaded : Colors.amber)),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        onTap: () {
                          if (isDownloaded) {
                            FlashcardStudyScreen.open(
                              context,
                              courseId: course.id,
                              courseTitle: course.title,
                            );
                          } else {
                            _showCourseDetailsSheet(course);
                          }
                        },
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildCardsSearchTab(AppLocalizations loc) {
    final isFa = Localizations.localeOf(context).languageCode == 'fa';

    if (_downloadedCourses.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.download_for_offline_outlined, size: 54, color: AppColors.textSecondary),
              const SizedBox(height: 16),
              Text(
                loc.translate('no_downloaded_courses_avail'),
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                loc.translate('no_downloaded_courses_desc'),
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 18),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => setState(() => _activeTabIndex = 0),
                child: Text(loc.translate('search_courses_tab'), style: const TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        // Filter Chips Row
        Container(
          height: 36,
          margin: const EdgeInsets.only(top: 2, bottom: 6),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _downloadedCourses.length + 1,
            separatorBuilder: (_, __) => const SizedBox(width: 6),
            itemBuilder: (context, idx) {
              if (idx == 0) {
                final isSelected = _selectedCourseFilterId == null;
                return ChoiceChip(
                  showCheckmark: false,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  avatar: Icon(
                    Icons.layers_outlined,
                    size: 13,
                    color: isSelected ? Colors.white : AppColors.textSecondary,
                  ),
                  label: Text(
                    loc.translate('all_courses_filter'),
                    style: TextStyle(
                      color: isSelected ? Colors.white : AppColors.textSecondary,
                      fontSize: 11.5,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: AppColors.primary,
                  backgroundColor: AppColors.surface.withOpacity(0.7),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(color: isSelected ? AppColors.primary : AppColors.border),
                  ),
                  onSelected: (_) => _onCourseFilterChipSelected(null),
                );
              }

              final course = _downloadedCourses[idx - 1];
              final isSelected = _selectedCourseFilterId == course.id;
              return ChoiceChip(
                showCheckmark: false,
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                avatar: Icon(
                  Icons.menu_book,
                  size: 13,
                  color: isSelected ? Colors.white : AppColors.textSecondary,
                ),
                label: Text(
                  course.title,
                  textDirection: detectTextDirection(course.title),
                  style: TextStyle(
                    color: isSelected ? Colors.white : AppColors.textSecondary,
                    fontSize: 11.5,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                selected: isSelected,
                selectedColor: AppColors.primary,
                backgroundColor: AppColors.surface.withOpacity(0.7),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: isSelected ? AppColors.primary : AppColors.border),
                ),
                onSelected: (_) => _onCourseFilterChipSelected(course.id),
              );
            },
          ),
        ),

        // Search Input
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.surface.withOpacity(0.9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: TextField(
              controller: _cardSearchController,
              onChanged: _onCardSearchChanged,
              style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
              decoration: InputDecoration(
                hintText: loc.translate('search_cards_hint'),
                hintStyle: TextStyle(color: AppColors.textSecondary.withOpacity(0.7), fontSize: 13),
                prefixIcon: Icon(Icons.search, size: 20, color: AppColors.primary),
                suffixIcon: _cardSearchController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear, size: 18, color: AppColors.textSecondary),
                        onPressed: () {
                          _cardSearchController.clear();
                          _onCardSearchChanged('');
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                border: InputBorder.none,
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),

        // Card Results List
        Expanded(
          child: _isLoadingCards
              ? Center(child: CircularProgressIndicator(color: AppColors.primary))
              : _cardSearchController.text.trim().isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search, size: 48, color: AppColors.textSecondary.withOpacity(0.4)),
                          const SizedBox(height: 12),
                          Text(
                            loc.translate('type_to_search'),
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                          ),
                        ],
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
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          itemCount: _filteredCards.length,
                          itemBuilder: (context, index) {
                            final card = _filteredCards[index];
                            Course? course;
                            try {
                              course = _allPlatformCourses.firstWhere((c) => c.id == card.courseId);
                            } catch (_) {
                              course = null;
                            }

                            // Box status badge color
                            Color statusColor = AppColors.box1;
                            if (card.progress.currentBox == 2) statusColor = AppColors.box2;
                            if (card.progress.currentBox == 3) statusColor = AppColors.box3;
                            if (card.progress.currentBox == 4) statusColor = AppColors.box4;
                            if (card.progress.currentBox == 5) statusColor = AppColors.box5;
                            if (card.progress.currentBox >= 6) statusColor = AppColors.finished;

                            return Card(
                              margin: const EdgeInsets.only(bottom: 10),
                              color: AppColors.surface.withOpacity(0.7),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(color: AppColors.border.withOpacity(0.6)),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                title: Row(
                                  children: [
                                    Text(
                                      isFa ? 'کارت شماره ${card.cardNumber}' : 'Card #${card.cardNumber}',
                                      style: TextStyle(
                                        color: AppColors.textPrimary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13.5,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: statusColor.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: statusColor.withOpacity(0.4)),
                                      ),
                                      child: Text(
                                        card.progress.currentBox >= 6
                                            ? loc.translate('finished_box')
                                            : '${loc.translate('box_label_prefix')}${card.progress.currentBox}',
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
                                      textDirection: detectTextDirection(card.questionText),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5, height: 1.4),
                                    ),
                                    if (course != null) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        '${loc.translate('course_label_prefix')}${course.title}',
                                        textDirection: detectTextDirection(course.title),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w600),
                                      ),
                                    ],
                                  ],
                                ),
                                trailing: Icon(
                                  Directionality.of(context) == TextDirection.rtl
                                      ? Icons.arrow_back_ios
                                      : Icons.arrow_forward_ios,
                                  size: 15,
                                  color: AppColors.primary,
                                ),
                                onTap: () => _navigateToCardStudyScreen(card),
                              ),
                            );
                          },
                        ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);

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
              : Column(
                  children: [
                    _buildTabSelector(loc),
                    Expanded(
                      child: _activeTabIndex == 0
                          ? _buildCoursesSearchTab(loc)
                          : _buildCardsSearchTab(loc),
                    ),
                  ],
                ),
    );
  }
}
