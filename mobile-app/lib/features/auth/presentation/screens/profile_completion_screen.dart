import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_app/app/theme.dart';
import 'package:mobile_app/core/localization/app_localizations.dart';
import 'package:mobile_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:mobile_app/features/auth/presentation/bloc/auth_event.dart';
import 'package:mobile_app/features/auth/presentation/bloc/auth_state.dart';
import 'home_hub_screen.dart';

class ProfileCompletionScreen extends StatefulWidget {
  final String mobileNumber;
  final String token;
  final String refreshToken;

  const ProfileCompletionScreen({
    Key? key,
    required this.mobileNumber,
    required this.token,
    required this.refreshToken,
  }) : super(key: key);

  @override
  State<ProfileCompletionScreen> createState() => _ProfileCompletionScreenState();
}

class _ProfileCompletionScreenState extends State<ProfileCompletionScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _phoneController;
  final _usernameController = TextEditingController();

  String? _selectedInterest;
  String? _selectedField = 'General';
  String? _selectedLevel = 'Student';
  File? _pickedImage;

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
    _phoneController = TextEditingController(text: widget.mobileNumber);
    _usernameController.text = 'Student_${widget.mobileNumber.substring(widget.mobileNumber.length - 4)}';
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final isFa = Localizations.localeOf(context).languageCode == 'fa';
    final picked = await showModalBottomSheet<XFile?>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.photo_library, color: AppColors.primary),
              title: Text(isFa ? 'انتخاب از گالری' : 'Choose from Gallery',
                  style: TextStyle(color: AppColors.textPrimary)),
              onTap: () async {
                final img = await picker.pickImage(
                  source: ImageSource.gallery,
                  imageQuality: 80,
                  maxWidth: 512,
                  maxHeight: 512,
                );
                Navigator.pop(ctx, img);
              },
            ),
            ListTile(
              leading: Icon(Icons.camera_alt, color: AppColors.secondary),
              title: Text(isFa ? 'عکس‌برداری با دوربین' : 'Take a Photo',
                  style: TextStyle(color: AppColors.textPrimary)),
              onTap: () async {
                final img = await picker.pickImage(
                  source: ImageSource.camera,
                  imageQuality: 80,
                  maxWidth: 512,
                  maxHeight: 512,
                );
                Navigator.pop(ctx, img);
              },
            ),
          ],
        ),
      ),
    );
    if (picked != null) {
      final file = File(picked.path);
      final sizeBytes = await file.length();
      if (sizeBytes > 3 * 1024 * 1024) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isFa ? 'حجم تصویر باید کمتر از ۳ مگابایت باشد.' : 'Image size must be less than 3MB.',
            ),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
      setState(() => _pickedImage = file);
    }
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      context.read<AuthBloc>().add(
            UpdateProfileEvent(
              username: _usernameController.text.trim(),
              interests: _selectedInterest,
              educationalField: _selectedField,
              educationalLevel: _selectedLevel,
              profilePicture: _pickedImage,
            ),
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final loc = AppLocalizations.of(context);
    final isFa = Localizations.localeOf(context).languageCode == 'fa';

    return Scaffold(
      body: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthenticatedState) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const HomeHubScreen()),
              (route) => false,
            );
          } else if (state is AuthErrorState) {
            String errorMessage = state.message;
            if (state.errorCode != null) {
              final key = state.errorCode!.toLowerCase();
              final translated = loc.translate(key);
              if (translated != key) {
                errorMessage = translated;
              }
            }
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(errorMessage),
                backgroundColor: AppColors.error,
              ),
            );
          }
        },
        builder: (context, state) {
          final isLoading = state is AuthLoadingState;

          return SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        loc.completeProfile,
                        style: textTheme.displaySmall?.copyWith(
                          color: AppColors.primary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        loc.tellUsProfile,
                        style: textTheme.bodyLarge,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),

                      // ─── Avatar Picker ───────────────────────────────────
                      Center(
                        child: GestureDetector(
                          onTap: isLoading ? null : _pickImage,
                          child: Stack(
                            alignment: Alignment.bottomRight,
                            children: [
                              CircleAvatar(
                                radius: 54,
                                backgroundColor: AppColors.surface,
                                backgroundImage: _pickedImage != null
                                    ? FileImage(_pickedImage!) as ImageProvider
                                    : null,
                                child: _pickedImage == null
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
                      const SizedBox(height: 28),

                      // Read-only Phone Number
                      TextFormField(
                        controller: _phoneController,
                        enabled: false,
                        style: TextStyle(color: AppColors.textPrimary.withOpacity(0.6)),
                        decoration: InputDecoration(
                          labelText: loc.mobileReadonly,
                          prefixIcon: Icon(Icons.lock_outline, color: AppColors.textSecondary),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Username
                      TextFormField(
                        controller: _usernameController,
                        style: TextStyle(color: AppColors.textPrimary),
                        decoration: InputDecoration(
                          labelText: loc.username,
                          prefixIcon: Icon(Icons.person_outline, color: AppColors.textSecondary),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return loc.pleaseEnterUsername;
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      // Interests Dropdown
                      DropdownButtonFormField<String>(
                        value: _selectedInterest,
                        style: TextStyle(color: AppColors.textPrimary, fontSize: 15),
                        dropdownColor: AppColors.surface,
                        decoration: InputDecoration(
                          labelText: loc.interests,
                          prefixIcon: Icon(Icons.interests_outlined, color: AppColors.textSecondary),
                        ),
                        items: _interestsOptions.map((opt) {
                          return DropdownMenuItem<String>(
                            value: opt['en'],
                            child: Text(isFa ? opt['fa']! : opt['en']!),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedInterest = value;
                          });
                        },
                      ),
                      const SizedBox(height: 20),

                      // Educational Field Dropdown
                      DropdownButtonFormField<String>(
                        value: _selectedField,
                        style: TextStyle(color: AppColors.textPrimary, fontSize: 15),
                        dropdownColor: AppColors.surface,
                        decoration: InputDecoration(
                          labelText: loc.educationalField,
                          prefixIcon: Icon(Icons.school_outlined, color: AppColors.textSecondary),
                        ),
                        items: _fieldOptions.map((opt) {
                          return DropdownMenuItem<String>(
                            value: opt['en'],
                            child: Text(isFa ? opt['fa']! : opt['en']!),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedField = value;
                          });
                        },
                      ),
                      const SizedBox(height: 20),

                      // Educational Level Dropdown
                      DropdownButtonFormField<String>(
                        value: _selectedLevel,
                        style: TextStyle(color: AppColors.textPrimary, fontSize: 15),
                        dropdownColor: AppColors.surface,
                        decoration: InputDecoration(
                          labelText: loc.educationalLevel,
                          prefixIcon: Icon(Icons.grade_outlined, color: AppColors.textSecondary),
                        ),
                        items: _levelOptions.map((opt) {
                          return DropdownMenuItem<String>(
                            value: opt['en'],
                            child: Text(isFa ? opt['fa']! : opt['en']!),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedLevel = value;
                          });
                        },
                      ),
                      const SizedBox(height: 40),

                      // Submit button
                      ElevatedButton(
                        onPressed: isLoading ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: isLoading
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : Text(
                                loc.saveEnterApp,
                                style: textTheme.titleLarge?.copyWith(
                                  color: Colors.white,
                                  fontSize: 16,
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
