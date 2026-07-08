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
import 'package:mobile_app/injection_container.dart' as di;

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late OfflineBackupService _backupService;
  final _passwordController = TextEditingController();
  double _fontScale = 1.0;
  List<FileSystemEntity> _backupFiles = [];
  bool _isLoadingBackups = true;

  @override
  void initState() {
    super.initState();
    _backupService = di.sl<OfflineBackupService>();
    _loadSettings();
    _loadBackupFiles();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final prefs = di.sl<SharedPreferences>();
    setState(() {
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
        SnackBar(content: const Text('Password must be at least 6 characters.'), backgroundColor: AppColors.error),
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
          SnackBar(content: const Text('Local database restored successfully!'), backgroundColor: AppColors.secondary),
        );
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

            // Section 0.2: Font Scaling Card
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
                      Icon(Icons.text_fields, color: AppColors.primary),
                      const SizedBox(width: 10),
                      Text(
                        isFa ? 'اندازه قلم فلش‌کارت‌ها' : 'Flashcard Font Size',
                        style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: Center(child: Text(isFa ? 'کوچک' : 'Small', style: TextStyle(color: _fontScale == 0.85 ? Colors.white : AppColors.textPrimary, fontWeight: FontWeight.bold))),
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
                          label: Center(child: Text(isFa ? 'معمولی' : 'Normal', style: TextStyle(color: _fontScale == 1.0 ? Colors.white : AppColors.textPrimary, fontWeight: FontWeight.bold))),
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
                          label: Center(child: Text(isFa ? 'بزرگ' : 'Large', style: TextStyle(color: _fontScale == 1.25 ? Colors.white : AppColors.textPrimary, fontWeight: FontWeight.bold))),
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
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }
}
