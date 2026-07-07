import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:mobile_app/app/theme.dart';
import 'package:mobile_app/core/database/database_helper.dart';
import 'package:mobile_app/injection_container.dart' as di;
import 'package:sqflite/sqflite.dart';

class CreateCustomCardScreen extends StatefulWidget {
  final String courseTitle;
  final Map<String, dynamic>? cardToEdit;
  const CreateCustomCardScreen({Key? key, required this.courseTitle, this.cardToEdit}) : super(key: key);

  @override
  State<CreateCustomCardScreen> createState() => _CreateCustomCardScreenState();
}

class _CreateCustomCardScreenState extends State<CreateCustomCardScreen> {
  final _formKey = GlobalKey<FormState>();
  final _questionController = TextEditingController();
  final _answerController = TextEditingController();
  late final TextEditingController _titleController;
  final _optionsController = TextEditingController();
  
  bool _isSaving = false;
  
  File? _pickedImage;
  String? _recordedAudioPath;
  bool _isRecording = false;
  bool _isPlaying = false;

  final ImagePicker _picker = ImagePicker();
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();

  List<String> _courses = [];
  String? _selectedCourse;
  bool _isCreatingNewCourse = false;
  final _newCourseController = TextEditingController();
  late DatabaseHelper _databaseHelper;

  @override
  void initState() {
    super.initState();
    _databaseHelper = di.sl<DatabaseHelper>();
    _titleController = TextEditingController(text: widget.courseTitle);
    _loadCourses();
    if (widget.cardToEdit != null) {
      _questionController.text = widget.cardToEdit!['question_text'] as String? ?? '';
      _answerController.text = widget.cardToEdit!['answer_text'] as String? ?? '';
      final optionsJson = widget.cardToEdit!['options'] as String?;
      if (optionsJson != null && optionsJson.isNotEmpty) {
        try {
          final List<dynamic> optionsList = jsonDecode(optionsJson);
          _optionsController.text = optionsList.join(', ');
        } catch (_) {}
      }
      final imgPath = widget.cardToEdit!['image_path'] as String?;
      if (imgPath != null && File(imgPath).existsSync()) {
        _pickedImage = File(imgPath);
      }
      final audPath = widget.cardToEdit!['audio_path'] as String?;
      if (audPath != null && File(audPath).existsSync()) {
        _recordedAudioPath = audPath;
      }
    }
  }

