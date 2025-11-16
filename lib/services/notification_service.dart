// lib/services/notification_service.dart

import 'dart:convert'; // --- FIX: Import dart:convert for jsonDecode ---
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../screens/main_conversation_screen.dart';
import '../main.dart'; // --- FIX: Import main.dart to access the global navigatorKey ---
import 'api_service.dart';

class NotificationService {
  // --- NEW: Instance for standard notifications ---
  static final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  NotificationService();

  Future<void> initialize() async {
    // Initialize the local notifications plugin for our fallback
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);
    await _localNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onDidReceiveNotificationResponse,
      onDidReceiveBackgroundNotificationResponse:
          _onDidReceiveBackgroundNotificationResponse,
    );

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print(
          "[NotificationService] Foreground message received: ${message.messageId}");
      print("[NotificationService] Foreground Payload: ${message.data}");

      if (message.data['type'] == 'incoming_call') {
        // When in foreground, show the heads-up notification with buttons.
        _showStandardIncomingCallNotification(message);
      }
    });

    FirebaseMessaging.instance
        .getInitialMessage()
        .then((RemoteMessage? message) {
      if (message != null) {
        print(
            "[NotificationService] App opened from terminated state by message: ${message.messageId}");
      }
    });
  }

  // --- NEW: Handlers for local notification button taps ---
  @pragma('vm:entry-point')
  static void _onDidReceiveBackgroundNotificationResponse(
      NotificationResponse notificationResponse) {
    print(
        "[Notification] Background action tapped: ${notificationResponse.actionId}");
    _handleNotificationAction(notificationResponse);
  }

  void _onDidReceiveNotificationResponse(
      NotificationResponse notificationResponse) {
    print(
        "[Notification] Foreground action tapped: ${notificationResponse.actionId}");
    _handleNotificationAction(notificationResponse);
  }

  static void _handleNotificationAction(
      NotificationResponse notificationResponse) {
    final payload = jsonDecode(notificationResponse.payload ?? '{}');
    final String callId = payload['call_id'] ?? '';
    final String userPhone = payload['user_phone'] ?? '';
    final String description = payload['description'] ?? '';

    if (notificationResponse.actionId == 'answer_action') {
      print("[Notification] User chose to ANSWER the call.");
      // Since this is a static method, we create a new ApiService instance.
      ApiService().answerCall(userPhone, callId);
      navigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(
            builder: (_) => MainConversationScreen(
                userPhone: userPhone, initialMessage: description)),
        (route) => false,
      );
    } else if (notificationResponse.actionId == 'decline_action') {
      print("[Notification] User chose to DECLINE the call.");
      // Since this is a static method, we create a new ApiService instance.
      ApiService().declineCall(userPhone, callId);
    }
  }

  // This function now handles all incoming call notifications.
  static Future<void> _showStandardIncomingCallNotification(
      RemoteMessage message) async {
    print("[Notification] Attempting to show call-style notification...");
    try {
      const AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
        'memora_incoming_call_channel', // A unique channel ID for calls
        'Incoming Calls', // A channel name
        channelDescription: 'Channel for incoming call notifications.',
        importance: Importance.max,
        priority: Priority.high,
        showWhen: true,
        // --- IMPLEMENTING THE EXPLANATION ---
        category: AndroidNotificationCategory.call, // Mark as a call
        fullScreenIntent: true, // This is the key for locked screens
        // ---
        actions: <AndroidNotificationAction>[
          AndroidNotificationAction(
            'answer_action',
            'Answer',
            showsUserInterface: true,
          ),
          AndroidNotificationAction(
            'decline_action',
            'Decline',
          ),
        ],
      );
      const NotificationDetails platformChannelSpecifics =
          NotificationDetails(android: androidPlatformChannelSpecifics);

      await _localNotificationsPlugin.show(
        message.hashCode,
        message.data['caller_name'] ?? 'Incoming Call',
        'Tap to answer or decline.',
        platformChannelSpecifics,
        payload: jsonEncode(message.data),
      );
      print("[Notification] Call-style notification shown successfully.");
    } catch (e) {
      print("[Notification] FAILED to show call-style notification: $e");
    }
  }

  @pragma('vm:entry-point')
  static Future<void> processBackgroundMessage(RemoteMessage message) async {
    await Firebase.initializeApp();
    print(
        "[NotificationService] Background handler processing message: ${message.messageId}");
    print("[NotificationService] Background Payload: ${message.data}");

    if (message.data['type'] == 'incoming_call') {
      // Always attempt to show the call-style notification.
      // The OS will decide how to display it (full-screen or heads-up).
      await _showStandardIncomingCallNotification(message);
    }
  }
}
