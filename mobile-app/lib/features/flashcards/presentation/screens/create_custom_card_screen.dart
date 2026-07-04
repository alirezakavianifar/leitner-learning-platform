import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:mobile_app/app/theme.dart';
import 'package:mobile_app/core/database/database_helper.dart';
import 'package:mobile_app/injection_container.dart' as di;

class CreateCustomCardScreen extends StatefulWidget {
  const CreateCustomCardScreen({Key? key}) : super(key: key);

  @override
  State<CreateCustomCardScreen> createState() => _CreateCustomCardScreenState();
}

class _CreateCustomCardScreenState extends State<CreateCustomCardScreen> {
  final _formKey = GlobalKey<FormState>();
  final _questionController = TextEditingController();
  final _answerController = TextEditingController();
  final _titleController = TextEditingController(text: 'My Custom Cards');
  
  bool _isSaving = false;
  
  File? _pickedImage;
  String? _recordedAudioPath;
  bool _isRecording = false;
  bool _isPlaying = false;

  final ImagePicker _picker = ImagePicker();
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void dispose() {
    _questionController.dispose();
    _answerController.dispose();
    _titleController.dispose();
    _recorder.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
      if (image != null) {
        setState(() {
          _pickedImage = File(image.path);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to pick image: $e')),
      );
    }
  }

  Future<void> _toggleRecording() async {
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
          const SnackBar(content: Text('Microphone permission denied.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to record: $e')),
      );
    }
  }

  Future<void> _playRecordedAudio() async {
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
        SnackBar(content: Text('Failed to play audio: $e')),
      );
      setState(() => _isPlaying = false);
    }
  }

  Future<void> _saveCard() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    
    try {
      final dbHelper = di.sl<DatabaseHelper>();
      final db = await dbHelper.localDatabase;
      
      final appDir = await getApplicationDocumentsDirectory();
      final customMediaDir = Directory(p.join(appDir.path, 'custom_media'));
      if (!customMediaDir.existsSync()) {
        customMediaDir.createSync(recursive: true);
      }

      String? imagePath;
      if (_pickedImage != null) {
        final filename = 'image_${DateTime.now().millisecondsSinceEpoch}${p.extension(_pickedImage!.path)}';
        final savedImageFile = await _pickedImage!.copy(p.join(customMediaDir.path, filename));
        imagePath = savedImageFile.path;
      }

      String? audioPath;
      if (_recordedAudioPath != null) {
        final filename = 'audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
        final savedAudioFile = await File(_recordedAudioPath!).copy(p.join(customMediaDir.path, filename));
        audioPath = savedAudioFile.path;
        // Clean up temporary recording
        try {
          File(_recordedAudioPath!).deleteSync();
        } catch (_) {}
      }
      
      await db.insert('user_created_cards', {
        'course_title': _titleController.text.trim(),
        'question_text': _questionController.text.trim(),
        'answer_text': _answerController.text.trim(),
        'image_path': imagePath,
        'audio_path': audioPath,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Custom card saved successfully (device-only)!'),
          backgroundColor: AppColors.secondary,
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save card: $e'),
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
          'Create Custom Card',
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
                        'Device-Only Storage: This card is stored strictly locally on your device to protect your privacy.',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Title
              TextFormField(
                controller: _titleController,
                style: TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Course Category / Title',
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
                  if (val == null || val.trim().isEmpty) return 'Category is required';
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Question
              TextFormField(
                controller: _questionController,
                maxLines: 4,
                style: TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Question Text',
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
                  if (val == null || val.trim().isEmpty) return 'Question is required';
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
                  labelText: 'Answer Text',
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
                  if (val == null || val.trim().isEmpty) return 'Answer is required';
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Media selection UI
              Text(
                'Media Attachments (Optional)',
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
                      label: Text(_pickedImage != null ? 'Change Image' : 'Pick Image'),
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
                      label: Text(_isRecording ? 'Stop' : (_recordedAudioPath != null ? 'Re-record' : 'Record Audio')),
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
                          Text('Audio attached', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
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
                    : const Text(
                        'Save Card',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
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