  Future<void> _loadCourses() async {
    try {
      final db = await _databaseHelper.localDatabase;
      final results = await db.query('user_created_courses', columns: ['title']);
      final titles = results.map((row) => row['title'] as String).toList();
      setState(() {
        _courses = titles;
        
        final initialTitle = widget.cardToEdit != null 
            ? (widget.cardToEdit!['course_title'] as String? ?? widget.courseTitle)
            : widget.courseTitle;

        if (initialTitle.isNotEmpty && !_courses.contains(initialTitle)) {
          _courses.add(initialTitle);
        }
        
        _selectedCourse = initialTitle.isNotEmpty ? initialTitle : (_courses.isNotEmpty ? _courses.first : null);
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _questionController.dispose();
    _answerController.dispose();
    _titleController.dispose();
    _optionsController.dispose();
    _newCourseController.dispose();
    _recorder.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final isFa = Localizations.localeOf(context).languageCode == 'fa';
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
      if (image != null) {
        setState(() {
          _pickedImage = File(image.path);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isFa ? 'خطا در انتخاب تصویر: $e' : 'Failed to pick image: $e')),
      );
    }
  }

  Future<void> _toggleRecording() async {
    final isFa = Localizations.localeOf(context).languageCode == 'fa';
    try {
      if (await _recorder.hasPermission()) {
        if (_isRecording) {
          final path = await _recorder.stop();
          setState(() {
            _isRecording = false;
            _recordedAudioPath = path;
          });
        } else {
          final dir = await getTemporaryDirectory();
          final path = p.join(dir.path, 'custom_card_audio_${DateTime.now().millisecondsSinceEpoch}.m4a');
          await _recorder.start(const RecordConfig(), path: path);
          setState(() {
            _isRecording = true;
            _recordedAudioPath = null;
          });
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isFa ? 'دسترسی به میکروفون رد شد.' : 'Microphone permission denied.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isFa ? 'خطا در ضبط صدا: $e' : 'Failed to record: $e')),
      );
    }
  }

  Future<void> _playRecordedAudio() async {
    final isFa = Localizations.localeOf(context).languageCode == 'fa';
    if (_recordedAudioPath == null) return;
    try {
      if (_isPlaying) {
        await _audioPlayer.stop();
        setState(() => _isPlaying = false);
      } else {
        setState(() => _isPlaying = true);
        await _audioPlayer.play(DeviceFileSource(_recordedAudioPath!));
        _audioPlayer.onPlayerComplete.listen((_) {
          if (mounted) {
            setState(() => _isPlaying = false);
          }
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isFa ? 'خطا در پخش صدا: $e' : 'Failed to play audio: $e')),
      );
      setState(() => _isPlaying = false);
    }
  }

  Future<void> _saveCard() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    final isFa = Localizations.localeOf(context).languageCode == 'fa';
    
    try {
      final dbHelper = di.sl<DatabaseHelper>();
      final db = await dbHelper.localDatabase;
      
      final appDir = await getApplicationDocumentsDirectory();
      final customMediaDir = Directory(p.join(appDir.path, 'custom_media'));
      if (!customMediaDir.existsSync()) {
        customMediaDir.createSync(recursive: true);
      }

      String? imagePath = widget.cardToEdit?['image_path'];
      if (_pickedImage != null) {
        if (widget.cardToEdit == null || _pickedImage!.path != widget.cardToEdit!['image_path']) {
          // A new image was picked, save it and clean up the old one
          final filename = 'image_${DateTime.now().millisecondsSinceEpoch}${p.extension(_pickedImage!.path)}';
          final savedImageFile = await _pickedImage!.copy(p.join(customMediaDir.path, filename));
          imagePath = savedImageFile.path;
          
          final oldImgPath = widget.cardToEdit?['image_path'] as String?;
          if (oldImgPath != null && File(oldImgPath).existsSync()) {
            try { File(oldImgPath).deleteSync(); } catch (_) {}
          }
        }
      } else {
        // Image was cleared by the user, delete the old physical file
        final oldImgPath = widget.cardToEdit?['image_path'] as String?;
        if (oldImgPath != null && File(oldImgPath).existsSync()) {
          try { File(oldImgPath).deleteSync(); } catch (_) {}
        }
        imagePath = null;
      }

      String? audioPath = widget.cardToEdit?['audio_path'];
      if (_recordedAudioPath != null) {
        if (widget.cardToEdit == null || _recordedAudioPath != widget.cardToEdit!['audio_path']) {
          // A new audio was recorded, save it and clean up the old one
          final filename = 'audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
          final savedAudioFile = await File(_recordedAudioPath!).copy(p.join(customMediaDir.path, filename));
          audioPath = savedAudioFile.path;
          
          // Clean up temporary recording
          try {
            File(_recordedAudioPath!).deleteSync();
          } catch (_) {}

          final oldAudPath = widget.cardToEdit?['audio_path'] as String?;
          if (oldAudPath != null && File(oldAudPath).existsSync()) {
            try { File(oldAudPath).deleteSync(); } catch (_) {}
          }
        }
      } else {
        // Audio was cleared by the user, delete the old physical file
        final oldAudPath = widget.cardToEdit?['audio_path'] as String?;
        if (oldAudPath != null && File(oldAudPath).existsSync()) {
          try { File(oldAudPath).deleteSync(); } catch (_) {}
        }
        audioPath = null;
      }
      
      final optionsText = _optionsController.text.trim();
      String? optionsJson;
      if (optionsText.isNotEmpty) {
        final optionsList = optionsText.split(',').map((o) => o.trim()).where((o) => o.isNotEmpty).toList();
        optionsJson = jsonEncode(optionsList);
      }
      
      String finalCourseTitle = _selectedCourse ?? 'My Custom Cards';
      if (_isCreatingNewCourse) {
        finalCourseTitle = _newCourseController.text.trim();
        // Insert new course to database
        await db.insert(
          'user_created_courses',
          {
            'title': finalCourseTitle,
            'created_at': DateTime.now().toUtc().toIso8601String(),
          },
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }

      if (widget.cardToEdit != null) {
        await db.update(
          'user_created_cards',
          {
            'course_title': finalCourseTitle,
            'question_text': _questionController.text.trim(),
            'answer_text': _answerController.text.trim(),
            'options': optionsJson,
            'image_path': imagePath,
            'audio_path': audioPath,
          },
          where: 'id = ?',
          whereArgs: [widget.cardToEdit!['id']],
        );
      } else {
        await db.insert('user_created_cards', {
          'course_title': finalCourseTitle,
          'question_text': _questionController.text.trim(),
          'answer_text': _answerController.text.trim(),
          'options': optionsJson,
          'image_path': imagePath,
          'audio_path': audioPath,
          'created_at': DateTime.now().toUtc().toIso8601String(),
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.cardToEdit != null
              ? (isFa ? 'تغییرات کارت با موفقیت ذخیره شد!' : 'Custom card updated successfully!')
              : (isFa ? 'کارت اختصاصی با موفقیت ذخیره شد (فقط روی دستگاه)!' : 'Custom card saved successfully (device-only)!')),
          backgroundColor: AppColors.secondary,
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isFa ? 'خطا در ذخیره کارت: $e' : 'Failed to save card: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }



  @override
  Widget build(BuildContext context) {
    final isFa = Localizations.localeOf(context).languageCode == 'fa';
    
    final tCreateCustomCard = widget.cardToEdit != null
        ? (isFa ? 'ویرایش کارت اختصاصی' : 'Edit Custom Card')
        : (isFa ? 'ایجاد کارت اختصاصی' : 'Create Custom Card');
    final tDeviceStorageInfo = isFa 
        ? 'ذخیره‌سازی فقط روی دستگاه: این کارت برای حفظ حریم خصوصی شما صرفاً به صورت محلی روی دستگاهتان ذخیره می‌شود.'
        : 'Device-Only Storage: This card is stored strictly locally on your device to protect your privacy.';
    final tCourseCategory = isFa ? 'دسته‌بندی / عنوان دوره' : 'Course Category / Title';
    final tQuestionText = isFa ? 'متن سوال' : 'Question Text';
    final tQuestionRequired = isFa ? 'ورود سوال الزامی است' : 'Question is required';
    final tAnswerText = isFa ? 'متن پاسخ' : 'Answer Text';
    final tAnswerRequired = isFa ? 'ورود پاسخ الزامی است' : 'Answer is required';
    final tMultipleChoice = isFa ? 'گزینه‌های چندگزینه‌ای (اختیاری، جدا شده با کاما)' : 'Multiple-Choice Options (Optional, comma-separated)';
    final tOptionsExample = isFa ? 'مثال: تهران، شیراز، اصفهان' : 'e.g. Tehran, Shiraz, Isfahan';
    final tMediaAttachments = isFa ? 'فایل‌های پیوست (اختیاری)' : 'Media Attachments (Optional)';
    final tChangeImage = isFa ? 'تغییر تصویر' : 'Change Image';
    final tPickImage = isFa ? 'انتخاب تصویر' : 'Pick Image';
    final tStop = isFa ? 'توقف' : 'Stop';
    final tRerecord = isFa ? 'ضبط مجدد' : 'Re-record';
    final tRecordAudio = isFa ? 'ضبط صدا' : 'Record Audio';
    final tAudioAttached = isFa ? 'فایل صوتی پیوست شد' : 'Audio attached';
    final tSaveCard = widget.cardToEdit != null
        ? (isFa ? 'ذخیره تغییرات' : 'Save Changes')
        : (isFa ? 'ذخیره کارت' : 'Save Card');

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
          tCreateCustomCard,
          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Info Banner
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.secondary.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.lock, color: AppColors.secondary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        tDeviceStorageInfo,
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Title/Course Dropdown
              DropdownButtonFormField<String>(
                value: _selectedCourse,
                dropdownColor: AppColors.surface,
                style: TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  labelText: tCourseCategory,
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
                items: [
                  ..._courses.map((c) => DropdownMenuItem(
                        value: c,
                        child: Text(c, style: TextStyle(color: AppColors.textPrimary)),
                      )),
                  DropdownMenuItem(
                    value: '__NEW_COURSE__',
                    child: Text(
                      isFa ? '+ ایجاد دوره جدید...' : '+ Create New Course...',
                      style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
                onChanged: (val) {
                  setState(() {
                    _selectedCourse = val;
                    _isCreatingNewCourse = (val == '__NEW_COURSE__');
                  });
                },
                validator: (val) {
                  if (val == null) return isFa ? 'انتخاب دوره الزامی است' : 'Course is required';
                  return null;
                },
              ),
              if (_isCreatingNewCourse) ...[
                const SizedBox(height: 20),
                TextFormField(
                  controller: _newCourseController,
                  style: TextStyle(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    labelText: isFa ? 'عنوان دوره جدید' : 'New Course Title',
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
                    if (_isCreatingNewCourse && (val == null || val.trim().isEmpty)) {
                      return isFa ? 'عنوان دوره نمی‌تواند خالی باشد' : 'Course title cannot be empty';
                    }
                    return null;
                  },
                ),
              ],
              const SizedBox(height: 20),

              // Question
              TextFormField(
                controller: _questionController,
                maxLines: 4,
                style: TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  labelText: tQuestionText,
                  labelStyle: TextStyle(color: AppColors.textSecondary),
                  alignLabelWithHint: true,
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
                  if (val == null || val.trim().isEmpty) return tQuestionRequired;
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Answer
              TextFormField(
                controller: _answerController,
                maxLines: 4,
                style: TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  labelText: tAnswerText,
                  labelStyle: TextStyle(color: AppColors.textSecondary),
                  alignLabelWithHint: true,
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
                  if (val == null || val.trim().isEmpty) return tAnswerRequired;
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Options
              TextFormField(
                controller: _optionsController,
                style: TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  labelText: tMultipleChoice,
                  labelStyle: TextStyle(color: AppColors.textSecondary),
                  hintText: tOptionsExample,
                  hintStyle: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: AppColors.border),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: AppColors.primary),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Media selection UI
              Text(
                tMediaAttachments,
                style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textPrimary,
                        side: BorderSide(color: AppColors.border),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: _pickImage,
                      icon: Icon(Icons.image, color: AppColors.secondary),
                      label: Text(_pickedImage != null ? tChangeImage : tPickImage),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isRecording ? AppColors.error : AppColors.secondary,
                        foregroundColor: AppColors.background,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: _toggleRecording,
                      icon: Icon(_isRecording ? Icons.stop : Icons.mic),
                      label: Text(_isRecording ? tStop : (_recordedAudioPath != null ? tRerecord : tRecordAudio)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              if (_pickedImage != null || _recordedAudioPath != null)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (_pickedImage != null)
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            width: 70,
                            height: 70,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              image: DecorationImage(
                                image: FileImage(_pickedImage!),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          Positioned(
                            top: -8,
                            right: -8,
                            child: CircleAvatar(
                              radius: 10,
                              backgroundColor: AppColors.error,
                              child: GestureDetector(
                                onTap: () => setState(() => _pickedImage = null),
                                child: const Icon(Icons.close, color: Colors.white, size: 12),
                              ),
                            ),
                          ),
                        ],
                      )
                    else
                      const SizedBox.shrink(),

                    if (_recordedAudioPath != null)
                      Row(
                        children: [
                          IconButton(
                            icon: Icon(_isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill, color: AppColors.primary, size: 36),
                            onPressed: _playRecordedAudio,
                          ),
                          Text(tAudioAttached, style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                          IconButton(
                            icon: Icon(Icons.delete_outline, color: AppColors.error),
                            onPressed: () => setState(() => _recordedAudioPath = null),
                          ),
                        ],
                      )
                    else
                      const SizedBox.shrink(),
                  ],
                ),
              
              const SizedBox(height: 32),

              // Save Button
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _isSaving ? null : _saveCard,
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : Text(
                        tSaveCard,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
