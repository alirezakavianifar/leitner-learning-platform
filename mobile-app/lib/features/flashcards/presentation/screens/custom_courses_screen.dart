import 'package:flutter/material.dart';
import 'package:mobile_app/app/theme.dart';
import 'package:mobile_app/core/database/database_helper.dart';
import 'package:mobile_app/injection_container.dart' as di;
import 'package:mobile_app/core/error/error_formatter.dart';
import 'custom_cards_screen.dart';
import 'create_custom_card_screen.dart';

class CustomCoursesScreen extends StatefulWidget {
  const CustomCoursesScreen({Key? key}) : super(key: key);

  @override
  State<CustomCoursesScreen> createState() => _CustomCoursesScreenState();
}

class _CustomCoursesScreenState extends State<CustomCoursesScreen> {
  late DatabaseHelper _databaseHelper;
  List<Map<String, dynamic>> _customCourses = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _databaseHelper = di.sl<DatabaseHelper>();
    _loadCourses();
  }

  Future<void> _loadCourses() async {
    setState(() => _isLoading = true);
    try {
      final db = await _databaseHelper.localDatabase;
      // Fetch courses along with their card count using a subquery
      final results = await db.rawQuery('''
        SELECT c.id, c.title, c.created_at,
               (SELECT COUNT(*) FROM user_created_cards WHERE course_title = c.title) as card_count
        FROM user_created_courses c
        ORDER BY c.id DESC
      ''');
      setState(() {
        _customCourses = results;
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _createCourse() async {
    final isFa = Localizations.localeOf(context).languageCode == 'fa';
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final dialogTitle = isFa ? 'ایجاد دوره اختصاصی' : 'Create Custom Course';
    final labelText = isFa ? 'عنوان دوره' : 'Course Title';
    final cancelText = isFa ? 'انصراف' : 'Cancel';
    final createText = isFa ? 'ایجاد' : 'Create';
    final errorEmpty = isFa ? 'عنوان دوره نمی‌تواند خالی باشد' : 'Course title cannot be empty';
    final errorExists = isFa ? 'دوره‌ای با این عنوان از قبل وجود دارد' : 'A course with this title already exists';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: AppColors.border),
          ),
          title: Text(dialogTitle, style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: controller,
              style: TextStyle(color: AppColors.textPrimary),
              autofocus: true,
              decoration: InputDecoration(
                labelText: labelText,
                labelStyle: TextStyle(color: AppColors.textSecondary),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: AppColors.border),
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: AppColors.primary),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return errorEmpty;
                }
                // Check if already exists in loaded list
                final titleLower = val.trim().toLowerCase();
                for (final course in _customCourses) {
                  if ((course['title'] as String).toLowerCase() == titleLower) {
                    return errorExists;
                  }
                }
                return null;
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(cancelText, style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(context, true);
                }
              },
              child: Text(createText, style: const TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      final title = controller.text.trim();
      try {
        final db = await _databaseHelper.localDatabase;
        await db.insert('user_created_courses', {
          'title': title,
          'created_at': DateTime.now().toUtc().toIso8601String(),
        });
        _loadCourses();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppErrorFormatter.formatError('Failed to create course: $e', context: context)),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  Future<void> _deleteCourse(int id, String title) async {
    final isFa = Localizations.localeOf(context).languageCode == 'fa';
    final dialogTitle = isFa ? 'حذف دوره' : 'Delete Course';
    final contentText = isFa 
        ? 'آیا مطمئن هستید که می‌خواهید دوره "$title" و تمام کارت‌های آن را حذف کنید؟ این عمل غیرقابل بازگشت است.' 
        : 'Are you sure you want to delete the course "$title" and all of its cards? This action cannot be undone.';
    final cancelText = isFa ? 'انصراف' : 'Cancel';
    final deleteText = isFa ? 'حذف' : 'Delete';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(dialogTitle, style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
        content: Text(contentText, style: TextStyle(color: AppColors.textSecondary, height: 1.4)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(cancelText, style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(context, true),
            child: Text(deleteText, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final db = await _databaseHelper.localDatabase;
        // Delete course
        await db.delete('user_created_courses', where: 'id = ?', whereArgs: [id]);
        // Delete all associated cards under this title
        await db.delete('user_created_cards', where: 'course_title = ?', whereArgs: [title]);
        
        _loadCourses();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(isFa ? 'دوره با موفقیت حذف شد' : 'Course deleted successfully.'),
              backgroundColor: AppColors.secondary,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppErrorFormatter.formatError('Failed to delete course: $e', context: context)),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isFa = Localizations.localeOf(context).languageCode == 'fa';
    final screenTitle = isFa ? 'دوره‌های اختصاصی من' : 'My Custom Courses';

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
          screenTitle,
          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.add, color: AppColors.primary),
            onPressed: _createCourse,
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _customCourses.isEmpty
              ? _buildEmptyState()
              : _buildCoursesList(),
    );
  }

  Widget _buildEmptyState() {
    final isFa = Localizations.localeOf(context).languageCode == 'fa';
    final emptyTitle = isFa ? 'هیچ دوره اختصاصی یافت نشد' : 'No Custom Courses Found';
    final emptyDesc = isFa
        ? 'ابتدا یک دوره اختصاصی ایجاد کنید تا بتوانید کارت‌های آموزشی خود را درون آن بسازید و به صورت محلی مطالعه نمایید.'
        : 'Create a custom course first to start building and studying your own flashcards locally on your device.';
    final buttonText = isFa ? 'ایجاد اولین دوره' : 'Create First Course';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_open, size: 64, color: AppColors.secondary.withOpacity(0.5)),
            const SizedBox(height: 16),
            Text(
              emptyTitle,
              style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              emptyDesc,
              style: TextStyle(color: AppColors.textSecondary, height: 1.4),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _createCourse,
              icon: const Icon(Icons.add, color: Colors.white),
              label: Text(buttonText, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCoursesList() {
    final isFa = Localizations.localeOf(context).languageCode == 'fa';
    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: _customCourses.length,
      itemBuilder: (context, index) {
        final course = _customCourses[index];
        final id = course['id'] as int;
        final title = course['title'] as String;
        final cardCount = course['card_count'] as int? ?? 0;
        final countText = isFa ? '$cardCount کارت' : '$cardCount cards';

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          color: AppColors.surface.withOpacity(0.6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: AppColors.border),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CustomCardsScreen(courseTitle: title),
                ),
              ).then((_) => _loadCourses());
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.folder, color: AppColors.primary),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          countText,
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.add_circle_outline, color: AppColors.primary, size: 20),
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CreateCustomCardScreen(courseTitle: title),
                        ),
                      );
                      _loadCourses();
                    },
                  ),
                  IconButton(
                    icon: Icon(Icons.delete_outline, color: AppColors.error, size: 20),
                    onPressed: () => _deleteCourse(id, title),
                  ),
                  Icon(Icons.chevron_right, color: AppColors.border, size: 20),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
