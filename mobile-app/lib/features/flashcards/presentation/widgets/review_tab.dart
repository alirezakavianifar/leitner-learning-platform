import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:mobile_app/app/theme.dart';
import 'package:mobile_app/core/event_bus/event_bus.dart';
import 'package:mobile_app/core/event_bus/domain_events.dart';
import 'package:mobile_app/core/localization/app_localizations.dart';
import 'package:mobile_app/features/courses/domain/entities/course.dart';
import 'package:mobile_app/features/courses/domain/repositories/courses_repository.dart';
import 'package:mobile_app/features/flashcards/domain/repositories/flashcard_repository.dart';
import 'package:mobile_app/features/flashcards/presentation/screens/flashcard_study_screen.dart';
import 'package:mobile_app/injection_container.dart' as di;

class ReviewTab extends StatefulWidget {
  final VoidCallback? onNavigateToCatalog;
  final ValueNotifier<int>? activeTabNotifier;

  const ReviewTab({
    Key? key,
    this.onNavigateToCatalog,
    this.activeTabNotifier,
  }) : super(key: key);

  @override
  State<ReviewTab> createState() => _ReviewTabState();
}

class _ReviewTabState extends State<ReviewTab> with WidgetsBindingObserver {
  late CoursesRepository _coursesRepository;
  late FlashcardRepository _flashcardRepository;
  late EventBus _eventBus;
  StreamSubscription<DomainEvent>? _eventSubscription;

  List<Course> _purchasedCourses = [];
  Map<String, int> _dueCounts = {};
  final Map<String, double> _downloadProgress = {};
  final Set<String> _downloadingIds = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _coursesRepository = di.sl<CoursesRepository>();
    _flashcardRepository = di.sl<FlashcardRepository>();
    _eventBus = di.sl<EventBus>();

    _eventSubscription = _eventBus.on<DomainEvent>().listen((event) {
      if (event is CardReviewed ||
          event is CardFinished ||
          event is DueDateOverdueReset ||
          event is LeitnerProgressReset ||
          event is CourseDownloaded ||
          event is CourseProgressChanged ||
          event is StatsRefreshRequested) {
        _loadData(showLoading: false);
      }
    });

    widget.activeTabNotifier?.addListener(_onActiveTabChanged);

