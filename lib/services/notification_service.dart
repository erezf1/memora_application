// lib/services/notification_service.dart

import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../main.dart'; // for navigatorKey

class NotificationService {
  NotificationService._(); // private constructor

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  /// Call once from main() in the foreground isolate.
  static Future<void> initialize() async {
    // --- Local notifications initialization ---
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');

    const initSettings = InitializationSettings(
      android: androidInit,
    );

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );

    // --- FCM foreground & tap handlers ---
    FirebaseMessaging.onMessage.listen(_onForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpenedApp);

    // If the app was launched by tapping a notification
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      _handleRemoteMessage(initialMessage, source: 'launch');
    }
  }

  // ============================================================
  // FCM BACKGROUND HANDLER
  // ============================================================
  /// This is referenced in main.dart as:
  /// FirebaseMessaging.onBackgroundMessage(NotificationService.firebaseMessagingBackgroundHandler);
  @pragma('vm:entry-point')
  static Future<void> firebaseMessagingBackgroundHandler(
    RemoteMessage message,
  ) async {
    // Ensure Firebase is ready in the background isolate.
    await Firebase.initializeApp();

    // Initialize local notifications (no tap callback needed here).
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await _plugin.initialize(initSettings);

    _handleRemoteMessage(message, source: 'background');
  }

  // ============================================================
  // FCM MESSAGE ROUTING
  // ============================================================
  static void _onForegroundMessage(RemoteMessage message) {
    _handleRemoteMessage(message, source: 'foreground');
  }

  static void _onMessageOpenedApp(RemoteMessage message) {
    _handleRemoteMessage(message, source: 'opened_app');
  }

  /// Central place to interpret incoming FCM messages.
  static void _handleRemoteMessage(
    RemoteMessage message, {
    required String source,
  }) {
    final data = message.data;
    final type = data['type'];

    // Debug logs (you can keep or remove)
    // print('[NotificationService] FCM from $source: ${message.messageId}');
    // print('[NotificationService] data: $data');

    if (type == 'incoming_call') {
      final callerName = data['callerName'] ?? 'Unknown';
      final callId = data['callId'] ?? '';

      _showIncomingCallNotification(
        callerName: callerName,
        callId: callId,
      );
    } else {
      // Handle other notification types if needed
      final title = data['title'] ?? 'Memora';
      final body = data['body'] ?? 'You have a new notification';

      _showBasicNotification(title: title, body: body);
    }
  }

  // ============================================================
  // LOCAL NOTIFICATION HELPERS
  // ============================================================

  /// Simple notification (no full-screen).
  static Future<void> _showBasicNotification({
    required String title,
    required String body,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'memora_basic_channel',
      'Memora Notifications',
      channelDescription: 'General Memora notifications',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );

    const details = NotificationDetails(android: androidDetails);

    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000, // unique ID
      title,
      body,
      details,
    );
  }

  /// Full-screen incoming call notification.
  static Future<void> _showIncomingCallNotification({
    required String callerName,
    required String callId,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'memora_incoming_call_channel',
      'Incoming Calls',
      channelDescription: 'Memora incoming call notifications',
      importance: Importance.max,
      priority: Priority.high,
      category: AndroidNotificationCategory.call,
      fullScreenIntent: true, // 💥 key flag to get call-style behavior
      autoCancel: false,
      ongoing: true,
    );

    const details = NotificationDetails(android: androidDetails);

    final payload = jsonEncode({
      'type': 'incoming_call',
      'callerName': callerName,
      'callId': callId,
    });

    await _plugin.show(
      9999, // fixed ID for the active call
      'Incoming call',
      callerName,
      details,
      payload: payload,
    );
  }

  /// Cancel the active incoming call notification.
  static Future<void> cancelIncomingCallNotification() async {
    await _plugin.cancel(9999);
  }

  // ============================================================
  // TAP HANDLER
  // ============================================================

  static void _onNotificationResponse(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;

    final data = jsonDecode(payload) as Map<String, dynamic>;
    final type = data['type'];

    if (type == 'incoming_call') {
      final callerName = data['callerName'] as String? ?? 'Unknown';
      final callId = data['callId'] as String? ?? '';

      // Navigate to the dedicated incoming call screen.
      // This uses the global navigatorKey from main.dart.
      navigatorKey.currentState?.pushNamed(
        '/incoming_call',
        arguments: {
          'callerName': callerName,
          'callId': callId,
        },
      );
    }
  }
}
