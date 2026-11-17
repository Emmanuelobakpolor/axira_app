import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/notification_service.dart';

const _kBlue = Color(0xFF0E24A0);
const _kDark = Color(0xFF111827);
const _kGrey = Color(0xFF9CA3AF);
const _kBg = Color(0xFFF2F4F8);

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final NotificationService _notificationService = NotificationService.instance;
  List<AppNotification> _notifications = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    final serverNotifications = await _notificationService.fetchServerNotifications();
    final localNotifications = await _notificationService.getNotifications();
    final merged = [...serverNotifications, ...localNotifications];
    final map = <String, AppNotification>{};
    for (final item in merged) {
      map[item.id] = item;
    }

    if (!mounted) return;
    setState(() {
      _notifications = map.values.toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _loading = false;
    });
  }

  Future<void> _markAsRead(String id) async {
    await _notificationService.markAsRead(id);
    await _loadNotifications();
  }

  Future<void> _markAllRead() async {
    await _notificationService.markAllRead();
    await _loadNotifications();
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = _notifications.where((n) => !n.isRead).length;

    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: _kDark),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            const Text(
              'Notifications',
              style: TextStyle(
                color: _kDark,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (unreadCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _kBlue,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$unreadCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: _loading ? null : _markAllRead,
            icon: const Icon(Icons.done_all, size: 20),
            label: const Text('Mark all read'),
            style: TextButton.styleFrom(foregroundColor: _kBlue),
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: _kBlue),
            )
          : _notifications.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.notifications_none, size: 80, color: _kGrey),
                      SizedBox(height: 16),
                      Text(
                        'No notifications yet',
                        style: TextStyle(fontSize: 18, color: _kDark),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  itemCount: _notifications.length,
                  itemBuilder: (context, index) {
                    final notification = _notifications[index];
                    return _NotificationCard(
                      notification: notification,
                      onTap: () async {
                        await _markAsRead(notification.id);
                        HapticFeedback.lightImpact();
                      },
                    );
                  },
                ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onTap;

  const _NotificationCard({
    required this.notification,
    required this.onTap,
  });

  Color _getIconColor() {
    switch (notification.type) {
      case 'transaction':
        return const Color(0xFF10B981);
      case 'security':
        return const Color(0xFFEF4444);
      case 'promotion':
        return _kBlue;
      default:
        return _kBlue;
    }
  }

  IconData _getIcon() {
    switch (notification.type) {
      case 'transaction':
        return Icons.swap_horiz_rounded;
      case 'security':
        return Icons.security_outlined;
      case 'promotion':
        return Icons.campaign_outlined;
      default:
        return Icons.notifications_none_rounded;
    }
  }

  String _formatTime(DateTime createdAt) {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hr ago';
    if (diff.inDays < 7) return '${diff.inDays} day ago';
    return '${createdAt.day}/${createdAt.month}/${createdAt.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: !notification.isRead
                  ? Border.all(color: _kBlue.withOpacity(0.2))
                  : null,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _getIconColor().withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(_getIcon(), color: _getIconColor(), size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              notification.title,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: notification.isRead
                                    ? FontWeight.w500
                                    : FontWeight.w600,
                                color: _kDark,
                              ),
                            ),
                          ),
                          Text(
                            _formatTime(notification.createdAt),
                            style: const TextStyle(
                              fontSize: 12,
                              color: _kGrey,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        notification.body,
                        style: const TextStyle(
                          fontSize: 14,
                          color: _kGrey,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!notification.isRead)
                  Container(
                    margin: const EdgeInsets.only(left: 8, top: 4),
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: _kBlue,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}