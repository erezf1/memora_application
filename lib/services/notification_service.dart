// lib/services/notification_service.dart

import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/services.dart';

import '../main.dart';
import '../screens/incoming_call_screen.dart';
import '../screens/main_conversation_screen.dart';
import 'api_service.dart';

const String _incomingCallChannelId = 'memora_incoming_call_channel';
const String _incomingCallChannelName = 'Memora Incoming Calls';
const String _incomingCallChannelDescription =
    'High priority incoming-call style notifications for Memora';
const int _incomingCallNotificationId = 1001;

const String _answerActionId = 'ANSWER_ACTION';
const String _declineActionId = 'DECLINE_ACTION';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('[NotificationService] BG handler start');
  await Firebase.initializeApp();
  await NotificationService.instance._ensureLocalNotificationsInitialized();
  await NotificationService.instance
      ._handleRemoteMessage(message, source: 'background');
  debugPrint('[NotificationService] BG handler end');
}

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) {
  NotificationService.instance.handleNotificationResponse(response);
}

class NotificationService {
  NotificationService._internal();
  static final NotificationService instance = NotificationService._internal();

  final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    await _ensureLocalNotificationsInitialized();

    FirebaseMessaging.onMessage.listen(
      (RemoteMessage message) async {
        await _handleRemoteMessage(message, source: 'foreground');
      },
    );

    FirebaseMessaging.onMessageOpenedApp.listen(
      (RemoteMessage message) async {
        await _handleRemoteMessage(message, source: 'opened_app');
      },
    );

