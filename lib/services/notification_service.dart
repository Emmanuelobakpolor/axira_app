import 'dart:convert';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_service.dart';

class AppNotification {
  final String id;
  final String title;
  final String body;
  final String type;
  final DateTime createdAt;
  bool isRead;

  AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.createdAt,
    this.isRead = false,
  });

  factory AppNotification.fromRemoteMessage(RemoteMessage message) {
    final data = message.data;
    final title = message.notification?.title ?? data['title'] ?? 'Axira update';
    final body = message.notification?.body ?? data['body'] ?? 'You have a new update.';
    final type = data['type'] ?? 'general';

    return AppNotification(
      id: message.messageId ?? DateTime.now().microsecondsSinceEpoch.toString(),
      title: title,
      body: body,
      type: type,
      createdAt: DateTime.now(),
      isRead: false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'body': body,
        'type': type,
        'createdAt': createdAt.toIso8601String(),
        'isRead': isRead,
      };

  factory AppNotification.fromJson(Map<String, dynamic> json) => AppNotification(
        id: json['id'] as String? ?? DateTime.now().microsecondsSinceEpoch.toString(),
        title: json['title'] as String? ?? 'Axira update',
        body: json['body'] as String? ?? '',
        type: json['type'] as String? ?? 'general',
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
        isRead: json['isRead'] as bool? ?? false,
      );
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  await NotificationService.instance.handleIncomingRemoteMessage(message);
}

const _kBaseUrl = 'https://web-production-b557d.up.railway.app/api';

class RemoteNotificationPayload {
  final String title;
  final String body;
  final String type;

  RemoteNotificationPayload({
    required this.title,
    required this.body,
    required this.type,
  });
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  static NotificationService get instance => _instance;

  static const String _storageKey = 'axira_notifications';
  static const String _fcmTokenKey = 'axira_fcm_token';

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  Future<void> initialize() async {
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
    } catch (e) {
      debugPrint('Firebase initialization failed: $e');
    }

    try {
      final settings = await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        final token = await _messaging.getToken();
        if (token != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_fcmTokenKey, token);
          await _registerDeviceToken(token);
          debugPrint('FCM token: $token');
        }
      }
    } catch (e) {
      debugPrint('FCM token setup failed: $e');
    }

    FirebaseMessaging.onMessage.listen((message) async {
      await handleIncomingRemoteMessage(message);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      debugPrint('Notification opened: ${message.data}');
    });

    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      await handleIncomingRemoteMessage(initialMessage, fromInitialLaunch: true);
    }
  }

  Future<void> _registerDeviceToken(String token) async {
    try {
      final headers = await AuthService.authHeaders();
      final res = await http.post(
        Uri.parse('$_kBaseUrl/notifications/device-token/'),
        headers: headers,
        body: jsonEncode({'token': token}),
      );
      if (res.statusCode >= 200 && res.statusCode < 300) {
        debugPrint('Device token registered successfully.');
      }
    } catch (_) {
      debugPrint('Could not register FCM token to backend.');
    }
  }

  Future<List<AppNotification>> fetchServerNotifications() async {
    try {
      final headers = await AuthService.authHeaders();
      final res = await http.get(
        Uri.parse('$_kBaseUrl/notifications/me/'),
        headers: headers,
      );
      if (res.statusCode != 200) {
        return const <AppNotification>[];
      }

      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final items = body['notifications'] as List? ?? const [];
      final notifications = items
          .map((e) => AppNotification(
                id: (e['id'] ?? DateTime.now().microsecondsSinceEpoch.toString()).toString(),
                title: e['title']?.toString() ?? 'Axira update',
                body: e['body']?.toString() ?? '',
                type: e['type']?.toString() ?? 'general',
                createdAt: DateTime.tryParse(e['created_at']?.toString() ?? '') ?? DateTime.now(),
                isRead: false,
              ))
          .toList();

      final local = await getNotifications();
      final merged = [...notifications, ...local];
      final unique = <String, AppNotification>{};
      for (final item in merged) {
        unique[item.id] = item;
      }

      final finalList = unique.values.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        _storageKey,
        finalList.map((item) => jsonEncode(item.toJson())).toList(),
      );
      return finalList;
    } catch (_) {
      return await getNotifications();
    }
  }

  Future<void> handleIncomingRemoteMessage(
    RemoteMessage message, {
    bool fromInitialLaunch = false,
  }) async {
    final notification = AppNotification.fromRemoteMessage(message);
    await saveNotification(notification);

    if (fromInitialLaunch) {
      debugPrint('App launched from push notification: ${message.data}');
    }
  }

  Future<void> saveNotification(AppNotification notification) async {
    final prefs = await SharedPreferences.getInstance();
    final notifications = await getNotifications();

    final existing = notifications.where((item) => item.id == notification.id).toList();
    if (existing.isNotEmpty) {
      return;
    }

    final updated = [notification, ...notifications];
    final encoded = updated
        .take(100)
        .map((item) => jsonEncode(item.toJson()))
        .toList();
    await prefs.setStringList(_storageKey, encoded);
  }

  Future<List<AppNotification>> getNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_storageKey) ?? const <String>[];
    final notifications = raw
        .map((item) => AppNotification.fromJson(jsonDecode(item) as Map<String, dynamic>))
        .toList();
    notifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return notifications;
  }

  Future<void> markAsRead(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final list = await getNotifications();
    final updated = list.map((item) {
      if (item.id == id) item.isRead = true;
      return item;
    }).toList();

    await prefs.setStringList(
      _storageKey,
      updated.map((item) => jsonEncode(item.toJson())).toList(),
    );
  }

  Future<void> markAllRead() async {
    final prefs = await SharedPreferences.getInstance();
    final items = await getNotifications();
    final updated = items.map((item) {
      item.isRead = true;
      return item;
    }).toList();

    await prefs.setStringList(
      _storageKey,
      updated.map((item) => jsonEncode(item.toJson())).toList(),
    );
  }

  Future<void> addManualNotification({
    required String title,
    required String body,
    String type = 'general',
  }) async {
    await saveNotification(
      AppNotification(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        title: title,
        body: body,
        type: type,
        createdAt: DateTime.now(),
      ),
    );
  }
}
