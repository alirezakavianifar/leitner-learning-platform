import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile_app/app/theme.dart';
import 'package:mobile_app/core/localization/app_localizations.dart';
import 'package:mobile_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:mobile_app/features/auth/presentation/bloc/auth_event.dart';
import 'package:mobile_app/features/auth/presentation/bloc/auth_state.dart';
import 'package:mobile_app/injection_container.dart' as di;

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _usernameController = TextEditingController();
  String _mobileNumber = '';
  String? _interests;
  String _educationalField = 'General';
  String _educationalLevel = 'Student'; // fixed: was 'Learner' which is not in the list
  bool _isSavingProfile = false;
  File? _pickedImage;
  String? _savedAvatarPath; // local file path of previously saved avatar

  final List<Map<String, String>> _interestsOptions = const [
    {'en': 'Foreign Languages', 'fa': 'زبان‌های خارجی'},
    {'en': 'Basic Sciences', 'fa': 'علوم پایه'},
    {'en': 'Information Technology', 'fa': 'فناوری اطلاعات'},
    {'en': 'Exams & Academics', 'fa': 'کنکور و تحصیلات'},
    {'en': 'General & Misc', 'fa': 'عمومی و متفرقه'},
  ];

  final List<Map<String, String>> _fieldOptions = const [
    {'en': 'Technical & Engineering', 'fa': 'فنی و مهندسی'},
    {'en': 'Humanities', 'fa': 'علوم انسانی'},
    {'en': 'Medical Sciences', 'fa': 'علوم پزشکی'},
    {'en': 'Basic Sciences', 'fa': 'علوم پایه'},
    {'en': 'Art', 'fa': 'هنر'},
    {'en': 'General', 'fa': 'عمومی'},
  ];

  final List<Map<String, String>> _levelOptions = const [
    {'en': 'Student', 'fa': 'دانش‌آموز'},
    {'en': 'High School Diploma', 'fa': 'دیپلم'},
    {'en': 'Associate Degree', 'fa': 'کاردانی'},
    {'en': 'Bachelor\'s', 'fa': 'کارشناسی'},
    {'en': 'Master\'s', 'fa': 'کارشناسی ارشد'},
    {'en': 'PhD & Above', 'fa': 'دکتری و بالاتر'},
  ];

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final prefs = di.sl<SharedPreferences>();
    setState(() {
      _usernameController.text = prefs.getString('user_username') ?? '';
      _mobileNumber = prefs.getString('user_mobile_number') ?? '';
      _interests = prefs.getString('user_interests');
      _educationalField = prefs.getString('user_educational_field') ?? 'General';
      // Ensure the loaded level is actually in the options list to avoid assertion error
      final savedLevel = prefs.getString('user_educational_level') ?? 'Student';
      const validLevels = ['Student', 'High School Diploma', 'Associate Degree', "Bachelor's", "Master's", 'PhD & Above'];
      _educationalLevel = validLevels.contains(savedLevel) ? savedLevel : 'Student';
      _savedAvatarPath = prefs.getString('user_avatar_path');
    });
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (image != null) {
      setState(() {
        _pickedImage = File(image.path);
      });
    }
  }

  Future<void> _saveProfile() async {
    final username = _usernameController.text.trim();
    if (username.isEmpty) {
      final loc = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(loc.pleaseEnterUsername),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isSavingProfile = true);
    context.read<AuthBloc>().add(
          UpdateProfileEvent(
            username: username,
            interests: _interests,
            educationalField: _educationalField,
            educationalLevel: _educationalLevel,
            profilePicture: _pickedImage,
          ),
        );
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
          loc.profileDetails,
          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
        ),
      ),
      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthenticatedState) {
            setState(() {
              _isSavingProfile = false;
            });
            final user = state.user;
            final prefs = di.sl<SharedPreferences>();
            prefs.setString('user_username', user.username);
            if (user.interests != null) prefs.setString('user_interests', user.interests!);
            prefs.setString('user_educational_field', user.educationalField ?? 'General');
            prefs.setString('user_educational_level', user.educationalLevel ?? 'Student');
            // Save the local avatar path if a new image was picked
            if (_pickedImage != null) {
              prefs.setString('user_avatar_path', _pickedImage!.path);
              setState(() {
                _savedAvatarPath = _pickedImage!.path;
                _pickedImage = null; // clear pending state
              });
            }
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(loc.saveProfile),
                backgroundColor: AppColors.secondary,
              ),
            );
          } else if (state is AuthErrorState) {
            setState(() {
              _isSavingProfile = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppColors.error,
              ),
            );
          }
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ─── Avatar Section ─────────────────────────────────────────
              Center(
                child: GestureDetector(
                  onTap: _isSavingProfile ? null : _pickImage,
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      CircleAvatar(
                        radius: 54,
                        backgroundColor: AppColors.surface,
                        backgroundImage: _pickedImage != null
                            ? FileImage(_pickedImage!) as ImageProvider
                            : (_savedAvatarPath != null
                                ? FileImage(File(_savedAvatarPath!))
                                : null),
                        child: (_pickedImage == null && _savedAvatarPath == null)
                            ? Icon(Icons.person, size: 54, color: AppColors.textSecondary)
                            : null,
                      ),
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.background, width: 2),
                        ),
                        child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                loc.profileDetails,
                style: TextStyle(color: AppColors.primary, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _usernameController,
                style: TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  labelText: loc.username,
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
              ),
              const SizedBox(height: 16),
              // Mobile Number (Locked / Read-Only)
              TextFormField(
                key: ValueKey(_mobileNumber),
                initialValue: _mobileNumber,
                enabled: false,
                style: TextStyle(color: AppColors.textSecondary),
                decoration: InputDecoration(
                  labelText: loc.mobileReadonly,
                  labelStyle: TextStyle(color: AppColors.textSecondary),
                  disabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: AppColors.border.withOpacity(0.3)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Interests Dropdown
              DropdownButtonFormField<String>(
                value: _interests,
                style: TextStyle(color: AppColors.textPrimary, fontSize: 15),
                dropdownColor: AppColors.surface,
                decoration: InputDecoration(
                  labelText: loc.interests,
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
                items: _interestsOptions.map((opt) {
                  return DropdownMenuItem<String>(
                    value: opt['en'],
                    child: Text(isFa ? opt['fa']! : opt['en']!),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _interests = value;
                  });
                },
              ),
              const SizedBox(height: 16),
              // Educational Field Dropdown
              DropdownButtonFormField<String>(
                value: _educationalField,
                style: TextStyle(color: AppColors.textPrimary, fontSize: 15),
                dropdownColor: AppColors.surface,
                decoration: InputDecoration(
                  labelText: loc.educationalField,
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
                items: _fieldOptions.map((opt) {
                  return DropdownMenuItem<String>(
                    value: opt['en'],
                    child: Text(isFa ? opt['fa']! : opt['en']!),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _educationalField = value ?? 'General';
                  });
                },
              ),
              const SizedBox(height: 16),
              // Educational Level Dropdown
              DropdownButtonFormField<String>(
                value: _educationalLevel,
                style: TextStyle(color: AppColors.textPrimary, fontSize: 15),
                dropdownColor: AppColors.surface,
                decoration: InputDecoration(
                  labelText: loc.educationalLevel,
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
                items: _levelOptions.map((opt) {
                  return DropdownMenuItem<String>(
                    value: opt['en'],
                    child: Text(isFa ? opt['fa']! : opt['en']!),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _educationalLevel = value ?? 'Learner';
                  });
                },
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _isSavingProfile ? null : _saveProfile,
                child: _isSavingProfile
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(loc.updateProfile, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