    _loadData();
  }

  void _onActiveTabChanged() {
    if (widget.activeTabNotifier?.value == 1) {
      _loadData(showLoading: false);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadData(showLoading: false);
    }
  }

  @override
  void didUpdateWidget(ReviewTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activeTabNotifier != widget.activeTabNotifier) {
      oldWidget.activeTabNotifier?.removeListener(_onActiveTabChanged);
      widget.activeTabNotifier?.addListener(_onActiveTabChanged);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.activeTabNotifier?.removeListener(_onActiveTabChanged);
    _eventSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadData({bool showLoading = true}) async {
    if (showLoading) {
      setState(() => _isLoading = true);
    }

    final either = await _coursesRepository.getCourses();

    await either.fold(
      (failure) async {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      },
      (data) async {
        final (courses, isOffline) = data;
        // Strictly filter to purchased / owned courses only.
        final purchased = courses.where((c) => c.isPurchased).toList();
        final Map<String, int> counts = {};

        for (final course in purchased) {
          if (course.isDownloaded || kIsWeb) {
            try {
              final queue = await _flashcardRepository.getReviewQueue(course.id, isTodayReview: true);
              counts[course.id] = queue.length;
            } catch (_) {
              counts[course.id] = 0;
            }
          }
        }

        if (mounted) {
          setState(() {
            _purchasedCourses = purchased;
            _dueCounts = counts;
            _isLoading = false;
          });
        }
      },
    );
  }

  Future<void> _startDownload(Course course) async {
    if (_downloadingIds.contains(course.id)) return;

    setState(() {
      _downloadingIds.add(course.id);
      _downloadProgress[course.id] = 0.0;
    });

    final result = await _coursesRepository.downloadCourse(
      course.id,
      onProgress: (received, total) {
        if (mounted) {
          setState(() {
            _downloadProgress[course.id] = total > 0 ? (received / total).clamp(0.0, 1.0) : 0.05;
          });
        }
      },
    );

    if (mounted) {
      setState(() {
        _downloadingIds.remove(course.id);
        _downloadProgress.remove(course.id);
      });

      result.fold(
        (failure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(failure.message),
              backgroundColor: AppColors.error,
            ),
          );
        },
        (_) {
          _loadData(showLoading: false);
        },
      );
    }
  }

  TextDirection _getTextDirection(String text) {
    final isRtl = RegExp(r'[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB50-\uFDFF\uFE70-\uFEFF]').hasMatch(text);
    return isRtl ? TextDirection.rtl : TextDirection.ltr;
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);

    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    if (_purchasedCourses.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.auto_stories_outlined,
                  size: 56,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                loc.noOwnedCoursesTitle,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                loc.noOwnedCoursesDesc,
                style: TextStyle(color: AppColors.textSecondary, height: 1.5, fontSize: 13.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              if (widget.onNavigateToCatalog != null)
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  onPressed: widget.onNavigateToCatalog,
                  icon: const Icon(Icons.menu_book_rounded, size: 18),
                  label: Text(
                    loc.exploreCatalog,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: AppColors.surface,
      onRefresh: () => _loadData(showLoading: false),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: _purchasedCourses.length,
        itemBuilder: (context, index) {
          final course = _purchasedCourses[index];
          final isDownloaded = course.isDownloaded || kIsWeb;
          final isDownloading = _downloadingIds.contains(course.id);
          final progress = _downloadProgress[course.id] ?? 0.0;
          final dueCount = _dueCounts[course.id] ?? 0;
          final titleDirection = _getTextDirection(course.title);

          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            color: AppColors.surface.withOpacity(0.6),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: AppColors.border),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Course Title with explicit TextDirection to prevent BiDi token scrambling
                      Expanded(
                        child: Text(
                          course.title,
                          textDirection: titleDirection,
                          textAlign: titleDirection == TextDirection.rtl ? TextAlign.right : TextAlign.left,
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            height: 1.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Status / Due reviews badge
                      if (isDownloaded)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: dueCount > 0 ? AppColors.box1.withOpacity(0.15) : Colors.white.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: dueCount > 0 ? AppColors.box1 : AppColors.textSecondary.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                dueCount > 0 ? Icons.today : Icons.check_circle_outline,
                                size: 14,
                                color: dueCount > 0 ? AppColors.box1 : AppColors.textSecondary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                dueCount > 0
                                    ? '$dueCount ${loc.dueBadge}'
                                    : loc.todayReviewsDone,
                                style: TextStyle(
                                  color: dueCount > 0 ? AppColors.box1 : AppColors.textSecondary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11.5,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: AppColors.primary.withOpacity(0.4),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.cloud_download_outlined,
                                size: 14,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                loc.downloadToReview,
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${course.cardCount} ${loc.totalCardsCount}',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 14),
                  const Divider(color: Color(0xFF333E56), height: 1),
                  const SizedBox(height: 12),

                  // Action: Study Button or Download Button / Progress
                  if (isDownloaded)
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () async {
                          await FlashcardStudyScreen.open(
                            context,
                            courseId: course.id,
                            courseTitle: course.title,
                            isTodayReview: true,
                          );
                          _loadData(showLoading: false);
                        },
                        icon: const Icon(Icons.play_arrow, color: Colors.white, size: 18),
                        label: Text(
                          loc.startStudy,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ),
                    )
                  else if (isDownloading)
                    Container(
                      height: 44,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.primary.withOpacity(0.4)),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              value: progress > 0 ? progress : null,
                              color: AppColors.primary,
                              strokeWidth: 2.2,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '${(progress * 100).clamp(0, 100).toInt()}%',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 13.5,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () => _startDownload(course),
                        icon: const Icon(Icons.download_rounded, color: Colors.white, size: 18),
                        label: Text(
                          loc.downloadNow,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
