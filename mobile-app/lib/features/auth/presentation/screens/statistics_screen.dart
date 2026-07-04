import 'package:flutter/material.dart';
import 'package:mobile_app/app/theme.dart';
import 'package:mobile_app/core/localization/app_localizations.dart';
import 'package:mobile_app/features/courses/domain/entities/course.dart';
import 'package:mobile_app/features/courses/domain/repositories/courses_repository.dart';
import 'package:mobile_app/features/flashcards/domain/repositories/flashcard_repository.dart';
import 'package:mobile_app/injection_container.dart' as di;

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  late final CoursesRepository _coursesRepository;
  late final FlashcardRepository _flashcardRepository;

  bool _isLoading = true;
  String? _errorMessage;

  List<Course> _downloadedCourses = [];
  Map<String, Map<int, int>> _courseStats = {}; // courseId -> box statistics

  // Global metrics
  int _totalCourses = 0;
  int _totalCards = 0;
  Map<int, int> _globalBoxCounts = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0, 6: 0};

  @override
  void initState() {
    super.initState();
    _coursesRepository = di.sl<CoursesRepository>();
    _flashcardRepository = di.sl<FlashcardRepository>();
    _loadStatisticsData();
  }

  Future<void> _loadStatisticsData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final coursesResult = await _coursesRepository.getCourses();

    coursesResult.fold(
      (failure) {
        setState(() {
          _isLoading = false;
          _errorMessage = failure.message;
        });
      },
      (data) async {
        final downloaded = data.$1.where((c) => c.isDownloaded).toList();
        final Map<String, Map<int, int>> statsMap = {};
        final Map<int, int> globalCounts = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0, 6: 0};
        int sumCards = 0;

        for (final course in downloaded) {
          final stats = await _flashcardRepository.getCourseStatistics(course.id);
          statsMap[course.id] = stats;

          // Sum box counts
          for (int box = 1; box <= 6; box++) {
            final count = stats[box] ?? 0;
            globalCounts[box] = (globalCounts[box] ?? 0) + count;
            sumCards += count;
          }
        }

        if (mounted) {
          setState(() {
            _downloadedCourses = downloaded;
            _courseStats = statsMap;
            _totalCourses = downloaded.length;
            _totalCards = sumCards;
            _globalBoxCounts = globalCounts;
            _isLoading = false;
          });
        }
      },
    );
  }

  double _getBoxPercentage(int boxCount) {
    if (_totalCards == 0) return 0.0;
    return (boxCount / _totalCards) * 100;
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
          loc.learningStatistics,
          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Text(_errorMessage!, style: TextStyle(color: AppColors.error)),
                  ),
                )
              : _totalCourses == 0
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Text(
                          loc.noDownloadedCoursesStats,
                          style: TextStyle(color: AppColors.textSecondary),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      color: AppColors.primary,
                      backgroundColor: AppColors.surface,
                      onRefresh: _loadStatisticsData,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 1. Global Metrics Card
                            _buildGlobalMetricsCard(loc),
                            const SizedBox(height: 24),

                            // 2. Global Leitner Box Distribution
                            Text(
                              loc.globalBoxDistribution,
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildGlobalDistributionCard(loc),
                            const SizedBox(height: 24),

                            // 3. Per-Course Statistics
                            Text(
                              loc.perCourseProgression,
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ..._downloadedCourses.map((c) => _buildCourseStatsCard(c, loc)),
                            const SizedBox(height: 80),
                          ],
                        ),
                      ),
                    ),
    );
  }

  Widget _buildGlobalMetricsCard(AppLocalizations loc) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacity(0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildMetricCol(loc.activeCourses, '$_totalCourses', Icons.library_books, AppColors.primary),
          Container(width: 1, height: 48, color: AppColors.border),
          _buildMetricCol(loc.totalCards, '$_totalCards', Icons.style, AppColors.secondary),
        ],
      ),
    );
  }

  Widget _buildMetricCol(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildGlobalDistributionCard(AppLocalizations loc) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacity(0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Segmented progress bar
          if (_totalCards > 0)
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                height: 24,
                width: double.infinity,
                child: Row(
                  children: [
                    if (_globalBoxCounts[1]! > 0) Expanded(flex: _globalBoxCounts[1]!, child: Container(color: AppColors.box1)),
                    if (_globalBoxCounts[2]! > 0) Expanded(flex: _globalBoxCounts[2]!, child: Container(color: AppColors.box2)),
                    if (_globalBoxCounts[3]! > 0) Expanded(flex: _globalBoxCounts[3]!, child: Container(color: AppColors.box3)),
                    if (_globalBoxCounts[4]! > 0) Expanded(flex: _globalBoxCounts[4]!, child: Container(color: AppColors.box4)),
                    if (_globalBoxCounts[5]! > 0) Expanded(flex: _globalBoxCounts[5]!, child: Container(color: AppColors.box5)),
                    if (_globalBoxCounts[6]! > 0) Expanded(flex: _globalBoxCounts[6]!, child: Container(color: AppColors.finished)),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 20),
          // Percentage list with specific colors
          _buildDistributionRow(loc.box1Orange, _globalBoxCounts[1] ?? 0, AppColors.box1, loc),
          _buildDistributionRow(loc.box2Yellow, _globalBoxCounts[2] ?? 0, AppColors.box2, loc),
          _buildDistributionRow(loc.box3Green, _globalBoxCounts[3] ?? 0, AppColors.box3, loc),
          _buildDistributionRow(loc.box4Blue, _globalBoxCounts[4] ?? 0, AppColors.box4, loc),
          _buildDistributionRow(loc.box5Purple, _globalBoxCounts[5] ?? 0, AppColors.box5, loc),
          _buildDistributionRow(loc.finishedGold, _globalBoxCounts[6] ?? 0, AppColors.finished, loc),
        ],
      ),
    );
  }

  Widget _buildDistributionRow(String label, int count, Color color, AppLocalizations loc) {
    final pct = _getBoxPercentage(count);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 12),
              Text(label, style: TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w500)),
            ],
          ),
          Text(
            '$count ${loc.cardsUnit} (${pct.toStringAsFixed(1)}%)',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildCourseStatsCard(Course course, AppLocalizations loc) {
    final stats = _courseStats[course.id] ?? {1: 0, 2: 0, 3: 0, 4: 0, 5: 0, 6: 0};
    final sumCards = stats.values.fold(0, (sum, val) => sum + val);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacity(0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  course.title,
                  style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 15),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '$sumCards ${loc.cardsUnit}',
                style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Horizontal status bar
          if (sumCards > 0)
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                height: 12,
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
          const SizedBox(height: 10),
          // Mini breakdown counts
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              _buildMiniBoxTag(loc.b1Mini, stats[1] ?? 0, AppColors.box1),
              _buildMiniBoxTag(loc.b2Mini, stats[2] ?? 0, AppColors.box2),
              _buildMiniBoxTag(loc.b3Mini, stats[3] ?? 0, AppColors.box3),
              _buildMiniBoxTag(loc.b4Mini, stats[4] ?? 0, AppColors.box4),
              _buildMiniBoxTag(loc.b5Mini, stats[5] ?? 0, AppColors.box5),
              _buildMiniBoxTag(loc.finMini, stats[6] ?? 0, AppColors.finished),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniBoxTag(String label, int count, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text('$label: $count', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
      ],
    );
  }
}
