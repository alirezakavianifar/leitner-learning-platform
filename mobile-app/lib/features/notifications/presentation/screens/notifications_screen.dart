import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mobile_app/app/theme.dart';
import 'package:mobile_app/core/localization/app_localizations.dart';
import 'package:mobile_app/features/notifications/domain/entities/announcement.dart';
import 'package:mobile_app/features/notifications/domain/repositories/notifications_repository.dart';
import 'package:mobile_app/injection_container.dart' as di;

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({Key? key}) : super(key: key);

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late NotificationsRepository _notificationsRepository;
  List<Announcement> _announcements = [];
  Set<String> _readIds = {};
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _notificationsRepository = di.sl<NotificationsRepository>();
    _loadAnnouncements();
  }

  Future<void> _loadAnnouncements({bool force = false}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final data = await _notificationsRepository.getAnnouncements(forceRefresh: force);
      final readIds = await _notificationsRepository.getReadAnnouncementIds();
      if (mounted) {
        setState(() {
          _announcements = data;
          _readIds = readIds;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        final loc = AppLocalizations.of(context);
        setState(() {
          _errorMessage = loc.failedLoadNotifications;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _markAllAsRead() async {
    await _notificationsRepository.markAllAsRead();
    if (mounted) {
      final readIds = await _notificationsRepository.getReadAnnouncementIds();
      final loc = AppLocalizations.of(context);
      setState(() {
        _readIds = readIds;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(loc.allMarkedReadMsg),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _toggleItemRead(String id) async {
    if (!_readIds.contains(id)) {
      await _notificationsRepository.markAsRead(id);
      if (mounted) {
        final readIds = await _notificationsRepository.getReadAnnouncementIds();
        setState(() {
          _readIds = readIds;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final unreadCount = _announcements.where((a) => !_readIds.contains(a.id)).length;

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
          loc.notificationCenter,
          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
        ),
        actions: [
          if (_announcements.isNotEmpty && unreadCount > 0)
            TextButton.icon(
              onPressed: _markAllAsRead,
              icon: Icon(Icons.done_all, size: 18, color: AppColors.primary),
              label: Text(
                loc.markAllRead,
                style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        backgroundColor: AppColors.surface,
        onRefresh: () => _loadAnnouncements(force: true),
        child: _buildBody(loc),
      ),
    );
  }

  Widget _buildBody(AppLocalizations loc) {
    if (_isLoading && _announcements.isEmpty) {
      return Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (_errorMessage != null && _announcements.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.3),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, color: AppColors.error, size: 48),
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => _loadAnnouncements(force: true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.black,
                  ),
                  child: Text(loc.retry),
                ),
              ],
            ),
          ),
        ],
      );
    }

    if (_announcements.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.3),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.notifications_off_outlined, color: AppColors.textSecondary, size: 48),
                const SizedBox(height: 16),
                Text(
                  loc.noNotificationsFound,
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      itemCount: _announcements.length,
      itemBuilder: (context, index) {
        final item = _announcements[index];
        final isUnread = !_readIds.contains(item.id);
        final formattedDate = DateFormat.yMMMd().add_jm().format(item.publishedAt.toLocal());
        
        return InkWell(
          onTap: () => _toggleItemRead(item.id),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: isUnread
                  ? AppColors.primary.withOpacity(0.08)
                  : AppColors.surface.withOpacity(0.6),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isUnread ? AppColors.primary.withOpacity(0.5) : AppColors.border,
                width: isUnread ? 1.5 : 1.0,
              ),
            ),
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isUnread) ...[
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsetsDirectional.only(top: 6, end: 8),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                    Expanded(
                      child: Text(
                        item.title,
                        style: TextStyle(
                          color: isUnread ? AppColors.textPrimary : AppColors.textPrimary.withOpacity(0.85),
                          fontWeight: isUnread ? FontWeight.bold : FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    if (isUnread)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        margin: const EdgeInsets.only(left: 6, right: 6),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          loc.newBadge,
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    Text(
                      formattedDate,
                      style: TextStyle(
                        color: isUnread ? AppColors.primary : AppColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  item.content,
                  style: TextStyle(
                    color: isUnread ? AppColors.textPrimary.withOpacity(0.9) : AppColors.textSecondary,
                    height: 1.45,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

