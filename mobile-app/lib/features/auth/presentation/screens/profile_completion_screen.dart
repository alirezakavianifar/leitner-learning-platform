import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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
  final _interestsController = TextEditingController();
  final _fieldController = TextEditingController();
  final _levelController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _phoneController = TextEditingController(text: widget.mobileNumber);
    // Seed default username
    _usernameController.text = 'Student_${widget.mobileNumber.substring(widget.mobileNumber.length - 4)}';
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _usernameController.dispose();
    _interestsController.dispose();
    _fieldController.dispose();
    _levelController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      context.read<AuthBloc>().add(
            UpdateProfileEvent(
              username: _usernameController.text.trim(),
              interests: _interestsController.text.trim().isNotEmpty ? _interestsController.text.trim() : null,
              educationalField: _fieldController.text.trim().isNotEmpty ? _fieldController.text.trim() : null,
              educationalLevel: _levelController.text.trim().isNotEmpty ? _levelController.text.trim() : null,
            ),
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final loc = AppLocalizations.of(context);

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
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
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
                      const SizedBox(height: 48),

                      // Read-only Phone Number
                      TextFormField(
                        controller: _phoneController,
                        enabled: false, // Strictly locked/read-only
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
                            return loc.username;
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      // Interests
                      TextFormField(
                        controller: _interestsController,
                        style: TextStyle(color: AppColors.textPrimary),
                        decoration: InputDecoration(
                          labelText: loc.interests,
                          prefixIcon: Icon(Icons.interests_outlined, color: AppColors.textSecondary),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Educational Field
                      TextFormField(
                        controller: _fieldController,
                        style: TextStyle(color: AppColors.textPrimary),
                        decoration: InputDecoration(
                          labelText: loc.educationalField,
                          prefixIcon: Icon(Icons.school_outlined, color: AppColors.textSecondary),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Educational Level
                      TextFormField(
                        controller: _levelController,
                        style: TextStyle(color: AppColors.textPrimary),
                        decoration: InputDecoration(
                          labelText: loc.educationalLevel,
                          prefixIcon: Icon(Icons.grade_outlined, color: AppColors.textSecondary),
                        ),
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
