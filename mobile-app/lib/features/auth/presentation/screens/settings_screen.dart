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
import 'package:mobile_app/core/services/review_notification_scheduler.dart';
import 'package:mobile_app/core/error/error_formatter.dart';
import 'package:mobile_app/injection_container.dart' as di;

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late OfflineBackupService _backupService;
  late ReviewNotificationScheduler _notificationScheduler;
  final _passwordController = TextEditingController();
  double _fontScale = 1.0;
  List<FileSystemEntity> _backupFiles = [];
  bool _isLoadingBackups = true;
  bool _notificationsEnabled = true;
  bool _dailyReminderEnabled = true;
  TimeOfDay _reminderTime = const TimeOfDay(hour: 20, minute: 0);

  final List<Map<String, dynamic>> _premiumPalettes = const [
    {
      'name_en': 'Purple Indigo',
      'name_fa': 'ارغوانی بنفش',
      'primary': 0xFF6B4EE6,
      'secondary': 0xFF09E5C3,
    },
    {
      'name_en': 'Emerald Ocean',
      'name_fa': 'سبز زمردی',
      'primary': 0xFF00A86B,
      'secondary': 0xFF00E5FF,
    },
    {
      'name_en': 'Classic Tech',
      'name_fa': 'آبی کلاسیک',
      'primary': 0xFF1A9CFF,
      'secondary': 0xFF00F5D4,
    },
    {
      'name_en': 'Crimson Rose',
      'name_fa': 'سرخ گل‌بهی',
      'primary': 0xFFF43F5E,
      'secondary': 0xFFFF7A1A,
    },
    {
      'name_en': 'Midnight Royal',
      'name_fa': 'پوسته سلطنتی',
      'primary': 0xFF3F51B5,
      'secondary': 0xFFE040FB,
    },
  ];

  @override
  void initState() {
    super.initState();
    _backupService = di.sl<OfflineBackupService>();
    _notificationScheduler = di.sl<ReviewNotificationScheduler>();
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
      _notificationsEnabled = _notificationScheduler.areNotificationsEnabled;
      _dailyReminderEnabled = _notificationScheduler.isDailyReminderEnabled;
      _reminderTime = TimeOfDay(
        hour: _notificationScheduler.dailyReminderHour,
        minute: _notificationScheduler.dailyReminderMinute,
      );
    });
  }

  Future<void> _toggleNotifications(bool value) async {
    await _notificationScheduler.setNotificationsEnabled(value);
    setState(() {
      _notificationsEnabled = value;
    });
  }

  Future<void> _toggleDailyReminder(bool value) async {
    await _notificationScheduler.setDailyReminderEnabled(value);
    setState(() {
      _dailyReminderEnabled = value;
    });
  }

  Future<void> _pickReminderTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _reminderTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: AppColors.primary,
              surface: AppColors.surface,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      await _notificationScheduler.setDailyReminderTime(picked.hour, picked.minute);
      setState(() {
        _reminderTime = picked;
      });
    }
  }

  Future<void> _sendTestNotification() async {
    final isFa = Localizations.localeOf(context).languageCode == 'fa';
    await _notificationScheduler.sendTestNotification(isPersian: isFa);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).testNotificationSent),
          backgroundColor: AppColors.secondary,
        ),
      );
    }
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
    final loc = AppLocalizations.of(context);
    final password = _passwordController.text;
    if (password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.translate('password_length_warning')), backgroundColor: AppColors.error),
      );
      return;
    }

    try {
      final loc = AppLocalizations.of(context);
      final path = await _backupService.exportBackup(password);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(loc.translate('backup_success_msg').replaceAll('{filename}', p.basename(path))),
          backgroundColor: AppColors.secondary,
        ),
      );
      _passwordController.clear();
      _loadBackupFiles();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppErrorFormatter.formatError(e, context: context)),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _restoreBackup(String filePath) async {
    final loc = AppLocalizations.of(context);
    final isFa = Localizations.localeOf(context).languageCode == 'fa';
    final password = await showDialog<String>(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text(loc.translate('enter_backup_password'), style: TextStyle(color: AppColors.textPrimary)),
          content: TextField(
            controller: controller,
            obscureText: true,
            style: TextStyle(color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: isFa ? 'رمز عبور صادر شده را وارد کنید' : 'Enter password used during export',
              hintStyle: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(loc.cancel, style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => Navigator.pop(context, controller.text),
              child: Text(
                loc.translate('restore_db'),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
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
          SnackBar(content: Text(loc.translate('database_restored_success')), backgroundColor: AppColors.secondary),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppErrorFormatter.formatError(e, context: context)),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _deleteBackup(String filePath) async {
    final loc = AppLocalizations.of(context);
    final isFa = Localizations.localeOf(context).languageCode == 'fa';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(loc.translate('delete_backup_title'), style: TextStyle(color: AppColors.textPrimary)),
        content: Text(loc.translate('delete_backup_confirm'), style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(loc.cancel, style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              isFa ? 'حذف' : 'Delete',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
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
                      const SizedBox(height: 16),
                      Divider(color: AppColors.primary.withOpacity(0.2)),
                      const SizedBox(height: 12),
                      Text(
                        isFa ? 'رنگ تم برنامه' : 'Accent Color Theme',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 54,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: _premiumPalettes.map((palette) {
                            final isSelected = AppColors.primary.value == palette['primary'];
                            return Padding(
                              padding: const EdgeInsets.only(right: 12),
                              child: GestureDetector(
                                onTap: () {
                                  context.read<ThemeBloc>().add(
                                    ChangePrimaryColorEvent(
                                      primaryColorHex: palette['primary'],
                                      secondaryColorHex: palette['secondary'],
                                    ),
                                  );
                                },
                                child: Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Color(palette['primary']),
                                        Color(palette['secondary']),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isSelected
                                          ? AppColors.textPrimary
                                          : Colors.transparent,
                                      width: 3,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Color(palette['primary']).withOpacity(0.3),
                                        blurRadius: 6,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: isSelected
                                      ? Icon(
                                          Icons.check,
                                          color: Colors.white,
                                          shadows: [
                                            Shadow(
                                              blurRadius: 3,
                                              color: Colors.black.withOpacity(0.5),
                                              offset: const Offset(0, 1),
                                            ),
                                          ],
                                        )
                                      : null,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
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
            const SizedBox(height: 16),

            // Section 0.3: Reminders & Notifications Card
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
                      Icon(Icons.notifications_active_outlined, color: AppColors.primary),
                      const SizedBox(width: 10),
                      Text(
                        loc.remindersAndNotifications,
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Toggle: Card Review Notifications
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    activeThumbColor: AppColors.primary,
                    title: Text(
                      loc.cardReviewNotifications,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      loc.cardReviewNotificationsDesc,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    value: _notificationsEnabled,
                    onChanged: _toggleNotifications,
                  ),
                  if (_notificationsEnabled) ...[
                    Divider(color: AppColors.primary.withOpacity(0.2)),
                    // Toggle: Daily Study Reminder
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      activeThumbColor: AppColors.primary,
                      title: Text(
                        loc.dailyStudyReminder,
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        loc.dailyStudyReminderDesc,
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      value: _dailyReminderEnabled,
                      onChanged: _toggleDailyReminder,
                    ),
                    if (_dailyReminderEnabled) ...[
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            loc.reminderTime,
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 14,
                            ),
                          ),
                          InkWell(
                            onTap: _pickReminderTime,
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppColors.primary.withOpacity(0.4)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.access_time, size: 16, color: AppColors.primary),
                                  const SizedBox(width: 6),
                                  Text(
                                    '${_reminderTime.hour.toString().padLeft(2, '0')}:${_reminderTime.minute.toString().padLeft(2, '0')}',
                                    style: TextStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 14),
                    // Button: Send Test Notification
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: BorderSide(color: AppColors.primary.withOpacity(0.6)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                      ),
                      onPressed: _sendTestNotification,
                      icon: const Icon(Icons.send_outlined, size: 18),
                      label: Text(
                        loc.sendTestNotification,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  ],
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
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _exportBackup,
              icon: const Icon(Icons.download, color: Colors.white),
              label: Text(
                loc.exportNewBackup,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
              ),
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
