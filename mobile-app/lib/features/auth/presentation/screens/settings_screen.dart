import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as p;
import 'package:mobile_app/app/theme.dart';
import 'package:mobile_app/app/theme_bloc.dart';
import 'package:mobile_app/core/localization/app_localizations.dart';
import 'package:mobile_app/core/localization/locale_bloc.dart';
import 'package:mobile_app/core/services/backup_service.dart';
import 'package:mobile_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:mobile_app/features/auth/presentation/bloc/auth_event.dart';
import 'package:mobile_app/injection_container.dart' as di;

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late OfflineBackupService _backupService;
  final _passwordController = TextEditingController();
  final _usernameController = TextEditingController();
  
  String _mobileNumber = '';
  String _educationalField = 'General';
  String _educationalLevel = 'Learner';
  double _fontScale = 1.0;

  List<FileSystemEntity> _backupFiles = [];
  bool _isLoadingBackups = true;
  bool _isSavingProfile = false;

  @override
  void initState() {
    super.initState();
    _backupService = di.sl<OfflineBackupService>();
    _loadProfile();
    _loadBackupFiles();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final prefs = di.sl<SharedPreferences>();
    setState(() {
      _usernameController.text = prefs.getString('user_username') ?? '';
      _mobileNumber = prefs.getString('user_mobile_number') ?? '';
      _educationalField = prefs.getString('user_educational_field') ?? 'General';
      _educationalLevel = prefs.getString('user_educational_level') ?? 'Learner';
      _fontScale = prefs.getDouble('flashcard_font_scale') ?? 1.0;
    });
  }

  Future<void> _changeFontScale(double scale) async {
    final prefs = di.sl<SharedPreferences>();
    await prefs.setDouble('flashcard_font_scale', scale);
    setState(() {
      _fontScale = scale;
    });
  }

  Future<void> _saveProfile() async {
    setState(() => _isSavingProfile = true);
    final prefs = di.sl<SharedPreferences>();
    await prefs.setString('user_username', _usernameController.text.trim());
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Profile updated successfully!'), backgroundColor: AppColors.secondary),
    );
    setState(() => _isSavingProfile = false);
  }

  Future<void> _loadBackupFiles() async {
    setState(() => _isLoadingBackups = true);
    try {
      final dirPath = await _backupService.getBackupsDirectoryPath();
      final dir = Directory(dirPath);
      if (dir.existsSync()) {
        final list = dir.listSync().where((f) => f.path.endsWith('.enc')).toList();
        list.sort((a, b) => b.path.compareTo(a.path)); // Latest first
        setState(() {
          _backupFiles = list;
        });
      }
    } catch (_) {}
    setState(() => _isLoadingBackups = false);
  }

  Future<void> _exportBackup() async {
    final password = _passwordController.text;
    if (password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Password must be at least 6 characters.'), backgroundColor: AppColors.error),
      );
      return;
    }

    try {
      final path = await _backupService.exportBackup(password);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Backup exported successfully: ${p.basename(path)}'),
          backgroundColor: AppColors.secondary,
        ),
      );
      _passwordController.clear();
      _loadBackupFiles();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Backup failed: $e'), backgroundColor: AppColors.error),
      );
    }
  }

  Future<void> _restoreBackup(String filePath) async {
    final password = await showDialog<String>(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text('Enter Backup Password', style: TextStyle(color: AppColors.textPrimary)),
          content: TextField(
            controller: controller,
            obscureText: true,
            style: TextStyle(color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Enter password used during export',
              hintStyle: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: () => Navigator.pop(context, controller.text),
              child: const Text('Restore'),
            ),
          ],
        );
      },
    );

    if (password == null || password.isEmpty) return;

    try {
      final success = await _backupService.importBackup(filePath, password);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Local database restored successfully!'), backgroundColor: AppColors.secondary),
        );
        _loadProfile();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Restore failed: ${e.toString()}'), backgroundColor: AppColors.error),
      );
    }
  }

  Future<void> _deleteBackup(String filePath) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Delete Backup', style: TextStyle(color: AppColors.textPrimary)),
        content: Text('Are you sure you want to delete this backup file?', style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      File(filePath).deleteSync();
      _loadBackupFiles();
    }
  }

  void _showLogoutConfirmation() {
    final loc = AppLocalizations.of(context);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: AppColors.border),
          ),
          title: Text(
            loc.logout,
            style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
          ),
          content: Text(
            loc.logoutConfirm,
            style: TextStyle(color: AppColors.textSecondary, height: 1.4),
          ),
          actions: [
            TextButton(
              style: TextButton.styleFrom(
                backgroundColor: const Color(0xFF333E56).withOpacity(0.4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () => Navigator.pop(dialogContext),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Text(loc.cancel, style: TextStyle(color: AppColors.textPrimary)),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () {
                Navigator.pop(dialogContext); // Close modal
                context.read<AuthBloc>().add(LogoutEvent()); // Trigger logout
                Navigator.pop(context); // Close settings screen
              },
              child: Text(loc.confirm, style: const TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
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
          loc.settings,
          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Section 0: Language Selection Card
            BlocBuilder<LocaleBloc, LocaleState>(
              builder: (context, localeState) {
                final isFa = localeState.locale.languageCode == 'fa';
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.primary.withOpacity(0.4)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.language, color: AppColors.primary),
                          const SizedBox(width: 10),
                          Text(
                            loc.language,
                            style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ChoiceChip(
                              label: Center(child: Text(loc.persian, style: TextStyle(color: isFa ? Colors.white : AppColors.textPrimary, fontWeight: FontWeight.bold))),
                              selected: isFa,
                              selectedColor: AppColors.primary,
                              backgroundColor: AppColors.background,
                              onSelected: (selected) {
                                if (selected) {
                                  context.read<LocaleBloc>().add(ChangeLocaleEvent(const Locale('fa')));
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ChoiceChip(
                              label: Center(child: Text(loc.english, style: TextStyle(color: !isFa ? Colors.white : AppColors.textPrimary, fontWeight: FontWeight.bold))),
                              selected: !isFa,
                              selectedColor: AppColors.primary,
                              backgroundColor: AppColors.background,
                              onSelected: (selected) {
                                if (selected) {
                                  context.read<LocaleBloc>().add(ChangeLocaleEvent(const Locale('en')));
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 16),

            // Section 0.1: Theme Selection Card
            BlocBuilder<ThemeBloc, ThemeState>(
              builder: (context, themeState) {
                final isFa = Localizations.localeOf(context).languageCode == 'fa';
                final isLight = themeState.themeMode == ThemeMode.light;
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.primary.withOpacity(0.4)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.palette_outlined, color: AppColors.primary),
                          const SizedBox(width: 10),
                          Text(
                            isFa ? 'پوسته برنامه' : 'App Theme',
                            style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ChoiceChip(
                              label: Center(
                                child: Text(
                                  isFa ? 'تیره' : 'Dark Mode',
                                  style: TextStyle(
                                    color: !isLight ? Colors.white : AppColors.textPrimary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              selected: !isLight,
                              selectedColor: AppColors.primary,
                              backgroundColor: AppColors.background,
                              onSelected: (selected) {
                                if (selected) {
                                  context.read<ThemeBloc>().add(ChangeThemeEvent(ThemeMode.dark));
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ChoiceChip(
                              label: Center(
                                child: Text(
                                  isFa ? 'روشن' : 'Light Mode',
                                  style: TextStyle(
                                    color: isLight ? Colors.white : AppColors.textPrimary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              selected: isLight,
                              selectedColor: AppColors.primary,
                              backgroundColor: AppColors.background,
                              onSelected: (selected) {
                                if (selected) {
                                  context.read<ThemeBloc>().add(ChangeThemeEvent(ThemeMode.light));
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 16),

            // Section 0.2: Font Size Adjustment Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface.withOpacity(0.6),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primary.withOpacity(0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.format_size, color: AppColors.primary),
                      const SizedBox(width: 10),
                      Text(
                        Localizations.localeOf(context).languageCode == 'fa'
                            ? 'اندازه قلم فلش‌کارت‌ها'
                            : 'Flashcard Font Size',
                        style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: Center(
                            child: Text(
                              Localizations.localeOf(context).languageCode == 'fa' ? 'کوچک' : 'Small',
                              style: TextStyle(
                                color: _fontScale == 0.85 ? Colors.white : AppColors.textPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          selected: _fontScale == 0.85,
                          selectedColor: AppColors.primary,
                          backgroundColor: AppColors.background,
                          onSelected: (selected) {
                            if (selected) _changeFontScale(0.85);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ChoiceChip(
                          label: Center(
                            child: Text(
                              Localizations.localeOf(context).languageCode == 'fa' ? 'معمولی' : 'Medium',
                              style: TextStyle(
                                color: _fontScale == 1.0 ? Colors.white : AppColors.textPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          selected: _fontScale == 1.0,
                          selectedColor: AppColors.primary,
                          backgroundColor: AppColors.background,
                          onSelected: (selected) {
                            if (selected) _changeFontScale(1.0);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ChoiceChip(
                          label: Center(
                            child: Text(
                              Localizations.localeOf(context).languageCode == 'fa' ? 'بزرگ' : 'Large',
                              style: TextStyle(
                                color: _fontScale == 1.25 ? Colors.white : AppColors.textPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          selected: _fontScale == 1.25,
                          selectedColor: AppColors.primary,
                          backgroundColor: AppColors.background,
                          onSelected: (selected) {
                            if (selected) _changeFontScale(1.25);
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Section 1: Profile Editing
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
            TextFormField(
              initialValue: '$_educationalField • $_educationalLevel',
              enabled: false,
              style: TextStyle(color: AppColors.textSecondary),
              decoration: InputDecoration(
                labelText: loc.educationalField,
                labelStyle: TextStyle(color: AppColors.textSecondary),
                disabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: AppColors.border.withOpacity(0.3)),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),
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
            const SizedBox(height: 32),

            // Section 2: Backup & Restore
            Text(
              loc.offlineBackupRestore,
              style: TextStyle(color: AppColors.primary, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.secondary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.secondary.withOpacity(0.3)),
              ),
              child: Text(
                loc.backupDesc,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.4),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _passwordController,
              obscureText: true,
              style: TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                labelText: loc.backupEncryptionPassword,
                labelStyle: TextStyle(color: AppColors.textSecondary),
                hintText: 'Minimum 6 characters',
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
            const SizedBox(height: 12),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.secondary,
                foregroundColor: AppColors.background,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _exportBackup,
              icon: const Icon(Icons.download),
              label: Text(loc.exportNewBackup, style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 24),

            Text(
              loc.availableBackups,
              style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 8),
            _isLoadingBackups
                ? Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _backupFiles.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12.0),
                        child: Text(loc.noBackupsFound, style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _backupFiles.length,
                        itemBuilder: (context, index) {
                          final file = _backupFiles[index];
                          final filename = p.basename(file.path);
                          return Card(
                            color: AppColors.surface.withOpacity(0.4),
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              title: Text(filename, style: TextStyle(color: AppColors.textPrimary, fontSize: 13)),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: Icon(Icons.settings_backup_restore, color: AppColors.primary),
                                    onPressed: () => _restoreBackup(file.path),
                                    tooltip: 'Restore from this backup',
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.delete, color: AppColors.error),
                                    onPressed: () => _deleteBackup(file.path),
                                    tooltip: 'Delete backup file',
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
            const SizedBox(height: 40),

            // Section 3: Logout
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error.withOpacity(0.15),
                foregroundColor: AppColors.error,
                side: BorderSide(color: AppColors.error, width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _showLogoutConfirmation,
              icon: const Icon(Icons.logout),
              label: Text(loc.logoutAccount, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