    final initialMsg = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMsg != null) {
      await _handleRemoteMessage(initialMsg, source: 'opened_app');
    }

    _initialized = true;
  }

  Future<void> _ensureLocalNotificationsInitialized() async {
    const AndroidInitializationSettings androidInitSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initSettings =
        InitializationSettings(android: androidInitSettings);

    await _localNotificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: handleNotificationResponse,
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    const AndroidNotificationChannel incomingCallChannel =
        AndroidNotificationChannel(
      _incomingCallChannelId,
      _incomingCallChannelName,
      description: _incomingCallChannelDescription,
      importance: Importance.max,
      playSound: true,
      showBadge: true,
    );

    final androidPlugin =
        _localNotificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(incomingCallChannel);
  }

  Future<void> _handleRemoteMessage(
    RemoteMessage message, {
    required String source,
  }) async {
    debugPrint('[NotificationService] _handleRemoteMessage from $source');

    final data = message.data;
    final notification = message.notification;

    debugPrint('[NotificationService]   data: $data');
    debugPrint('[NotificationService]   notification: $notification');

    final String? type = data['type'] as String?;
    final String title =
        data['caller_name'] as String? ?? notification?.title ?? 'Memora';
    final String body = data['description'] as String? ??
        notification?.body ??
        'You have a new message from Memora.';
    final String? callerName = data['caller_name'] as String? ?? title;
    final String? callId = data['call_id'] as String?;
    final String? userPhone = data['user_phone'] as String?;

    final bool isIncomingCall = type == 'incoming_call' && callId != null;
    debugPrint('[NotificationService]   isIncomingCall=$isIncomingCall');

    if (isIncomingCall) {
      debugPrint('[NotificationService]   Showing incoming call notification');
      await _showIncomingCallNotification(
        callerName: callerName ?? 'Memora',
        callId: callId!,
        initialMessage: body,
        userPhone: userPhone,
        presentationSource: source,
      );
    } else {
      await _showSimpleNotification(title: title, body: body, data: data);
    }
  }

  Future<void> _showIncomingCallNotification({
    required String callerName,
    required String callId,
    required String initialMessage,
    required String? userPhone,
    required String presentationSource,
  }) async {
    final bool useFullScreen =
        presentationSource == 'background'; // heads-up only

    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      _incomingCallChannelId,
      _incomingCallChannelName,
      channelDescription: _incomingCallChannelDescription,
      importance: Importance.max,
      priority: Priority.high,
      category: AndroidNotificationCategory.call,
      fullScreenIntent: useFullScreen,
      ongoing: true,
      autoCancel: false,
      playSound: true,
      ticker: 'Memora incoming call',
      actions: <AndroidNotificationAction>[
        const AndroidNotificationAction(
          _answerActionId,
          'Answer',
          showsUserInterface: true,
          cancelNotification: true,
        ),
        const AndroidNotificationAction(
          _declineActionId,
          'Decline',
          showsUserInterface: true,
          cancelNotification: true,
        ),
      ],
      visibility: NotificationVisibility.public,
    );

    final NotificationDetails details =
        NotificationDetails(android: androidDetails);

    final payload = jsonEncode({
      'type': 'incoming_call',
      'callerName': callerName,
      'callId': callId,
      'initialMessage': initialMessage,
      'userPhone': userPhone,
      'presentationSource': presentationSource,
      'forceFullScreen': useFullScreen,
    });

    debugPrint(
        '[NotificationService]   Posting notification payload: $payload');

    await _localNotificationsPlugin.show(
      _incomingCallNotificationId,
      callerName,
      initialMessage,
      details,
      payload: payload,
    );
  }

  Future<void> _showSimpleNotification({
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'memora_default_channel',
      'Memora Notifications',
      channelDescription: 'General notifications from Memora',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
    );

    const NotificationDetails details =
        NotificationDetails(android: androidDetails);

    final payload = jsonEncode({
      'type': 'generic',
      'title': title,
      'body': body,
      if (data != null) 'data': data,
    });

    await _localNotificationsPlugin.show(
      0,
      title,
      body,
      details,
      payload: payload,
    );
  }

  Future<void> handleNotificationResponse(NotificationResponse response) async {
    debugPrint(
        '[NotificationService] handleNotificationResponse actionId=${response.actionId} payload=${response.payload ?? 'null'}');

    if (response.payload == null) return;

    final Map<String, dynamic> data =
        jsonDecode(response.payload!) as Map<String, dynamic>;
    final String? type = data['type'] as String?;
    if (type == 'incoming_call') {
      await _handleIncomingCallNotificationResponse(response, data);
    }
  }

  Future<void> _handleIncomingCallNotificationResponse(
    NotificationResponse response,
    Map<String, dynamic> data,
  ) async {
    final String? callerName = data['callerName'] as String?;
    final String? callId = data['callId'] as String?;
    final String? initialMessageFromPayload = data['initialMessage'] as String?;
    final String? userPhone = data['userPhone'] as String?;
    final String actionId = response.actionId ?? '';

    debugPrint(
        '[NotificationService]   incoming_call response: callId=$callId userPhone=$userPhone actionId=$actionId source=${data['presentationSource']} payload=$data');

    if (callId == null) return;

    // No tap: escalate to in-app incoming screen.
    if (actionId.isEmpty) {
      debugPrint('[NotificationService]   No action; showing incoming call UI');
      await cancelIncomingCallNotification();
      if (userPhone != null && userPhone.isNotEmpty) {
        _navigateToIncomingCallScreen(
          callerName: callerName ?? 'Memora',
          callId: callId,
          initialMessage: initialMessageFromPayload ?? 'Hello, how can I help?',
        );
      }
      return;
    }

    final api = ApiService();

    if (actionId == _declineActionId) {
      if (userPhone != null && userPhone.isNotEmpty) {
        try {
          await api.declineCall(userPhone);
        } catch (e) {
          debugPrint('[NotificationService]   Failed to send declineCall: $e');
        }
      }

      await cancelIncomingCallNotification();
      navigatorKey.currentState?.popUntil((route) => route.isFirst);
      SystemNavigator.pop();
      return;
    }

    Map<String, dynamic>? backendResult;
    if (actionId == _answerActionId &&
        userPhone != null &&
        userPhone.isNotEmpty) {
      try {
        backendResult = await api.answerCall(userPhone);
      } catch (e) {
        debugPrint('[NotificationService]   Failed to send answerCall: $e');
      }
    }

    final String safeInitialMessage =
        (backendResult?['initial_message'] as String?) ??
            initialMessageFromPayload ??
            'Hello, how can I help?';

    await cancelIncomingCallNotification();

    if (userPhone == null || userPhone.isEmpty) return;

    _navigateToMainConversationScreen(
      userPhone: userPhone,
      initialMessage: safeInitialMessage,
    );
  }

  void _navigateToIncomingCallScreen({
    required String callerName,
    required String callId,
    required String initialMessage,
  }) {
    final nav = navigatorKey.currentState;
    if (nav == null) return;

    nav.push(
      MaterialPageRoute(
        builder: (_) => IncomingCallScreen(
          callerName: callerName,
          callId: callId,
          initialMessage: initialMessage,
        ),
      ),
    );
  }

  void _navigateToMainConversationScreen({
    required String userPhone,
    required String initialMessage,
  }) {
    final nav = navigatorKey.currentState;
    if (nav == null) return;

    nav.pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => MainConversationScreen(
          userPhone: userPhone,
          initialMessage: initialMessage,
        ),
      ),
      (route) => false,
    );
  }

  static Future<void> cancelIncomingCallNotification() async {
    await instance._localNotificationsPlugin
        .cancel(_incomingCallNotificationId);
  }
}
