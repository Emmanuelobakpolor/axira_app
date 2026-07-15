import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const _kBlue = Color(0xFF0E24A0);const _kDark = Color(0xFF111827);
const _kGrey = Color(0xFF9CA3AF);
const _kBg = Color(0xFFF2F4F8);

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  // Sample notifications - replace with real data later
  final List<NotificationItem> _notifications = [
    NotificationItem(
      id: 1,
      title: 'Transaction Successful',
      body: 'Your withdrawal of 0.045 BTC to wallet ****7890 was successful.',
      time: '2 min ago',
      type: NotificationType.transaction,
      isRead: false,
    ),
    NotificationItem(
      id: 2,
      title: 'Security Alert',
      body: 'New login detected from Lagos, Nigeria on your account.',
      time: '1 hour ago',
      type: NotificationType.security,
      isRead: false,
    ),
    NotificationItem(
      id: 3,
      title: 'Welcome Bonus',
      body: 'You just received N4000 welcome bonus. Start trading now!',
      time: 'Yesterday',
      type: NotificationType.promotion,
      isRead: true,
    ),
    NotificationItem(
      id: 4,
      title: 'Deposit Confirmed',
      body: 'Your deposit of ₦250,000 has been credited to your wallet.',
      time: 'Yesterday',
      type: NotificationType.transaction,
      isRead: true,
    ),
  ];

  void _markAsRead(int id) {
    setState(() {
      final index = _notifications.indexWhere((n) => n.id == id);
      if (index != -1) _notifications[index].isRead = true;
    });
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
            onPressed: () {
              setState(() {
                for (var n in _notifications) {
                  n.isRead = true;
                }
              });
              HapticFeedback.lightImpact();
            },
            icon: const Icon(Icons.done_all, size: 20),
            label: const Text('Mark all read'),
            style: TextButton.styleFrom(foregroundColor: _kBlue),
          ),
        ],
      ),
      body: _notifications.isEmpty
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
                  onTap: () {
                    _markAsRead(notification.id);
                    HapticFeedback.lightImpact();
                    // TODO: Navigate to detail or perform action
                  },
                );
              },
            ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final NotificationItem notification;
  final VoidCallback onTap;

  const _NotificationCard({
    required this.notification,
    required this.onTap,
  });

  Color _getIconColor() {
    switch (notification.type) {
      case NotificationType.transaction:
        return const Color(0xFF10B981);
      case NotificationType.security:
        return const Color(0xFFEF4444);
      case NotificationType.promotion:
        return _kBlue;
    }
  }

  IconData _getIcon() {
    switch (notification.type) {
      case NotificationType.transaction:
        return Icons.swap_horiz_rounded;
      case NotificationType.security:
        return Icons.security_outlined;
      case NotificationType.promotion:
        return Icons.campaign_outlined;
    }
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
                  ? Border.all(color: _kBlue.withValues(alpha: 0.2))
                  : null,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _getIconColor().withValues(alpha: 0.1),
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
                            notification.time,
                            style: TextStyle(
                              fontSize: 12,
                              color: _kGrey,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        notification.body,
                        style: TextStyle(
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

enum NotificationType { transaction, security, promotion }

class NotificationItem {
  final int id;
  final String title;
  final String body;
  final String time;
  final NotificationType type;
  bool isRead;

  NotificationItem({
    required this.id,
    required this.title,
    required this.body,
    required this.time,
    required this.type,
    required this.isRead,
  });
}